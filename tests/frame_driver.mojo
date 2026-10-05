"""Run the shared app driver with a virtual host clock and real routed events."""

from std.collections import List

from moxi import (
    ACTION_KIND,
    ACTION_PRESS,
    Animation,
    App,
    ColumnView,
    Component,
    CounterState,
    Event,
    FRAME_TICK_KIND,
    INVALIDATE_CONTENT,
    INVALIDATE_ACCESSIBILITY,
    MemoryClipboard,
    PaintCommand,
    Rect,
    Renderer,
    SemanticActionEvent,
    Size,
    TASK_COMPLETED,
    TASK_RESULT_KIND,
    TaskScheduler,
    WindowBackend,
    test_check,
)
from moxi.accessibility import AccessibilitySnapshot


struct DriverWindow(WindowBackend):
    """Advance time only at host waits; wake early for queued input."""

    var now: Int
    var opened: Bool
    var waits: List[Float32]
    var wait_limit: Int
    var interval: Float32
    var events: List[Event]
    var event_times: List[Int]
    var event_cursor: Int

    def __init__(out self, wait_limit: Int = 4, interval: Float32 = 0.125):
        self.now = 0
        self.opened = True
        self.waits = List[Float32]()
        self.wait_limit = wait_limit
        self.interval = interval
        self.events = List[Event]()
        self.event_times = List[Int]()
        self.event_cursor = 0

    def is_open(self) raises -> Bool:
        return self.opened

    def clock_nanoseconds(self) raises -> Int:
        return self.now

    def frame_interval_seconds(self) -> Float32:
        return self.interval

    def size(self) raises -> Size:
        return Size(320.0, 160.0)

    def wait_for_work(mut self, timeout_seconds: Float32) raises:
        self.waits.append(timeout_seconds)
        if len(self.waits) > self.wait_limit:
            self.opened = False
            return
        var deadline = self.now + 125_000_000
        if timeout_seconds >= 0.0:
            deadline = self.now + max(1, Int(timeout_seconds * 1_000_000_000.0))
        if self.event_cursor < len(self.events):
            var event_time = self.event_times[self.event_cursor]
            if event_time < deadline:
                deadline = max(self.now, event_time)
        self.now = deadline

    def poll_event(mut self) raises -> Event:
        if self.event_cursor < len(self.events):
            if self.event_times[self.event_cursor] <= self.now:
                var event = self.events[self.event_cursor]
                self.event_cursor += 1
                return event
        return Event()

    def enqueue(mut self, time_ns: Int, event: Event):
        self.event_times.append(time_ns)
        self.events.append(event)


struct DriverState(Component):
    var ticks: Int
    var task_results: Int
    var request_results: Int
    var action_results: Int
    var last_request_key: Int
    var last_request_payload: String
    var tween: Animation

    def __init__(out self):
        self.ticks = 0
        self.task_results = 0
        self.request_results = 0
        self.action_results = 0
        self.last_request_key = -1
        self.last_request_payload = ""
        self.tween = Animation(0.0, 1.0, 0.5)

    def build(self, bounds: Rect) -> ColumnView:
        var view = ColumnView(bounds, 8.0, 4.0)
        view.add_label(1, String("Tasks: ", self.task_results), 24.0)
        view.add_label(2, String("Requests: ", self.request_results), 24.0)
        view.add_label(3, String("Actions: ", self.action_results), 24.0)
        view.add_label(4, String("Tween: ", self.tween.value()), 24.0)
        view.layout()
        return view^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        if event.kind == FRAME_TICK_KIND:
            self.ticks += 1
            return self.tween.advance(event.delta_seconds)
        if event.kind == TASK_RESULT_KIND and event.task_status == TASK_COMPLETED:
            if event.request_key >= 0:
                self.request_results += 1
                self.last_request_key = event.request_key
                self.last_request_payload = event.text
            else:
                self.task_results += 1
            return True
        if event.kind == ACTION_KIND:
            self.action_results += 1
            return True
        return False


