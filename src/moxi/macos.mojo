"""Native macOS window and rendering backends."""

from std.ffi import external_call
from .geometry import Point
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

    def draw_button(self, command: PaintCommand) raises:
        var text = command.text
        var c_text = text.as_c_string_slice()
        external_call["moxi_window_set_button", NoneType](
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

    def open(mut self, config: WindowConfig) raises:
        var title = config.title
        var c_title = title.as_c_string_slice()
        external_call["moxi_window_open", NoneType](
            c_title.ptr(), config.width, config.height
        )

    def run(mut self) raises:
        while self.is_open():
            self.pump()

    def pump(mut self) raises:
        external_call["moxi_window_pump", NoneType]()

    def is_open(self) raises -> Bool:
        return external_call["moxi_window_is_open", Int32]() != 0

    def poll_click(mut self) raises -> Bool:
        return external_call["moxi_window_poll_click", Int32]() != 0

    def click_position(self) raises -> Point:
        return Point(
            external_call["moxi_window_click_x", Float32](),
            external_call["moxi_window_click_y", Float32](),
        )
