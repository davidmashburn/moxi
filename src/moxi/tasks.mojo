"""Deterministic, cancellable task scheduling without hidden threads."""

from std.collections import List


comptime TASK_PENDING = 0
comptime TASK_COMPLETED = 1
comptime TASK_CANCELLED = 2
comptime TASK_FAILED = 3


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
