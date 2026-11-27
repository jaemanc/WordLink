"""Build offline WordLink inference boards with a proof for each starting hand."""
import heapq
from functools import lru_cache
from itertools import combinations
import json
import logging
import random
from collections import defaultdict
from pathlib import Path

from review_inference_recipes import candidate_priority, validate_recipe_labels, verdict

ASSETS = Path(__file__).resolve().parents[1] / "assets/inference"
BOARDS_PER_LEVEL = 10_000
HAND_SIZE = 16
SCORES = (100, 88, 76, 64, 52, 43, 35, 28, 22, 17, 14, 12, 10)


def bake():
    data = json.loads((ASSETS / "lexicon.json").read_text(encoding="utf-8"))
    words = dict(data["starts"])
    starter_words = set(words)
    recipes = {}
    reverse = defaultdict(list)
    edges = defaultdict(dict)

    def link(a, b, weight):
        edges[a][b] = min(weight, edges[a].get(b, weight))
        edges[b][a] = min(weight, edges[b].get(a, weight))

    def add_recipe(pair, result):
        a, b = pair
        validate_recipe_labels(a, b, result)
        validate_recipe_labels(words[a], words[b], words[result])
        recipes[pair] = result
        reverse[result].append(pair)
        link(a, result, 1)
        link(b, result, 1)

    for a, b, result, korean in data["recipes"]:
        pair = tuple(sorted((a, b)))
        if pair in recipes or result in words or not {a, b} <= words.keys():
            raise ValueError(f"Invalid or duplicate recipe: {pair} -> {result}")
        words[result] = korean
        add_recipe(pair, result)
    for a, b, result in data["alternativeRecipes"]:
        pair = tuple(sorted((a, b)))
        if pair in recipes or result not in reverse or result in starter_words or not {a, b} <= words.keys():
            raise ValueError(f"Invalid or duplicate alternative: {pair} -> {result}")
        add_recipe(pair, result)

    candidates = []
    known_ingredients = set(words)
    entries = list(data["semanticRecipes"])
    for result, korean, members in data["sharedConcepts"]:
        for a, b in combinations(members, 2):
            entries.append({
                "inputs": [a, b], "result": result, "korean": korean,
                "relation": "umbrella", "concrete": False,
                "connections": [f"{word} is a member of {result}." for word in (a, b)],
                "existenceEvidence": "Reviewed dictionary category.",
                "scores": dict(existence=25, logic=23, intuition=15, independence=12, gameplay=5),
                "hardReject": False, "explainable": True,
            })
    for entry in entries:
        a, b = entry["inputs"]
        if a == b or not {a, b} <= known_ingredients:
            raise ValueError(f"Invalid semantic recipe inputs: {entry['inputs']}")
        pair = [(a, words[a]), (b, words[b])]
        if verdict(entry, pair) != "approve":
            continue
        result, korean = entry["result"], entry["korean"]
        priority = candidate_priority(entry)
        candidates.append((priority, tuple(sorted((a, b))), result, korean))

    for _, pair, result, korean in sorted(candidates):
        if pair in recipes:
            continue
        if words.setdefault(result, korean) != korean:
            raise ValueError(f"Conflicting Korean label for {result}")
        add_recipe(pair, result)
    for group in data["topics"]:
        for index, a in enumerate(group):
            for b in group[index + 1:]:
                link(a, b, 2)

    ids = {word: index for index, word in enumerate(words)}

    def distances(target):
        found = {target: 0}
        queue = [(0, target)]
        while queue:
            distance, name = heapq.heappop(queue)
            if distance != found[name]:
                continue
            for other, weight in edges[name].items():
                candidate = distance + weight
                if candidate < found.get(other, len(SCORES)):
                    found[other] = candidate
                    heapq.heappush(queue, (candidate, other))
        return {word: SCORES[found[word]] if word in found else 0 for word in words}

    @lru_cache(maxsize=None)
    def proofs(word):
        found = {
            (left | right, left_steps | right_steps | {word})
            for a, b in reverse.get(word, ())
            for left, left_steps in proofs(a)
            for right, right_steps in proofs(b)
        }
        if word in starter_words:
            found.add((frozenset({word}), frozenset()))
        return tuple(sorted(found, key=lambda proof: (len(proof[1]), sorted(proof[0]), sorted(proof[1]))))

    def closure(hand):
        reachable = set(hand)
        while True:
            size = len(reachable)
            for (a, b), result in recipes.items():
                if a in reachable and b in reachable:
                    reachable.add(result)
            if len(reachable) == size:
                return reachable

    goals = [[], [], []]
    scores = {}
    answer_words = data["answerWords"]
    if len(set(answer_words)) != len(answer_words):
        raise ValueError("Duplicate reviewed answer")
    for target in answer_words:
        if target not in reverse or any(not 1 <= len(label.split()) <= 3
                                        for label in (target, words[target])):
            raise ValueError(f"Invalid reviewed answer: {target}")
        paths = proofs(target)
        near_scores = distances(target)
        nearby = sorted(word for word in starter_words - {target} if near_scores[word] >= 10)
        nearby_set = set(nearby)
        available_paths = [(needed, steps) for needed, steps in paths if needed <= nearby_set]
        if len(nearby) < HAND_SIZE or not available_paths:
            raise ValueError(f"No playable hand for reviewed answer: {target}")
        moves = len(available_paths[0][1])
        level = 0 if moves <= 2 else 1 if moves == 3 else 2
        path_words = set().union(*(steps for _, steps in paths))
        traps = [
            (word, trap_inputs)
            for word in sorted(reverse.keys() - path_words - starter_words)
            if 25 <= near_scores[word] < 100
            for trap_inputs, _ in proofs(word)
            if trap_inputs <= nearby_set
        ]
        candidates = set()
        for needed, steps in available_paths:
            if (0 if len(steps) <= 2 else 1 if len(steps) == 3 else 2) != level:
                continue
            for trap, trap_inputs in traps:
                combined = needed | trap_inputs
                if len(combined) < HAND_SIZE:
                    candidates.add((combined, trap, False))
                for other_needed, other_steps in available_paths:
                    if (other_needed, other_steps) != (needed, steps):
                        branched = combined | other_needed
                        if len(branched) < HAND_SIZE:
                            candidates.add((branched, trap, True))
        candidates = sorted(candidates, key=lambda entry: (entry[2], sorted(entry[0]), entry[1]))
        if not candidates:
            raise ValueError(f"No suitable distractor for reviewed answer: {target}")
        goals[level].append((target, nearby, candidates, available_paths, moves))
        scores[ids[target]] = list(near_scores.values())

    for level, candidates in enumerate(goals):
        if not candidates:
            raise ValueError(f"No solvable goals at level {level}")
        randomizer = random.Random(9407 + level)
        seen = set()
        boards = []
        multiple_routes = 0
        for index in range(BOARDS_PER_LEVEL):
            target, nearby, starting_proofs, all_proofs, moves = candidates[index % len(candidates)]
            branch_options = [entry for entry in starting_proofs if entry[2]]
            options = branch_options if branch_options and index % 2 == 0 else starting_proofs
            for attempt in range(2000):
                required, trap, _ = randomizer.choice(options)
                extras = sorted(set(nearby) - required)
                hand = required | set(randomizer.sample(extras, HAND_SIZE - len(required)))
                starter_ids = tuple(sorted(ids[word] for word in hand))
                board = (ids[target], *starter_ids)
                distances_in_hand = [len(steps) for needed, steps in all_proofs if needed <= hand]
                if starter_ids not in seen and min(distances_in_hand) == moves:
                    break
            else:
                raise ValueError(f"Exhausted distinct starting hands for {target}")
            reached = closure(hand)
            assert target not in hand and {target, trap} <= reached
            assert all(scores[ids[target]][word] >= 10 for word in starter_ids)
            multiple_routes += len(distances_in_hand) > 1
            seen.add(starter_ids)
            boards.append((*board, min(distances_in_hand)))
        (ASSETS / f"level_{level}.json").write_text(
            "[\n" + ",\n".join(json.dumps(row, separators=(",", ":")) for row in boards) + "\n]\n",
            encoding="utf-8",
        )
        print(f"Level {level}: {len(boards)} hands, {len(candidates)} goals, {multiple_routes} hands with alternatives")

    (ASSETS / "engine.json").write_text(
        json.dumps(
            {
                "words": list(words.items()),
                "recipes": [[ids[a], ids[b], ids[result]] for (a, b), result in recipes.items()],
                "scores": scores,
                "handSize": HAND_SIZE,
            },
            ensure_ascii=False,
            separators=(",", ":"),
        ) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    bake()
