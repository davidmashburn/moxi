"""Deterministic, cancellable task scheduling without hidden threads."""

from std.collections import List


comptime TASK_PENDING = 0
comptime TASK_COMPLETED = 1
comptime TASK_CANCELLED = 2
comptime TASK_FAILED = 3
comptime TASK_TIMED_OUT = 4
comptime REQUEST_GLOBAL_SCOPE = 0


struct TaskHandle(ImplicitlyCopyable):
    """Stable id returned when a task is scheduled."""

    var id: Int

    def __init__(out self, id: Int = -1):
        self.id = id

    def is_valid(self) -> Bool:
        return self.id >= 0


struct TaskResult(ImplicitlyCopyable):
    """A completed task message delivered through the normal event path."""

    var task_id: Int
    var status: Int
    var payload: String

    def __init__(
        out self,
        task_id: Int = -1,
        status: Int = TASK_FAILED,
        payload: String = "",
    ):
        self.task_id = task_id
        self.status = status
        self.payload = payload


struct RequestScopeHandle(ImplicitlyCopyable):
    """Stable lifetime identity for a group of component-owned requests."""

    var id: Int

    def __init__(out self, id: Int = -1):
        self.id = id

    def is_valid(self) -> Bool:
        return self.id >= 0


struct RequestHandle(ImplicitlyCopyable):
    """Stable identity for one keyed background request.

    A request key identifies the logical work owned by a component. Replacing
    the same key creates a new generation, so an adapter can ignore a result
    from an older request even when the underlying operation cannot be stopped
    immediately.
    """

    var key: Int
    var generation: Int
    var task_id: Int
    var scope_id: Int

    def __init__(
        out self,
        key: Int = -1,
        generation: Int = -1,
        task_id: Int = -1,
        scope_id: Int = REQUEST_GLOBAL_SCOPE,
    ):
        self.key = key
        self.generation = generation
        self.task_id = task_id
        self.scope_id = scope_id

    def is_valid(self) -> Bool:
        return (
            self.key >= 0
            and self.generation > 0
            and self.task_id >= 0
            and self.scope_id >= 0
        )


struct RequestResult(ImplicitlyCopyable):
    """A task result annotated with its logical request identity."""

    var key: Int
    var generation: Int
    var task_id: Int
    var status: Int
    var payload: String
    var scope_id: Int

    def __init__(
        out self,
        key: Int = -1,
        generation: Int = -1,
        task_id: Int = -1,
        status: Int = TASK_FAILED,
        payload: String = "",
        scope_id: Int = REQUEST_GLOBAL_SCOPE,
    ):
        self.key = key
        self.generation = generation
        self.task_id = task_id
        self.status = status
        self.payload = payload
        self.scope_id = scope_id

    def is_valid(self) -> Bool:
        return (
            self.key >= 0
            and self.generation > 0
            and self.task_id >= 0
            and self.scope_id >= 0
        )

    def matches(self, handle: RequestHandle) -> Bool:
        return (
            self.key == handle.key
            and self.generation == handle.generation
            and self.task_id == handle.task_id
            and self.scope_id == handle.scope_id
        )


struct TaskRecord(ImplicitlyCopyable):
    """Internal deterministic task state."""

    var id: Int
    var label: String
    var remaining_seconds: Float32
    var payload: String
    var status: Int

    def __init__(
        out self,
        id: Int,
        label: String,
        delay_seconds: Float32,
        payload: String,
    ):
        self.id = id
        self.label = label
        self.remaining_seconds = delay_seconds if delay_seconds > 0.0 else 0.0
        self.payload = payload
        self.status = TASK_PENDING


