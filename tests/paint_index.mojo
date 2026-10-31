"""Regression coverage for indexed paint invalidation."""

from moxi import (
    CONTAINER_KIND,
    LABEL_KIND,
    PANEL_KIND,
    SCROLLBAR_KIND,
    Color,
    ColumnRuntime,
    ColumnView,
    PaintCommands,
    Rect,
    Style,
    test_check,
)


comptime OUTER_ID = 10
comptime INNER_ID = 20
comptime COMPONENT_SLOT_ID = 90
comptime SHARED_ID = 77


def check(condition: Bool, label: String):
    if not condition:
        print(label)
    test_check(condition)


def same_rect(left: Rect, right: Rect) -> Bool:
    return (
        left.x == right.x
        and left.y == right.y
        and left.width == right.width
        and left.height == right.height
    )


def covers(outer: Rect, inner: Rect) -> Bool:
    return (
        outer.x <= inner.x
        and outer.y <= inner.y
        and outer.x + outer.width >= inner.x + inner.width
        and outer.y + outer.height >= inner.y + inner.height
    )


def command_index(commands: PaintCommands, kind: Int, id: Int) -> Int:
    for index in range(commands.count()):
        var command = commands.command(index)
        if command.kind == kind and command.id == id:
            return index
    return -1


def has_removed_region(commands: PaintCommands, bounds: Rect) -> Bool:
    for index in range(commands.removed_count()):
        if same_rect(commands.removed_region(index), bounds):
            return True
    return False


struct PaintHarness:
    var runtime: ColumnRuntime

    def __init__(out self):
        self.runtime = ColumnRuntime()

    def frame(mut self, view: ColumnView) -> PaintCommands:
        var laid_out = view.clone()
        laid_out.layout()
        self.runtime.reconcile(laid_out)
        return self.runtime.paint()


def ordered_view(reversed: Bool) -> ColumnView:
    var view = ColumnView(Rect(0.0, 0.0, 240.0, 120.0), 8.0, 4.0)
    if reversed:
        view.add_label(2, "Second", 24.0)
        view.add_label(1, "First", 24.0)
    else:
        view.add_label(1, "First", 24.0)
        view.add_label(2, "Second", 24.0)
    return view^


def removable_view(include_removed: Bool, removed_text: String) -> ColumnView:
    var view = ColumnView(Rect(0.0, 0.0, 240.0, 120.0), 8.0, 4.0)
    view.add_label(10, "Kept", 24.0)
    if include_removed:
        view.add_label(11, removed_text, 24.0)
    return view^


def component_in_portal_view(scroll_offset: Float32) -> ColumnView:
    var root = ColumnView(Rect(0.0, 0.0, 220.0, 100.0), 0.0, 0.0)
    root.set_clip_to_bounds()
    var outer = root.add_portal(OUTER_ID, 50.0, 0.0, 0.0, scroll_offset)

    var component = ColumnView(Rect(0.0, 0.0, 180.0, 70.0), 4.0, 2.0)
    component.set_clip_to_bounds()
    component.add_label(1, "Component child", 24.0)
    root.add_component_view_to(
        outer,
        COMPONENT_SLOT_ID,
        component,
        100,
        70.0,
    )
    return root^


def panel_and_scrollbar_view(panel_style: Style) -> ColumnView:
    var view = ColumnView(Rect(0.0, 0.0, 220.0, 100.0), 0.0, 0.0)
    view.set_panel(SHARED_ID, Rect(0.0, 0.0, 220.0, 100.0), panel_style)
    var portal = view.add_portal(SHARED_ID, 40.0, 0.0, 0.0)
    view.add_label_to(portal, 1, "one", 24.0)
    view.add_label_to(portal, 2, "two", 24.0)
    view.add_label_to(portal, 3, "three", 24.0)
    return view^


def nested_overflow_view(
    overflow: Bool,
    outer_offset: Float32,
    inner_offset: Float32,
) -> ColumnView:
    var root = ColumnView(Rect(0.0, 0.0, 240.0, 120.0), 8.0, 4.0)
    root.set_clip_to_bounds()
    var outer = root.add_portal(OUTER_ID, 70.0, 0.0, 4.0, outer_offset)
    var inner = root.add_portal_to(
        outer,
        INNER_ID,
        40.0,
        0.0,
        4.0,
        inner_offset,
    )
    root.add_label_to(inner, 31, "one", 24.0)
    if overflow:
        root.add_label_to(inner, 32, "two", 24.0)
        root.add_label_to(inner, 33, "three", 24.0)
        root.add_label_to(outer, 41, "outer one", 24.0)
        root.add_label_to(outer, 42, "outer two", 24.0)
    return root^


