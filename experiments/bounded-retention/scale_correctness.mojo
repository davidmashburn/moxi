"""Correctness checks shared by the baseline and bounded-retention probes."""
from scale_model import (
    ScaleScreen,
    HandlerHost,
    active_slots,
    assert_churn_counts,
    assert_visible_counts,
    control_id,
    control_index,
    total_slots,
)
from runtime import UI, require
from moxi import (
    ActionEvent,
    App,
    ClickEvent,
    CompositionEvent,
    Event,
    KeyEvent,
    KEY_LEFT,
    Point,
    Rect,
    TextInputEvent,
)


def frame(mut app: App[HandlerHost[ScaleScreen]]):
    var commands = app.paint()
    require(commands.count() > 0, "paint produced no commands")


def action_event(id: Int) -> Event:
    var event = Event(ActionEvent(id))
    event.set_target(id)
    return event^


def text_event(id: Int, text: String) -> Event:
    var event = Event(TextInputEvent(text))
    event.set_target(id)
    return event^


def composition_event(id: Int, text: String) -> Event:
    var event = Event(CompositionEvent(text, 1, 2))
    event.set_target(id)
    return event^


def assert_survivor_state(
    mut app: App[HandlerHost[ScaleScreen]],
    id: Int,
    expected_text: String,
    expected_cursor: Int,
    expected_anchor: Int,
    expected_composition: String,
    expected_composition_start: Int,
    expected_composition_end: Int,
    stage: String,
):
    var index = control_index(app, id)
    require(index >= 0, stage + " retained editor exists")
    var editor = app.component.ui.controls[index].editor
    require(editor.text == expected_text, stage + " text survives")
    require(editor.cursor == expected_cursor, stage + " caret survives")
    require(editor.anchor == expected_anchor, stage + " anchor survives")
    require(editor.composition == expected_composition, stage + " IME text survives")
    require(editor.has_composition(), stage + " active IME survives")
    require(
        editor.composition_selection_start == expected_composition_start,
        stage + " IME selection start survives",
    )
    require(
        editor.composition_selection_end == expected_composition_end,
        stage + " IME selection end survives",
    )


def prepare_survivor(mut app: App[HandlerHost[ScaleScreen]]) -> Int:
    var text_id = control_id(app, 2, 1)
    var bounds = app.view.bounds_for(text_id)
    require(
        app.update(ClickEvent(Point(bounds.x + 8.0, bounds.y + 8.0))),
        "focus surviving text input",
    )
    require(app.focus_id() == text_id, "surviving text input focused")
    require(app.update(text_event(text_id, "survivor")), "surviving text input edit")
    require(
        app.update(Event(KeyEvent(KEY_LEFT))),
        "surviving text input cursor move",
    )
    require(
        app.update(composition_event(text_id, "ime")),
        "surviving text input composition",
    )
    return text_id


def check_visible(count: Int):
    var app = App(HandlerHost(ScaleScreen(count)), Rect(0.0, 0.0, 960.0, 20000.0))
    frame(app)
    assert_visible_counts(app, count)
    var button_id = control_id(app, 1, 2)
    require(app.update(action_event(button_id)), "ordinary button action")
    frame(app)
    assert_visible_counts(app, count)
    require(app.component.root.children[0].clicks == 1, "local button state")
    print(
        "PASS visible",
        count,
        "controls",
        total_slots(app),
        "active",
        active_slots(app),
        "tree",
        app.view.child_count(),
        "next_id",
        app.component.ui.next_id,
    )


