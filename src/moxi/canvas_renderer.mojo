"""Portable ``canvas_mojo`` scene renderer.

This adapter is intentionally a small vertical slice.  It owns a canvas
buffer and translates the renderer-neutral scene contract into canvas
operations; it does not expose canvas types through ``Scene``.  Text, image,
and string-path commands are counted as explicit fallbacks until Moxi has a
shared resource/text/path contract that can be consumed without guessing.
"""

from std.collections import List
from std.math import ceil, floor

from canvas import (
    Canvas,
    Color as CanvasColor,
    FillRule,
    LinearGradient,
    Matrix2D,
    Path,
    draw_line_aa,
    fill_path_aa,
    fill_rect,
    fill_rect_gradient,
    stroke_path_aa,
    write_bmp,
    write_png,
)

from .backend import BACKEND_HEADLESS, BackendCapabilities
from .geometry import Point, Rect, Transform
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
    SCENE_RESET_TRANSFORM,
    SCENE_ROUNDED_RECT,
    SCENE_TEXT,
    SCENE_TRANSFORM,
    SceneCommand,
    SceneRenderer,
)
from .style import Color


def _clamp_unit(value: Float32) -> Float32:
    if value < 0.0:
        return 0.0
    if value > 1.0:
        return 1.0
    return value


def _channel(value: Float32) -> UInt8:
    return UInt8(_clamp_unit(value) * 255.0 + 0.5)


def _canvas_color(color: Color, opacity: Float32 = 1.0) -> CanvasColor:
    return CanvasColor(
        _channel(color.red),
        _channel(color.green),
        _channel(color.blue),
        _channel(color.alpha * _clamp_unit(opacity)),
    )


def _matrix(transform: Transform) -> Matrix2D:
    return Matrix2D(
        Float64(transform.m11),
        Float64(transform.m12),
        Float64(transform.m21),
        Float64(transform.m22),
        Float64(transform.tx),
        Float64(transform.ty),
    )


def _clip_bounds(bounds: Rect) -> Tuple[Int, Int, Int, Int]:
    """Convert a continuous scene clip to a half-open pixel rectangle."""
    var left = Int(floor(Float64(bounds.x)))
    var top = Int(floor(Float64(bounds.y)))
    var right = Int(ceil(Float64(bounds.x + bounds.width)))
    var bottom = Int(ceil(Float64(bounds.y + bounds.height)))
    if right < left:
        right = left
    if bottom < top:
        bottom = top
    return (left, top, right - left, bottom - top)


def _rounded_path(bounds: Rect, radius: Float32) raises -> Path:
    var path = Path()
    path.round_rect(
        Float64(bounds.x),
        Float64(bounds.y),
        Float64(bounds.width),
        Float64(bounds.height),
        Float64(radius),
    )
    return path^


