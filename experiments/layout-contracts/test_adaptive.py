"""Executable checks for the adaptive layout identity contract."""

import unittest

from adaptive import (
    AdaptiveRuntime,
    Column,
    DuplicateKeyError,
    Layout,
    Row,
    Slot,
    Split,
    UnknownKeyError,
)


class AdaptiveContractTests(unittest.TestCase):
    def _layout(self, policy, *children):
        return Layout("body", policy, tuple(children))

    def test_row_column_split_switch_preserves_slots_focus_editor_and_layout_owner(self):
        slots = (Slot("settings", "form"), Slot("results", "table"))
        runtime = AdaptiveRuntime("workbench")

        runtime.commit(self._layout(Row("body", gap=8), *slots), generation=1)
        settings_state = runtime.component_state("settings")
        results_state = runtime.component_state("results")
        layout_state = runtime.layout_state("body")
        draft = object()
        runtime.set_application_value("settings", draft)
        focused = runtime.focus_component("results")
        edited = runtime.begin_edit("results")

        runtime.commit(self._layout(Column("body", gap=12), *slots), generation=2)
        self.assertIs(runtime.component_state("settings"), settings_state)
        self.assertIs(runtime.component_state("results"), results_state)
        self.assertIs(runtime.layout_state("body"), layout_state)
        self.assertIs(runtime.component_state("settings").application_value, draft)
        self.assertEqual(runtime.component_focus, focused)
        self.assertEqual(runtime.active_editor, edited)
        self.assertEqual(runtime.snapshot.dividers, ())

        runtime.commit(self._layout(Split("body", initial_fraction=0.32), *slots), generation=3)
        self.assertIs(runtime.component_state("settings"), settings_state)
        self.assertIs(runtime.component_state("results"), results_state)
        self.assertIs(runtime.layout_state("body"), layout_state)
        self.assertEqual(runtime.component_focus, focused)
        self.assertEqual(runtime.active_editor, edited)
        self.assertEqual(len(runtime.snapshot.dividers), 1)
        allocations = [placement.allocation for placement in runtime.snapshot.placements]
        self.assertAlmostEqual(sum(allocations), 1.0)

    def test_split_controller_owns_chrome_and_hidden_divider_loses_interaction_state(self):
        slots = (Slot("settings", "form"), Slot("results", "table"))
        runtime = AdaptiveRuntime("workbench")
        runtime.commit(self._layout(Split("body", initial_fraction=0.32), *slots), 1)
        layout_state = runtime.layout_state("body")
        old_divider = runtime.snapshot.dividers[0]
        editor = runtime.begin_edit("settings")
        runtime.begin_resize(0)
        runtime.focus_divider(0)
        before = dict(layout_state.allocations)
        runtime.resize_divider(0.10)
        stored_allocation = dict(layout_state.allocations)

        self.assertNotEqual(stored_allocation, before)
        self.assertEqual(layout_state.resize_session.divider, old_divider)
        self.assertIsNone(runtime.component_focus)
        self.assertEqual(runtime.active_editor, editor)
        self.assertEqual(runtime.pointer_capture, old_divider)
        self.assertNotIn(old_divider, runtime.snapshot.component_identities)

        runtime.commit(self._layout(Column("body"), *slots), generation=3)
        self.assertEqual(runtime.snapshot.dividers, ())
        self.assertIsNone(runtime.divider_focus)
        self.assertIsNone(runtime.pointer_capture)
        self.assertIsNone(layout_state.resize_session)
        self.assertEqual(runtime.active_editor, editor)
        self.assertEqual(runtime.component_focus, editor)

        runtime.commit(self._layout(Split("body", initial_fraction=0.9), *slots), generation=4)
        new_divider = runtime.snapshot.dividers[0]
        self.assertNotEqual(new_divider, old_divider)
        self.assertGreater(
            new_divider.materialization_generation,
            old_divider.materialization_generation,
        )
        self.assertEqual(layout_state.allocations, stored_allocation)
        self.assertIsNone(runtime.divider_focus)
        self.assertIsNone(runtime.pointer_capture)
        self.assertIsNone(layout_state.resize_session)

    def test_removal_then_readdition_does_not_reuse_component_state_or_mount_generation(self):
        runtime = AdaptiveRuntime("workbench")
        runtime.commit(
            self._layout(Row("body"), Slot("editor", "text-field"), Slot("results", "table")),
            1,
        )
        old_state = runtime.component_state("editor")
        old_identity = old_state.identity
        runtime.set_application_value("editor", "draft")
        runtime.focus_component("editor")
        runtime.begin_edit("editor")

        runtime.commit(self._layout(Column("body"), Slot("results", "table")), 2)
        with self.assertRaises(UnknownKeyError):
            runtime.component_state("editor")
        self.assertIsNone(runtime.component_focus)
        self.assertIsNone(runtime.active_editor)

        runtime.commit(
            self._layout(Column("body"), Slot("editor", "text-field"), Slot("results", "table")),
            3,
        )
        fresh_state = runtime.component_state("editor")
        self.assertIsNot(fresh_state, old_state)
        self.assertNotEqual(fresh_state.identity, old_identity)
        self.assertEqual(fresh_state.identity.mount_generation, old_identity.mount_generation + 1)
        self.assertIsNone(fresh_state.application_value)

    def test_same_key_type_replacement_is_a_remount(self):
        runtime = AdaptiveRuntime("workbench")
        runtime.commit(self._layout(Row("body"), Slot("editor", "text-field")), 1)
        old_state = runtime.component_state("editor")
        runtime.focus_component("editor")
        runtime.begin_edit("editor")

        runtime.commit(self._layout(Row("body"), Slot("editor", "label")), 2)
        new_state = runtime.component_state("editor")
        self.assertIsNot(new_state, old_state)
        self.assertEqual(new_state.identity.mount_generation, old_state.identity.mount_generation + 1)
        self.assertEqual(new_state.component_type, "label")
        self.assertIsNone(runtime.component_focus)
        self.assertIsNone(runtime.active_editor)

    def test_duplicate_active_keys_fail_before_mutating_the_previous_snapshot(self):
        runtime = AdaptiveRuntime("workbench")
        runtime.commit(self._layout(Row("body"), Slot("a", "label"), Slot("b", "label")), 1)
        state = runtime.component_state("a")
        runtime.focus_component("a")
        runtime.begin_edit("a")

        with self.assertRaises(DuplicateKeyError):
            runtime.commit(self._layout(Column("body"), Slot("a"), Slot("a")), 2)

        self.assertEqual(runtime.snapshot.generation, 1)
        self.assertIs(runtime.component_state("a"), state)
        self.assertEqual(runtime.component_focus, state.identity)
        self.assertEqual(runtime.active_editor, state.identity)

    def test_stale_generation_is_a_noop_even_if_candidate_would_replace_a_type(self):
        runtime = AdaptiveRuntime("workbench")
        runtime.commit(self._layout(Row("body"), Slot("editor", "text-field")), 4)
        state = runtime.component_state("editor")
        runtime.focus_component("editor")
        runtime.begin_edit("editor")
        snapshot = runtime.snapshot

        result = runtime.commit(
            self._layout(Column("body"), Slot("editor", "label")),
            generation=3,
        )

        self.assertFalse(result.accepted)
        self.assertTrue(result.stale)
        self.assertIs(result.snapshot, snapshot)
        self.assertIs(runtime.component_state("editor"), state)
        self.assertEqual(runtime.component_focus, state.identity)
        self.assertEqual(runtime.active_editor, state.identity)

    def test_split_allocations_follow_pane_keys_when_order_changes(self):
        runtime = AdaptiveRuntime("workbench")
        runtime.commit(self._layout(Split("body", initial_fraction=0.3), Slot("a"), Slot("b")), 1)
        state_a = runtime.component_state("a")
        state_b = runtime.component_state("b")
        runtime.begin_resize(0)
        runtime.resize_divider(0.15)
        allocations = dict(runtime.layout_state("body").allocations)
        old_divider = runtime.snapshot.dividers[0]

        runtime.commit(self._layout(Split("body"), Slot("b"), Slot("a")), 3)
        self.assertIs(runtime.component_state("a"), state_a)
        self.assertIs(runtime.component_state("b"), state_b)
        self.assertEqual(runtime.layout_state("body").allocations, allocations)
        self.assertEqual(runtime.snapshot.placements[0].allocation, allocations["b"])
        self.assertEqual(runtime.snapshot.placements[1].allocation, allocations["a"])
        self.assertNotEqual(runtime.snapshot.dividers[0], old_divider)
        self.assertIsNone(runtime.layout_state("body").resize_session)
        self.assertIsNone(runtime.pointer_capture)

    def test_changing_layout_owner_key_does_not_leak_split_state(self):
        runtime = AdaptiveRuntime("workbench")
        children = (Slot("a"), Slot("b"))
        runtime.commit(Layout("body", Split("body", 0.25), children), 1)
        old_component_a = runtime.component_state("a")
        old_layout_state = runtime.layout_state("body")
        runtime.begin_resize(0)
        runtime.resize_divider(0.1)
        old_allocations = dict(old_layout_state.allocations)

        runtime.commit(Layout("other", Split("other", 0.75), children), 3)
        with self.assertRaises(UnknownKeyError):
            runtime.layout_state("body")
        new_layout_state = runtime.layout_state("other")
        self.assertIsNot(new_layout_state, old_layout_state)
        self.assertNotEqual(new_layout_state.allocations, old_allocations)
        self.assertAlmostEqual(new_layout_state.allocations["a"], 0.75)
        self.assertIsNot(runtime.component_state("a"), old_component_a)
        self.assertEqual(
            runtime.component_state("a").identity.mount_generation,
            old_component_a.identity.mount_generation + 1,
        )

    def test_divider_materialization_ids_do_not_collide_after_owner_key_reuse(self):
        runtime = AdaptiveRuntime("workbench")
        children = (Slot("a"), Slot("b"))
        runtime.commit(Layout("body", Split("body"), children), 1)
        body_first = runtime.snapshot.dividers[0]
        runtime.commit(Layout("other", Split("other"), children), 2)
        other = runtime.snapshot.dividers[0]
        runtime.commit(Layout("body", Split("body"), children), 3)
        body_second = runtime.snapshot.dividers[0]

        self.assertNotEqual(body_first, other)
        self.assertNotEqual(body_first, body_second)
        self.assertNotEqual(other, body_second)
        self.assertLess(
            body_first.materialization_generation,
            other.materialization_generation,
        )
        self.assertLess(
            other.materialization_generation,
            body_second.materialization_generation,
        )


if __name__ == "__main__":
    unittest.main()
