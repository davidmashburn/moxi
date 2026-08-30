"""Contract tests for lenses, invalidation, actions, and task scheduling."""

from moxi import (
    ActionMessage,
    ActionQueue,
    App,
    Component,
    ColumnView,
    StateScope,
    StateVersion,
    StringLens,
    StringMemo,
    TASK_CANCELLED,
    TASK_COMPLETED,
    TASK_RESULT_KIND,
    TaskScheduler,
    test_check,
)
from moxi.event import Event
from moxi.geometry import Rect


struct TaskState(Component):
    var completed: Int

    def __init__(out self):
        self.completed = 0

    def build(self, bounds: Rect) -> ColumnView:
        var view = ColumnView(bounds, 8.0, 4.0)
        view.add_label(1, String("Completed: ", self.completed), 24.0)
        view.layout()
        return view^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        if event.kind == TASK_RESULT_KIND and event.task_status == TASK_COMPLETED:
            self.completed += 1
            return True
        return False


def main():
    var version = StateVersion()
    var prior = version
    version.advance()
    test_check(version.changed_since(prior))

    var scope = StateScope(1)
    scope.invalidate()
    test_check(scope.dirty)
    test_check(scope.version.value == 1)
    scope.clear()
    test_check(not scope.dirty)

    var lens = StringLens(7, 1, 4)
    test_check(lens.read("Moxi") == "oxi")
    test_check(lens.write("Moxi", "UI") == "MUI")

    var memo = StringMemo(3)
    test_check(not memo.is_valid(version))
    memo.remember(3, version, "cached")
    test_check(memo.is_valid(version))
    version.advance()
    test_check(not memo.is_valid(version))

    var actions = ActionQueue(1)
    test_check(actions.enqueue(ActionMessage(1, "one")))
    test_check(not actions.enqueue(ActionMessage(2, "two")))
    test_check(actions.dropped_count() == 1)
    test_check(actions.dequeue().payload == "one")
    test_check(actions.enqueue(ActionMessage(3, "three")))
    test_check(actions.dequeue().payload == "three")
    test_check(actions.set_capacity(2))

    var scheduler = TaskScheduler(2)
    var first = scheduler.schedule("first", 0.5, "done")
    var second = scheduler.schedule("second", 10.0, "later")
    test_check(first.is_valid())
    test_check(scheduler.pending_count() == 2)
    scheduler.advance(0.25)
    test_check(not scheduler.has_ready())
    scheduler.advance(0.25)
    test_check(scheduler.has_ready())
    var result = scheduler.pop_ready()
    test_check(result.status == TASK_COMPLETED)
    test_check(result.payload == "done")
    test_check(scheduler.cancel(second))
    test_check(scheduler.pop_ready().status == TASK_CANCELLED)
    test_check(scheduler.forget(first))

    var bounded = TaskScheduler(1)
    var ready_task = bounded.schedule("ready", 0.0, "result")
    test_check(ready_task.is_valid())
    bounded.advance(0.0)
    test_check(bounded.ready_count() == 1)
    var rejected = bounded.schedule("second", 0.0, "dropped")
    test_check(rejected.is_valid())
    bounded.advance(0.0)
    test_check(bounded.dropped_count() == 1)
    _ = bounded.pop_ready()

    var app = App[TaskState](TaskState(), Rect(0.0, 0.0, 520.0, 320.0))
    var handle = app.schedule_task("app task", 0.1, "payload")
    test_check(app.pending_task_count() == 1)
    test_check(app.tick(0.1))
    test_check(app.task_status(handle) == TASK_COMPLETED)
    test_check(app.component.completed == 1)
    test_check(app.forget_task(handle))

    print("Moxi reactivity-tasks test passed")
