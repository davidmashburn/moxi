"""Metal scene renderer for the macOS GPU slice.

The native bridge keeps one reusable vertex buffer and one render submission per
frame. The Mojo side owns the scene-state interpretation (transforms, layers,
opacity, and fallback accounting), so the same command stream can still be
checked against the software renderer.
"""

from std.collections import List
from std.ffi import external_call

from .backend import BACKEND_GPU, BackendCapabilities, backend_capabilities
from .scene import (
    SCENE_CLIP,
    SCENE_IMAGE,
    SCENE_LINEAR_GRADIENT,
    SCENE_LINE,
    SCENE_PATH,
    SCENE_POP_CLIP,
    SCENE_POP_LAYER,
    SCENE_PUSH_LAYER,
    SCENE_RECT,
    SCENE_ROUNDED_RECT,
    SCENE_RESET_TRANSFORM,
    SCENE_TEXT,
    SCENE_TRANSFORM,
    Scene,
    SceneCommand,
    SceneRenderer,
)
from .event import Event
from .geometry import Point, Rect, Size, Transform
from .resources import ImageResource
from .style import Color
from .window import WindowBackend, WindowConfig


def _compose(outer: Transform, inner: Transform) -> Transform:
    """Compose two affine transforms in scene order."""
    return Transform(
        outer.m11 * inner.m11 + outer.m21 * inner.m12,
        outer.m12 * inner.m11 + outer.m22 * inner.m12,
        outer.m11 * inner.m21 + outer.m21 * inner.m22,
        outer.m12 * inner.m21 + outer.m22 * inner.m22,
        outer.m11 * inner.tx + outer.m21 * inner.ty + outer.tx,
        outer.m12 * inner.tx + outer.m22 * inner.ty + outer.ty,
    )


def _transformed_bounds(transform: Transform, bounds: Rect) -> Rect:
    """Return the axis-aligned bounds used by both portable renderers."""
    var top_left = transform.apply(Point(bounds.x, bounds.y))
    var top_right = transform.apply(Point(bounds.x + bounds.width, bounds.y))
    var bottom_left = transform.apply(Point(bounds.x, bounds.y + bounds.height))
    var bottom_right = transform.apply(
        Point(bounds.x + bounds.width, bounds.y + bounds.height)
    )
    var left = top_left.x
    var right = top_left.x
    var top = top_left.y
    var bottom = top_left.y
    if top_right.x < left:
        left = top_right.x
    if top_right.x > right:
        right = top_right.x
    if top_right.y < top:
        top = top_right.y
    if top_right.y > bottom:
        bottom = top_right.y
    if bottom_left.x < left:
        left = bottom_left.x
    if bottom_left.x > right:
        right = bottom_left.x
    if bottom_left.y < top:
        top = bottom_left.y
    if bottom_left.y > bottom:
        bottom = bottom_left.y
    if bottom_right.x < left:
        left = bottom_right.x
    if bottom_right.x > right:
        right = bottom_right.x
    if bottom_right.y < top:
        top = bottom_right.y
    if bottom_right.y > bottom:
        bottom = bottom_right.y
    return Rect(left, top, right - left, bottom - top)


def _with_opacity(color: Color, opacity: Float32) -> Color:
    var value = opacity
    if value < 0.0:
        value = 0.0
    if value > 1.0:
        value = 1.0
    return Color(color.red, color.green, color.blue, color.alpha * value)


