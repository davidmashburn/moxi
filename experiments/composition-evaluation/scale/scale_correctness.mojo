"""Bounded correctness checks for the keyed HandlerHost scale model."""
from scale_model import (
    ScaleScreen,
    HandlerHost,
    active_slots,
    assert_churn_counts,
    assert_visible_counts,
    control_id,
    control_index,
    path_for,
    total_slots,
)
from runtime import require
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

    for cycle in range(cycles):
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
        require(app.component.ui.controls[control_index(app, text_id)].editor.text == before_text, "text survives hide")
        require(app.component.ui.controls[control_index(app, text_id)].editor.cursor == before_cursor, "caret survives hide")
        require(app.component.ui.controls[control_index(app, text_id)].editor.anchor == before_anchor, "selection survives hide")
        require(app.component.ui.controls[control_index(app, text_id)].editor.composition == before_composition, "composition survives hide")

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
        require(app.component.ui.controls[control_index(app, text_id)].editor.text == before_text, "text survives remount")
        require(app.component.ui.controls[control_index(app, text_id)].editor.cursor == before_cursor, "caret survives remount")
        require(app.component.ui.controls[control_index(app, text_id)].editor.anchor == before_anchor, "selection survives remount")
        require(app.component.ui.controls[control_index(app, text_id)].editor.composition == before_composition, "composition survives remount")
        require(
            app.component.ui.controls[control_index(app, text_id)].editor.composition_selection_start == before_composition_start,
            "composition selection start survives remount",
        )
        require(
            app.component.ui.controls[control_index(app, text_id)].editor.composition_selection_end == before_composition_end,
            "composition selection end survives remount",
        )

        stale_event = action_event(retired_button)
        require(not app.update(stale_event), "retired event rejected after remount")
        stale_context = None
        stale_action(app.component.root, stale_context)
        require(app.component.root.children[1].text == live_text, "post-remount stale callback cannot edit live text")
        require(app.component.root.children[1].clicks == live_clicks, "post-remount stale callback cannot edit live clicks")

        var fresh_button = control_id(app, fresh_key, 2)
        require(fresh_button != retired_button, "fresh key receives a fresh control id")
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
    check_churn(1)
    check_churn(100)
    check_churn(1000)
    print("PASS correctness scale and guarded churn")