struct CanvasSceneRenderer(SceneRenderer):
    """Render the supported Moxi scene subset into a ``canvas_mojo`` buffer.

    The canvas package is a raster/export backend, not the scene contract.
    ``fallback_count`` makes unsupported commands observable to callers and
    tests instead of turning them into misleading placeholder pixels.
    """

    var width: Int
    var height: Int
    var background: Color
    var canvas: Canvas
    var opacity: Float32
    var opacity_stack: List[Float32]
    var frame_count: Int
    var command_count: Int
    var fallback_count: Int

    def __init__(
        out self,
        width: Int = 640,
        height: Int = 480,
        background: Color = Color(0.0, 0.0, 0.0, 0.0),
    ) raises:
        self.width = width if width > 0 else 1
        self.height = height if height > 0 else 1
        self.background = background
        self.canvas = Canvas(
            self.width,
            self.height,
            _canvas_color(background),
        )
        self.opacity = 1.0
        self.opacity_stack = List[Float32]()
        self.frame_count = 0
        self.command_count = 0
        self.fallback_count = 0

    def backend_capabilities(self) -> BackendCapabilities:
        return BackendCapabilities(
            BACKEND_HEADLESS,
            "canvas_mojo",
            True,
            False,
            False,
            False,
            False,
            False,
            False,
            True,
            False,
            "Portable RGBA/PNG raster export for the supported Scene subset; text, images, and string paths remain explicit fallbacks.",
        )

    def begin_scene(mut self) raises:
        # Reinitialize the value so unbalanced input from a caller cannot leak
        # clips, transforms, or layer state into the next frame.
        self.canvas = Canvas(
            self.width,
            self.height,
            _canvas_color(self.background),
        )
        self.opacity = 1.0
        self.opacity_stack = List[Float32]()
        self.command_count = 0
        self.fallback_count = 0

    def draw_scene_command(mut self, command: SceneCommand) raises:
        self.command_count += 1

        if command.kind == SCENE_PUSH_LAYER:
            self.opacity_stack.append(self.opacity)
            self.opacity *= _clamp_unit(command.opacity)
        elif command.kind == SCENE_POP_LAYER:
            if len(self.opacity_stack) > 0:
                self.opacity = self.opacity_stack.pop()
        elif command.kind == SCENE_TRANSFORM:
            self.canvas.transform(_matrix(command.transform))
        elif command.kind == SCENE_RESET_TRANSFORM:
            self.canvas.reset_transform()
        elif command.kind == SCENE_CLIP:
            var clip = _clip_bounds(command.bounds)
            self.canvas.push_clip(clip[0], clip[1], clip[2], clip[3])
        elif command.kind == SCENE_POP_CLIP:
            self.canvas.pop_clip()
        elif command.kind == SCENE_RECT:
            fill_rect(
                self.canvas,
                Float64(command.bounds.x),
                Float64(command.bounds.y),
                Float64(command.bounds.width),
                Float64(command.bounds.height),
                _canvas_color(command.fill, self.opacity * command.opacity),
            )
        elif command.kind == SCENE_ROUNDED_RECT:
            var fill_path = _rounded_path(command.bounds, command.corner_radius)
            fill_path_aa(
                self.canvas,
                fill_path,
                _canvas_color(command.fill, self.opacity * command.opacity),
                FillRule.EVEN_ODD,
            )
            if command.stroke_width > 0.0 and command.stroke.alpha > 0.0:
                var stroke_path = _rounded_path(
                    command.bounds,
                    command.corner_radius,
                )
                stroke_path_aa(
                    self.canvas,
                    stroke_path,
                    _canvas_color(
                        command.stroke,
                        self.opacity * command.opacity,
                    ),
                    Float64(command.stroke_width),
                )
        elif command.kind == SCENE_LINE:
            draw_line_aa(
                self.canvas,
                Float64(command.point_start.x),
                Float64(command.point_start.y),
                Float64(command.point_end.x),
                Float64(command.point_end.y),
                _canvas_color(command.stroke, self.opacity * command.opacity),
                Float64(command.stroke_width),
            )
        elif command.kind == SCENE_LINEAR_GRADIENT:
            var gradient = LinearGradient(
                Float64(command.gradient_start.x),
                Float64(command.gradient_start.y),
                Float64(command.gradient_end.x),
                Float64(command.gradient_end.y),
            )
            gradient.add_stop(
                0.0,
                _canvas_color(
                    command.gradient_start_color,
                    self.opacity * command.opacity,
                ),
            )
            gradient.add_stop(
                1.0,
                _canvas_color(
                    command.gradient_end_color,
                    self.opacity * command.opacity,
                ),
            )
            fill_rect_gradient(
                self.canvas,
                Float64(command.bounds.x),
                Float64(command.bounds.y),
                Float64(command.bounds.width),
                Float64(command.bounds.height),
                gradient,
            )
        elif (
            command.kind == SCENE_TEXT
            or command.kind == SCENE_IMAGE
            or command.kind == SCENE_PATH
        ):
            self.fallback_count += 1

    def end_scene(mut self) raises:
        self.frame_count += 1

    def pixel(self, x: Int, y: Int) -> Color:
        """Read one rendered pixel as a normalized Moxi color."""
        var pixel = self.canvas.get_pixel(x, y)
        return Color(
            Float32(pixel.r) / 255.0,
            Float32(pixel.g) / 255.0,
            Float32(pixel.b) / 255.0,
            Float32(pixel.a) / 255.0,
        )

    def checksum(self) -> Int:
        """Return a stable RGBA checksum for deterministic tests."""
        var result = 0
        for y in range(self.height):
            for x in range(self.width):
                var pixel = self.canvas.get_pixel(x, y)
                result += Int(pixel.r)
                result += Int(pixel.g) * 3
                result += Int(pixel.b) * 7
                result += Int(pixel.a) * 11
        return result

    def rgba_bytes(self) -> List[UInt8]:
        """Copy the row-major RGBA buffer for a value-boundary consumer."""
        var result = List[UInt8](capacity=self.width * self.height * 4)
        for byte in self.canvas.pixels:
            result.append(byte)
        return result^

    def write_png(mut self, path: String) raises:
        """Write the current RGBA frame as a PNG."""
        write_png(self.canvas, path)

    def write_bmp(mut self, path: String) raises:
        """Write the current frame as a BMP for simple inspection."""
        write_bmp(self.canvas, path)