struct FrameRecorder(Renderer):
    """Record each publication, including an empty incremental redraw."""

    var frames: List[Int]
    var command_ids: List[Int]
    var semantic_counts: List[Int]
    var commands: List[PaintCommand]
    var frame_ends: Int

    def __init__(out self):
        self.frames = List[Int]()
        self.command_ids = List[Int]()
        self.semantic_counts = List[Int]()
        self.commands = List[PaintCommand]()
        self.frame_ends = 0

    def supports_incremental(self) -> Bool:
        return True

    def begin_frame(mut self) raises:
        self.frames.append(0)

    def draw(mut self, command: PaintCommand) raises:
        self.frames[len(self.frames) - 1] += 1
        self.command_ids.append(command.id)
        self.commands.append(command)

    def update_accessibility(mut self, snapshot: AccessibilitySnapshot) raises:
        self.semantic_counts.append(snapshot.count())

    def end_frame(mut self) raises:
        self.frame_ends += 1


def check_scheduler_deadlines():
    var tasks = TaskScheduler()
    test_check(tasks.next_wakeup_seconds() == -1.0)
    var later = tasks.schedule("later", 0.5)
    var earlier = tasks.schedule("earlier", 0.125)
    test_check(tasks.next_wakeup_seconds() == 0.125)
    tasks.advance(0.0625)
    test_check(tasks.next_wakeup_seconds() == 0.0625)
    test_check(tasks.cancel(earlier))
    test_check(tasks.next_wakeup_seconds() == 0.0)
    _ = tasks.pop_ready()
    test_check(tasks.next_wakeup_seconds() == 0.4375)
    test_check(tasks.cancel(later))
    _ = tasks.pop_ready()
    test_check(tasks.next_wakeup_seconds() == -1.0)


def check_tasks_and_requests[with_clipboard: Bool]() raises:
    var app = App[DriverState](DriverState(), Rect(0.0, 0.0, 320.0, 160.0))
    _ = app.schedule_task("due now", 0.0)
    _ = app.schedule_task("delayed", 0.125)
    _ = app.schedule_request(5, "due request", 0.0, "first")
    _ = app.schedule_request(9, "stale", 10.0, "stale")
    _ = app.schedule_request(9, "current", 0.25, "current")
    var window = DriverWindow(4)
    var renderer = FrameRecorder()
    comptime if with_clipboard:
        var clipboard = MemoryClipboard()
        app.run_with_clipboard(window, renderer, clipboard)
    else:
        app.run(window, renderer)
    test_check(app.component.task_results == 2)
    test_check(app.component.request_results == 2)
    test_check(app.component.last_request_key == 9)
    test_check(app.component.last_request_payload == "current")
    test_check(app.pending_task_count() == 0)
    test_check(app.requests.pending_count() == 0)
    test_check(app.component.ticks == 1)
    test_check(window.waits[0] == 0.125)
    test_check(window.waits[1] == 0.125)
    test_check(window.waits[2] == -1.0)
    test_check(len(renderer.frames) == 3)
    test_check(renderer.frame_ends == 3)


def check_animation() raises:
    var app = App[DriverState](DriverState(), Rect(0.0, 0.0, 320.0, 160.0))
    app.request_animation_frames()
    var window = DriverWindow(4)
    # Waking for input halfway to a frame must not advance the animation early.
    window.enqueue(62_500_000, Event(SemanticActionEvent(3, ACTION_PRESS)))
    var renderer = FrameRecorder()
    app.run(window, renderer)
    test_check(app.component.action_results == 1)
    test_check(app.component.ticks == 4)
    test_check(app.component.tween.value() == 0.75)
    test_check(window.waits[0] == 0.125)
    test_check(window.waits[1] == 0.0625)
    test_check(window.waits[2] == 0.125)
    app.request_animation_frames(False)
    test_check(app.frame_wait_seconds(0.0, 0.125) == -1.0)