struct TaskScheduler:
    """Frame-stepped task lifecycle with bounded active and ready queues.

    Moxi leaves actual I/O and thread execution to an adapter. The adapter
    schedules a result, or applications use this deterministic scheduler for
    timers and tests. No background work is implied by this type.
    """

    var tasks: List[TaskRecord]
    var ready: List[TaskResult]
    var ready_head: Int
    var capacity_value: Int
    var next_id: Int
    var dropped_value: Int

    def __init__(out self, capacity: Int = 32):
        self.tasks = List[TaskRecord]()
        self.ready = List[TaskResult]()
        self.ready_head = 0
        self.capacity_value = capacity if capacity > 0 else 1
        self.next_id = 1
        self.dropped_value = 0

    def schedule(
        mut self,
        label: String,
        delay_seconds: Float32,
        payload: String = "",
    ) -> TaskHandle:
        var active = 0
        for index in range(len(self.tasks)):
            if self.tasks[index].status == TASK_PENDING:
                active += 1
        if active >= self.capacity_value:
            self.dropped_value += 1
            return TaskHandle()
        var id = self.next_id
        self.next_id += 1
        self.tasks.append(TaskRecord(id, label, delay_seconds, payload))
        return TaskHandle(id)

    def cancel(mut self, handle: TaskHandle) -> Bool:
        for index in range(len(self.tasks)):
            if (
                self.tasks[index].id == handle.id
                and self.tasks[index].status == TASK_PENDING
            ):
                self.tasks[index].status = TASK_CANCELLED
                self.enqueue_ready(TaskResult(handle.id, TASK_CANCELLED, ""))
                return True
        return False

    def complete(
        mut self,
        handle: TaskHandle,
        status: Int = TASK_COMPLETED,
        payload: String = "",
    ) -> Bool:
        """Inject an adapter-owned completion into the normal result queue."""
        if status == TASK_PENDING:
            return False
        for index in range(len(self.tasks)):
            if (
                self.tasks[index].id == handle.id
                and self.tasks[index].status == TASK_PENDING
            ):
                self.tasks[index].status = status
                self.enqueue_ready(TaskResult(handle.id, status, payload))
                return True
        return False

    def advance(mut self, delta_seconds: Float32):
        var delta = delta_seconds if delta_seconds > 0.0 else 0.0
        for index in range(len(self.tasks)):
            if self.tasks[index].status != TASK_PENDING:
                continue
            self.tasks[index].remaining_seconds -= delta
            if self.tasks[index].remaining_seconds <= 0.0:
                self.tasks[index].status = TASK_COMPLETED
                self.enqueue_ready(
                    TaskResult(
                        self.tasks[index].id,
                        TASK_COMPLETED,
                        self.tasks[index].payload,
                    )
                )

    def fail(mut self, handle: TaskHandle, payload: String = "") -> Bool:
        for index in range(len(self.tasks)):
            if (
                self.tasks[index].id == handle.id
                and self.tasks[index].status == TASK_PENDING
            ):
                self.tasks[index].status = TASK_FAILED
                self.enqueue_ready(TaskResult(handle.id, TASK_FAILED, payload))
                return True
        return False

    def status(self, handle: TaskHandle) -> Int:
        for index in range(len(self.tasks)):
            if self.tasks[index].id == handle.id:
                return self.tasks[index].status
        return TASK_FAILED

    def has_ready(self) -> Bool:
        return self.ready_head < len(self.ready)

    def has_ready_task(self, task_id: Int) -> Bool:
        """Return whether a result for one task remains in the ready queue."""
        for index in range(self.ready_head, len(self.ready)):
            if self.ready[index].task_id == task_id:
                return True
        return False

    def enqueue_ready(mut self, result: TaskResult):
        """Append a result without allowing the ready queue to grow forever."""
        if self.ready_head > 0:
            self.compact_ready()
        if len(self.ready) - self.ready_head >= self.capacity_value:
            self.dropped_value += 1
            return
        self.ready.append(result)

    def compact_ready(mut self):
        """Reclaim consumed result slots before another task completes."""
        if self.ready_head == 0:
            return
        var active = List[TaskResult]()
        for index in range(self.ready_head, len(self.ready)):
            active.append(self.ready[index])
        self.ready = active^
        self.ready_head = 0

    def pop_ready(mut self) -> TaskResult:
        if not self.has_ready():
            return TaskResult()
        var result = self.ready[self.ready_head]
        self.ready_head += 1
        if self.ready_head == len(self.ready):
            self.ready = List[TaskResult]()
            self.ready_head = 0
        return result

    def pending_count(self) -> Int:
        var count = 0
        for index in range(len(self.tasks)):
            if self.tasks[index].status == TASK_PENDING:
                count += 1
        return count

    def ready_count(self) -> Int:
        return len(self.ready) - self.ready_head

    def capacity(self) -> Int:
        return self.capacity_value

    def set_capacity(mut self, capacity: Int) -> Bool:
        """Change the active/result limit without dropping pending work."""
        if capacity <= 0 or capacity < self.pending_count():
            return False
        self.capacity_value = capacity
        return True

    def forget(mut self, handle: TaskHandle) -> Bool:
        """Release a terminal task record and its stable id from local history."""
        var found = False
        var retained = List[TaskRecord]()
        for index in range(len(self.tasks)):
            var task = self.tasks[index]
            if task.id == handle.id:
                if task.status == TASK_PENDING:
                    return False
                found = True
                continue
            retained.append(task)
        if found:
            self.tasks = retained^
        return found

    def dropped_count(self) -> Int:
        return self.dropped_value


