"""Headless renderer, control, row, pointer, and Unicode contract test."""

from moxi import test_check
from moxi import (
    App,
    BUTTON_KIND,
    ButtonControl,
    ColumnRuntime,
    Event,
    FormState,
    KEY_A,
    KEY_C,
    KEY_LEFT,
    KEY_V,
    KEY_X,
    MOD_COMMAND,
    MemoryClipboard,
    Point,
    PointerEvent,
    POINTER_DOWN_KIND,
    POINTER_MOVE_KIND,
    POINTER_UP_KIND,
    Rect,
    ROLE_BUTTON,
    ROLE_LABEL,
    ROLE_TEXT_INPUT,
    RowState,
    TestRenderer,
    TestWindow,
    TextInputState,
    KeyEvent,
    TextInputEvent,
    WindowConfig,
    make_row,
    NEXT_BUTTON_ID,
)


def main() raises:
    var editing = TextInputState("aé🙂")
    test_check(editing.cursor == 3)
    test_check(editing.handle_key(KEY_LEFT, 0))
    test_check(editing.cursor == 2)
    test_check(editing.delete_backward())
    test_check(editing.text == "a🙂")
    test_check(editing.cursor == 1)
    test_check(editing.handle_key(KEY_A, MOD_COMMAND))
    test_check(editing.has_selection())
    test_check(editing.insert_text("Moxi"))
    test_check(editing.text == "Moxi")
    test_check(editing.cursor == 4)

    var clipboard_editing = TextInputState("aé🙂")
    test_check(clipboard_editing.select_all())
    test_check(clipboard_editing.handle_key(KEY_C, MOD_COMMAND))
    test_check(clipboard_editing.clipboard == "aé🙂")
    test_check(clipboard_editing.handle_key(KEY_X, MOD_COMMAND))
    test_check(clipboard_editing.text == "")
    test_check(clipboard_editing.handle_key(KEY_V, MOD_COMMAND))
    test_check(clipboard_editing.text == "aé🙂")

    var clipboard_app = App[FormState](FormState(), Rect(0.0, 0.0, 520.0, 320.0))
    test_check(clipboard_app.dispatch(Event(TextInputEvent("copy me"))))
    test_check(clipboard_app.dispatch(Event(KeyEvent(KEY_A, MOD_COMMAND))))
    var backend_clipboard = MemoryClipboard()
    test_check(not clipboard_app.dispatch_with_clipboard(
        Event(KeyEvent(KEY_C, MOD_COMMAND)),
        backend_clipboard,
    ))
    test_check(backend_clipboard.text == "copy me")
    test_check(clipboard_app.dispatch_with_clipboard(
        Event(KeyEvent(KEY_X, MOD_COMMAND)),
        backend_clipboard,
    ))
    test_check(clipboard_app.component.input.text == "")
    test_check(clipboard_app.dispatch_with_clipboard(
        Event(KeyEvent(KEY_V, MOD_COMMAND)),
        backend_clipboard,
    ))
    test_check(clipboard_app.component.input.text == "copy me")

    var row = make_row(Rect(0.0, 0.0, 400.0, 80.0), 10.0, 5.0)
    var first = ButtonControl(1, "First", 36.0)
    row.add(first.node())
    row.add_spacer(2, 20.0)
    var second = ButtonControl(3, "Second", 36.0)
    row.add(second.node())
    row.set_preferred_width(1, 100.0)
    row.layout()
    test_check(row.child(0).bounds.x == 10.0)
    test_check(row.child(0).bounds.width == 100.0)
    test_check(row.child(1).bounds.x == 115.0)
    test_check(row.child(1).bounds.width == 20.0)
    test_check(row.child(2).bounds.x == 140.0)
    test_check(row.child(2).bounds.width == 250.0)
    var row_runtime = ColumnRuntime()
    row_runtime.reconcile(row)
    var row_commands = row_runtime.paint()
    test_check(row_commands.count() == 3)

    var row_app = App[RowState](RowState(), Rect(0.0, 0.0, 560.0, 180.0))
    test_check(row_app.view.child(0).bounds.width == 140.0)
    test_check(row_app.view.child(2).bounds.width == 140.0)
    var next = row_app.view.child(2).bounds
    var next_point = Point(next.x + 1.0, next.y + 1.0)
    test_check(row_app.dispatch(Event(PointerEvent(POINTER_DOWN_KIND, next_point))))
    test_check(row_app.dispatch(Event(PointerEvent(POINTER_UP_KIND, next_point))))
    test_check(row_app.component.selected == NEXT_BUTTON_ID)

    var disabled_row = make_row(Rect(0.0, 0.0, 240.0, 80.0), 10.0, 5.0)
    var disabled = ButtonControl(9, "Disabled", 36.0)
    disabled_row.add(disabled.node())
    disabled_row.set_enabled(9, False)
    disabled_row.layout()
    var disabled_runtime = ColumnRuntime()
    disabled_runtime.reconcile(disabled_row)
    test_check(disabled_runtime.focus_id() == -1)
    test_check(disabled_runtime.hit_test(Point(20.0, 20.0)) == -1)
    test_check(disabled_runtime.accessibility().node(0).role == ROLE_BUTTON)
    test_check(not disabled_runtime.accessibility().node(0).enabled)

    var app = App[FormState](FormState(), Rect(0.0, 0.0, 520.0, 320.0))
    var semantics = app.accessibility()
    test_check(semantics.count() == 5)
    test_check(semantics.node(0).role == ROLE_LABEL)
    test_check(semantics.node(2).role == ROLE_TEXT_INPUT)
    test_check(semantics.node(2).label == "Name")
    test_check(semantics.node(2).hint == "Enter your name")
    test_check(semantics.node(2).focused)
    test_check(semantics.node(4).role == ROLE_BUTTON)
    var submit = app.view.child(4).bounds
    var submit_point = Point(submit.x + 1.0, submit.y + 1.0)
    test_check(app.dispatch(Event(PointerEvent(POINTER_MOVE_KIND, submit_point))))
    test_check(app.hover_id() == 4)
    test_check(app.dispatch(Event(PointerEvent(POINTER_DOWN_KIND, submit_point))))
    test_check(app.pressed_id() == 4)
    var frame = app.paint()
    test_check(frame.command(6).hovered)
    test_check(frame.command(6).pressed)
    test_check(app.dispatch(Event(PointerEvent(POINTER_MOVE_KIND, Point(0.0, 0.0)))))
    test_check(app.hover_id() == -1)
    test_check(app.dispatch(Event(PointerEvent(POINTER_UP_KIND, Point(0.0, 0.0)))))
    test_check(app.component.submissions == 0)
    test_check(app.pressed_id() == -1)
    test_check(app.dispatch(Event(PointerEvent(POINTER_DOWN_KIND, submit_point))))
    test_check(app.dispatch(Event(PointerEvent(POINTER_UP_KIND, submit_point))))
    test_check(app.component.submissions == 1)
    test_check(app.pressed_id() == -1)
    test_check(app.dispatch(Event(PointerEvent(POINTER_DOWN_KIND, Point(510.0, 310.0)))))
    test_check(app.focus_id() == -1)
    test_check(app.dispatch(Event(PointerEvent(POINTER_UP_KIND, Point(510.0, 310.0)))))
    test_check(app.focus_id() == -1)

    var renderer = TestRenderer()
    app.render(renderer)
    test_check(renderer.count() == 7)
    test_check(renderer.command(6).kind == BUTTON_KIND)

    var window = TestWindow()
    window.open(WindowConfig("test", 100.0, 80.0))
    window.enqueue(Event(PointerEvent(POINTER_MOVE_KIND, Point(4.0, 5.0))))
    test_check(window.pending_count() == 1)
    test_check(window.poll_event().kind == POINTER_MOVE_KIND)
    test_check(window.pending_count() == 0)
    print("Moxi headless test passed")