struct MacOSMetalRenderer(SceneRenderer):
    """Batch scene geometry through an offscreen or CAMetalLayer target.

    Rectangles, rounded rectangles, lines, gradients, clipping, transforms,
    layer opacity, fast-path ASCII geometry, CoreText-rasterized Unicode text,
    registered image textures, curve/arc-flattened paths, and concave polygon
    tessellation are submitted to Metal. Unsupported image resources and
    ambiguous path commands remain explicit fallback commands and are never
    misreported as GPU-rendered pixels.
    """

    var width: Int
    var height: Int
    var initialized: Bool
    var opacity: Float32
    var transform: Transform
    var layer_stack: List[Float32]
    var frame_rect_count: Int
    var frame_line_count: Int
    var frame_fallback_count: Int
    var frame_clip_count: Int
    var frame_text_count: Int
    var frame_text_glyph_count: Int
    var frame_text_texture_count: Int
    var frame_text_texture_cache_hit_count: Int
    var frame_text_texture_raster_count: Int
    var frame_image_count: Int
    var frame_path_count: Int
    var frame_gpu_time_ms: Float32
    var frame_cpu_encode_time_ms: Float32
    var frame_cpu_wait_time_ms: Float32
    var last_frame_time_ms: Float32
    var frame_gpu_timing_available: Bool

    def __init__(out self, width: Int = 640, height: Int = 480):
        self.width = width if width > 0 else 1
        self.height = height if height > 0 else 1
        self.initialized = external_call["moxi_metal_init", Int32](
            Int32(self.width), Int32(self.height)
        ) != 0
        self.opacity = 1.0
        self.transform = Transform()
        self.layer_stack = List[Float32]()
        self.frame_rect_count = 0
        self.frame_line_count = 0
        self.frame_fallback_count = 0
        self.frame_clip_count = 0
        self.frame_text_count = 0
        self.frame_text_glyph_count = 0
        self.frame_text_texture_count = 0
        self.frame_text_texture_cache_hit_count = 0
        self.frame_text_texture_raster_count = 0
        self.frame_image_count = 0
        self.frame_path_count = 0
        self.frame_gpu_time_ms = 0.0
        self.frame_cpu_encode_time_ms = 0.0
        self.frame_cpu_wait_time_ms = 0.0
        self.last_frame_time_ms = 0.0
        self.frame_gpu_timing_available = False

    def backend_capabilities(self) -> BackendCapabilities:
        var result = backend_capabilities(BACKEND_GPU)
        result.name = "macOS Metal"
        result.available = self.initialized
        result.gpu_acceleration = self.initialized
        result.incremental = False
        result.clipping = self.initialized
        result.note = "Batched Metal geometry with ASCII fast-path text, CoreText Unicode text textures, registered images, curve/arc paths, concave fills, clips, transforms, and explicit unsupported-resource fallback."
        return result

    def is_ready(self) -> Bool:
        return self.initialized

    def begin_scene(mut self) raises:
        if self.initialized:
            self.opacity = 1.0
            self.transform = Transform()
            self.layer_stack = List[Float32]()
            self.frame_rect_count = 0
            self.frame_line_count = 0
            self.frame_fallback_count = 0
            self.frame_clip_count = 0
            self.frame_text_count = 0
            self.frame_text_glyph_count = 0
            self.frame_text_texture_count = 0
            self.frame_text_texture_cache_hit_count = 0
            self.frame_text_texture_raster_count = 0
            self.frame_image_count = 0
            self.frame_path_count = 0
            self.frame_gpu_time_ms = 0.0
            self.frame_cpu_encode_time_ms = 0.0
            self.frame_cpu_wait_time_ms = 0.0
            self.last_frame_time_ms = 0.0
            self.frame_gpu_timing_available = False
            external_call["moxi_metal_begin", NoneType](0.05, 0.07, 0.12, 1.0)

    def draw_scene_command(mut self, command: SceneCommand) raises:
        if not self.initialized:
            return
        elif command.kind == SCENE_PUSH_LAYER:
            self.layer_stack.append(self.opacity)
            self.opacity *= command.opacity
        elif command.kind == SCENE_POP_LAYER:
            if len(self.layer_stack) > 0:
                self.opacity = self.layer_stack[len(self.layer_stack) - 1]
                var restored = List[Float32]()
                for index in range(len(self.layer_stack) - 1):
                    restored.append(self.layer_stack[index])
                self.layer_stack = restored^
        elif command.kind == SCENE_TRANSFORM:
            self.transform = _compose(self.transform, command.transform)
        elif command.kind == SCENE_RESET_TRANSFORM:
            self.transform = Transform()
        elif command.kind == SCENE_RECT:
            var bounds = _transformed_bounds(self.transform, command.bounds)
            var color = _with_opacity(command.fill, self.opacity * command.opacity)
            external_call["moxi_metal_draw_rect", NoneType](
                bounds.x, bounds.y, bounds.width, bounds.height,
                color.red, color.green, color.blue, color.alpha,
            )
            self.frame_rect_count += 1
        elif command.kind == SCENE_ROUNDED_RECT:
            var bounds = _transformed_bounds(self.transform, command.bounds)
            var color = _with_opacity(command.fill, self.opacity * command.opacity)
            external_call["moxi_metal_draw_rounded_rect", NoneType](
                bounds.x, bounds.y, bounds.width, bounds.height,
                command.corner_radius,
                color.red, color.green, color.blue, color.alpha,
            )
            self.frame_rect_count += 1
        elif command.kind == SCENE_LINE:
            var start = self.transform.apply(command.point_start)
            var end = self.transform.apply(command.point_end)
            var color = _with_opacity(command.stroke, self.opacity * command.opacity)
            external_call["moxi_metal_draw_line", NoneType](
                start.x, start.y, end.x, end.y,
                command.stroke_width,
                color.red, color.green, color.blue, color.alpha,
            )
            self.frame_line_count += 1
        elif command.kind == SCENE_CLIP:
            var bounds = _transformed_bounds(self.transform, command.bounds)
            external_call["moxi_metal_push_clip", NoneType](
                bounds.x, bounds.y, bounds.width, bounds.height,
            )
            self.frame_clip_count += 1
        elif command.kind == SCENE_POP_CLIP:
            external_call["moxi_metal_pop_clip", NoneType]()
        elif command.kind == SCENE_LINEAR_GRADIENT:
            var bounds = _transformed_bounds(self.transform, command.bounds)
            var start = self.transform.apply(command.gradient_start)
            var end = self.transform.apply(command.gradient_end)
            var start_color = _with_opacity(
                command.gradient_start_color, self.opacity * command.opacity
            )
            var end_color = _with_opacity(
                command.gradient_end_color, self.opacity * command.opacity
            )
            external_call["moxi_metal_draw_gradient", NoneType](
                bounds.x, bounds.y, bounds.width, bounds.height,
                start.x, start.y, end.x, end.y,
                start_color.red, start_color.green, start_color.blue, start_color.alpha,
                end_color.red, end_color.green, end_color.blue, end_color.alpha,
            )
            self.frame_rect_count += 1
        elif command.kind == SCENE_PATH:
            var color = _with_opacity(command.fill, self.opacity * command.opacity)
            var stroke = _with_opacity(command.stroke, self.opacity * command.opacity)
            var path = command.path_data
            var result = external_call["moxi_metal_draw_path", Int32](
                path.as_c_string_slice().ptr(),
                color.red, color.green, color.blue, color.alpha,
                stroke.red, stroke.green, stroke.blue, stroke.alpha,
                command.stroke_width,
                self.transform.m11,
                self.transform.m12,
                self.transform.m21,
                self.transform.m22,
                self.transform.tx,
                self.transform.ty,
            )
            if result >= 0:
                self.frame_path_count += 1
            else:
                self.frame_fallback_count += 1
        elif command.kind == SCENE_TEXT:
            var color = _with_opacity(command.fill, self.opacity * command.opacity)
            var text = command.text
            var result = external_call["moxi_metal_draw_text", Int32](
                text.as_c_string_slice().ptr(),
                command.bounds.x,
                command.bounds.y,
                command.bounds.width,
                command.bounds.height,
                color.red,
                color.green,
                color.blue,
                color.alpha,
                self.transform.m11,
                self.transform.m12,
                self.transform.m21,
                self.transform.m22,
                self.transform.tx,
                self.transform.ty,
            )
            if result >= 0:
                self.frame_text_count += 1
                self.frame_text_glyph_count += Int(result)
            else:
                self.frame_fallback_count += 1
        elif command.kind == SCENE_IMAGE:
            var bounds = command.bounds
            var result = external_call["moxi_metal_draw_image", Int32](
                Int32(command.resource_id),
                bounds.x,
                bounds.y,
                bounds.width,
                bounds.height,
                self.opacity * command.opacity,
                self.transform.m11,
                self.transform.m12,
                self.transform.m21,
                self.transform.m22,
                self.transform.tx,
                self.transform.ty,
            )
            if result != 0:
                self.frame_image_count += 1
            else:
                self.frame_fallback_count += 1

    def end_scene(mut self) raises:
        if self.initialized:
            external_call["moxi_metal_end", NoneType]()
            self.frame_text_texture_count = Int(
                external_call["moxi_metal_text_texture_count_value", Int32]()
            )
            self.frame_text_texture_cache_hit_count = Int(
                external_call["moxi_metal_text_texture_cache_hit_count_value", Int32]()
            )
            self.frame_text_texture_raster_count = Int(
                external_call["moxi_metal_text_texture_raster_count_value", Int32]()
            )
            self.frame_gpu_time_ms = external_call["moxi_metal_gpu_time_ms_value", Float32]()
            self.frame_cpu_encode_time_ms = external_call[
                "moxi_metal_cpu_encode_time_ms_value", Float32
            ]()
            self.frame_cpu_wait_time_ms = external_call[
                "moxi_metal_cpu_wait_time_ms_value", Float32
            ]()
            self.last_frame_time_ms = external_call["moxi_metal_frame_time_ms_value", Float32]()
            self.frame_gpu_timing_available = external_call[
                "moxi_metal_gpu_timing_available_value", Int32
            ]() != 0

    def resize(mut self, width: Int, height: Int) -> Bool:
        """Resize the logical offscreen target and preserve the scene contract."""
        if not self.initialized:
            return False
        var next_width = width if width > 0 else 1
        var next_height = height if height > 0 else 1
        var resized = external_call["moxi_metal_resize", Int32](
            Int32(next_width), Int32(next_height)
        ) != 0
        if resized:
            self.width = next_width
            self.height = next_height
        return resized

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

    def buffer_capacity(self) -> Int:
        return Int(external_call["moxi_metal_buffer_capacity_value", Int32]())

    def buffer_reallocation_count(self) -> Int:
        return Int(
            external_call["moxi_metal_buffer_reallocation_count_value", Int32]()
        )

    def draw_submission_count(self) -> Int:
        return Int(
            external_call["moxi_metal_draw_submission_count_value", Int32]()
        )

    def resize_count(self) -> Int:
        return Int(external_call["moxi_metal_resize_count_value", Int32]())

    def rendered_rect_count(self) -> Int:
        return self.frame_rect_count

    def rendered_line_count(self) -> Int:
        return self.frame_line_count

    def rendered_text_count(self) -> Int:
        return self.frame_text_count

    def rendered_text_glyph_count(self) -> Int:
        return self.frame_text_glyph_count

    def rendered_text_texture_count(self) -> Int:
        """Return Unicode/CoreText text textures submitted in the last frame."""
        return self.frame_text_texture_count

    def rendered_text_texture_cache_hit_count(self) -> Int:
        """Return persistent text-cache hits recorded in the last frame."""
        return self.frame_text_texture_cache_hit_count

    def rendered_text_texture_raster_count(self) -> Int:
        """Return CoreText texture rasterizations recorded in the last frame."""
        return self.frame_text_texture_raster_count

    def rendered_image_count(self) -> Int:
        return self.frame_image_count

    def rendered_path_count(self) -> Int:
        return self.frame_path_count

    def gpu_time_ms(self) -> Float32:
        """Return GPU execution time for the last synchronized frame, when available."""
        return self.frame_gpu_time_ms

    def cpu_encode_time_ms(self) -> Float32:
        """Return CPU command encoding time for the last frame."""
        return self.frame_cpu_encode_time_ms

    def cpu_wait_time_ms(self) -> Float32:
        """Return CPU time spent waiting for completion in the last frame."""
        return self.frame_cpu_wait_time_ms

    def frame_time_ms(self) -> Float32:
        """Return synchronized begin-to-completion time for the last frame."""
        return self.last_frame_time_ms

    def gpu_timing_available(self) -> Bool:
        """Return whether the driver exposed valid GPU start/end timestamps."""
        return self.frame_gpu_timing_available

    def fallback_command_count(self) -> Int:
        return self.frame_fallback_count

    def clip_count(self) -> Int:
        return self.frame_clip_count

    def checksum(self) -> Int:
        return Int(external_call["moxi_metal_checksum", Int64]())

    def register_image(self, resource: ImageResource) raises -> Bool:
        """Upload a file-backed image to the Metal resource cache."""
        var source = resource.source
        return external_call["moxi_metal_register_image_file", Int32](
            Int32(resource.id), source.as_c_string_slice().ptr()
        ) != 0

    def release_image(self, resource_id: Int):
        """Release one cached Metal image texture."""
        external_call["moxi_metal_release_image", NoneType](Int32(resource_id))

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
        if self.opened:
            self.config.width = external_call["moxi_metal_window_width", Float32]()
            self.config.height = external_call["moxi_metal_window_height", Float32]()

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
