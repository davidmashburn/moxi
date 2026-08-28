"""Window lifecycle and input contracts with portable configuration."""

from .geometry import Point


struct WindowConfig:
    """The platform-independent inputs needed to create a window."""

    var title: String
    var width: Float32
    var height: Float32

    def __init__(out self, title: String, width: Float32, height: Float32):
        self.title = title
        self.width = width
        self.height = height


trait WindowBackend:
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

    def click_position(self) raises -> Point:
        """Return the last click position in content coordinates."""
        return Point(0.0, 0.0)

    def run(mut self) raises:
        """Pump native events until the window closes."""
        while self.is_open():
            self.pump()
