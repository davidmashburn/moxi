"""Adapter-owned request/effect contract with explicit completion acknowledgements."""

from moxi import (
    App,
    Component,
    ColumnView,
    Rect,
    RequestHandle,
    TASK_CANCELLED,
    TASK_COMPLETED,
    TASK_FAILED,
    TASK_RESULT_KIND,
    TASK_TIMED_OUT,
    test_check,
)
from moxi.event import Event


struct AdapterState(Component):
    """A component that only consumes request results through events."""

    var completed: Int
    var failed: Int
    var timed_out: Int
    var cancelled: Int
    var last_generation: Int
    var last_payload: String

    def __init__(out self):
        self.completed = 0
        self.failed = 0
        self.timed_out = 0
        self.cancelled = 0
        self.last_generation = -1
        self.last_payload = ""

    def build(self, bounds: Rect) -> ColumnView:
        # The view is a pure projection of state. It does not submit work.
        var view = ColumnView(bounds, 4.0, 2.0)
        view.add_label(1, "Request adapter", 20.0)
        view.layout()
        return view^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        if event.kind != TASK_RESULT_KIND or event.request_key < 0:
            return False
        self.last_generation = event.request_generation
        self.last_payload = event.text
        if event.task_status == TASK_COMPLETED:
            self.completed += 1
        elif event.task_status == TASK_FAILED:
            self.failed += 1
        elif event.task_status == TASK_TIMED_OUT:
            self.timed_out += 1
        elif event.task_status == TASK_CANCELLED:
            self.cancelled += 1
        else:
            return False
        return True


struct SearchEffect(ImplicitlyCopyable):
    """An explicit command value applied outside view construction."""

    var key: Int
    var query: String

    def __init__(out self, key: Int, query: String):
        self.key = key
        self.query = query

    def submit(self, mut app: App[AdapterState]) -> RequestHandle:
        return app.schedule_request(self.key, "search", 60.0, self.query)


struct NetworkAdapterProbe(ImplicitlyCopyable):
    """A synchronous test double for a host-owned network adapter."""

    var submitted: Int
    var cancel_acknowledged: Int
    var timeout_acknowledged: Int
    var completion_acknowledged: Int

    def __init__(out self):
        self.submitted = 0
        self.cancel_acknowledged = 0
        self.timeout_acknowledged = 0
        self.completion_acknowledged = 0

    def submit(
        mut self,
        mut app: App[AdapterState],
        effect: SearchEffect,
    ) -> RequestHandle:
        self.submitted += 1
        return effect.submit(app)

    def cancel(
        mut self,
        mut app: App[AdapterState],
        handle: RequestHandle,
    ) -> Bool:
        var accepted = app.cancel_request(handle)
        if accepted:
            self.cancel_acknowledged += 1
        return accepted

    def finish(
        mut self,
        mut app: App[AdapterState],
        handle: RequestHandle,
        status: Int,
        payload: String,
    ) -> Bool:
        var accepted = app.complete_request(handle, status, payload)
        if accepted:
            if status == TASK_TIMED_OUT:
                self.timeout_acknowledged += 1
            elif status == TASK_COMPLETED:
                self.completion_acknowledged += 1
        return accepted


def main():
    var app = App[AdapterState](
        AdapterState(),
        Rect(0.0, 0.0, 320.0, 120.0),
    )
    var adapter = NetworkAdapterProbe()

    var first = adapter.submit(app, SearchEffect(7, "first"))
    test_check(first.is_valid())
    test_check(adapter.submitted == 1)
    test_check(app.component.completed == 0)
    test_check(adapter.finish(app, first, TASK_COMPLETED, "answer"))
    test_check(app.tick(0.0))
    test_check(app.component.completed == 1)
    test_check(app.component.last_payload == "answer")
    test_check(adapter.completion_acknowledged == 1)

    var failed = adapter.submit(app, SearchEffect(8, "failure"))
    test_check(adapter.finish(app, failed, TASK_FAILED, "server"))
    test_check(app.tick(0.0))
    test_check(app.component.failed == 1)

    var timed_out = adapter.submit(app, SearchEffect(9, "deadline"))
    test_check(adapter.finish(app, timed_out, TASK_TIMED_OUT, "deadline"))
    test_check(adapter.timeout_acknowledged == 1)
    test_check(app.tick(0.0))
    test_check(app.component.timed_out == 1)

    var cancelled = adapter.submit(app, SearchEffect(10, "cancel"))
    test_check(adapter.cancel(app, cancelled))
    test_check(adapter.cancel_acknowledged == 1)
    test_check(app.tick(0.0))
    test_check(app.component.cancelled == 1)

    # Replacing a logical key invalidates the old generation. A host adapter
    # may receive a late transport callback, but the core rejects it.
    var stale = adapter.submit(app, SearchEffect(11, "old"))
    var current = adapter.submit(app, SearchEffect(11, "new"))
    test_check(stale.is_valid())
    test_check(current.is_valid())
    test_check(current.generation == stale.generation + 1)
    test_check(not adapter.finish(app, stale, TASK_COMPLETED, "late"))
    test_check(not app.tick(0.0))
    test_check(app.component.cancelled == 1)
    test_check(adapter.finish(app, current, TASK_COMPLETED, "fresh"))
    test_check(app.tick(0.0))
    test_check(app.component.completed == 2)
    test_check(app.component.last_payload == "fresh")

    print("Moxi request-adapter test passed")
