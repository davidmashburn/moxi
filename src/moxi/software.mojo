"""Small deterministic software scene renderer for headless validation."""

from std.collections import List

from .geometry import Point, Rect, Transform
from .scene import (
    SCENE_CLIP,
    SCENE_IMAGE,
    SCENE_LINEAR_GRADIENT,
    SCENE_LINE,
    SCENE_POP_CLIP,
    SCENE_POP_LAYER,
    SCENE_PATH,
    SCENE_PUSH_LAYER,
    SCENE_RESET_TRANSFORM,
    SCENE_RECT,
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


def _lerp(left: Float32, right: Float32, amount: Float32) -> Float32:
    return left + (right - left) * amount


def _over(background: Color, foreground: Color) -> Color:
    """Composite one source color over a destination color."""
    var alpha = _clamp_unit(foreground.alpha)
    var inverse = 1.0 - alpha
    return Color(
        foreground.red * alpha + background.red * inverse,
        foreground.green * alpha + background.green * inverse,
        foreground.blue * alpha + background.blue * inverse,
        alpha + background.alpha * inverse,
    )


def _with_opacity(color: Color, opacity: Float32) -> Color:
    var value = _clamp_unit(opacity)
    return Color(color.red, color.green, color.blue, color.alpha * value)


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


def _line_distance_squared(
    px: Float32,
    py: Float32,
    start: Point,
    end: Point,
) -> Float32:
    """Return the squared distance from a point to a line segment."""
    var dx = end.x - start.x
    var dy = end.y - start.y
    var length_squared = dx * dx + dy * dy
    if length_squared <= 0.0:
        var point_dx = px - start.x
        var point_dy = py - start.y
        return point_dx * point_dx + point_dy * point_dy
    var amount = ((px - start.x) * dx + (py - start.y) * dy) / length_squared
    if amount < 0.0:
        amount = 0.0
    if amount > 1.0:
        amount = 1.0
    var closest_x = start.x + amount * dx
    var closest_y = start.y + amount * dy
    var point_dx = px - closest_x
    var point_dy = py - closest_y
    return point_dx * point_dx + point_dy * point_dy


struct SoftwareSceneRenderer(SceneRenderer):
    """Rasterize basic scene primitives into a deterministic RGBA buffer.

    This is intentionally a compact verification backend, not a replacement
    for a GPU compositor. Rectangles, rounded rectangles, gradients, line
    segments, and paths' declared bounds are rasterized; text and images remain
    resource-dependent and are counted without inventing pixels.
    """

    var width: Int
    var height: Int
    var background: Color
    var pixels: List[Color]
    var command_count: Int
    var frame_count: Int
    var clip_stack: List[Rect]
    var layer_stack: List[Float32]
    var has_clip: Bool
    var clip: Rect
    var opacity: Float32
    var transform: Transform

    def __init__(
        out self,
        width: Int,
        height: Int,
        background: Color = Color(0.0, 0.0, 0.0, 0.0),
    ):
        self.width = width if width > 0 else 1
        self.height = height if height > 0 else 1
        self.background = background
        self.pixels = List[Color]()
        self.command_count = 0
        self.frame_count = 0
        self.clip_stack = List[Rect]()
        self.layer_stack = List[Float32]()
        self.has_clip = False
        self.clip = Rect(0.0, 0.0, 0.0, 0.0)
        self.opacity = 1.0
        self.transform = Transform()
        self.clear()

    def clear(mut self):
        """Clear the complete software surface to its background color."""
        self.pixels = List[Color]()
        for _ in range(self.width * self.height):
            self.pixels.append(self.background)

    def begin_scene(mut self) raises:
        self.clear()
        self.command_count = 0
        self.clip_stack = List[Rect]()
        self.layer_stack = List[Float32]()
        self.has_clip = False
        self.clip = Rect(0.0, 0.0, 0.0, 0.0)
        self.opacity = 1.0
        self.transform = Transform()

    def draw_scene_command(mut self, command: SceneCommand) raises:
        self.command_count += 1
        if command.kind == SCENE_CLIP:
            if self.has_clip:
                self.clip = self.clip.intersection(command.bounds)
            else:
                self.clip = command.bounds
                self.has_clip = True
            self.clip_stack.append(self.clip)
        elif command.kind == SCENE_POP_CLIP:
            if len(self.clip_stack) > 1:
                var restored = List[Rect]()
                for index in range(len(self.clip_stack) - 1):
                    restored.append(self.clip_stack[index])
                self.clip_stack = restored^
                self.clip = self.clip_stack[len(self.clip_stack) - 1]
            elif len(self.clip_stack) == 1:
                self.clip_stack = List[Rect]()
                self.has_clip = False
        elif command.kind == SCENE_PUSH_LAYER:
            self.layer_stack.append(self.opacity)
            self.opacity *= _clamp_unit(command.opacity)
        elif command.kind == SCENE_POP_LAYER:
            if len(self.layer_stack) > 0:
                var restored = List[Float32]()
                for index in range(len(self.layer_stack) - 1):
                    restored.append(self.layer_stack[index])
                self.opacity = self.layer_stack[len(self.layer_stack) - 1]
                self.layer_stack = restored^
        elif command.kind == SCENE_TRANSFORM:
            self.transform = _compose(self.transform, command.transform)
        elif command.kind == SCENE_RESET_TRANSFORM:
            self.transform = Transform()
        elif command.kind == SCENE_RECT:
            self.fill_rect(
                _transformed_bounds(self.transform, command.bounds),
                _with_opacity(command.fill, self.opacity * command.opacity),
            )
        elif command.kind == SCENE_ROUNDED_RECT:
            self.fill_rounded_rect(
                _transformed_bounds(self.transform, command.bounds),
                _with_opacity(command.fill, self.opacity * command.opacity),
                command.corner_radius,
            )
        elif command.kind == SCENE_LINEAR_GRADIENT:
            self.fill_gradient(
                _transformed_bounds(self.transform, command.bounds),
                self.transform.apply(command.gradient_start),
                self.transform.apply(command.gradient_end),
                _with_opacity(
                    command.gradient_start_color,
                    self.opacity * command.opacity,
                ),
                _with_opacity(
                    command.gradient_end_color,
                    self.opacity * command.opacity,
                ),
            )
        elif command.kind == SCENE_LINE:
            var start = self.transform.apply(command.point_start)
            var end = self.transform.apply(command.point_end)
            var stroke_width = command.stroke_width if command.stroke_width > 0.0 else 1.0
            self.stroke_line(
                start,
                end,
                _with_opacity(command.stroke, self.opacity * command.opacity),
                stroke_width,
            )
        elif command.kind == SCENE_PATH:
            # The path grammar belongs to a future path tessellator. Its
            # declared bounds still make a useful deterministic smoke path.
            self.fill_rect(
                _transformed_bounds(self.transform, command.bounds),
                _with_opacity(command.fill, self.opacity * command.opacity),
            )
        elif command.kind == SCENE_TEXT or command.kind == SCENE_IMAGE:
            # Resource and glyph rasterization are deliberately not faked.
            pass

    def end_scene(mut self) raises:
        self.frame_count += 1

    def fill_rect(mut self, bounds: Rect, color: Color):
        var visible = bounds
        if self.has_clip:
            visible = visible.intersection(self.clip)
        var left = Int(visible.x)
        var top = Int(visible.y)
        var right = Int(visible.x + visible.width)
        var bottom = Int(visible.y + visible.height)
        if left < 0:
            left = 0
        if top < 0:
            top = 0
        if right > self.width:
            right = self.width
        if bottom > self.height:
            bottom = self.height
        if right <= left or bottom <= top:
            return
        for y in range(top, bottom):
            for x in range(left, right):
                self.pixels[y * self.width + x] = _over(
                    self.pixels[y * self.width + x],
                    color,
                )

    def fill_rounded_rect(mut self, bounds: Rect, color: Color, radius: Float32):
        """Fill an axis-aligned rounded rectangle with optional clipping."""
        var visible = bounds
        if self.has_clip:
            visible = visible.intersection(self.clip)
        var left = Int(visible.x)
        var top = Int(visible.y)
        var right = Int(visible.x + visible.width)
        var bottom = Int(visible.y + visible.height)
        if left < 0:
            left = 0
        if top < 0:
            top = 0
        if right > self.width:
            right = self.width
        if bottom > self.height:
            bottom = self.height
        if right <= left or bottom <= top:
            return
        var safe_radius = radius
        if safe_radius < 0.0:
            safe_radius = 0.0
        var half_width = bounds.width * 0.5
        var half_height = bounds.height * 0.5
        if safe_radius > half_width:
            safe_radius = half_width
        if safe_radius > half_height:
            safe_radius = half_height
        var radius_squared = safe_radius * safe_radius
        for y in range(top, bottom):
            for x in range(left, right):
                var px = Float32(x) + 0.5
                var py = Float32(y) + 0.5
                var inside = True
                if safe_radius > 0.0:
                    var corner_x = bounds.x + safe_radius
                    if px > bounds.x + bounds.width - safe_radius:
                        corner_x = bounds.x + bounds.width - safe_radius
                    var corner_y = bounds.y + safe_radius
                    if py > bounds.y + bounds.height - safe_radius:
                        corner_y = bounds.y + bounds.height - safe_radius
                    var in_horizontal = (
                        px >= bounds.x + safe_radius
                        and px <= bounds.x + bounds.width - safe_radius
                    )
                    var in_vertical = (
                        py >= bounds.y + safe_radius
                        and py <= bounds.y + bounds.height - safe_radius
                    )
                    if not in_horizontal and not in_vertical:
                        var dx = px - corner_x
                        var dy = py - corner_y
                        inside = dx * dx + dy * dy <= radius_squared
                if inside:
                    self.pixels[y * self.width + x] = _over(
                        self.pixels[y * self.width + x],
                        color,
                    )

    def stroke_line(
        mut self,
        start: Point,
        end: Point,
        color: Color,
        width: Float32,
    ):
        """Rasterize a line segment with a circular coverage threshold."""
        var half_width = width * 0.5
        if half_width <= 0.0:
            half_width = 0.5
        var left = start.x if start.x < end.x else end.x
        var right = start.x if start.x > end.x else end.x
        var top = start.y if start.y < end.y else end.y
        var bottom = start.y if start.y > end.y else end.y
        left -= half_width
        right += half_width
        top -= half_width
        bottom += half_width
        var visible = Rect(left, top, right - left, bottom - top)
        if self.has_clip:
            visible = visible.intersection(self.clip)
        var first_x = Int(visible.x)
        var first_y = Int(visible.y)
        var last_x = Int(visible.x + visible.width)
        var last_y = Int(visible.y + visible.height)
        if first_x < 0:
            first_x = 0
        if first_y < 0:
            first_y = 0
        if last_x > self.width:
            last_x = self.width
        if last_y > self.height:
            last_y = self.height
        if last_x <= first_x or last_y <= first_y:
            return
        var threshold = half_width * half_width
        for y in range(first_y, last_y):
            for x in range(first_x, last_x):
                var px = Float32(x) + 0.5
                var py = Float32(y) + 0.5
                if _line_distance_squared(px, py, start, end) <= threshold:
                    self.pixels[y * self.width + x] = _over(
                        self.pixels[y * self.width + x],
                        color,
                    )

    def fill_gradient(
        mut self,
        bounds: Rect,
        start: Point,
        end: Point,
        start_color: Color,
        end_color: Color,
    ):
        var visible = bounds
        if self.has_clip:
            visible = visible.intersection(self.clip)
        var left = Int(visible.x)
        var top = Int(visible.y)
        var right = Int(visible.x + visible.width)
        var bottom = Int(visible.y + visible.height)
        if left < 0:
            left = 0
        if top < 0:
            top = 0
        if right > self.width:
            right = self.width
        if bottom > self.height:
            bottom = self.height
        if right <= left or bottom <= top:
            return
        var delta_x = end.x - start.x
        var delta_y = end.y - start.y
        var span = delta_x * delta_x + delta_y * delta_y
        if span <= 0.0:
            span = bounds.width * bounds.width
            if span <= 0.0:
                span = 1.0
        for y in range(top, bottom):
            for x in range(left, right):
                var amount = (
                    (Float32(x) - start.x) * delta_x
                    + (Float32(y) - start.y) * delta_y
                ) / span
                amount = _clamp_unit(amount)
                var color = Color(
                    _lerp(
                        start_color.red,
                        end_color.red,
                        amount,
                    ),
                    _lerp(
                        start_color.green,
                        end_color.green,
                        amount,
                    ),
                    _lerp(
                        start_color.blue,
                        end_color.blue,
                        amount,
                    ),
                    _lerp(
                        start_color.alpha,
                        end_color.alpha,
                        amount,
                    ),
                )
                self.pixels[y * self.width + x] = _over(
                    self.pixels[y * self.width + x],
                    color,
                )

    def pixel(self, x: Int, y: Int) -> Color:
        """Read a pixel, returning transparent black outside the surface."""
        if x < 0 or x >= self.width or y < 0 or y >= self.height:
            return Color(0.0, 0.0, 0.0, 0.0)
        return self.pixels[y * self.width + x]

    def checksum(self) -> Int:
        """Return a stable integer checksum for snapshot-style tests."""
        var result = 0
        for index in range(len(self.pixels)):
            var color = self.pixels[index]
            result += Int(_clamp_unit(color.red) * 255.0)
            result += Int(_clamp_unit(color.green) * 255.0) * 3
            result += Int(_clamp_unit(color.blue) * 255.0) * 7
            result += Int(_clamp_unit(color.alpha) * 255.0) * 11
        return result

    def supports_incremental(self) -> Bool:
        return False
