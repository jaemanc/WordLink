"""Review AI recipe candidates offline before including them in the catalog."""
import json
import logging
import re
import sqlite3
import subprocess
import sys
from pathlib import Path

MAX_SCORES = {
    "existence": 25, "logic": 30, "intuition": 20, "independence": 15, "gameplay": 10,
}

RELATION_RANK = {
    "physical": 0, "purpose": 1, "function": 1,
    "association": 2, "umbrella": 2, "symbolic": 3,
}
LOGGER = logging.getLogger(__name__)
TERMINAL_ESCAPE = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")

ESTABLISHED_COMPOUNDS = {
    "vanillahotchocolate", "honeyvanillahotchocolate", "vanillaicecream",
    "honeyporridge", "lemonice", "honeylatte", "honeyvanillalatte", "chocolatemilk",
    "바닐라핫초코", "꿀바닐라핫초코", "바닐라아이스크림", "버터잼샌드위치",
    "유리병양초", "얼음물", "소금물", "레몬얼음", "왁스종이",
}


def validate_recipe_labels(a, b, result):
    def compact(label):
        return "".join(char for char in label.casefold() if char.isalnum())

    left, right, output = map(compact, (a, b, result))
    generic = re.search(
        r"\b(?:bundle|set|mixture|combination|collection|pack|lump)$"
        r"|(?:묶음|세트|혼합물|조합|덩어리|꾸러미)$",
        result.strip().casefold(),
    )
    joined = output in (left + right, right + left) and output not in ESTABLISHED_COMPOUNDS
    if not output or output in (left, right) or joined or generic or re.search(r"[+·]", result):
        raise ValueError(f"Invalid combination result: {a} + {b} -> {result}")


def verdict(candidate, pair):
    def decide(outcome, reason, total=None):
        LOGGER.info("%s: %s, score=%s, reason=%s", pair, outcome, total, reason)
        return outcome

    if not isinstance(candidate, dict) or candidate.get("inputs") != [word[0] for word in pair]:
        return decide("reject", "missing candidate or mismatched inputs")
    scores = candidate.get("scores")
    if not isinstance(scores, dict) or scores.keys() != MAX_SCORES.keys():
        return decide("reject", "missing rubric scores")
    if any(type(scores[key]) is not int or not 0 <= scores[key] <= limit
           for key, limit in MAX_SCORES.items()):
        return decide("reject", "score out of range")

    total = sum(scores.values())
    if candidate.get("hardReject") is not False:
        return decide("reject", candidate.get("rejectionReason") or "hard rejection", total)
    connections = candidate.get("connections")
    if (not isinstance(connections, list) or len(connections) != 2
            or any(not isinstance(note, str) or not note.strip() for note in connections)
            or not isinstance(candidate.get("existenceEvidence"), str)
            or not candidate["existenceEvidence"].strip()
            or candidate.get("relation") not in RELATION_RANK
            or type(candidate.get("concrete")) is not bool
            or not isinstance(candidate.get("result"), str)
            or not isinstance(candidate.get("korean"), str)):
        return decide("reject", "missing existence or relationship evidence", total)
    if any(re.search(r"[\r\n.!?;:]", candidate[key]) for key in ("result", "korean")):
        return decide("reject", "result label must be a single noun or noun phrase", total)
    try:
        validate_recipe_labels(pair[0][0], pair[1][0], candidate["result"])
        validate_recipe_labels(pair[0][1], pair[1][1], candidate["korean"])
    except ValueError as error:
        return decide("reject", str(error), total)

    if candidate.get("explainable") is not True:
        return decide("reject", "unconfirmed ingredient connections", total)
    return decide("approve", "both connections are explainable", total)


def candidate_priority(candidate):
    scores = candidate["scores"]
    return (
        RELATION_RANK[candidate["relation"]], not candidate["concrete"],
        -scores["intuition"], -sum(scores.values()), candidate["result"], candidate["korean"],
    )


class RecipeReviewer:
    def __init__(self, generate, database=None):
        self.generate = generate
        self.database = database
        self.cache = {}
        self.calls = 0
        if database is not None:
            database.execute(
                "CREATE TABLE IF NOT EXISTS recipe_successes "
                "(pair TEXT PRIMARY KEY, candidate TEXT NOT NULL)"
            )

    def review(self, left, right):
        pair = tuple(sorted((tuple(left), tuple(right))))
        if pair in self.cache:
            return self.cache[pair]

        key = json.dumps(pair, ensure_ascii=False)
        if self.database is not None:
            saved = self.database.execute(
                "SELECT candidate FROM recipe_successes WHERE pair = ?", (key,),
            ).fetchone()
            if saved:
                candidate = json.loads(saved[0])
                if verdict(candidate, pair) == "approve":
                    self.cache[pair] = candidate
                    return candidate

        previous = None
        result = None
        for attempt in ("initial", "regenerate"):
            self.calls += 1
            response = self.generate(pair, attempt, previous)
            candidates = (
                response["candidates"]
                if isinstance(response, dict) and isinstance(response.get("candidates"), list)
                else [response]
            )
            approved = [item for item in candidates if verdict(item, pair) == "approve"]
            if approved:
                result = min(approved, key=candidate_priority)
                break
            previous = response

        if result is not None and self.database is not None:
            with self.database:
                self.database.execute(
                    "INSERT OR REPLACE INTO recipe_successes VALUES (?, ?)",
                    (key, json.dumps(result, ensure_ascii=False)),
                )
        self.cache[pair] = result
        return result


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    command = sys.argv[1:]
    if not command:
        raise SystemExit("Pass a local model command that reads a prompt on stdin and writes JSON.")
    prompt = Path(__file__).with_name("inference_recipe_prompt.md").read_text(encoding="utf-8")

    def generate(pair, attempt, previous):
        request = json.dumps(
            {
                "inputs": [word[0] for word in pair],
                "koreanLabels": [word[1] for word in pair],
                "attempt": attempt,
                "previous": previous,
            }, ensure_ascii=False,
        )
        try:
            output = subprocess.run(
                command, input=f"{prompt}\n\n{request}\n", text=True,
                capture_output=True, check=True, timeout=120,
            ).stdout
            return json.loads(TERMINAL_ESCAPE.sub("", output))
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired, json.JSONDecodeError) as error:
            LOGGER.info("Model response unavailable: %s", type(error).__name__)
            return None

    cache_path = Path.home() / ".cache/wordlink/recipes.sqlite3"
    cache_path.parent.mkdir(parents=True, exist_ok=True)
    with sqlite3.connect(cache_path) as database:
        reviewer = RecipeReviewer(generate, database)
        results = [reviewer.review(left, right) for left, right in json.load(sys.stdin)]
    LOGGER.info("AI calls per request: %.2f (%s/%s)",
                reviewer.calls / len(results) if results else 0, reviewer.calls, len(results))
    print(json.dumps(results, ensure_ascii=False, indent=2))
