import unittest
from dataclasses import replace

from measurement import Context, Leaf, Placement, Plan, Proposal, baseline_pair


class MeasurementContractTests(unittest.TestCase):
    def setUp(self):
        self.context = Context()
        self.children = [Leaf("label", "A", ascent=8, descent=2),
                         Leaf("field", "abcdefgh", ascent=6, descent=3)]

    def test_distinct_queries_cached_independently(self):
        child = self.children[1]
        natural = self.context.measure(child, Proposal("unbounded"))
        zero = self.context.measure(child, Proposal("exactly", 0))
        self.assertEqual(natural.width, 40)
        self.assertEqual(zero.width, 0)
        self.assertTrue(zero.overflow)
        self.assertIs(zero, self.context.measure(child, Proposal("exactly", 0)))
        self.assertEqual(self.context.calls, 2)

    def test_wrapping_threshold_remeasures_only_changed_offer(self):
        wide = baseline_pair(self.context, self.children, 54, 10)
        narrow = baseline_pair(self.context, self.children, 53, 10)
        self.assertEqual(wide.height, 11)
        self.assertEqual(narrow.height, 20)
        self.assertEqual(self.context.calls, 3)
        self.assertIs(wide.placements[0].measurement, narrow.placements[0].measurement)

    def test_baseline_height_accounts_for_ascent_and_descent(self):
        plan = baseline_pair(self.context, self.children, 54, 10)
        self.assertEqual([p.y + p.measurement.baseline for p in plan.placements], [8, 8])
        # max(child.height) = 10 is WRONG: the baseline-aligned union is 11.
        self.assertEqual(plan.height, 11)
        self.assertTrue(all(p.y + p.measurement.height <= plan.height for p in plan.placements))

    def test_unchanged_and_paint_only_change_reuse_results(self):
        before = baseline_pair(self.context, self.children, 54, 10)
        self.children[1].paint_revision += 1
        after = baseline_pair(self.context, self.children, 54, 10)
        self.assertEqual(before, after)
        self.assertEqual(self.context.calls, 2)

    def test_text_edit_invalidates_old_plan_and_only_affected_leaf(self):
        before = baseline_pair(self.context, self.children, 54, 10)
        self.children[1].replace_text("abcdefghijklmnop")
        with self.assertRaisesRegex(ValueError, "stale"):
            before.validate(self.children, self.context)
        after = baseline_pair(self.context, self.children, 54, 10)
        self.assertEqual(self.context.calls, 3)
        self.assertGreater(after.height, before.height)

    def test_font_environment_and_remount_invalidate_tokens(self):
        plan = baseline_pair(self.context, self.children, 54, 10)
        self.context.environment += 1
        with self.assertRaisesRegex(ValueError, "stale"):
            plan.validate(self.children, self.context)
        fresh = baseline_pair(self.context, self.children, 54, 10)
        self.children[0].generation += 1
        with self.assertRaisesRegex(ValueError, "stale"):
            fresh.validate(self.children, self.context)

    def test_equal_geometry_does_not_make_old_content_token_valid(self):
        before = baseline_pair(self.context, self.children, 54, 10)
        self.children[1].replace_text("ABCDEFGH")
        after = baseline_pair(self.context, self.children, 54, 10)
        self.assertEqual((before.width, before.height), (after.width, after.height))
        self.assertNotEqual(before.placements[1].measurement.stamp,
                            after.placements[1].measurement.stamp)
        with self.assertRaisesRegex(ValueError, "stale"):
            before.validate(self.children, self.context)

    def test_final_allocation_cannot_reuse_natural_width_token(self):
        token = self.context.measure(self.children[0], Proposal("unbounded"))
        plan = Plan(10, 10, (Placement("label", 0, 0, token),))
        with self.assertRaisesRegex(ValueError, "exactly"):
            plan.validate(self.children[:1], self.context)

    def test_missing_duplicate_and_foreign_placements_rejected(self):
        plan = baseline_pair(self.context, self.children, 54, 10)
        for placements in (plan.placements[:1], (plan.placements[0],) * 2,
                           (replace(plan.placements[0], key="alien"), plan.placements[1])):
            with self.assertRaisesRegex(ValueError, "one placement"):
                replace(plan, placements=placements).validate(self.children, self.context)

    def test_nonfinite_and_negative_proposals_rejected(self):
        for value in (-1, float("nan"), float("inf")):
            with self.assertRaises(ValueError):
                Proposal("exactly", value)


if __name__ == "__main__":
    unittest.main()
