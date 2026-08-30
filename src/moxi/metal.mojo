"""Metal scene renderer for the macOS GPU slice."""

from std.ffi import external_call

from .backend import BACKEND_GPU, BackendCapabilities, backend_capabilities
from .scene import (
    SCENE_CLIP,
    SCENE_LINEAR_GRADIENT,
    SCENE_LINE,
    SCENE_PATH,
    SCENE_POP_CLIP,
    SCENE_RECT,
    SCENE_ROUNDED_RECT,
    SCENE_TEXT,
    Scene,
    SceneCommand,
    SceneRenderer,
)
from .event import Event
from .geometry import Point, Size
from .window import WindowBackend, WindowConfig


struct MacOSMetalRenderer(SceneRenderer):
    """Batch basic scene geometry through an offscreen Metal render target."""

    var width: Int
    var height: Int
    var initialized: Bool

    def __init__(out self, width: Int = 640, height: Int = 480):
        self.width = width if width > 0 else 1
        self.height = height if height > 0 else 1
        self.initialized = external_call["moxi_metal_init", Int32](
            Int32(self.width), Int32(self.height)
        ) != 0

    def backend_capabilities(self) -> BackendCapabilities:
        var result = backend_capabilities(BACKEND_GPU)
        result.available = self.initialized
        result.clipping = self.initialized
        return result

    def is_ready(self) -> Bool:
        return self.initialized

    def begin_scene(mut self) raises:
        if self.initialized:
            external_call["moxi_metal_begin", NoneType](0.05, 0.07, 0.12, 1.0)

    def draw_scene_command(mut self, command: SceneCommand) raises:
        if not self.initialized:
            return
        if command.kind == SCENE_RECT or command.kind == SCENE_ROUNDED_RECT:
            external_call["moxi_metal_draw_rect", NoneType](
                command.bounds.x,
                command.bounds.y,
                command.bounds.width,
                command.bounds.height,
                command.fill.red,
                command.fill.green,
                command.fill.blue,
                command.fill.alpha,
            )
        elif command.kind == SCENE_LINE:
            external_call["moxi_metal_draw_line", NoneType](
                command.point_start.x,
                command.point_start.y,
                command.point_end.x,
                command.point_end.y,
                command.stroke_width,
                command.stroke.red,
                command.stroke.green,
                command.stroke.blue,
                command.stroke.alpha,
            )
        elif command.kind == SCENE_CLIP:
            external_call["moxi_metal_push_clip", NoneType](
                command.bounds.x,
                command.bounds.y,
                command.bounds.width,
                command.bounds.height,
            )
        elif command.kind == SCENE_POP_CLIP:
            external_call["moxi_metal_pop_clip", NoneType]()
        elif command.kind == SCENE_LINEAR_GRADIENT:
            # The first GPU slice keeps the command portable and uses the
            # start color; a gradient shader is a follow-up capability.
            external_call["moxi_metal_draw_rect", NoneType](
                command.bounds.x,
                command.bounds.y,
                command.bounds.width,
                command.bounds.height,
                command.gradient_start_color.red,
                command.gradient_start_color.green,
                command.gradient_start_color.blue,
                command.gradient_start_color.alpha,
            )
        elif command.kind == SCENE_PATH:
            external_call["moxi_metal_draw_rect", NoneType](
                command.bounds.x,
                command.bounds.y,
                command.bounds.width,
                command.bounds.height,
                command.fill.red,
                command.fill.green,
                command.fill.blue,
                command.fill.alpha,
            )
        # Text and images wait for the shared resource/glyph upload contract.

    def end_scene(mut self) raises:
        if self.initialized:
            external_call["moxi_metal_end", NoneType]()

    def render_scene(mut self, scene: Scene) raises:
        self.begin_scene()
        for index in range(scene.count()):
            self.draw_scene_command(scene.command(index))
        self.end_scene()

    def frame_count(self) -> Int:
        return Int(external_call["moxi_metal_frame_count_value", Int32]())

    def vertex_count(self) -> Int:
        return Int(external_call["moxi_metal_vertex_count_value", Int32]())

    def overflow_count(self) -> Int:
        return Int(external_call["moxi_metal_overflow_count_value", Int32]())

    def checksum(self) -> Int:
        return Int(external_call["moxi_metal_checksum", Int64]())

    def shutdown(mut self):
        if self.initialized:
            external_call["moxi_metal_shutdown", NoneType]()
            self.initialized = False


struct MacOSMetalWindow(WindowBackend):
    """AppKit window backed by a CAMetalLayer for scene demos."""

    var config: WindowConfig
    var opened: Bool

    def __init__(out self):
        self.config = WindowConfig("Moxi Metal", 640.0, 480.0)
        self.opened = False

    def open(mut self, config: WindowConfig) raises:
        self.config = config
        var title = config.title
        self.opened = external_call["moxi_metal_open_window", Int32](
            title.as_c_string_slice().ptr(),
            config.width,
            config.height,
        ) != 0

    def pump(mut self) raises:
        external_call["moxi_metal_pump_window", NoneType]()
        self.opened = external_call["moxi_metal_window_is_open", Int32]() != 0

    def is_open(self) raises -> Bool:
        return self.opened and external_call["moxi_metal_window_is_open", Int32]() != 0

    def poll_event(mut self) raises -> Event:
        return Event()

    def click_position(self) raises -> Point:
        return Point(0.0, 0.0)

    def size(self) raises -> Size:
        return Size(self.config.width, self.config.height)

    def close(mut self):
        external_call["moxi_metal_close_window", NoneType]()
        self.opened = False
