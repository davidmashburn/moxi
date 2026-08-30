"""Deterministic renderer and window backends for integration tests."""

from std.ffi import external_call
from std.collections import List

from .accessibility import AccessibilitySnapshot, Semantics
from .event import Event
from .geometry import Point, Rect, Size
from .paint import PaintCommand, PaintCommands, Renderer
from .window import WindowBackend, WindowConfig


def test_check(condition: Bool):
    """Fail a test process when a contract condition is false.

    Mojo's language-level ``assert`` is not a reliable release-test gate in
    every compilation mode.  The test suite uses this explicit process-level
    check so a failed condition cannot be reported as a passing test.
    """
    if not condition:
        print("Moxi test failure")
        external_call["exit", NoneType](1)


struct TestRenderer(Renderer):
    """Record a complete frame without opening a native window."""

    var commands: List[PaintCommand]
    var incremental: Bool
    var cleared_regions: List[Rect]
    var last_accessibility_count: Int
    var last_accessibility_value_change_count: Int
    var previous_accessibility: List[Semantics]

    def __init__(out self):
        self.commands = List[PaintCommand]()
        self.incremental = False
        self.cleared_regions = List[Rect]()
        self.last_accessibility_count = 0
        self.last_accessibility_value_change_count = 0
        self.previous_accessibility = List[Semantics]()

    def begin_frame(mut self) raises:
        self.commands = List[PaintCommand]()
        self.cleared_regions = List[Rect]()
        self.last_accessibility_count = 0
        self.last_accessibility_value_change_count = 0

    def update_accessibility(
        mut self,
        snapshot: AccessibilitySnapshot,
    ) raises:
        self.last_accessibility_count = snapshot.count()
        var changes = 0
        for index in range(snapshot.count()):
            var node = snapshot.node(index)
            for previous_index in range(len(self.previous_accessibility)):
                var previous = self.previous_accessibility[previous_index]
                if previous.id == node.id:
                    if previous.role == node.role and previous.value != node.value:
                        changes += 1
                    break
        self.last_accessibility_value_change_count = changes
        self.previous_accessibility = List[Semantics]()
        for index in range(snapshot.count()):
            self.previous_accessibility.append(snapshot.node(index))

    def draw(mut self, command: PaintCommand) raises:
        self.commands.append(command)

    def supports_incremental(self) -> Bool:
        return self.incremental

    def set_incremental(mut self, enabled: Bool = True):
        """Opt this test backend into retained-surface rendering semantics."""
        self.incremental = enabled

    def clear_region(mut self, bounds: Rect) raises:
        self.cleared_regions.append(bounds)

    def count(self) -> Int:
        return len(self.commands)

    def command(self, index: Int) -> PaintCommand:
        return self.commands[index]

    def clear_count(self) -> Int:
        return len(self.cleared_regions)

    def cleared_region(self, index: Int) -> Rect:
        return self.cleared_regions[index]


struct TestWindow(WindowBackend):
    """Queue backend-neutral events for a deterministic app loop."""

    var config: WindowConfig
    var opened: Bool
    var events: List[Event]
    var cursor: Int

    def __init__(out self):
        self.config = WindowConfig("", 0.0, 0.0)
        self.opened = False
        self.events = List[Event]()
        self.cursor = 0

    def open(mut self, config: WindowConfig) raises:
        self.config = config
        self.opened = True
        self.events = List[Event]()
        self.cursor = 0

    def pump(mut self) raises:
        pass

    def is_open(self) raises -> Bool:
        return self.opened

    def poll_event(mut self) raises -> Event:
        if self.cursor >= len(self.events):
            return Event()
        var event = self.events[self.cursor]
        self.cursor += 1
        return event

    def size(self) raises -> Size:
        return Size(self.config.width, self.config.height)

    def enqueue(mut self, event: Event):
        self.events.append(event)

    def pending_count(self) -> Int:
        return len(self.events) - self.cursor

    def close(mut self):
        self.opened = False

    def run(mut self) raises:
        while self.opened and self.pending_count() > 0:
            self.pump()
            _ = self.poll_event()
        self.opened = False
