from moxi import (
    ColumnView,
    Color,
    CONTAINER_KIND,
    PANEL_KIND,
    PaintCommands,
    Rect,
    SCROLLBAR_KIND,
    Style,
    test_check,
)
from moxi.baseline_runtime import ColumnRuntime as BaselineRuntime
from moxi.column_runtime import ColumnRuntime


comptime PANEL_AND_PORTAL_ID = 77
comptime COMPONENT_SLOT_ID = 90
comptime COMPONENT_OFFSET = 100
comptime TITLE_ID = 1
comptime BUTTON_ID = 2
comptime EDITOR_ID = 3
comptime CHECKBOX_ID = 4
comptime PORTAL_TITLE_ID = 78
comptime PORTAL_BUTTON_ID = 79
comptime PORTAL_EDITOR_ID = 80
comptime PORTAL_TAIL_ID = 81


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


def contains_command(commands: PaintCommands, kind: Int, id: Int) -> Bool:
    for index in range(commands.count()):
        var command = commands.command(index)
        if command.kind == kind and command.id == id:
            return True
    return False


def command_index(commands: PaintCommands, kind: Int, id: Int) -> Int:
    for index in range(commands.count()):
        var command = commands.command(index)
        if command.kind == kind and command.id == id:
            return index
    return -1


def compare_paints(left: PaintCommands, right: PaintCommands, label: String):
    check(left.count() == right.count(), label + ": command count")
    check(
        left.changed_count() == right.changed_count(),
        label + ": changed count",
    )
    check(
        left.removed_count() == right.removed_count(),
        label + ": removed count",
    )
    check(
        left.has_dirty_region() == right.has_dirty_region(),
        label + ": dirty-region presence",
    )

    if left.has_dirty_region() and right.has_dirty_region():
        check(
            same_rect(left.dirty_region(), right.dirty_region()),
            label + ": dirty bounds",
        )

    var common_count = left.count()
    if right.count() < common_count:
        common_count = right.count()
    for index in range(common_count):
        var left_command = left.command(index)
        var right_command = right.command(index)
        # equivalent covers every PaintCommand field except changed; compare
        # changed separately because it is the paint-diff result under test.
        check(
            left_command.equivalent(right_command),
            label + ": command fields " + String(index),
        )
        check(
            left_command.changed == right_command.changed,
            label + ": command changed " + String(index),
        )

    var common_removed = left.removed_count()
    if right.removed_count() < common_removed:
        common_removed = right.removed_count()
    for index in range(common_removed):
        check(
            same_rect(left.removed_region(index), right.removed_region(index)),
            label + ": removed region " + String(index),
        )