def check_churn(cycles: Int):
    var app = App(HandlerHost(ScaleScreen(8)), Rect(0.0, 0.0, 960.0, 20000.0))
    frame(app)
    assert_churn_counts(app, 0)
    var text_id = prepare_survivor(app)
    var live_text = app.component.root.children[1].text
    var live_clicks = app.component.root.children[1].clicks
    var before_text = app.component.ui.controls[control_index(app, text_id)].editor.text
    var before_cursor = app.component.ui.controls[control_index(app, text_id)].editor.cursor
    var before_anchor = app.component.ui.controls[control_index(app, text_id)].editor.anchor
    var before_composition = app.component.ui.controls[control_index(app, text_id)].editor.composition
    var before_composition_start = app.component.ui.controls[control_index(app, text_id)].editor.composition_selection_start
    var before_composition_end = app.component.ui.controls[control_index(app, text_id)].editor.composition_selection_end

    # Reordering keeps keyed paths and IDs stable while moving the surviving
    # child through the declaration order.  The focused child remains index 1.
    var first_key = app.component.root.children[0].key
    var third_key = app.component.root.children[2].key
    var first_text_id = control_id(app, first_key, 1)
    var first_button_id = control_id(app, first_key, 2)
    var third_text_id = control_id(app, third_key, 1)
    var third_button_id = control_id(app, third_key, 2)
    app.component.root.reorder_first_and_third()
    app.component.refresh()
    app.rebuild()
    frame(app)
    require(control_id(app, first_key, 1) == first_text_id, "reordered first text keeps ID")
    require(control_id(app, first_key, 2) == first_button_id, "reordered first button keeps ID")
    require(control_id(app, third_key, 1) == third_text_id, "reordered third text keeps ID")
    require(control_id(app, third_key, 2) == third_button_id, "reordered third button keeps ID")
    require(app.focus_id() == text_id, "focus survives reorder")
    require(app.component.root.children[1].key == 2, "survivor remains mounted")
    assert_survivor_state(
        app,
        text_id,
        before_text,
        before_cursor,
        before_anchor,
        before_composition,
        before_composition_start,
        before_composition_end,
        "reorder",
    )

    # Rebuild a copied retained host from the same declarations.  This forces
    # both copied indexes to resolve existing paths instead of appending them.
    var copied = app.component.ui
    var copied_declarations = UI[ScaleScreen]()
    app.component.root.render(copied_declarations)
    copied.rebuild(copied_declarations.declarations)
    require(len(copied.controls) == len(app.component.ui.controls), "copy preserves path index")
    require(copied.next_id == app.component.ui.next_id, "copy preserves next ID")
    var copied_index = copied.index(text_id)
    require(copied_index >= 0, "copy preserves ID index")
    require(copied.controls[copied_index].editor.text == before_text, "copy preserves editor text")
    require(copied.controls[copied_index].editor.cursor == before_cursor, "copy preserves caret")
    require(copied.controls[copied_index].editor.anchor == before_anchor, "copy preserves anchor")
    require(copied.controls[copied_index].editor.has_composition(), "copy preserves active IME")

    for _ in range(cycles):
        var retired_key = app.component.root.children[0].key
        var retired_button = control_id(app, retired_key, 2)
        var stale_action = app.component.ui.controls[control_index(app, retired_button)].action

        app.component.root.hide_first()
        app.component.refresh()
        app.rebuild()
        frame(app)
        require(app.focus_id() == text_id, "focus survives hidden sibling")
        require(app.component.root.children[1].text == live_text, "live model survives hide")
        require(app.component.root.children[1].clicks == live_clicks, "live clicks survive hide")
        assert_survivor_state(
            app,
            text_id,
            before_text,
            before_cursor,
            before_anchor,
            before_composition,
            before_composition_start,
            before_composition_end,
            "hide",
        )

        var stale_event = action_event(retired_button)
        require(not app.update(stale_event), "retired event rejected while hidden")
        var stale_context: NoneType = None
        stale_action(app.component.root, stale_context)
        require(app.component.root.children[1].text == live_text, "stale callback cannot edit live text")
        require(app.component.root.children[1].clicks == live_clicks, "stale callback cannot edit live clicks")

        var fresh_key = app.component.root.remount_first()
        require(fresh_key != retired_key, "remount uses a fresh key")
        app.component.refresh()
        app.rebuild()
        frame(app)
        require(app.focus_id() == text_id, "focus survives fresh-key remount")
        require(app.component.root.children[1].text == live_text, "live model survives remount")
        require(app.component.root.children[1].clicks == live_clicks, "live clicks survive remount")
        assert_survivor_state(
            app,
            text_id,
            before_text,
            before_cursor,
            before_anchor,
            before_composition,
            before_composition_start,
            before_composition_end,
            "remount",
        )

        stale_event = action_event(retired_button)
        require(not app.update(stale_event), "retired event rejected after remount")
        stale_context = None
        stale_action(app.component.root, stale_context)
        require(app.component.root.children[1].text == live_text, "post-remount stale callback cannot edit live text")
        require(app.component.root.children[1].clicks == live_clicks, "post-remount stale callback cannot edit live clicks")

        var fresh_button = control_id(app, fresh_key, 2)
        require(fresh_button != retired_button, "fresh key receives a fresh control ID")
        require(app.update(action_event(fresh_button)), "fresh child button action")
        require(app.component.root.children[0].clicks == 1, "fresh child owns its local state")
        live_text = app.component.root.children[1].text
        live_clicks = app.component.root.children[1].clicks
        before_text = app.component.ui.controls[control_index(app, text_id)].editor.text
        before_cursor = app.component.ui.controls[control_index(app, text_id)].editor.cursor
        before_anchor = app.component.ui.controls[control_index(app, text_id)].editor.anchor
        before_composition = app.component.ui.controls[control_index(app, text_id)].editor.composition
        before_composition_start = app.component.ui.controls[control_index(app, text_id)].editor.composition_selection_start
        before_composition_end = app.component.ui.controls[control_index(app, text_id)].editor.composition_selection_end

    # Copy after churn as well: the candidate must have rebuilt both maps after
    # compacting the retired records, while the baseline keeps its history.
    var compacted_copy = app.component.ui
    var compacted_declarations = UI[ScaleScreen]()
    app.component.root.render(compacted_declarations)
    compacted_copy.rebuild(compacted_declarations.declarations)
    require(len(compacted_copy.controls) == len(app.component.ui.controls), "compacted copy preserves storage")
    require(compacted_copy.next_id == app.component.ui.next_id, "compacted copy preserves next ID")
    require(compacted_copy.index(text_id) >= 0, "compacted copy preserves live ID")

    frame(app)
    assert_churn_counts(app, cycles)
    require(app.component.root.active_children() == 8, "active child population after churn")
    print(
        "PASS churn",
        cycles,
        "controls",
        total_slots(app),
        "active",
        active_slots(app),
        "tree",
        app.view.child_count(),
        "next_id",
        app.component.ui.next_id,
    )


def main():
    check_visible(10)
    check_visible(100)
    check_visible(300)
    check_visible(1000)
    check_churn(0)
    check_churn(100)
    check_churn(1000)
    print("PASS correctness scale, reorder, copy, and guarded churn")
