"""Contract test for typed actions delivered by App."""

from moxi import (
    ACTION_KIND,
    ACTION_INCREMENT,
    ActionMessage,
    ActionQueue,
    App,
    ColumnView,
    Component,
    Rect,
    SemanticActionEvent,
    test_check,
)
from moxi.event import Event


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