def make_view(
    bounds: Rect,
    edited: Bool,
    reordered: Bool,
    include_checkbox: Bool,
    include_tail: Bool,
    scroll_offset: Float32,
) -> ColumnView:
    var view = ColumnView(bounds, 8.0, 4.0)
    view.set_clip_to_bounds()

    var panel_style = Style(
        Color(0.08, 0.10, 0.14, 1.0),
        Color(0.18, 0.22, 0.30, 1.0),
        8.0,
        18.0,
        Color(0.32, 0.38, 0.48, 1.0),
        1.0,
        1.0,
    )
    if edited:
        panel_style = Style(
            Color(0.10, 0.08, 0.14, 1.0),
            Color(0.26, 0.18, 0.34, 1.0),
            8.0,
            18.0,
            Color(0.52, 0.34, 0.68, 1.0),
            1.0,
            1.0,
        )
    view.set_panel(
        PANEL_AND_PORTAL_ID,
        Rect(
            bounds.x + 4.0,
            bounds.y + 4.0,
            bounds.width - 8.0,
            bounds.height - 8.0,
        ),
        panel_style,
    )

    var title = "Title"
    var button_text = "Apply"
    var editor_text = "draft"
    var composition = "kana"
    var cursor = 4
    var selection_anchor = 1
    if edited:
        title = "Edited title"
        button_text = "Apply now"
        editor_text = "edited"
        composition = "nihon"
        cursor = 6
        selection_anchor = 2

    if reordered:
        view.add_button(BUTTON_ID, button_text, 32.0)
        view.add_label(TITLE_ID, title, 24.0)
    else:
        view.add_label(TITLE_ID, title, 24.0)
        view.add_button(BUTTON_ID, button_text, 32.0)

    var editor_style = Style(
        Color(0.06, 0.07, 0.09, 1.0),
        Color(0.14, 0.16, 0.20, 1.0),
        5.0,
        16.0,
        Color(0.34, 0.40, 0.50, 1.0),
        1.0,
        1.0,
    )
    if edited:
        editor_style = Style(
            Color(0.08, 0.06, 0.10, 1.0),
            Color(0.22, 0.14, 0.28, 1.0),
            5.0,
            16.0,
            Color(0.64, 0.40, 0.78, 1.0),
            1.0,
            1.0,
        )
    view.add_text_input_selection(
        EDITOR_ID,
        editor_text,
        32.0,
        editor_style,
        cursor,
        selection_anchor,
    )
    for index in range(view.child_count()):
        if view.children[index].id == EDITOR_ID:
            view.children[index].set_composition(
                composition,
                1 if edited else 0,
                4 if edited else 2,
            )

    if include_checkbox:
        view.add_checkbox(CHECKBOX_ID, "Remember", edited, 24.0)

    # This portal intentionally shares an ID with the panel. Its scrollbar is
    # therefore the same identity as the panel only when command kind is
    # included in the key.
    _ = view.add_portal(
        PANEL_AND_PORTAL_ID,
        70.0,
        6.0,
        2.0,
        scroll_offset,
    )
    if reordered:
        if include_tail:
            view.add_label_to(PANEL_AND_PORTAL_ID, PORTAL_TAIL_ID, "Tail", 24.0)
        view.add_text_input_to(
            PANEL_AND_PORTAL_ID,
            PORTAL_EDITOR_ID,
            "Nested input",
            28.0,
        )
        view.add_button_to(
            PANEL_AND_PORTAL_ID,
            PORTAL_BUTTON_ID,
            "Nested action",
            28.0,
        )
        view.add_label_to(
            PANEL_AND_PORTAL_ID,
            PORTAL_TITLE_ID,
            "Nested title",
            24.0,
        )
    else:
        view.add_label_to(
            PANEL_AND_PORTAL_ID,
            PORTAL_TITLE_ID,
            "Nested title",
            24.0,
        )
        view.add_button_to(
            PANEL_AND_PORTAL_ID,
            PORTAL_BUTTON_ID,
            "Nested action",
            28.0,
        )
        view.add_text_input_to(
            PANEL_AND_PORTAL_ID,
            PORTAL_EDITOR_ID,
            "Nested input",
            28.0,
        )
        if include_tail:
            view.add_label_to(PANEL_AND_PORTAL_ID, PORTAL_TAIL_ID, "Tail", 24.0)
    var component = ColumnView(Rect(0.0, 0.0, 100.0, 70.0), 3.0, 2.0)
    component.set_clip_to_bounds()
    component.add_label(1, "Component child", 28.0)
    component.add_button(2, "Component action", 28.0)
    view.add_component_view_to(
        PANEL_AND_PORTAL_ID, COMPONENT_SLOT_ID, component, COMPONENT_OFFSET, 50.0
    )
    return view^


struct ParityHarness:
    var candidate: ColumnRuntime
    var baseline: BaselineRuntime
    var frame_count: Int
    var changed: Int
    var removed: Int

    def __init__(out self):
        self.candidate = ColumnRuntime()
        self.baseline = BaselineRuntime()
        self.frame_count = 0
        self.changed = 0
        self.removed = 0

    def replay(
        mut self,
        view: ColumnView,
        focus: Int,
        hover: Int,
        press: Int,
        label: String,
        require_shared_panel_scrollbar: Bool = False,
    ):
        var candidate_view = view.clone()
        var baseline_view = view.clone()
        candidate_view.layout()
        baseline_view.layout()

        self.candidate.reconcile(candidate_view)
        self.baseline.reconcile(baseline_view)
        check(not self.candidate.validation_failed(), label + ": valid tree")

        _ = self.candidate.set_focus(focus)
        _ = self.baseline.set_focus(focus)
        _ = self.candidate.set_hover(hover)
        _ = self.baseline.set_hover(hover)
        _ = self.candidate.press(press)
        _ = self.baseline.press(press)

        check(
            self.candidate.widget_count() == self.baseline.widget_count(),
            label + ": widget count",
        )
        check(
            self.candidate.retained_count() == self.baseline.retained_count(),
            label + ": retained count",
        )
        check(
            self.candidate.last_created() == self.baseline.last_created(),
            label + ": created count",
        )
        check(
            self.candidate.last_reused() == self.baseline.last_reused(),
            label + ": reused count",
        )
        check(
            self.candidate.last_updated() == self.baseline.last_updated(),
            label + ": updated count",
        )
        check(
            self.candidate.last_removed() == self.baseline.last_removed(),
            label + ": removed count",
        )
        check(
            self.candidate.last_moved() == self.baseline.last_moved(),
            label + ": moved count",
        )
        check(
            self.candidate.validation_failed() == self.baseline.validation_failed(),
            label + ": validation result",
        )
        check(
            self.candidate.focus_id() == self.baseline.focus_id(),
            label + ": focus",
        )
        check(
            self.candidate.hover_id() == self.baseline.hover_id(),
            label + ": hover",
        )
        check(
            self.candidate.pressed_view_id() == self.baseline.pressed_view_id(),
            label + ": pressed view",
        )

        var candidate_paint = self.candidate.paint()
        var baseline_paint = self.baseline.paint()
        self.changed = candidate_paint.changed_count()
        self.removed = candidate_paint.removed_count()
        if require_shared_panel_scrollbar:
            check(contains_command(candidate_paint, PANEL_KIND, COMPONENT_SLOT_ID), label + ": component surface present")
            var panel_index = command_index(
                candidate_paint,
                PANEL_KIND,
                PANEL_AND_PORTAL_ID,
            )
            var scrollbar_index = command_index(
                candidate_paint,
                SCROLLBAR_KIND,
                PANEL_AND_PORTAL_ID,
            )
            check(panel_index >= 0, label + ": panel identity present")
            check(scrollbar_index >= 0, label + ": scrollbar identity present")
            check(
                panel_index < scrollbar_index,
                label + ": panel/scrollbar order",
            )
            check(
                contains_command(
                    candidate_paint,
                    CONTAINER_KIND,
                    PANEL_AND_PORTAL_ID,
                ) == False,
                label + ": portal is not painted as a leaf",
            )

        compare_paints(candidate_paint, baseline_paint, label)
        self.frame_count += 1


