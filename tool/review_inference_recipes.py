"""Review AI recipe candidates offline before including them in the catalog."""
import json
import re
import subprocess
import sys
from pathlib import Path

MAX_SCORES = {
    "existence": 25, "logic": 30, "intuition": 20, "independence": 15, "gameplay": 10,
}


ESTABLISHED_COMPOUNDS = {
    "vanillahotchocolate", "honeyvanillahotchocolate", "vanillaicecream",
    "honeyporridge", "lemonice",
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
    if not isinstance(candidate, dict) or candidate.get("inputs") != [word[0] for word in pair]:
        return "reject"
    scores = candidate.get("scores")
    if not isinstance(scores, dict) or scores.keys() != MAX_SCORES.keys():
        return "reject"
    if any(type(scores[key]) is not int or not 0 <= scores[key] <= limit
           for key, limit in MAX_SCORES.items()):
        return "reject"

    connections = candidate.get("connections")
    if (candidate.get("hardReject") is not False
            or not isinstance(connections, list) or len(connections) != 2
            or any(not isinstance(note, str) or not note.strip() for note in connections)
            or not isinstance(candidate.get("existenceEvidence"), str)
            or not candidate["existenceEvidence"].strip()
            or candidate.get("relation") not in ("function", "physical", "purpose", "association")
            or type(candidate.get("concrete")) is not bool
            or not isinstance(candidate.get("result"), str)
            or not isinstance(candidate.get("korean"), str)):
        return "reject"
    try:
        validate_recipe_labels(pair[0][0], pair[1][0], candidate["result"])
        validate_recipe_labels(pair[0][1], pair[1][1], candidate["korean"])
    except ValueError:
        return "reject"

    total = sum(scores.values())
    return "approve" if total >= 85 else "review" if total >= 70 else "reject"


class RecipeReviewer:
    def __init__(self, generate):
        self.generate = generate
        self.cache = {}

    def review(self, left, right):
        pair = tuple(sorted((tuple(left), tuple(right))))
        if pair in self.cache:
            return self.cache[pair]

        first = self.generate(pair, "initial", None)
        decision = verdict(first, pair)
        if decision == "approve":
            result = first
        else:
            retry = "alternate" if decision == "review" else "regenerate"
            second = self.generate(pair, retry, first)
            result = None
            if verdict(second, pair) == "approve":
                same_result = isinstance(first, dict) and any(
                    isinstance(first.get(key), str)
                    and second[key].strip().casefold() == first[key].strip().casefold()
                    for key in ("result", "korean")
                )
                if not same_result:
                    result = second

        self.cache[pair] = result
        return result


if __name__ == "__main__":
    command = sys.argv[1:]
    if not command:
        raise SystemExit("Pass a local model command that reads a prompt on stdin and writes JSON.")
    prompt = Path(__file__).with_name("inference_recipe_prompt.md").read_text(encoding="utf-8")

    def generate(pair, attempt, previous):
        request = json.dumps(
            {"pair": pair, "attempt": attempt, "previous": previous}, ensure_ascii=False,
        )
        output = subprocess.run(
            command, input=f"{prompt}\n\n{request}\n", text=True,
            capture_output=True, check=True,
        ).stdout
        try:
            return json.loads(output)
        except json.JSONDecodeError:
            return None

    reviewer = RecipeReviewer(generate)
    results = [reviewer.review(left, right) for left, right in json.load(sys.stdin)]
    print(json.dumps(results, ensure_ascii=False, indent=2))