def check_idle_and_semantic_input() raises:
    var app = App[DriverState](DriverState(), Rect(0.0, 0.0, 320.0, 160.0))
    var window = DriverWindow(4)
    window.enqueue(187_500_000, Event(SemanticActionEvent(3, ACTION_PRESS)))
    var renderer = FrameRecorder()
    app.run(window, renderer)
    test_check(app.component.ticks == 1)
    test_check(app.component.action_results == 1)
    test_check(window.event_cursor == 1)
    test_check(len(window.waits) == 5)
    for index in range(len(window.waits)):
        test_check(window.waits[index] == -1.0)
    test_check(len(renderer.frames) == 2)
    # The semantic action changes one label without repainting its siblings.
    test_check(renderer.frames[1] == 1)
    test_check(renderer.command_ids[len(renderer.command_ids) - 1] == 3)
    test_check(len(renderer.semantic_counts) == 2)
    test_check(renderer.frame_ends == 2)


def check_explicit_invalidation() raises:
    var app = App[CounterState](CounterState(), Rect(0.0, 0.0, 320.0, 160.0))
    var renderer = FrameRecorder()
    app.render(renderer)
    var initial_count = renderer.frames[0]
    var bounds = app.root_bounds
    app.invalidate(INVALIDATE_CONTENT, bounds)
    test_check(app.needs_frame())
    app.render(renderer)
    test_check(renderer.frames[1] == initial_count)
    test_check(not app.needs_frame())
    app.render(renderer)
    test_check(renderer.frames[2] == 0)

    var bounded = App[DriverState](DriverState(), Rect(0.0, 0.0, 320.0, 160.0))
    var bounded_renderer = FrameRecorder()
    bounded.render(bounded_renderer)
    var label = bounded.view.bounds_for(1)
    var region = Rect(label.x + 1.0, label.y + 1.0, 2.0, 2.0)
    bounded.invalidate(INVALIDATE_CONTENT, region)
    bounded.render(bounded_renderer)
    # Repaint the background and this label, clipped to the exposed region.
    test_check(bounded_renderer.frames[1] == 2)
    for index in range(len(bounded_renderer.commands) - 2, len(bounded_renderer.commands)):
        var command = bounded_renderer.commands[index]
        test_check(command.has_clip)
        test_check(command.clip_bounds.x == region.x)
        test_check(command.clip_bounds.y == region.y)
        test_check(command.clip_bounds.width == region.width)
        test_check(command.clip_bounds.height == region.height)


def check_deadline_accounts_for_frame_work() raises:
    var app = App[DriverState](DriverState(), Rect(0.0, 0.0, 320.0, 160.0))
    app.clear_invalidation()
    _ = app.schedule_task("later", 0.5)
    var window = DriverWindow()
    window.now = 125_000_000
    app.wait_for_host_work(window, 0, 0, 0.25)
    test_check(window.waits[0] == 0.375)
    app.request_animation_frames()
    var animated_window = DriverWindow()
    animated_window.now = 125_000_000
    app.wait_for_host_work(animated_window, 0, 0, 0.25)
    test_check(animated_window.waits[0] == 0.125)


def main() raises:
    check_scheduler_deadlines()
    check_tasks_and_requests[False]()
    check_tasks_and_requests[True]()
    check_animation()
    check_idle_and_semantic_input()
    check_explicit_invalidation()
    check_deadline_accounts_for_frame_work()
    var app = App[DriverState](DriverState(), Rect(0,0,320,160))
    var renderer = FrameRecorder()
    app.render(renderer)
    app.invalidate(INVALIDATE_ACCESSIBILITY, Rect(0,0,320,160))
    app.render(renderer)
    test_check(len(renderer.frames) == 1)
    test_check(renderer.frame_ends == 1)
    test_check(len(renderer.semantic_counts) == 2)
    print("Moxi shared frame driver test passed")
