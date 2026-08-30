"""WxPython-style teaching scenario and nested composition contract test."""

from moxi import test_check
from moxi import (
    App,
    Event,
    KEY_A,
    KEY_C,
    KEY_ENTER,
    KEY_LEFT,
    KEY_RIGHT,
    KEY_TAB,
    KeyEvent,
    MemoryClipboard,
    MOD_COMMAND,
    POINTER_DOWN_KIND,
    POINTER_UP_KIND,
    Point,
    PointerEvent,
    Rect,
    ROLE_CONTAINER,
    ROLE_CHECKBOX,
    ROLE_PROGRESS_INDICATOR,
    ROLE_TEXT_INPUT,
    TEXT_INPUT_VIEW_KIND,
    TextInputEvent,
    TestRenderer,
    WxStyleState,
    WX_ACTIONS_ID,
    WX_AGENT_RESET_BUTTON_ID,
    WX_APPROVE_RESET_ID,
    WX_APPROVAL_STATUS_ID,
    WX_BODY_ID,
    WX_CAPABILITIES_ID,
    WX_CANCEL_BUTTON_ID,
    WX_CAPABILITY_STATUS_ID,
    WX_COMPONENT_SLOT_ID,
    WX_COUNTER_ID_OFFSET,
    WX_HEADER_ID,
    WX_HELP_ID,
    WX_NAME_FIELD_ID,
    WX_OK_BUTTON_ID,
    WX_PANEL_ID,
    WX_PROGRESS_ID,
    WX_REMEMBER_ID,
    WX_RESET_BUTTON_ID,
)


def main() raises:
    var app = App[WxStyleState](WxStyleState(), Rect(0.0, 0.0, 560.0, 840.0))

    test_check(app.view.child(0).id == WX_PANEL_ID)
    test_check(app.view.child(1).id == WX_HEADER_ID)
    test_check(app.view.child(4).id == WX_BODY_ID)
    test_check(app.view.child(6).kind == TEXT_INPUT_VIEW_KIND)
    test_check(app.view.bounds_for(WX_COMPONENT_SLOT_ID).height > 0.0)
    test_check(app.view.bounds_for(WX_NAME_FIELD_ID).width > 0.0)

    var ok = app.view.bounds_for(WX_OK_BUTTON_ID)
    var cancel = app.view.bounds_for(WX_CANCEL_BUTTON_ID)
    test_check(cancel.x > ok.x)
    test_check(app.view.bounds_for(WX_ACTIONS_ID).width > 0.0)
    var details = app.view.bounds_for(WX_CAPABILITIES_ID)
    var actions = app.view.bounds_for(WX_ACTIONS_ID)
    var help = app.view.bounds_for(WX_HELP_ID)
    var component = app.view.bounds_for(WX_COMPONENT_SLOT_ID)
    test_check(details.y + details.height <= actions.y)
    test_check(actions.y + actions.height <= help.y)
    test_check(help.y + help.height <= component.y)
    test_check(app.focus_id() == WX_NAME_FIELD_ID)

    var semantics = app.accessibility()
    test_check(semantics.node(0).role == ROLE_CONTAINER)
    test_check(semantics.node(0).id == WX_PANEL_ID)
    test_check(semantics.node(1).parent_id == WX_PANEL_ID)
    test_check(semantics.node(6).role == ROLE_TEXT_INPUT)
    test_check(semantics.node(6).parent_id == WX_BODY_ID)
    test_check(semantics.node(8).role == ROLE_CHECKBOX)
    test_check(semantics.node(9).role == ROLE_PROGRESS_INDICATOR)

    test_check(app.dispatch(Event(TextInputEvent("Ada"))))
    test_check(app.component.input.text == "Ada")
    test_check(app.dispatch(Event(KeyEvent(KEY_A, MOD_COMMAND))))
    var clipboard = MemoryClipboard()
    test_check(not app.dispatch_with_clipboard(
        Event(KeyEvent(KEY_C, MOD_COMMAND)),
        clipboard,
    ))
    test_check(clipboard.text == "Ada")
    test_check(app.dispatch_with_clipboard(
        Event(KeyEvent(KEY_TAB, 0)),
        clipboard,
    ))
    test_check(app.focus_id() == WX_REMEMBER_ID)
    test_check(app.dispatch(Event(KeyEvent(KEY_TAB, 0))))
    test_check(app.focus_id() == WX_OK_BUTTON_ID)
    test_check(app.dispatch(Event(KeyEvent(KEY_RIGHT, 0))))
    test_check(app.focus_id() == WX_CANCEL_BUTTON_ID)
    test_check(app.dispatch(Event(KeyEvent(KEY_LEFT, 0))))
    test_check(app.focus_id() == WX_OK_BUTTON_ID)
    test_check(app.dispatch(Event(KeyEvent(KEY_ENTER, 0))))
    test_check(app.component.submissions == 1)
    test_check(app.component.status == "Hello, Ada")

    var cancel_point = Point(cancel.x + 1.0, cancel.y + 1.0)
    test_check(app.dispatch(Event(PointerEvent(POINTER_DOWN_KIND, cancel_point))))
    test_check(app.dispatch(Event(PointerEvent(POINTER_UP_KIND, cancel_point))))
    test_check(app.component.cancellations == 1)
    test_check(app.component.input.text == "")
    test_check(app.component.status == "Cancelled.")

    var remember = app.view.bounds_for(WX_REMEMBER_ID)
    var remember_point = Point(remember.x + 1.0, remember.y + 1.0)
    test_check(app.dispatch(Event(PointerEvent(POINTER_DOWN_KIND, remember_point))))
    test_check(app.dispatch(Event(PointerEvent(POINTER_UP_KIND, remember_point))))
    test_check(not app.component.remember_name)

    var child_button = app.view.bounds_for(WX_COUNTER_ID_OFFSET + 3)
    var child_point = Point(child_button.x + 1.0, child_button.y + 1.0)
    test_check(app.dispatch(Event(PointerEvent(POINTER_DOWN_KIND, child_point))))
    test_check(app.dispatch(Event(PointerEvent(POINTER_UP_KIND, child_point))))
    test_check(app.component.counter.component.count == 1)

    var blocked = app.component.agent_reset()
    test_check(blocked.status == 3)
    app.rebuild()
    test_check(app.view.bounds_for(WX_APPROVE_RESET_ID).width > 0.0)
    var reset = app.component.approve_agent_reset()
    test_check(reset.status == 0)
    app.rebuild()

    var renderer = TestRenderer()
    app.render(renderer)
    test_check(app.view.child_count() == 45)
    test_check(renderer.count() == 39)
    test_check(renderer.last_accessibility_count == 44)
    print("Moxi wx-style test passed")
