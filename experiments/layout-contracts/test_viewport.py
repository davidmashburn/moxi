"""Executable contract probes for :mod:`viewport`.

These tests are intentionally scenario-shaped.  They exercise the failure
boundaries that a production viewport adapter must make explicit rather than
proving a particular rendering backend.
"""

from __future__ import annotations

import sys
from pathlib import Path
import unittest


# ``layout-contracts`` is an experiment directory rather than a Python package.
sys.path.insert(0, str(Path(__file__).parent))

from viewport import (  # noqa: E402
    FixedAddress,
    ItemAddress,
    ItemIdentity,
    LazyRowSource,
    RowSpec,
    ScrollAnchor,
    StaleSourceError,
    StaleViewportPlanError,
    UnrealizedItemError,
    Viewport,
    ViewportContractError,
)


def rows(*heights: float) -> list[RowSpec]:
    return [RowSpec(f"row-{index}", height) for index, height in enumerate(heights)]


class ViewportContractTests(unittest.TestCase):
    def make_viewport(
        self,
        *,
        viewport_extent: float = 30.0,
        gap: float = 2.0,
        overscan: int = 0,
    ) -> Viewport:
        return Viewport(
            header_extent=5.0,
            footer_extent=7.0,
            viewport_extent=viewport_extent,
            gap=gap,
            cross_extent=320.0,
            overscan=overscan,
        )

    def test_fixed_nodes_gaps_extent_and_content_coordinates(self) -> None:
        source = LazyRowSource("results", rows(10.0, 20.0))
        viewport = self.make_viewport(viewport_extent=100.0)

        frame = viewport.layout(source)

        # header + row extents + footer + one gap between each adjacent node.
        self.assertEqual(frame.content_extent, 5.0 + 10.0 + 20.0 + 7.0 + 3 * 2.0)
        self.assertEqual(frame.offset, 0.0)
        self.assertEqual(frame.max_offset, 0.0)
        self.assertEqual(frame.placement(FixedAddress("header")).content_start, 0.0)
        self.assertEqual(frame.placement(ItemAddress(source.section, "row-0")).content_start, 7.0)
        self.assertEqual(frame.placement(ItemAddress(source.section, "row-1")).content_start, 19.0)
        self.assertEqual(frame.placement(FixedAddress("footer")).content_start, 41.0)

    def test_visible_range_reports_a_gap_even_when_no_row_intersects(self) -> None:
        source = LazyRowSource("results", rows(10.0, 20.0))
        viewport = self.make_viewport(viewport_extent=1.0)

        # row-0 ends at 17, the gap is [17, 19), row-1 starts at 19.
        frame = viewport.layout(source, offset=18.0, anchor=None)

        self.assertEqual(frame.visible.row_indices, ())
        self.assertEqual(len(frame.visible.gaps), 1)
        gap = frame.visible.gaps[0]
        self.assertEqual(gap.before, ItemAddress(source.section, "row-0"))
        self.assertEqual(gap.after, ItemAddress(source.section, "row-1"))
        self.assertEqual((gap.content_start, gap.content_end), (17.0, 19.0))
        # The realization decision still keeps the nearest row bounded.
        self.assertEqual(frame.realized_addresses, (ItemAddress(source.section, "row-1"),))

    def test_changed_estimate_before_anchor_moves_offset_by_prefix_delta(self) -> None:
        source = LazyRowSource("results", rows(10.0, 10.0, 10.0))
        viewport = self.make_viewport(viewport_extent=12.0)
        anchor_address = ItemAddress(source.section, "row-2")

        first = viewport.layout(
            source,
            offset=34.0,
            anchor=ScrollAnchor(anchor_address, 3.0),
        )
        self.assertEqual(first.offset, 34.0)
        self.assertEqual(first.anchor.address, anchor_address)

        source.replace(rows(25.0, 10.0, 10.0))
        second = viewport.layout(source)

        # row-0 grew by 15; row-2 remains 3 points below the viewport origin.
        self.assertEqual(second.offset, 49.0)
        self.assertEqual(second.anchor.address, anchor_address)
        self.assertEqual(second.anchor.within_item_offset, 3.0)

    def test_measured_extent_before_anchor_preserves_anchor(self) -> None:
        source = LazyRowSource("results", rows(10.0, 10.0, 10.0))
        viewport = self.make_viewport(viewport_extent=12.0, overscan=2)
        anchor_address = ItemAddress(source.section, "row-2")
        first = viewport.layout(
            source,
            offset=23.0,
            anchor=ScrollAnchor(anchor_address, 3.0),
        )

        measured = viewport.apply_measured_extent(source, ItemAddress(source.section, "row-0"), 25.0)

        self.assertEqual(measured.offset, first.offset + 15.0)
        self.assertEqual(measured.anchor.address, anchor_address)
        self.assertEqual(measured.presented_start(anchor_address), -3.0)

    def test_estimate_after_anchor_does_not_move_anchor_unless_bottom_clamps(self) -> None:
        source = LazyRowSource("results", rows(10.0, 10.0, 10.0))
        viewport = self.make_viewport(viewport_extent=12.0)
        anchor_address = ItemAddress(source.section, "row-0")
        first = viewport.layout(
            source,
            offset=7.0,
            anchor=ScrollAnchor(anchor_address, 0.0),
        )

        source.replace(rows(10.0, 30.0, 10.0))
        second = viewport.layout(source)

        self.assertEqual(second.offset, first.offset)
        self.assertEqual(second.anchor.address, anchor_address)

    def test_reorder_preserves_key_identity_and_measurement(self) -> None:
        source = LazyRowSource("results", rows(10.0, 20.0, 30.0))
        viewport = self.make_viewport(viewport_extent=15.0, overscan=2)
        anchor_address = ItemAddress(source.section, "row-1")
        initial = viewport.layout(
            source,
            offset=20.0,
            anchor=ScrollAnchor(anchor_address, 4.0),
        )
        measured = viewport.apply_measured_extent(source, anchor_address, 24.0)
        self.assertEqual(measured.anchor.address, anchor_address)

        source.replace([RowSpec("row-2", 30.0), RowSpec("row-1", 1.0), RowSpec("row-0", 10.0)])
        reordered = viewport.layout(source)

        # The measured 24 survives by stable key; the supplied estimate of 1
        # cannot overwrite it.  Its new prefix location is 5 + gap + 30 + gap.
        self.assertEqual(reordered.placement(anchor_address).extent, 24.0)
        self.assertEqual(reordered.offset, 5.0 + 2.0 + 30.0 + 2.0 + 4.0)
        self.assertEqual(reordered.anchor.address, anchor_address)
        self.assertEqual(initial.anchor.address, anchor_address)

    def test_removed_anchor_chooses_next_then_previous_at_end(self) -> None:
        source = LazyRowSource("results", rows(10.0, 20.0, 30.0))
        viewport = self.make_viewport(viewport_extent=12.0)
        anchor_address = ItemAddress(source.section, "row-1")
        viewport.layout(source, offset=19.0, anchor=ScrollAnchor(anchor_address, 4.0))

        source.replace([RowSpec("row-0", 10.0), RowSpec("row-2", 30.0)])
        next_frame = viewport.layout(source)
        self.assertEqual(next_frame.anchor.address, ItemAddress(source.section, "row-2"))
        self.assertEqual(next_frame.anchor.within_item_offset, 4.0)

        # Now remove the final row as well.  There is no next survivor, so the
        # previous row becomes the anchor and the within offset is clamped.
        source.replace([RowSpec("row-0", 10.0)])
        final = viewport.layout(source)
        self.assertEqual(final.anchor.address, ItemAddress(source.section, "row-0"))
        self.assertEqual(final.anchor.within_item_offset, 4.0)
        self.assertLessEqual(final.offset, final.max_offset)

    def test_removed_end_anchor_fallback_does_not_reuse_removed_measurement(self) -> None:
        source = LazyRowSource("results", rows(10.0, 20.0))
        viewport = self.make_viewport(viewport_extent=10.0, overscan=1)
        anchor_address = ItemAddress(source.section, "row-1")
        viewport.layout(source, offset=20.0, anchor=ScrollAnchor(anchor_address, 5.0))
        viewport.apply_measured_extent(source, ItemAddress(source.section, "row-0"), 40.0)

        source.replace([RowSpec("row-0", 1.0)])
        final = viewport.layout(source)

        # row-0's measurement survives because it survived.  The removed row-1
        # measurement, if any, cannot affect the replacement frame.
        self.assertEqual(final.placement(ItemAddress(source.section, "row-0")).extent, 40.0)
        self.assertEqual(final.anchor.address, ItemAddress(source.section, "row-0"))

    def test_reintroduced_key_gets_new_generation_and_no_old_measurement(self) -> None:
        source = LazyRowSource("results", rows(10.0, 20.0))
        viewport = self.make_viewport(viewport_extent=20.0, overscan=1)
        row = ItemAddress(source.section, "row-0")
        first = viewport.layout(source)
        viewport.apply_measured_extent(source, row, 50.0)
        old_identity = first.realized[0]

        source.replace([RowSpec("row-1", 20.0)])
        viewport.layout(source)
        source.replace([RowSpec("row-0", 3.0)])
        reintroduced = viewport.layout(source)

        new_identity = reintroduced.realized[0]
        self.assertEqual(new_identity.address, row)
        self.assertNotEqual(new_identity.generation, old_identity.generation)
        self.assertEqual(reintroduced.placement(row).extent, 3.0)

    def test_stale_source_plan_is_cancelled_and_does_not_publish(self) -> None:
        source = LazyRowSource("results", rows(10.0, 20.0, 30.0))
        viewport = self.make_viewport(viewport_extent=20.0)
        before = viewport.layout(source)
        plan = viewport.prepare(source, offset=10.0, anchor=None)

        source.replace(rows(11.0, 21.0, 31.0))
        with self.assertRaises(StaleSourceError):
            viewport.commit(plan, source)

        self.assertIs(viewport.snapshot, before)
        self.assertEqual(source.cancelled, tuple(item.identity for item in plan.staged))
        self.assertEqual(source.mounted, before.realized)

    def test_stale_same_revision_plan_cannot_overwrite_newer_scroll(self) -> None:
        source = LazyRowSource("results", rows(20.0, 20.0, 20.0))
        viewport = self.make_viewport(viewport_extent=10.0)
        viewport.layout(source, offset=8.0, anchor=None)
        plan = viewport.prepare(source, offset=14.0, anchor=None)

        current = viewport.layout(source, offset=21.0, anchor=None)
        self.assertEqual(current.source_revision, 0)
        with self.assertRaises(StaleViewportPlanError):
            viewport.commit(plan, source)
        self.assertIs(viewport.snapshot, current)
        self.assertEqual(viewport.snapshot.offset, 21.0)

    def test_new_source_revision_keeps_ordinary_user_scroll_offset(self) -> None:
        source = LazyRowSource("results", rows(20.0, 20.0, 20.0))
        viewport = self.make_viewport(viewport_extent=10.0)

        scrolled = viewport.layout(source, offset=14.0, anchor=None)
        source.replace(rows(20.0, 20.0, 20.0))
        no_op = viewport.layout(source)

        self.assertGreater(no_op.source_revision, scrolled.source_revision)
        self.assertEqual(no_op.offset, scrolled.offset)

    def test_scroll_outside_rows_keeps_absolute_offset_on_new_source_revision(self) -> None:
        source = LazyRowSource("results", rows(10.0, 10.0))
        viewport = self.make_viewport(viewport_extent=1.0)

        # Header, the first inter-node gap, and footer are deliberately not
        # row anchors.  A new source revision must not snap to a nearby row.
        for offset in (1.0, 6.0, 32.0):
            with self.subTest(offset=offset):
                scrolled = viewport.layout(source, offset=offset, anchor=None)
                source.replace(rows(10.0, 10.0))
                no_op = viewport.layout(source)
                self.assertGreater(no_op.source_revision, scrolled.source_revision)
                self.assertIsNone(scrolled.anchor)
                self.assertIsNone(no_op.anchor)
                self.assertEqual(no_op.offset, offset)

    def test_finite_viewport_extent_and_offset_clamping(self) -> None:
        source = LazyRowSource("results", rows(20.0, 20.0))
        viewport = self.make_viewport(viewport_extent=15.0)

        frame = viewport.layout(source, offset=10_000.0, anchor=None)

        self.assertEqual(frame.content_extent, 5.0 + 20.0 + 20.0 + 7.0 + 3 * 2.0)
        self.assertEqual(frame.offset, frame.max_offset)
        self.assertTrue(frame.content_extent >= frame.viewport_extent)
        self.assertTrue(frame.offset + frame.viewport_extent <= frame.content_extent)
        with self.assertRaises(ViewportContractError):
            Viewport(header_extent=0.0, footer_extent=0.0, viewport_extent=float("inf"))
        with self.assertRaises(ViewportContractError):
            viewport.layout(source, offset=float("inf"), anchor=None)

    def test_realization_is_bounded_and_estimates_can_cover_full_extent(self) -> None:
        source = LazyRowSource("results", [RowSpec(f"row-{i}", 10.0) for i in range(100)])
        viewport = self.make_viewport(viewport_extent=30.0, overscan=1)

        frame = viewport.layout(source)

        self.assertEqual(len(source.estimate_calls), 100)
        self.assertLess(len(source.realize_calls), 100)
        self.assertEqual(len(frame.realized), 3)  # visible rows 0..1 + one overscan row
        self.assertEqual(frame.content_extent, 5.0 + 100 * 10.0 + 7.0 + 101 * 2.0)
        self.assertEqual(len(frame.placements), 102)  # metadata is not realization

    def test_measurement_requires_current_realized_item(self) -> None:
        source = LazyRowSource("results", rows(10.0, 20.0, 30.0))
        viewport = self.make_viewport(viewport_extent=10.0, overscan=0)
        viewport.layout(source)
        offscreen = ItemAddress(source.section, "row-2")
        if offscreen in viewport.snapshot.realized_addresses:
            self.skipTest("fixture unexpectedly realizes the third row")
        with self.assertRaises(UnrealizedItemError):
            viewport.apply_measured_extent(source, offscreen, 40.0)

if __name__ == "__main__":
    unittest.main(verbosity=2)
