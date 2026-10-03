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
    RequestScheduler,
    TaskScheduler,
    test_check,
)
from moxi.event import Event
from moxi.geometry import Rect


struct TaskState(Component):
    var completed: Int
    var request_completed: Int
    var request_key: Int
    var request_generation: Int

    def __init__(out self):
        self.completed = 0
        self.request_completed = 0
        self.request_key = -1
        self.request_generation = -1

    def build(self, bounds: Rect) -> ColumnView:
        var view = ColumnView(bounds, 8.0, 4.0)
        view.add_label(1, String("Completed: ", self.completed), 24.0)
        view.layout()
        return view^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        if event.kind == TASK_RESULT_KIND and event.task_status == TASK_COMPLETED:
            if event.request_key >= 0:
                self.request_completed += 1
                self.request_key = event.request_key
                self.request_generation = event.request_generation
            else:
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

    var requests = RequestScheduler(4)
    var first_request = requests.request(11, "first", 0.5, "old")
    test_check(first_request.is_valid())
    test_check(requests.is_current(first_request))
    var replacement = requests.request(11, "replacement", 0.5, "new")
    test_check(replacement.is_valid())
    test_check(replacement.generation == first_request.generation + 1)
    test_check(not requests.is_current(first_request))
    test_check(requests.is_current(replacement))
    var cancelled_request = requests.pop_ready()
    test_check(cancelled_request.matches(first_request))
    test_check(cancelled_request.status == TASK_CANCELLED)
    requests.advance(0.5)
    var completed_request = requests.pop_ready()
    test_check(completed_request.matches(replacement))
    test_check(completed_request.status == TASK_COMPLETED)
    test_check(completed_request.payload == "new")
    test_check(not requests.is_current(replacement))

    var ready_request = requests.request(22, "ready", 0.0, "stale")
    requests.advance(0.0)
    var ready_replacement = requests.request(22, "fresh", 0.0, "current")
    test_check(not requests.is_current(ready_request))
    test_check(requests.is_current(ready_replacement))
    var stale_result = requests.pop_ready()
    test_check(stale_result.matches(ready_request))
    test_check(stale_result.payload == "stale")
    requests.advance(0.0)
    var fresh_result = requests.pop_ready()
    test_check(fresh_result.matches(ready_replacement))
    test_check(fresh_result.payload == "current")

    var keyed_cancel = requests.request(33, "cancel", 10.0, "ignored")
    test_check(requests.cancel_key(33))
    test_check(not requests.is_current(keyed_cancel))
    var keyed_cancel_result = requests.pop_ready()
    test_check(keyed_cancel_result.matches(keyed_cancel))
    test_check(keyed_cancel_result.status == TASK_CANCELLED)

    var injected_request = requests.request(44, "injected", 10.0)
    test_check(requests.complete(injected_request, TASK_COMPLETED, "external"))
    test_check(requests.is_current(injected_request))
    var injected_result = requests.pop_ready()
    test_check(injected_result.matches(injected_request))
    test_check(injected_result.payload == "external")
    var sequential_request = requests.request(44, "sequential", 0.0, "next")
    test_check(sequential_request.generation == injected_request.generation + 1)
    requests.advance(0.0)
    test_check(requests.pop_ready().matches(sequential_request))

    var completed_then_removed = requests.request(55, "removed", 0.0, "late")
    requests.advance(0.0)
    test_check(requests.cancel_key(55))
    test_check(not requests.is_current(completed_then_removed))
    var removed_result = requests.pop_ready()
    test_check(removed_result.matches(completed_then_removed))
    test_check(removed_result.status == TASK_COMPLETED)

    var request_scope = requests.create_scope()
    test_check(request_scope.is_valid())
    test_check(requests.scope_is_active(request_scope))
    var scoped_request = requests.request_in_scope(
        request_scope,
        66,
        "scoped",
        10.0,
        "detached",
    )
    test_check(scoped_request.is_valid())
    test_check(scoped_request.scope_id == request_scope.id)
    test_check(requests.cancel_scope(request_scope))
    test_check(not requests.scope_is_active(request_scope))
    test_check(not requests.request_in_scope(
        request_scope,
        66,
        "closed",
        0.0,
    ).is_valid())
    var scoped_cancel_result = requests.pop_ready()
    test_check(scoped_cancel_result.matches(scoped_request))
    test_check(not requests.should_deliver(scoped_cancel_result))

    var bounded_requests = RequestScheduler(2)
    _ = bounded_requests.request(1, "one", 0.0, "one")
    _ = bounded_requests.request(2, "two", 0.0, "two")
    bounded_requests.advance(0.0)
    _ = bounded_requests.request(3, "dropped", 0.0, "dropped")
    bounded_requests.advance(0.0)
    test_check(bounded_requests.retained_count() == 2)
    _ = bounded_requests.pop_ready()
    _ = bounded_requests.pop_ready()
    test_check(bounded_requests.retained_count() == 0)

    var app = App[TaskState](TaskState(), Rect(0.0, 0.0, 520.0, 320.0))
    var handle = app.schedule_task("app task", 0.1, "payload")
    test_check(app.pending_task_count() == 1)
    test_check(app.tick(0.1))
    test_check(app.task_status(handle) == TASK_COMPLETED)
    test_check(app.component.completed == 1)
    test_check(app.forget_task(handle))

    var request_handle = app.schedule_request(7, "request", 0.1, "response")
    test_check(request_handle.is_valid())
    test_check(app.pending_request_count() == 1)
    test_check(app.request_is_current(request_handle))
    test_check(app.tick(0.1))
    test_check(app.component.request_completed == 1)
    test_check(app.component.request_key == 7)
    test_check(app.component.request_generation == request_handle.generation)
    test_check(not app.request_is_current(request_handle))

    var external_handle = app.schedule_request(8, "external", 10.0)
    test_check(app.complete_request(external_handle, TASK_COMPLETED, "adapter"))
    test_check(app.tick(0.0))
    test_check(app.component.request_completed == 2)
    test_check(app.component.request_key == 8)
    test_check(app.component.request_generation == external_handle.generation)

    var app_scope = app.create_request_scope()
    var detached_handle = app.schedule_scoped_request(
        app_scope,
        9,
        "detached",
        10.0,
        "ignored",
    )
    test_check(detached_handle.is_valid())
    test_check(app.request_scope_is_active(app_scope))
    test_check(app.cancel_request_scope(app_scope))
    test_check(not app.request_scope_is_active(app_scope))
    test_check(not app.tick(0.0))
    test_check(app.component.request_completed == 2)

    print("Moxi reactivity-tasks test passed")
