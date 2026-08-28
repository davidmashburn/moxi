"""Native macOS window and rendering backends."""

from std.ffi import external_call
from .paint import PaintCommand, Renderer
from .window import WindowBackend, WindowConfig


struct MacOSRenderer(Renderer):
    """Submits Moxi paint commands to the active AppKit canvas."""

    def __init__(out self):
        pass

    def draw_label(self, command: PaintCommand) raises:
        var text = command.text
        var c_text = text.as_c_string_slice()
        external_call["moxi_window_set_label", NoneType](
            c_text.ptr(),
            command.bounds.x,
            command.bounds.y,
            command.bounds.width,
            command.bounds.height,
        )


struct MacOSWindow(WindowBackend):
    """Owns the AppKit window lifecycle without owning view state."""

    def __init__(out self):
        pass

    def open(self, config: WindowConfig) raises:
        var title = config.title
        var c_title = title.as_c_string_slice()
        external_call["moxi_window_open", NoneType](
            c_title.ptr(), config.width, config.height
        )

    def run(self) raises:
        external_call["moxi_window_run", NoneType]()