def main():
    # An unchanged command stream is completely idle after its first paint.
    var idle_harness = PaintHarness()
    var idle_view = ColumnView(Rect(0.0, 0.0, 240.0, 120.0), 8.0, 4.0)
    idle_view.add_label(1, "Stable", 24.0)
    _ = idle_harness.frame(idle_view)
    var idle_frame = idle_harness.frame(idle_view.clone())
    check(idle_frame.changed_count() == 0, "unchanged paint: changed count")
    check(idle_frame.removed_count() == 0, "unchanged paint: removed count")
    check(not idle_frame.has_dirty_region(), "unchanged paint: dirty region")

    # Text/style edits invalidate both the old and new geometry of the command.
    var edit_harness = PaintHarness()
    var old_view = ColumnView(Rect(0.0, 0.0, 240.0, 120.0), 8.0, 4.0)
    old_view.add_label(7, "Before", 24.0)
    old_view.layout()
    var old_bounds = old_view.bounds_for(7)
    _ = edit_harness.frame(old_view.clone())

    var new_style = Style(
        Color(0.35, 0.12, 0.48, 1.0),
        Color(0.95, 0.90, 0.98, 1.0),
        6.0,
        18.0,
    )
    var new_view = ColumnView(Rect(0.0, 0.0, 240.0, 120.0), 24.0, 4.0)
    new_view.add_label_styled(7, "After", 24.0, new_style)
    new_view.layout()
    var new_bounds = new_view.bounds_for(7)
    var edit_frame = edit_harness.frame(new_view.clone())
    var edited_index = command_index(edit_frame, LABEL_KIND, 7)
    check(edit_frame.changed_count() == 1, "text/style edit: changed count")
    check(edit_frame.removed_count() == 0, "text/style edit: removed count")
    check(edited_index >= 0, "text/style edit: command present")
    if edited_index >= 0:
        var edited = edit_frame.command(edited_index)
        check(edited.is_changed(), "text/style edit: command changed")
        check(edited.text == "After", "text/style edit: text updated")
        check(
            edited.style.fill.red == new_style.fill.red,
            "text/style edit: style updated",
        )
    check(
        covers(edit_frame.dirty_region(), old_bounds),
        "text/style edit: old bounds damaged",
    )
    check(
        covers(edit_frame.dirty_region(), new_bounds),
        "text/style edit: new bounds damaged",
    )

    # Reordering equal-kind commands changes their stream slots and redraws both.
    var reorder_harness = PaintHarness()
    _ = reorder_harness.frame(ordered_view(False))
    var reordered = reorder_harness.frame(ordered_view(True))
    check(reordered.changed_count() == 2, "reorder: changed count")
    check(
        reordered.command(command_index(reordered, LABEL_KIND, 1)).is_changed(),
        "reorder: first command changed",
    )
    check(
        reordered.command(command_index(reordered, LABEL_KIND, 2)).is_changed(),
        "reorder: second command changed",
    )
    check(reordered.removed_count() == 0, "reorder: removed count")

    # Removing the final command leaves exactly its old bounds; re-adding it is
    # a fresh changed command even though its stable identity is reused.
    var remove_harness = PaintHarness()
    var original = removable_view(True, "Old")
    original.layout()
    var removed_bounds = original.bounds_for(11)
    _ = remove_harness.frame(original.clone())
    var removed = remove_harness.frame(removable_view(False, "Unused"))
    check(removed.changed_count() == 0, "remove: changed count")
    check(removed.removed_count() == 1, "remove: removed count")
    check(
        same_rect(removed.removed_region(0), removed_bounds),
        "remove: old region",
    )

    var readded = remove_harness.frame(removable_view(True, "Fresh"))
    var readded_index = command_index(readded, LABEL_KIND, 11)
    check(readded.removed_count() == 0, "re-add: removed count")
    check(readded_index >= 0, "re-add: command present")
    if readded_index >= 0:
        check(
            readded.command(readded_index).is_changed(),
            "re-add: fresh command changed",
        )
        check(
            readded.command(readded_index).text == "Fresh",
            "re-add: fresh text",
        )

    # A component surface is itself a panel command, but its ancestor portal
    # supplies the clip while scrolling moves the surface outside that box.
    var component_harness = PaintHarness()
    var component_view = component_in_portal_view(12.0)
    component_view.layout()
    var outer_bounds = component_view.bounds_for(OUTER_ID)
    var component_frame = component_harness.frame(component_view.clone())
    var component_index = command_index(
        component_frame,
        PANEL_KIND,
        COMPONENT_SLOT_ID,
    )
    check(component_index >= 0, "component surface: panel present")
    check(
        command_index(component_frame, CONTAINER_KIND, COMPONENT_SLOT_ID) == -1,
        "component surface: container is not painted",
    )
    if component_index >= 0:
        var component_command = component_frame.command(component_index)
        check(
            component_command.bounds.y < outer_bounds.y,
            "component surface: scrolled bounds",
        )
        check(component_command.has_clip, "component surface: clip present")
        check(
            same_rect(
                component_command.clip_bounds,
                Rect(0.0, 0.0, 220.0, 100.0).intersection(outer_bounds),
            ),
            "component surface: ancestor clip",
        )

    # The panel and its overflowing portal intentionally share an id. Their
    # kind-qualified identities must remain independent across idle and edit frames.
    var panel_style = Style(
        Color(0.10, 0.14, 0.22, 1.0),
        Color(0.90, 0.95, 1.0, 1.0),
        8.0,
        16.0,
    )
    var panel_harness = PaintHarness()
    _ = panel_harness.frame(panel_and_scrollbar_view(panel_style))
    var shared_idle = panel_harness.frame(panel_and_scrollbar_view(panel_style))
    var panel_index = command_index(shared_idle, PANEL_KIND, SHARED_ID)
    var scrollbar_index = command_index(shared_idle, SCROLLBAR_KIND, SHARED_ID)
    check(panel_index >= 0, "shared id: panel present")
    check(scrollbar_index >= 0, "shared id: scrollbar present")
    check(shared_idle.changed_count() == 0, "shared id: idle changed count")
    check(shared_idle.removed_count() == 0, "shared id: idle removed count")

    var changed_panel_style = Style(
        Color(0.42, 0.12, 0.18, 1.0),
        Color(1.0, 0.92, 0.92, 1.0),
        8.0,
        16.0,
    )
    var shared_edit = panel_harness.frame(
        panel_and_scrollbar_view(changed_panel_style)
    )
    panel_index = command_index(shared_edit, PANEL_KIND, SHARED_ID)
    scrollbar_index = command_index(shared_edit, SCROLLBAR_KIND, SHARED_ID)
    check(shared_edit.changed_count() == 1, "shared id: panel-only changed count")
    check(
        shared_edit.command(panel_index).is_changed(),
        "shared id: panel changed",
    )
    check(
        not shared_edit.command(scrollbar_index).is_changed(),
        "shared id: scrollbar unchanged",
    )

    # Reconcile from no overflow to nested overflow and verify every ancestor
    # contributes to the leaf clip. The reverse transition also removes both bars.
    var overflow_harness = PaintHarness()
    var no_overflow = overflow_harness.frame(
        nested_overflow_view(False, 0.0, 0.0)
    )
    check(
        command_index(no_overflow, SCROLLBAR_KIND, OUTER_ID) == -1,
        "overflow update: outer initially not scrollable",
    )
    check(
        command_index(no_overflow, SCROLLBAR_KIND, INNER_ID) == -1,
        "overflow update: inner initially not scrollable",
    )

    var overflowing_view = nested_overflow_view(True, 10.0, 10.0)
    overflowing_view.layout()
    var nested_outer_bounds = overflowing_view.bounds_for(OUTER_ID)
    var nested_inner_bounds = overflowing_view.bounds_for(INNER_ID)
    var overflowing = overflow_harness.frame(overflowing_view.clone())
    var nested_leaf_index = command_index(overflowing, LABEL_KIND, 31)
    check(nested_leaf_index >= 0, "overflow update: nested leaf present")
    var expected_nested_clip = Rect(0.0, 0.0, 240.0, 120.0).intersection(
        nested_outer_bounds
    ).intersection(nested_inner_bounds)
    if nested_leaf_index >= 0:
        var nested_leaf = overflowing.command(nested_leaf_index)
        check(nested_leaf.has_clip, "overflow update: nested clip present")
        check(
            same_rect(nested_leaf.clip_bounds, expected_nested_clip),
            "overflow update: multiple ancestor intersection",
        )

    var outer_scrollbar_index = command_index(
        overflowing,
        SCROLLBAR_KIND,
        OUTER_ID,
    )
    var inner_scrollbar_index = command_index(
        overflowing,
        SCROLLBAR_KIND,
        INNER_ID,
    )
    check(outer_scrollbar_index >= 0, "overflow update: outer scrollbar added")
    check(inner_scrollbar_index >= 0, "overflow update: inner scrollbar added")
    if outer_scrollbar_index >= 0:
        check(
            overflowing.command(outer_scrollbar_index).is_changed(),
            "overflow update: outer scrollbar changed",
        )
    if inner_scrollbar_index >= 0:
        check(
            overflowing.command(inner_scrollbar_index).is_changed(),
            "overflow update: inner scrollbar changed",
        )

    if outer_scrollbar_index >= 0 and inner_scrollbar_index >= 0:
        var outer_scrollbar_bounds = overflowing.command(outer_scrollbar_index).bounds
        var inner_scrollbar_bounds = overflowing.command(inner_scrollbar_index).bounds
        var back_to_empty = overflow_harness.frame(
            nested_overflow_view(False, 0.0, 0.0)
        )
        check(
            command_index(back_to_empty, SCROLLBAR_KIND, OUTER_ID) == -1,
            "overflow update: outer scrollbar removed",
        )
        check(
            command_index(back_to_empty, SCROLLBAR_KIND, INNER_ID) == -1,
            "overflow update: inner scrollbar removed",
        )
        check(
            has_removed_region(back_to_empty, outer_scrollbar_bounds),
            "overflow update: outer stale region",
        )
        check(
            has_removed_region(back_to_empty, inner_scrollbar_bounds),
            "overflow update: inner stale region",
        )

    print("Moxi paint index regression test passed")
