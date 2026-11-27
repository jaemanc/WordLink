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
            **overrides,
        }

    def test_thresholds_and_hard_rejection(self):
        self.assertEqual(verdict(self.candidate(), self.pair), "approve")
        self.assertEqual(verdict(self.candidate(9), self.pair), "review")
        weak = self.candidate(0)
        weak["scores"]["logic"] = 15
        self.assertEqual(verdict(weak, self.pair), "review")
        weak["scores"]["logic"] = 14
        self.assertEqual(verdict(weak, self.pair), "reject")
        self.assertEqual(verdict(self.candidate(hardReject=True), self.pair), "reject")
        self.assertEqual(verdict(self.candidate(korean="자석묶음"), self.pair), "reject")

    def test_review_uses_one_alternate_and_caches_reversed_pair(self):
        calls = []
        first = self.candidate(9)
        second = self.candidate(result="Magnetometer", korean="자력계")

        def generate(pair, attempt, previous):
            self.assertEqual(pair, self.pair)
            calls.append((attempt, previous))
            return first if attempt == "initial" else second

        reviewer = RecipeReviewer(generate)
        self.assertEqual(reviewer.review(*reversed(self.pair)), second)
        self.assertEqual(reviewer.review(*self.pair), second)
        self.assertEqual(calls, [("initial", None), ("alternate", first)])

    def test_failed_regeneration_is_cached(self):
        calls = []

        def generate(pair, attempt, previous):
            calls.append(attempt)
            return None

        reviewer = RecipeReviewer(generate)
        self.assertIsNone(reviewer.review(*self.pair))
        self.assertIsNone(reviewer.review(*reversed(self.pair)))
        self.assertEqual(calls, ["initial", "regenerate"])

    def test_repeating_same_candidate_cannot_bypass_review(self):
        reviewer = RecipeReviewer(
            lambda pair, attempt, previous: self.candidate(9 if previous is None else 10)
        )
        self.assertIsNone(reviewer.review(*self.pair))


if __name__ == "__main__":
    unittest.main()
