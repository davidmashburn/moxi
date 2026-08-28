"""Native macOS window and rendering backends."""

from std.ffi import external_call
from .geometry import Point, Size
from .paint import PANEL_KIND, SURFACE_KIND, PaintCommand, Renderer
from .view import BUTTON_KIND, LABEL_KIND
from .window import WindowBackend, WindowConfig


struct MacOSRenderer(Renderer):
    """Submits Moxi paint commands to the active AppKit canvas."""

    def __init__(out self):
        pass

    def begin_frame(self) raises:
        external_call["moxi_window_begin_frame", NoneType]()

    def draw(self, command: PaintCommand) raises:
        if command.kind == SURFACE_KIND:
            self.draw_surface(command)
        elif command.kind == PANEL_KIND:
            self.draw_panel(command)
        elif command.kind == LABEL_KIND:
            self.draw_label(command)
        elif command.kind == BUTTON_KIND:
            self.draw_button(command)

    def draw_surface(self, command: PaintCommand) raises:
        external_call["moxi_window_set_surface", NoneType](
            command.style.fill.red,
            command.style.fill.green,
            command.style.fill.blue,
            command.style.fill.alpha,
        )

    def draw_panel(self, command: PaintCommand) raises:
        external_call["moxi_window_set_panel", NoneType](
            command.bounds.x,
            command.bounds.y,
            command.bounds.width,
            command.bounds.height,
            command.style.fill.red,
            command.style.fill.green,
            command.style.fill.blue,
            command.style.fill.alpha,
            command.style.corner_radius,
        )

    def draw_label(self, command: PaintCommand) raises:
        var text = command.text
        var c_text = text.as_c_string_slice()
        external_call["moxi_window_set_label_at", NoneType](
            Int32(command.slot),
            c_text.ptr(),
            command.bounds.x,
            command.bounds.y,
            command.bounds.width,
            command.bounds.height,
            command.style.text.red,
            command.style.text.green,
            command.style.text.blue,
            command.style.text.alpha,
            command.style.font_size,
        )

    def draw_button(self, command: PaintCommand) raises:
        var text = command.text
        var c_text = text.as_c_string_slice()
        external_call["moxi_window_set_button_at", NoneType](
            Int32(command.slot),
            c_text.ptr(),
            command.bounds.x,
            command.bounds.y,
            command.bounds.width,
            command.bounds.height,
            command.style.fill.red,
            command.style.fill.green,
            command.style.fill.blue,
            command.style.fill.alpha,
            command.style.text.red,
            command.style.text.green,
            command.style.text.blue,
            command.style.text.alpha,
            command.style.corner_radius,
            command.style.font_size,
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

    def size(self) raises -> Size:
        return Size(
            external_call["moxi_window_width", Float32](),
            external_call["moxi_window_height", Float32](),
        )
