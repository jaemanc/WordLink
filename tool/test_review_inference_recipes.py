import sqlite3
import unittest

from review_inference_recipes import RecipeReviewer, verdict


class RecipeReviewerTest(unittest.TestCase):
    pair = (("Magnet", "자석"), ("Needle", "바늘"))

    def candidate(self, gameplay=10, **overrides):
        return {
            "inputs": ["Magnet", "Needle"],
            "result": "Compass",
            "korean": "나침반",
            "connections": ["The magnet magnetizes.", "The needle can pivot."],
            "existenceEvidence": "Common navigation instrument.",
            "relation": "function",
            "concrete": True,
            "scores": {
                "existence": 25, "logic": 20, "intuition": 15,
                "independence": 15, "gameplay": gameplay,
            },
            "hardReject": False,
            "explainable": True,
            **overrides,
        }

    def test_scores_rank_candidates_without_an_approval_floor(self):
        low = self.candidate()
        low["scores"] = {key: 1 for key in low["scores"]}
        self.assertEqual(verdict(low, self.pair), "approve")
        self.assertEqual(verdict({**low, "explainable": False}, self.pair), "reject")

    def test_nonsense_and_unrelated_candidate_fixture(self):
        invalid = [
            self.candidate(hardReject=True),
            self.candidate(korean="자석묶음"),
            self.candidate(result="Magnet Needle", korean="자석바늘"),
            self.candidate(result="Clock", korean="시계", explainable=False),
            self.candidate(connections=["Needle only"]),
        ]
        self.assertEqual(sum(verdict(item, self.pair) == "approve" for item in invalid), 0)

    def test_one_call_ranks_approved_candidates_in_stages(self):
        direct = self.candidate(relation="physical", gameplay=0)
        symbolic = self.candidate(relation="symbolic", result="Direction", korean="방향")
        reviewer = RecipeReviewer(
            lambda *args: {"candidates": [symbolic, direct]}
        )
        self.assertEqual(reviewer.review(*self.pair), direct)
        self.assertEqual(reviewer.calls, 1)

    def test_explainable_candidate_needs_only_one_call(self):
        candidate = self.candidate(0)
        candidate["scores"]["intuition"] = 14
        calls = []

        def generate(pair, attempt, previous):
            calls.append(attempt)
            return candidate

        self.assertEqual(RecipeReviewer(generate).review(*self.pair), candidate)
        self.assertEqual(calls, ["initial"])

    def test_review_uses_one_alternate_and_caches_reversed_pair(self):
        calls = []
        first = self.candidate(hardReject=True)
        second = self.candidate(result="Magnetometer", korean="자력계")

        def generate(pair, attempt, previous):
            self.assertEqual(pair, self.pair)
            calls.append((attempt, previous))
            return first if attempt == "initial" else second

        reviewer = RecipeReviewer(generate)
        self.assertEqual(reviewer.review(*reversed(self.pair)), second)
        self.assertEqual(reviewer.review(*self.pair), second)
        self.assertEqual(calls, [("initial", None), ("regenerate", first)])

    def test_failed_regeneration_is_cached(self):
        calls = []

        def generate(pair, attempt, previous):
            calls.append(attempt)
            return None

        reviewer = RecipeReviewer(generate)
        self.assertIsNone(reviewer.review(*self.pair))
        self.assertIsNone(reviewer.review(*reversed(self.pair)))
        self.assertEqual(calls, ["initial", "regenerate"])

    def test_db_reuses_success_but_never_persists_failure(self):
        with sqlite3.connect(":memory:") as database:
            failed = RecipeReviewer(lambda *args: None, database)
            self.assertIsNone(failed.review(*self.pair))
            self.assertEqual(failed.calls, 2)
            candidate = self.candidate()
            recovered = RecipeReviewer(lambda *args: candidate, database)
            self.assertEqual(recovered.review(*self.pair), candidate)
            self.assertEqual(recovered.calls, 1)
            cached = RecipeReviewer(lambda *args: self.fail("model call"), database)
            self.assertEqual(cached.review(*reversed(self.pair)), candidate)
            self.assertEqual(cached.calls, 0)


if __name__ == "__main__":
    unittest.main()
