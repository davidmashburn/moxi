"""Keyboard, text-input, focus, and rebuild contract test."""

from moxi import test_check
from moxi import (
    App,
    COMPOSITION_END_KIND,
    COMPOSITION_UPDATE_KIND,
    CompositionEvent,
    Event,
    FormState,
    KEY_BACKSPACE,
    KEY_C,
    KEY_DELETE,
    KEY_END,
    KEY_ENTER,
    KEY_HOME,
    KEY_LEFT,
    KEY_RIGHT,
    KEY_SPACE,
    KEY_TAB,
    KEY_V,
    KEY_X,
    MOD_COMMAND,
    MOD_SHIFT,
    Point,
    Rect,
    ResizeEvent,
    Size,
    TestRenderer,
    TextInputEvent,
    KeyEvent,
    ClickEvent,
    TEXT_INPUT_VIEW_KIND,
)


def main() raises:
    var composition_app = App[FormState](FormState(), Rect(0.0, 0.0, 520.0, 320.0))
    var update_event = Event(CompositionEvent("ni", 1, 2))
    test_check(update_event.kind == COMPOSITION_UPDATE_KIND)
    test_check(composition_app.dispatch(update_event))
    test_check(composition_app.component.input.text == "")
    test_check(composition_app.component.input.composition == "ni")
    test_check(composition_app.component.input.composition_selection_start == 1)
    test_check(composition_app.component.input.composition_selection_end == 2)
    var composition_frame = composition_app.paint()
    test_check(composition_frame.command(4).composition == "ni")
    test_check(composition_frame.command(4).composition_selection_start == 1)
    test_check(composition_frame.command(4).composition_selection_end == 2)

    var focus_composition_app = App[FormState](
        FormState(),
        Rect(0.0, 0.0, 520.0, 320.0),
    )
    test_check(focus_composition_app.dispatch(Event(CompositionEvent("かな", 1, 2))))
    var submit_bounds = focus_composition_app.view.child(4).bounds
    test_check(focus_composition_app.dispatch(
        Event(ClickEvent(Point(submit_bounds.x + 1.0, submit_bounds.y + 1.0)))
    ))
    test_check(focus_composition_app.focus_id() == 4)
    test_check(focus_composition_app.component.input.composition == "")

    test_check(composition_app.dispatch(Event(CompositionEvent("n", 0, 1))))
    test_check(composition_app.component.input.composition == "n")
    var end_event = Event(CompositionEvent())
    test_check(end_event.kind == COMPOSITION_END_KIND)
    test_check(composition_app.dispatch(end_event))
    test_check(composition_app.component.input.composition == "")
    test_check(composition_app.dispatch(Event(CompositionEvent("ni", 0, 2))))
    test_check(composition_app.dispatch(Event(TextInputEvent("你"))))
    test_check(composition_app.component.input.text == "你")
    test_check(not composition_app.component.input.has_composition())
    test_check(not composition_app.dispatch(Event(CompositionEvent())))

    var accessibility_app = App[FormState](
        FormState(),
        Rect(0.0, 0.0, 520.0, 320.0),
    )
    var accessibility_renderer = TestRenderer()
    accessibility_app.render(accessibility_renderer)
    test_check(accessibility_renderer.last_accessibility_value_change_count == 0)
    test_check(accessibility_app.dispatch(Event(TextInputEvent("A"))))
    accessibility_app.render(accessibility_renderer)
    test_check(accessibility_renderer.last_accessibility_value_change_count == 1)
    accessibility_app.render(accessibility_renderer)
    test_check(accessibility_renderer.last_accessibility_value_change_count == 0)

    var app = App[FormState](FormState(), Rect(0.0, 0.0, 520.0, 320.0))
    test_check(app.view.child_count() == 5)
    test_check(app.focus_id() == 2)

    test_check(app.dispatch(Event(TextInputEvent("Moxi"))))
    test_check(app.component.input.text == "Moxi")
    test_check(app.component.input.cursor == 4)

    test_check(app.dispatch(Event(KeyEvent(KEY_LEFT))))
    test_check(app.component.input.cursor == 3)
    test_check(app.dispatch(Event(TextInputEvent("!"))))
    test_check(app.component.input.text == "Mox!i")
    test_check(app.component.input.cursor == 4)

    test_check(app.dispatch(Event(KeyEvent(KEY_HOME))))
    test_check(app.component.input.cursor == 0)
    test_check(app.dispatch(Event(KeyEvent(KEY_RIGHT))))
    test_check(app.component.input.cursor == 1)
    test_check(app.dispatch(Event(KeyEvent(KEY_DELETE))))
    test_check(app.component.input.text == "Mx!i")
    test_check(app.dispatch(Event(KeyEvent(KEY_BACKSPACE))))
    test_check(app.component.input.text == "x!i")
    test_check(app.component.input.cursor == 0)

    test_check(app.dispatch(Event(KeyEvent(KEY_END))))
    test_check(app.dispatch(Event(KeyEvent(KEY_LEFT, MOD_SHIFT))))
    test_check(app.component.input.selected_text() == "i")
    test_check(not app.dispatch(Event(KeyEvent(KEY_C, MOD_COMMAND))))
    test_check(app.component.input.clipboard == "i")
    var selected_frame = app.paint()
    test_check(selected_frame.command(4).has_selection())
    test_check(selected_frame.command(4).selection_start == 2)
    test_check(selected_frame.command(4).selection_end == 3)
    test_check(app.dispatch(Event(KeyEvent(KEY_X, MOD_COMMAND))))
    test_check(app.component.input.text == "x!")
    test_check(app.dispatch(Event(KeyEvent(KEY_V, MOD_COMMAND))))
    test_check(app.component.input.text == "x!i")

    var semantics = app.accessibility()
    test_check(semantics.count() == 5)
    test_check(semantics.node(2).role == 3)
    test_check(semantics.node(2).value == "x!i")
    test_check(semantics.node(2).focused)

    var commands = app.paint()
    test_check(commands.command(4).kind == TEXT_INPUT_VIEW_KIND)
    test_check(commands.command(4).focused)
    test_check(commands.command(4).cursor == 3)

    test_check(app.dispatch(Event(KeyEvent(KEY_TAB))))
    test_check(app.focus_id() == 4)
    test_check(app.dispatch(Event(KeyEvent(KEY_TAB, MOD_SHIFT))))
    test_check(app.focus_id() == 2)

    test_check(app.dispatch(Event(ClickEvent(Point(80.0, 205.0)))))
    test_check(app.focus_id() == 4)
    test_check(app.component.submissions == 1)
    test_check(app.dispatch(Event(KeyEvent(KEY_ENTER))))
    test_check(app.component.submissions == 2)
    test_check(app.dispatch(Event(KeyEvent(KEY_SPACE))))
    test_check(app.component.submissions == 3)

    test_check(app.dispatch(Event(ResizeEvent(Size(640.0, 400.0)))))
    test_check(app.focus_id() == 4)
    test_check(app.view.child(4).bounds.width == 576.0)

    var replacement_app = App[FormState](
        FormState(),
        Rect(0.0, 0.0, 520.0, 320.0),
    )
    test_check(replacement_app.dispatch(Event(TextInputEvent("Moxi"))))
    test_check(
        replacement_app.dispatch(Event(TextInputEvent("X", 1, 3)))
    )
    test_check(replacement_app.component.input.text == "MXi")
    test_check(replacement_app.component.input.cursor == 2)
    print("Moxi form test passed")
