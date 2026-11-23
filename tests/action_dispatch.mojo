"""Contract test for typed actions delivered by App."""

from moxi import (
    ACTION_INCREMENT,
    ACTION_PRESS,
    ACTION_SELECT,
    ActionMessage,
    ActionQueue,
    App,
    ColumnView,
    Component,
    Rect,
    SemanticActionEvent,
    test_check,
)
from moxi.event import (
    ACTION_KIND,
    COMPOSITION_END_KIND,
    COMPOSITION_UPDATE_KIND,
    DRAG_BEGIN_KIND,
    DRAG_UPDATE_KIND,
    DROP_KIND,
    FOCUS_KIND,
    FRAME_TICK_KIND,
    KEY_DOWN_KIND,
    KEY_ENTER,
    KEY_ESCAPE,
    KEY_SPACE,
    MOD_COMMAND,
    MOD_CONTROL,
    MOD_OPTION,
    MOD_SHIFT,
    NONE_KIND,
    NO_ACTION,
    POINTER_CANCEL_KIND,
    POINTER_DOWN_KIND,
    POINTER_MOVE_KIND,
    POINTER_UP_KIND,
    SCROLL_KIND,
    TASK_RESULT_KIND,
    TEXT_INPUT_KIND,
    TOUCH_BEGIN_KIND,
    TOUCH_END_KIND,
    TOUCH_UPDATE_KIND,
    WINDOW_RESIZED_KIND,
    ActionEvent,
    ClickEvent,
    Event,
    KeyEvent,
)
from moxi.geometry import Point


comptime TEST_APPLICATION_ACTION = 100


def _activation_contract():
    test_check(Event(ClickEvent(Point(2.0, 3.0), MOD_OPTION)).is_activation())
    for key in [KEY_ENTER, KEY_SPACE]:
        for modifiers in [0, MOD_SHIFT, MOD_COMMAND | MOD_CONTROL | MOD_OPTION]:
            var event = Event(KeyEvent(key, modifiers))
            test_check(event.is_activation())
            event.set_target(42)
            test_check(event.is_activation())
    test_check(Event(ActionEvent(ACTION_PRESS)).is_activation())
    test_check(Event(SemanticActionEvent(42, ACTION_PRESS)).is_activation())
    test_check(not Event(KeyEvent(KEY_ESCAPE)).is_activation())
    for action in [NO_ACTION, ACTION_INCREMENT, ACTION_SELECT, TEST_APPLICATION_ACTION]:
        test_check(not Event(ActionEvent(action)).is_activation())
        test_check(not Event(SemanticActionEvent(42, action)).is_activation())

    # A reused event's unrelated fields must not activate another event kind.
    var stale = Event(KeyEvent(KEY_ENTER))
    stale.set_action(ACTION_PRESS)
    for kind in [
        NONE_KIND,
        POINTER_DOWN_KIND,
        POINTER_UP_KIND,
        POINTER_MOVE_KIND,
        POINTER_CANCEL_KIND,
        TEXT_INPUT_KIND,
        WINDOW_RESIZED_KIND,
        COMPOSITION_UPDATE_KIND,
        COMPOSITION_END_KIND,
        FRAME_TICK_KIND,
        SCROLL_KIND,
        DRAG_BEGIN_KIND,
        DRAG_UPDATE_KIND,
        DROP_KIND,
        TASK_RESULT_KIND,
        TOUCH_BEGIN_KIND,
        TOUCH_UPDATE_KIND,
        TOUCH_END_KIND,
        FOCUS_KIND,
    ]:
        stale.kind = kind
        test_check(not stale.is_activation())
    stale.kind = ACTION_KIND
    stale.action_id = ACTION_INCREMENT
    test_check(not stale.is_activation())
    stale.kind = KEY_DOWN_KIND
    stale.key = KEY_ESCAPE
    stale.action_id = ACTION_PRESS
    test_check(not stale.is_activation())


struct ActionState(Component):
    var last_id: Int
    var last_target: Int
    var payload: String

    def __init__(out self):
        self.last_id = -1
        self.last_target = -1
        self.payload = ""

    def build(self, bounds: Rect) -> ColumnView:
        var view = ColumnView(bounds, 4.0, 4.0)
        view.add_label(1, self.payload, 20.0)
        view.layout()
        return view^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        if event.kind == ACTION_KIND:
            self.last_id = event.action_id
            self.last_target = event.target
            self.payload = event.text
            return True
        return False


def main():
    _activation_contract()
    var app = App[ActionState](ActionState(), Rect(0.0, 0.0, 200.0, 80.0))
    var actions = ActionQueue()
    test_check(actions.enqueue(ActionMessage(7, "refresh")))
    test_check(app.dispatch_actions(actions))
    test_check(app.component.last_id == 7)
    test_check(app.component.payload == "refresh")
    test_check(not actions.has_next())
    test_check(app.dispatch(Event(SemanticActionEvent(42, ACTION_INCREMENT))))
    test_check(app.component.last_target == 42)
    test_check(app.component.last_id == ACTION_INCREMENT)
    print("Moxi action-dispatch test passed")
