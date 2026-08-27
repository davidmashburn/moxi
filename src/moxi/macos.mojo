"""Native macOS presentation backend for the first Moxi demo."""

from std.ffi import external_call
from .paint import PaintCommand, Renderer


struct MacOSBackend(Renderer):
    """Presents the first Moxi paint command through AppKit."""

    def __init__(out self):
        pass

    def draw_label(self, command: PaintCommand):
        # The first C-ABI shim owns AppKit objects and the application run loop.
        external_call["moxi_show_window", NoneType]()