struct RequestRecord(ImplicitlyCopyable):
    """Internal request history retained until its result is consumed."""

    var handle: RequestHandle
    var active: Bool

    def __init__(out self, handle: RequestHandle, active: Bool = True):
        self.handle = handle
        self.active = active


struct RequestKeyState(ImplicitlyCopyable):
    """Internal monotonic generation counter for one logical request key."""

    var scope_id: Int
    var key: Int
    var generation: Int

    def __init__(
        out self,
        scope_id: Int,
        key: Int,
        generation: Int = 0,
    ):
        self.scope_id = scope_id
        self.key = key
        self.generation = generation


struct RequestScopeRecord(ImplicitlyCopyable):
    """Internal active/inactive state for one request lifetime scope."""

    var id: Int
    var active: Bool

    def __init__(out self, id: Int, active: Bool = True):
        self.id = id
        self.active = active


struct RequestScheduler:
    """Keyed request lifecycle on top of the deterministic task scheduler.

    This type describes request ownership but does not execute I/O or create
    threads. A host adapter may use the handle and generation to connect real
    work to the normal event path. Submitting a new request for an existing key
    cancels the previous pending task and makes the new generation current.
    """

    var tasks: TaskScheduler
    var requests: List[RequestRecord]
    var key_states: List[RequestKeyState]
    var scopes: List[RequestScopeRecord]
    var next_scope_id: Int

    def __init__(out self, capacity: Int = 32):
        self.tasks = TaskScheduler(capacity)
        self.requests = List[RequestRecord]()
        self.key_states = List[RequestKeyState]()
        self.scopes = List[RequestScopeRecord]()
        self.next_scope_id = 1

    def create_scope(mut self) -> RequestScopeHandle:
        """Create a scope whose requests can be invalidated together."""
        var id = self.next_scope_id
        self.next_scope_id += 1
        self.scopes.append(RequestScopeRecord(id))
        return RequestScopeHandle(id)

    def scope_is_active(self, scope: RequestScopeHandle) -> Bool:
        """Return whether a request scope may still receive completions."""
        if not scope.is_valid():
            return False
        if scope.id == REQUEST_GLOBAL_SCOPE:
            return True
        for index in range(len(self.scopes)):
            if self.scopes[index].id == scope.id:
                return self.scopes[index].active
        return False

    def _prune_records(mut self):
        """Drop terminal requests whose bounded result queue lost them."""
        var retained = List[RequestRecord]()
        for index in range(len(self.requests)):
            var record = self.requests[index]
            var task = TaskHandle(record.handle.task_id)
            if (
                self.tasks.status(task) == TASK_PENDING
                or self.tasks.has_ready_task(record.handle.task_id)
            ):
                retained.append(record)
        self.requests = retained^

    def request(
        mut self,
        key: Int,
        label: String,
        delay_seconds: Float32,
        payload: String = "",
    ) -> RequestHandle:
        """Start or replace a request in the process-wide scope."""
        return self.request_in_scope(
            RequestScopeHandle(REQUEST_GLOBAL_SCOPE),
            key,
            label,
            delay_seconds,
            payload,
        )

    def request_in_scope(
        mut self,
        scope: RequestScopeHandle,
        key: Int,
        label: String,
        delay_seconds: Float32,
        payload: String = "",
    ) -> RequestHandle:
        """Start or replace the request associated with ``scope`` and ``key``."""
        self._prune_records()
        if not self.scope_is_active(scope) or key < 0:
            return RequestHandle()

        var generation = 0
        var key_state_index = -1
        for index in range(len(self.key_states)):
            if (
                self.key_states[index].scope_id == scope.id
                and self.key_states[index].key == key
            ):
                generation = self.key_states[index].generation
                key_state_index = index
                break

        for index in range(len(self.requests)):
            var record = self.requests[index]
            if (
                record.handle.scope_id != scope.id
                or record.handle.key != key
            ):
                continue
            if record.active:
                # The task may already be complete but still waiting in the
                # ready queue. It is still stale once this key is replaced.
                _ = self.tasks.cancel(TaskHandle(record.handle.task_id))
                record.active = False
                self.requests[index] = record

        var task = self.tasks.schedule(label, delay_seconds, payload)
        if not task.is_valid():
            return RequestHandle()

        var next_generation = generation + 1
        if key_state_index == -1:
            self.key_states.append(
                RequestKeyState(scope.id, key, next_generation)
            )
        else:
            var key_state = self.key_states[key_state_index]
            key_state.generation = next_generation
            self.key_states[key_state_index] = key_state
        var handle = RequestHandle(key, next_generation, task.id, scope.id)
        self.requests.append(RequestRecord(handle))
        return handle

    def cancel(mut self, handle: RequestHandle) -> Bool:
        """Invalidate one request generation and cancel it when still pending."""
        for index in range(len(self.requests)):
            var record = self.requests[index]
            if (
                not record.active
                or record.handle.scope_id != handle.scope_id
                or record.handle.task_id != handle.task_id
            ):
                continue
            _ = self.tasks.cancel(TaskHandle(record.handle.task_id))
            record.active = False
            self.requests[index] = record
            return True
        return False

    def cancel_key(mut self, key: Int) -> Bool:
        """Invalidate the current global-scope request for a key."""
        return self.cancel_key_in_scope(
            RequestScopeHandle(REQUEST_GLOBAL_SCOPE),
            key,
        )

    def cancel_key_in_scope(
        mut self,
        scope: RequestScopeHandle,
        key: Int,
    ) -> Bool:
        """Invalidate the current request for a scoped key."""
        for index in range(len(self.requests)):
            var record = self.requests[index]
            if (
                not record.active
                or record.handle.scope_id != scope.id
                or record.handle.key != key
            ):
                continue
            _ = self.tasks.cancel(TaskHandle(record.handle.task_id))
            record.active = False
            self.requests[index] = record
            return True
        return False

    def cancel_scope(mut self, scope: RequestScopeHandle) -> Bool:
        """Invalidate every request and close one non-global scope."""
        if not self.scope_is_active(scope):
            return False
        var changed = False
        for index in range(len(self.requests)):
            var record = self.requests[index]
            if record.handle.scope_id != scope.id or not record.active:
                continue
            _ = self.tasks.cancel(TaskHandle(record.handle.task_id))
            record.active = False
            self.requests[index] = record
            changed = True

        if scope.id == REQUEST_GLOBAL_SCOPE:
            self._prune_records()
            return changed

        for index in range(len(self.scopes)):
            if self.scopes[index].id == scope.id:
                var scope_record = self.scopes[index]
                scope_record.active = False
                self.scopes[index] = scope_record
                break

        var retained_states = List[RequestKeyState]()
        for index in range(len(self.key_states)):
            if self.key_states[index].scope_id != scope.id:
                retained_states.append(self.key_states[index])
        self.key_states = retained_states^
        self._prune_records()
        return True

    def complete(
        mut self,
        handle: RequestHandle,
        status: Int = TASK_COMPLETED,
        payload: String = "",
    ) -> Bool:
        """Inject an adapter completion while preserving request metadata."""
        for index in range(len(self.requests)):
            var record = self.requests[index]
            if (
                record.active
                and record.handle.scope_id == handle.scope_id
                and record.handle.key == handle.key
                and record.handle.generation == handle.generation
                and record.handle.task_id == handle.task_id
            ):
                return self.tasks.complete(
                    TaskHandle(record.handle.task_id),
                    status,
                    payload,
                )
        return False

    def is_current(self, handle: RequestHandle) -> Bool:
        """Return whether a handle is the active generation for its key."""
        for index in range(len(self.requests)):
            var record = self.requests[index]
            if (
                record.active
                and record.handle.scope_id == handle.scope_id
                and record.handle.key == handle.key
                and record.handle.generation == handle.generation
                and record.handle.task_id == handle.task_id
            ):
                return True
        return False

    def current(self, key: Int) -> RequestHandle:
        """Return the active global-scope request for a key, if any."""
        return self.current_in_scope(
            RequestScopeHandle(REQUEST_GLOBAL_SCOPE),
            key,
        )

    def current_in_scope(
        self,
        scope: RequestScopeHandle,
        key: Int,
    ) -> RequestHandle:
        """Return the active request for a scoped key, if any."""
        for index in range(len(self.requests)):
            var record = self.requests[index]
            if (
                record.active
                and record.handle.scope_id == scope.id
                and record.handle.key == key
            ):
                return record.handle
        return RequestHandle()

    def advance(mut self, delta_seconds: Float32):
        """Advance deterministic work; real adapters may supply completions."""
        self.tasks.advance(delta_seconds)
        self._prune_records()

    def has_ready(self) -> Bool:
        return self.tasks.has_ready()

    def pop_ready(mut self) -> RequestResult:
        """Pop one result and retain its logical key/generation metadata."""
        if not self.tasks.has_ready():
            return RequestResult()
        var result = self.tasks.pop_ready()
        for index in range(len(self.requests)):
            var record = self.requests[index]
            if record.handle.task_id != result.task_id:
                continue
            var request_result = RequestResult(
                record.handle.key,
                record.handle.generation,
                result.task_id,
                result.status,
                result.payload,
                record.handle.scope_id,
            )
            _ = self.requests.pop(index)
            return request_result
        return RequestResult(
            -1,
            -1,
            result.task_id,
            result.status,
            result.payload,
            -1,
        )

    def should_deliver(self, result: RequestResult) -> Bool:
        """Reject completions belonging to a closed request scope."""
        return self.scope_is_active(RequestScopeHandle(result.scope_id))

    def retained_count(self) -> Int:
        """Return retained request metadata after bounded-queue pruning."""
        return len(self.requests)

    def pending_count(self) -> Int:
        return self.tasks.pending_count()

    def ready_count(self) -> Int:
        return self.tasks.ready_count()

    def capacity(self) -> Int:
        return self.tasks.capacity()

    def set_capacity(mut self, capacity: Int) -> Bool:
        return self.tasks.set_capacity(capacity)

    def dropped_count(self) -> Int:
        return self.tasks.dropped_count()