def main():
    var harness = ParityHarness()

    harness.replay(
        ColumnView(Rect(0.0, 0.0, 320.0, 160.0), 8.0, 4.0),
        -1,
        -1,
        -1,
        "empty first frame",
    )
    harness.replay(
        ColumnView(Rect(0.0, 0.0, 320.0, 160.0), 8.0, 4.0),
        -1,
        -1,
        -1,
        "empty idle frame",
    )

    harness.replay(
        make_view(
            Rect(0.0, 0.0, 360.0, 320.0),
            False,
            False,
            True,
            True,
            0.0,
        ),
        EDITOR_ID,
        BUTTON_ID,
        BUTTON_ID,
        "populated first frame",
        True,
    )
    harness.replay(
        make_view(
            Rect(0.0, 0.0, 360.0, 320.0),
            False,
            False,
            True,
            True,
            0.0,
        ),
        EDITOR_ID,
        BUTTON_ID,
        BUTTON_ID,
        "populated idle frame",
    )
    check(harness.changed == 0 and harness.removed == 0, "independent populated idle frame expectation")
    harness.replay(
        make_view(
            Rect(0.0, 0.0, 360.0, 320.0),
            True,
            False,
            True,
            True,
            0.0,
        ),
        EDITOR_ID,
        BUTTON_ID,
        BUTTON_ID,
        "text style selection composition edit",
    )
    check(harness.changed > 0, "independent text style selection composition edit expectation")
    harness.replay(
        make_view(
            Rect(0.0, 0.0, 360.0, 320.0),
            True,
            True,
            True,
            True,
            0.0,
        ),
        EDITOR_ID,
        BUTTON_ID,
        BUTTON_ID,
        "reordered frame",
    )
    harness.replay(
        make_view(
            Rect(0.0, 0.0, 360.0, 320.0),
            True,
            True,
            False,
            False,
            18.0,
        ),
        PORTAL_EDITOR_ID,
        PORTAL_BUTTON_ID,
        PORTAL_BUTTON_ID,
        "removal with nested scroll",
    )
    check(harness.removed == 2, "independent removal with nested scroll expectation")
    harness.replay(
        make_view(
            Rect(0.0, 0.0, 360.0, 320.0),
            True,
            False,
            True,
            True,
            18.0,
        ),
        PORTAL_EDITOR_ID,
        PORTAL_BUTTON_ID,
        PORTAL_BUTTON_ID,
        "re-add after removal",
    )
    check(harness.changed > 0, "independent re-add after removal expectation")
    harness.replay(
        make_view(
            Rect(12.0, 6.0, 420.0, 300.0),
            True,
            False,
            True,
            True,
            30.0,
        ),
        EDITOR_ID,
        BUTTON_ID,
        BUTTON_ID,
        "moved and resized bounds",
    )
    harness.replay(
        make_view(
            Rect(12.0, 6.0, 420.0, 300.0),
            True,
            False,
            True,
            True,
            30.0,
        ),
        EDITOR_ID,
        BUTTON_ID,
        BUTTON_ID,
        "moved bounds idle frame",
    )
    check(harness.changed == 0 and harness.removed == 0, "independent moved bounds idle frame expectation")

    print("paint parity frames:", harness.frame_count)
