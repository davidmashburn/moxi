"""Window lifecycle and input contracts with portable configuration."""

from .event import Event
from .frame import FrameHost, SurfaceMetrics
from .geometry import Point, Size
from std.time import perf_counter_ns, sleep


struct WindowConfig(ImplicitlyCopyable):
    """The platform-independent inputs needed to create a window."""

    var title: String
    var width: Float32
    var height: Float32
    var min_width: Float32
    var min_height: Float32
    var max_width: Float32
    var max_height: Float32
    var resizable: Bool
    var fullscreen: Bool

    def __init__(out self, title: String, width: Float32, height: Float32):
        self.title = title
        self.width = width
        self.height = height
        self.min_width = 0.0
        self.min_height = 0.0
        self.max_width = 0.0
        self.max_height = 0.0
        self.resizable = True
        self.fullscreen = False

    def set_min_size(mut self, width: Float32, height: Float32):
        self.min_width = width if width > 0.0 else 0.0
        self.min_height = height if height > 0.0 else 0.0

    def set_max_size(mut self, width: Float32, height: Float32):
        self.max_width = width if width > 0.0 else 0.0
        self.max_height = height if height > 0.0 else 0.0

    def set_resizable(mut self, enabled: Bool):
        self.resizable = enabled

    def set_fullscreen(mut self, enabled: Bool):
        self.fullscreen = enabled


trait WindowBackend(FrameHost):
    """Owns a native window and its event-loop lifecycle."""

    def open(mut self, config: WindowConfig) raises:
        pass

    def pump(mut self) raises:
        """Process a bounded slice of native events."""
        pass

    def is_open(self) raises -> Bool:
        """Return whether the native window is still open."""
        return True

    def poll_click(mut self) raises -> Bool:
        """Consume and report one pending primary-pointer click."""
        return False

    def poll_event(mut self) raises -> Event:
        """Consume one pending backend-neutral input event."""
        return Event()

    def click_position(self) raises -> Point:
        """Return the last click position in content coordinates."""
        return Point(0.0, 0.0)

    def size(self) raises -> Size:
        """Return the current content size."""
        return Size(0.0, 0.0)

    def metrics(self) raises -> SurfaceMetrics:
        """Return logical size and scale; native hosts override their scale."""
        return SurfaceMetrics(self.size())

    def close(mut self) raises:
        """Release this host's window; adapters override their lifecycle."""
        pass

    def clock_nanoseconds(self) raises -> Int:
        """Return monotonic time; headless hosts may supply a virtual clock."""
        return perf_counter_ns()

    def frame_interval_seconds(self) -> Float32:
        """Return the requested animation cadence when animation is active."""
        return 1.0 / 60.0

    def wait_for_work(mut self, timeout_seconds: Float32) raises:
        """Wait for input or a deadline; negative means no scheduled work.

        Native hosts can wait on their event source. The portable fallback
        sleeps for a bounded slice so a host without a wake primitive still
        processes input without spinning or painting continuously.
        """
        var timeout = timeout_seconds
        if timeout < 0.0 or timeout > 1.0 / 60.0:
            timeout = 1.0 / 60.0
        if timeout > 0.0:
            sleep(Float64(timeout))

    def run(mut self) raises:
        """Pump native events until the window closes."""
        while self.is_open():
            self.pump()
            if self.is_open():
                self.wait_for_work(-1.0)
