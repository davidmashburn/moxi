"""Interactive line-fractal state and renderer-neutral canvas contract.

This module ports the useful center of Xilem's ``interactive_paint`` example:
editable generator geometry, turtle presets, baseline transforms, hit testing,
and incremental fractal expansion.  A host supplies the small canvas painter
interface; the state itself remains independent of AppKit or a pixel format.
"""

from std.collections import List
from std.math import cos, sin, sqrt

from .accessibility import ACTION_PRESS
from .component import Component
from .controls import (
    ButtonControl,
    CheckboxControl,
    TextInputControl,
    TextInputState,
)
from .event import (
    ACTION_KIND,
    CLICK_KIND,
    COMPOSITION_END_KIND,
    COMPOSITION_UPDATE_KIND,
    DRAG_BEGIN_KIND,
    DRAG_UPDATE_KIND,
    DROP_KIND,
    FRAME_TICK_KIND,
    KEY_ENTER,
    KEY_DOWN_KIND,
    POINTER_CANCEL_KIND,
    POINTER_DOWN_KIND,
    POINTER_MOVE_KIND,
    POINTER_UP_KIND,
    TEXT_INPUT_KIND,
    Event,
)
from .geometry import Point, Rect
from .layout import ALIGN_CENTER, ALIGN_STRETCH, JUSTIFY_START
from .scene import Scene
from .style import Color, default_button_style, default_panel_style, default_surface_style
from .view import ColumnView


comptime FRACTAL_CANVAS_WIDTH: Float32 = 920.0
comptime FRACTAL_CANVAS_HEIGHT: Float32 = 620.0
comptime FRACTAL_PREVIEW_X: Float32 = 24.0
comptime FRACTAL_PREVIEW_Y: Float32 = 24.0
comptime FRACTAL_PREVIEW_WIDTH: Float32 = 872.0
comptime FRACTAL_PREVIEW_HEIGHT: Float32 = 560.0
comptime FRACTAL_HANDLE_RADIUS: Float32 = 8.0
comptime FRACTAL_BASELINE_RADIUS: Float32 = 9.5
comptime FRACTAL_NESTED_ENDPOINT_RADIUS: Float32 = 4.5
comptime FRACTAL_NESTED_HIT_TOLERANCE: Float32 = 3.0
comptime FRACTAL_HIT_RADIUS: Float32 = 14.0
comptime FRACTAL_MIN_SEGMENT_LENGTH: Float32 = 2.5
comptime FRACTAL_MAX_DEPTH: Int = 12
comptime FRACTAL_MAX_RENDERED_SEGMENTS: Int = 32768
comptime FRACTAL_RENDER_BATCH: Int = 384
comptime FRACTAL_DOUBLE_CLICK_SECONDS: Float32 = 0.30
comptime FRACTAL_PRESET_GRID_COLUMNS: Int = 4
comptime FRACTAL_PRESET_GRID_HEIGHT: Float32 = 160.0
comptime FRACTAL_PRESET_TARGET_WIDTH: Float32 = 560.0
comptime FRACTAL_PRESET_TARGET_HEIGHT: Float32 = 250.0
comptime FRACTAL_PRESET_TARGET_CENTER_X: Float32 = 350.0
comptime FRACTAL_PRESET_TARGET_CENTER_Y: Float32 = 150.0
comptime FRACTAL_PI: Float32 = 3.14159265358979323846

comptime FRACTAL_GROUP_CLASSIC: Int = 0
comptime FRACTAL_GROUP_EXPERIMENT: Int = 1
comptime FRACTAL_PRESET_COUNT: Int = 27

comptime FRACTAL_PANEL_ID: Int = 3000
comptime FRACTAL_SCROLL_ID: Int = 3001
comptime FRACTAL_TITLE_ID: Int = 3002
comptime FRACTAL_STATUS_ID: Int = 3003
comptime FRACTAL_CLASSIC_LABEL_ID: Int = 3004
comptime FRACTAL_CLASSIC_GRID_ID: Int = 3005
comptime FRACTAL_EXPERIMENT_LABEL_ID: Int = 3006
comptime FRACTAL_EXPERIMENT_GRID_ID: Int = 3007
comptime FRACTAL_RESET_ID: Int = 3008
comptime FRACTAL_CONTROL_ROW_ID: Int = 3009
comptime FRACTAL_DEPTH_LABEL_ID: Int = 3010
comptime FRACTAL_DEPTH_DOWN_ID: Int = 3011
comptime FRACTAL_DEPTH_INPUT_ID: Int = 3012
comptime FRACTAL_DEPTH_UP_ID: Int = 3013
comptime FRACTAL_GUIDES_ID: Int = 3014
comptime FRACTAL_RANDOM_ID: Int = 3015
comptime FRACTAL_HELP_ID: Int = 3016
comptime FRACTAL_STATUS_PRESET_ID: Int = 3017
comptime FRACTAL_STATUS_DEPTH_ID: Int = 3018
comptime FRACTAL_STATUS_SEGMENTS_ID: Int = 3019
comptime FRACTAL_PRESET_BUTTON_BASE: Int = 3100
comptime FRACTAL_CANVAS_ID: Int = 3200

comptime FRACTAL_TARGET_NONE: Int = -1
comptime FRACTAL_TARGET_ENDPOINT_BASE: Int = 100
comptime FRACTAL_TARGET_GENERATOR_BASE: Int = 200
comptime FRACTAL_TARGET_BASELINE_POINT_BASE: Int = 400
comptime FRACTAL_TARGET_GENERATOR_SHAPE: Int = 500
comptime FRACTAL_TARGET_BASELINE: Int = 501


struct FractalSegment(ImplicitlyCopyable):
    """One terminal segment ready to be drawn."""

    var start: Point
    var end: Point

    def __init__(out self, start: Point, end: Point):
        self.start = start
        self.end = end


trait FractalCanvasPainter:
    """Small host-facing drawing contract used by ``FractalState``."""

    def set_canvas_bounds(mut self, bounds: Rect) raises:
        """Inform a host painter where the canvas lives in window coordinates."""
        pass

    def begin(mut self, clip: Rect) raises:
        pass

    def end(mut self) raises:
        pass

    def fill_rect(
        mut self,
        bounds: Rect,
        fill: Color,
        border: Color,
        border_width: Float32,
    ) raises:
        pass

    def line(
        mut self,
        start: Point,
        end: Point,
        color: Color,
        width: Float32,
    ) raises:
        pass

    def line_batch(
        mut self,
        ref segments: List[FractalSegment],
        offset: Point,
        color: Color,
        width: Float32,
    ) raises:
        """Draw a uniform batch, with a per-line fallback for simple hosts."""
        for index in range(len(segments)):
            var segment = segments[index]
            self.line(
                Point(segment.start.x + offset.x, segment.start.y + offset.y),
                Point(segment.end.x + offset.x, segment.end.y + offset.y),
                color,
                width,
            )

    def circle(
        mut self,
        center: Point,
        radius: Float32,
        fill: Color,
        stroke: Color,
        stroke_width: Float32,
    ) raises:
        pass

    def begin_line_geometry(mut self) raises:
        """Start timing or batching the dense terminal-line portion."""
        pass

    def end_line_geometry(mut self) raises:
        """Finish timing or batching the dense terminal-line portion."""
        pass

struct FractalSegmentJob(ImplicitlyCopyable):
    """A deferred branch expansion in the depth-first renderer."""

    var start: Point
    var end: Point
    var depth: Int

    def __init__(out self, start: Point, end: Point, depth: Int):
        self.start = start
        self.end = end
        self.depth = depth


struct FractalLocalSegment(ImplicitlyCopyable):
    """A generator segment in normalized baseline coordinates."""

    var start: Point
    var end: Point

    def __init__(out self, start: Point, end: Point):
        self.start = start
        self.end = end


struct FractalGeometry(ImplicitlyCopyable):
    """Editable generator scaffold and its independently movable baseline."""

    var generator_points: List[Point]
    var baseline_start: Point
    var baseline_end: Point
    var endpoint0_docked: Bool
    var endpoint1_docked: Bool

    def __init__(out self):
        self.generator_points = List[Point]()
        self.generator_points.append(Point(0.0, 0.0))
        self.generator_points.append(Point(1.0, 0.0))
        self.baseline_start = Point(0.0, 0.0)
        self.baseline_end = Point(1.0, 0.0)
        self.endpoint0_docked = True
        self.endpoint1_docked = True

    def __init__(out self, *, copy: Self):
        self.generator_points = copy.generator_points.copy()
        self.baseline_start = copy.baseline_start
        self.baseline_end = copy.baseline_end
        self.endpoint0_docked = copy.endpoint0_docked
        self.endpoint1_docked = copy.endpoint1_docked

    def clone(self) -> FractalGeometry:
        var result = FractalGeometry()
        result.generator_points = self.generator_points.copy()
        result.baseline_start = self.baseline_start
        result.baseline_end = self.baseline_end
        result.endpoint0_docked = self.endpoint0_docked
        result.endpoint1_docked = self.endpoint1_docked
        return result^

    def point_count(self) -> Int:
        return len(self.generator_points)


def fractal_preset_name(index: Int) -> String:
    """Return the checked-in name for one of the 27 reference presets."""
    if index == 0:
        return "Koch Curve"
    if index == 1:
        return "Anti-Koch Inlet"
    if index == 2:
        return "Cesaro 70"
    if index == 3:
        return "Cesaro 85"
    if index == 4:
        return "Minkowski Sausage"
    if index == 5:
        return "Minkowski Mirror"
    if index == 6:
        return "Levy C"
    if index == 7:
        return "Dragon Fold"
    if index == 8:
        return "Terdragon"
    if index == 9:
        return "Arrowhead"
    if index == 10:
        return "Gosper Seed"
    if index == 11:
        return "Hilbert U"
    if index == 12:
        return "Peano Serpent"
    if index == 13:
        return "Lightning"
    if index == 14:
        return "Canyon"
    if index == 15:
        return "Sawblade"
    if index == 16:
        return "Harbor Steps"
    if index == 17:
        return "Crown"
    if index == 18:
        return "Orbit Hook"
    if index == 19:
        return "Metro Weave"
    if index == 20:
        return "Trident"
    if index == 21:
        return "Needle Fern"
    if index == 22:
        return "Ribbon Fold"
    if index == 23:
        return "Wave Tank"
    if index == 24:
        return "Catapult"
    if index == 25:
        return "Switchback"
    return "Kite Spine"


def fractal_preset_group(index: Int) -> Int:
    """Return classic or experimental grouping for a preset."""
    return FRACTAL_GROUP_CLASSIC if index < 13 else FRACTAL_GROUP_EXPERIMENT


def _preset_commands(index: Int) -> String:
    if index == 1:
        return "F-F++F-F"
    if index == 2 or index == 3:
        return "F+F--F+F"
    if index == 4:
        return "F+F-F-FF+F+F-F"
    if index == 5:
        return "F-F+F+FF-F-F+F"
    if index == 6:
        return "F-F"
    if index == 7:
        return "F+F"
    if index == 8 or index == 9:
        return "F+F-F"
    if index == 10:
        return "A-B--B+A++AA+B-"
    if index == 11:
        return "F+F-F"
    if index == 12:
        return "FF+F+F+FF-F-F+FF"
    if index == 15:
        return "F+F-F+F-F+F"
    if index == 16:
        return "FF+F-F+FF--F+F"
    if index == 17:
        return "F+F-F+F--F+F"
    if index == 18:
        return "F+F++F--F-F"
    if index == 19:
        return "F+F-F-F+FF-F+F"
    if index == 20:
        return "F+F--F++F--F+F"
    if index == 21:
        return "F+F-F+F++F-F"
    if index == 22:
        return "F-F+F++F-F"
    if index == 23:
        return "F+F-F--F+F++F-F"
    if index == 24:
        return "F++F-F+F--F"
    if index == 25:
        return "FF-F+F-F+FF+F-F"
    return "F+F+F--F-F"


def _preset_angle(index: Int) -> Float32:
    if index == 1:
        return 60.0
    if index == 2:
        return 70.0
    if index == 3:
        return 85.0
    if index == 4 or index == 5 or index == 6 or index == 7:
        return 90.0
    if index == 8:
        return 120.0
    if index == 9:
        return 60.0
    if index == 10:
        return 60.0
    if index == 11 or index == 12:
        return 90.0
    if index == 15:
        return 60.0
    if index == 16:
        return 90.0
    if index == 17:
        return 72.0
    if index == 18:
        return 45.0
    if index == 19:
        return 90.0
    if index == 20:
        return 60.0
    if index == 21:
        return 36.0
    if index == 22:
        return 72.0
    if index == 23:
        return 45.0
    if index == 24:
        return 60.0
    if index == 25:
        return 90.0
    return 72.0


def _point_preset_points(index: Int) -> List[Point]:
    var result = List[Point]()
    if index == 0:
        result.append(Point(160.0, 150.0))
        result.append(Point(260.0, 150.0))
        result.append(Point(310.0, 85.0))
        result.append(Point(360.0, 150.0))
        result.append(Point(460.0, 150.0))
    elif index == 13:
        result.append(Point(170.0, 150.0))
        result.append(Point(235.0, 125.0))
        result.append(Point(285.0, 190.0))
        result.append(Point(350.0, 110.0))
        result.append(Point(415.0, 165.0))
        result.append(Point(480.0, 145.0))
    else:
        result.append(Point(170.0, 155.0))
        result.append(Point(245.0, 155.0))
        result.append(Point(285.0, 215.0))
        result.append(Point(350.0, 95.0))
        result.append(Point(415.0, 215.0))
        result.append(Point(455.0, 155.0))
        result.append(Point(530.0, 155.0))
    return result^


def _distance(a: Point, b: Point) -> Float32:
    var dx = a.x - b.x
    var dy = a.y - b.y
    return Float32(sqrt(dx * dx + dy * dy))


def _geometry_from_points(points: List[Point]) -> FractalGeometry:
    var result = FractalGeometry()
    result.generator_points = points.copy()
    if len(result.generator_points) == 0:
        result.generator_points.append(Point(0.0, 0.0))
    if len(result.generator_points) == 1:
        result.generator_points.append(
            Point(result.generator_points[0].x + 1.0, result.generator_points[0].y)
        )
    result.baseline_start = result.generator_points[0]
    result.baseline_end = result.generator_points[len(result.generator_points) - 1]
    result.endpoint0_docked = True
    result.endpoint1_docked = True
    return result^


def _normalized_points(
    points: List[Point],
    baseline_start: Point,
    baseline_end: Point,
) -> List[Point]:
    var result = List[Point]()
    if len(points) < 2:
        result.append(Point(0.0, 0.0))
        result.append(Point(1.0, 0.0))
        return result^
    var dx = baseline_end.x - baseline_start.x
    var dy = baseline_end.y - baseline_start.y
    var length_squared = dx * dx + dy * dy
    if length_squared <= 0.000001:
        result.append(Point(0.0, 0.0))
        result.append(Point(1.0, 0.0))
        return result^
    for index in range(len(points)):
        var offset_x = points[index].x - baseline_start.x
        var offset_y = points[index].y - baseline_start.y
        var local_x = (offset_x * dx + offset_y * dy) / length_squared
        var local_y = (dx * offset_y - dy * offset_x) / length_squared
        result.append(Point(local_x, local_y))
    return result^


def _map_local(start: Point, end: Point, local: Point) -> Point:
    var dx = end.x - start.x
    var dy = end.y - start.y
    return Point(
        start.x + dx * local.x - dy * local.y,
        start.y + dy * local.x + dx * local.y,
    )


def _geometry_from_turtle(commands: String, angle_degrees: Float32) -> FractalGeometry:
    var turn = angle_degrees * FRACTAL_PI / 180.0
    var heading: Float32 = 0.0
    var raw = List[Point]()
    raw.append(Point(0.0, 0.0))
    for index in range(commands.count_codepoints()):
        var glyph = String(commands[codepoint=index:index + 1])
        if glyph == "+":
            heading += turn
        elif glyph == "-":
            heading -= turn
        elif glyph == " " or glyph == "\n" or glyph == "\t":
            pass
        else:
            var last = raw[len(raw) - 1]
            raw.append(
                Point(last.x + cos(heading), last.y + sin(heading))
            )
    if len(raw) < 2 or _distance(raw[0], raw[len(raw) - 1]) <= 0.0001:
        var first = raw[0]
        raw.append(Point(first.x + 1.0, first.y))

    var baseline_start = raw[0]
    var baseline_end = raw[len(raw) - 1]
    var local = _normalized_points(raw, baseline_start, baseline_end)
    var min_x: Float32 = 1000000000.0
    var max_x: Float32 = -1000000000.0
    var min_y: Float32 = 1000000000.0
    var max_y: Float32 = -1000000000.0
    for index in range(len(local)):
        if local[index].x < min_x:
            min_x = local[index].x
        if local[index].x > max_x:
            max_x = local[index].x
        if local[index].y < min_y:
            min_y = local[index].y
        if local[index].y > max_y:
            max_y = local[index].y
    var local_width = max_x - min_x
    var local_height = max_y - min_y
    if local_width < 1.0:
        local_width = 1.0
    if local_height < 0.3:
        local_height = 0.3
    var scale = FRACTAL_PRESET_TARGET_WIDTH / local_width
    var height_scale = FRACTAL_PRESET_TARGET_HEIGHT / local_height
    if height_scale < scale:
        scale = height_scale
    if scale > 360.0:
        scale = 360.0

    var mapped = List[Point]()
    for index in range(len(local)):
        mapped.append(Point(local[index].x * scale, local[index].y * scale))
    min_x = 1000000000.0
    max_x = -1000000000.0
    min_y = 1000000000.0
    max_y = -1000000000.0
    for index in range(len(mapped)):
        if mapped[index].x < min_x:
            min_x = mapped[index].x
        if mapped[index].x > max_x:
            max_x = mapped[index].x
        if mapped[index].y < min_y:
            min_y = mapped[index].y
        if mapped[index].y > max_y:
            max_y = mapped[index].y
    var offset_x = FRACTAL_PRESET_TARGET_CENTER_X - (min_x + max_x) * 0.5
    var offset_y = FRACTAL_PRESET_TARGET_CENTER_Y - (min_y + max_y) * 0.5
    for index in range(len(mapped)):
        mapped[index].x += offset_x
        mapped[index].y += offset_y
    return _geometry_from_points(mapped)


def fractal_preset_geometry(index: Int) -> FractalGeometry:
    """Construct an editable geometry for a named reference preset."""
    var safe_index = index
    if safe_index < 0 or safe_index >= FRACTAL_PRESET_COUNT:
        safe_index = 0
    if safe_index == 0 or safe_index == 13 or safe_index == 14:
        return _geometry_from_points(_point_preset_points(safe_index))
    return _geometry_from_turtle(
        _preset_commands(safe_index),
        _preset_angle(safe_index),
    )


def _local_segments(geometry: FractalGeometry) -> List[FractalLocalSegment]:
    var normalized = _normalized_points(
        geometry.generator_points,
        geometry.baseline_start,
        geometry.baseline_end,
    )
    var result = List[FractalLocalSegment]()
    if len(normalized) < 2:
        return result^
    for index in range(len(normalized) - 1):
        result.append(FractalLocalSegment(normalized[index], normalized[index + 1]))
    return result^


def _point_to_segment_distance(point: Point, start: Point, end: Point) -> Float32:
    var dx = end.x - start.x
    var dy = end.y - start.y
    var length_squared = dx * dx + dy * dy
    if length_squared <= 0.000001:
        return _distance(point, start)
    var t = ((point.x - start.x) * dx + (point.y - start.y) * dy) / length_squared
    if t < 0.0:
        t = 0.0
    if t > 1.0:
        t = 1.0
    return _distance(point, Point(start.x + dx * t, start.y + dy * t))


def _sync_docked(mut geometry: FractalGeometry):
    if len(geometry.generator_points) < 2:
        return
    if geometry.endpoint0_docked:
        geometry.generator_points[0] = geometry.baseline_start
    if geometry.endpoint1_docked:
        geometry.generator_points[len(geometry.generator_points) - 1] = geometry.baseline_end


def _transform_between_baselines(
    points: List[Point],
    old_start: Point,
    old_end: Point,
    new_start: Point,
    new_end: Point,
) -> List[Point]:
    var local = _normalized_points(points, old_start, old_end)
    var result = List[Point]()
    for index in range(len(local)):
        result.append(_map_local(new_start, new_end, local[index]))
    return result^


def _apply_drag(
    start_geometry: FractalGeometry,
    target: Int,
    delta: Point,
) -> FractalGeometry:
    var geometry = start_geometry.clone()
    if target >= FRACTAL_TARGET_ENDPOINT_BASE and target < FRACTAL_TARGET_GENERATOR_BASE:
        var base_index = target - FRACTAL_TARGET_ENDPOINT_BASE
        var point_index = 0 if base_index == 0 else len(geometry.generator_points) - 1
        geometry.generator_points[point_index] = Point(
            start_geometry.generator_points[point_index].x + delta.x,
            start_geometry.generator_points[point_index].y + delta.y,
        )
        var base = geometry.baseline_start if base_index == 0 else geometry.baseline_end
        var docked = _distance(geometry.generator_points[point_index], base) <= FRACTAL_BASELINE_RADIUS
        if docked:
            geometry.generator_points[point_index] = base
        if base_index == 0:
            geometry.endpoint0_docked = docked
        else:
            geometry.endpoint1_docked = docked
    elif target >= FRACTAL_TARGET_GENERATOR_BASE and target < FRACTAL_TARGET_BASELINE_POINT_BASE:
        var point_index = target - FRACTAL_TARGET_GENERATOR_BASE
        if point_index >= 0 and point_index < len(geometry.generator_points):
            var point = start_geometry.generator_points[point_index]
            geometry.generator_points[point_index] = Point(
                point.x + delta.x,
                point.y + delta.y,
            )
            if point_index == 0:
                geometry.endpoint0_docked = False
            elif point_index == len(geometry.generator_points) - 1:
                geometry.endpoint1_docked = False
            _sync_docked(geometry)
    elif target >= FRACTAL_TARGET_BASELINE_POINT_BASE and target < FRACTAL_TARGET_GENERATOR_SHAPE:
        var base_index = target - FRACTAL_TARGET_BASELINE_POINT_BASE
        var new_start = start_geometry.baseline_start
        var new_end = start_geometry.baseline_end
        if base_index == 0:
            new_start = Point(new_start.x + delta.x, new_start.y + delta.y)
        else:
            new_end = Point(new_end.x + delta.x, new_end.y + delta.y)
        geometry.baseline_start = new_start
        geometry.baseline_end = new_end
        geometry.generator_points = _transform_between_baselines(
            start_geometry.generator_points,
            start_geometry.baseline_start,
            start_geometry.baseline_end,
            new_start,
            new_end,
        )
        _sync_docked(geometry)
    elif target == FRACTAL_TARGET_GENERATOR_SHAPE:
        for index in range(len(geometry.generator_points)):
            geometry.generator_points[index].x = start_geometry.generator_points[index].x + delta.x
            geometry.generator_points[index].y = start_geometry.generator_points[index].y + delta.y
        geometry.endpoint0_docked = False
        geometry.endpoint1_docked = False
    elif target == FRACTAL_TARGET_BASELINE:
        geometry.baseline_start = Point(
            start_geometry.baseline_start.x + delta.x,
            start_geometry.baseline_start.y + delta.y,
        )
        geometry.baseline_end = Point(
            start_geometry.baseline_end.x + delta.x,
            start_geometry.baseline_end.y + delta.y,
        )
        for index in range(len(geometry.generator_points)):
            geometry.generator_points[index].x = start_geometry.generator_points[index].x + delta.x
            geometry.generator_points[index].y = start_geometry.generator_points[index].y + delta.y
        _sync_docked(geometry)
    return geometry^


def _geometry_equal(left: FractalGeometry, right: FractalGeometry) -> Bool:
    if left.baseline_start.x != right.baseline_start.x or left.baseline_start.y != right.baseline_start.y:
        return False
    if left.baseline_end.x != right.baseline_end.x or left.baseline_end.y != right.baseline_end.y:
        return False
    if left.endpoint0_docked != right.endpoint0_docked or left.endpoint1_docked != right.endpoint1_docked:
        return False
    if len(left.generator_points) != len(right.generator_points):
        return False
    for index in range(len(left.generator_points)):
        if left.generator_points[index].x != right.generator_points[index].x:
            return False
        if left.generator_points[index].y != right.generator_points[index].y:
            return False
    return True


def _random_line_color(start: Point, end: Point) -> Color:
    var seed = abs(sin(
        start.x * 12.9898 + start.y * 78.233 + end.x * 37.719 + end.y * 11.173
    ))
    var red = 0.20 + 0.55 * abs(sin(seed * 17.13))
    var green = 0.20 + 0.55 * abs(sin(seed * 29.71 + 1.7))
    var blue = 0.20 + 0.55 * abs(sin(seed * 43.37 + 3.2))
    return Color(red, green, blue, 1.0)


def _append_scene_circle(
    mut scene: Scene,
    id: Int,
    center: Point,
    radius: Float32,
    fill: Color,
):
    """Represent a canvas circle with the portable rounded-rect primitive."""
    scene.append_rounded_rect(
        id,
        Rect(
            center.x - radius,
            center.y - radius,
            radius * 2.0,
            radius * 2.0,
        ),
        fill,
        radius,
    )


def _append_scene_docked_endpoint(
    mut scene: Scene,
    id: Int,
    center: Point,
    red_active: Bool,
):
    """Add the layered endpoint affordance used by the canvas painter."""
    var outer = Color(184.0 / 255.0, 49.0 / 255.0, 90.0 / 255.0, 1.0)
    var inner = Color(87.0 / 255.0, 140.0 / 255.0, 201.0 / 255.0, 1.0)
    var ring = Color(250.0 / 255.0, 227.0 / 255.0, 235.0 / 255.0, 1.0)
    if red_active:
        outer = Color(87.0 / 255.0, 140.0 / 255.0, 201.0 / 255.0, 1.0)
        inner = Color(184.0 / 255.0, 49.0 / 255.0, 90.0 / 255.0, 1.0)
        ring = Color(230.0 / 255.0, 238.0 / 255.0, 250.0 / 255.0, 1.0)
    _append_scene_circle(scene, id, center, FRACTAL_BASELINE_RADIUS, outer)
    _append_scene_circle(
        scene,
        id + 1,
        center,
        FRACTAL_BASELINE_RADIUS - 1.0,
        ring,
    )
    _append_scene_circle(
        scene,
        id + 2,
        center,
        FRACTAL_NESTED_ENDPOINT_RADIUS,
        inner,
    )


struct FractalState(Component):
    """A complete Moxi component for the interactive line fractal explorer."""

    var depth: Int
    var depth_input: TextInputState
    var show_guides: Bool
    var random_colors: Bool
    var preset_id: Int
    var geometry: FractalGeometry
    var local_segments: List[FractalLocalSegment]
    var pending_segments: List[FractalSegmentJob]
    var rendered_segments: List[FractalSegment]
    var endpoint0_revealed: Bool
    var endpoint1_revealed: Bool
    var drag_target: Int
    var drag_anchor: Point
    var drag_start_geometry: FractalGeometry
    var dragging: Bool
    var last_click_endpoint: Int
    var last_click_position: Point
    var last_click_age: Float32

    def __init__(out self):
        self.depth = 5
        self.depth_input = TextInputState("5")
        self.show_guides = True
        self.random_colors = False
        self.preset_id = 0
        self.geometry = fractal_preset_geometry(0)
        self.local_segments = List[FractalLocalSegment]()
        self.pending_segments = List[FractalSegmentJob]()
        self.rendered_segments = List[FractalSegment]()
        self.endpoint0_revealed = False
        self.endpoint1_revealed = False
        self.drag_target = FRACTAL_TARGET_NONE
        self.drag_anchor = Point(0.0, 0.0)
        self.drag_start_geometry = self.geometry.clone()
        self.dragging = False
        self.last_click_endpoint = -1
        self.last_click_position = Point(0.0, 0.0)
        self.last_click_age = FRACTAL_DOUBLE_CLICK_SECONDS + 1.0
        self.reset_render_progress()

    def __init__(out self, *, copy: Self):
        self.depth = copy.depth
        self.depth_input = copy.depth_input
        self.show_guides = copy.show_guides
        self.random_colors = copy.random_colors
        self.preset_id = copy.preset_id
        self.geometry = copy.geometry.copy()
        self.local_segments = copy.local_segments.copy()
        self.pending_segments = copy.pending_segments.copy()
        self.rendered_segments = copy.rendered_segments.copy()
        self.endpoint0_revealed = copy.endpoint0_revealed
        self.endpoint1_revealed = copy.endpoint1_revealed
        self.drag_target = copy.drag_target
        self.drag_anchor = copy.drag_anchor
        self.drag_start_geometry = copy.drag_start_geometry.copy()
        self.dragging = copy.dragging
        self.last_click_endpoint = copy.last_click_endpoint
        self.last_click_position = copy.last_click_position
        self.last_click_age = copy.last_click_age

    def build(self, bounds: Rect) -> ColumnView:
        var root = ColumnView(bounds, 20.0, 12.0)
        root.set_surface_style(default_surface_style())
        var panel_width = bounds.width - 40.0
        var panel_height = bounds.height - 40.0
        if panel_width < 0.0:
            panel_width = 0.0
        if panel_height < 0.0:
            panel_height = 0.0
        root.set_panel(
            0,
            Rect(bounds.x + 20.0, bounds.y + 20.0, panel_width, panel_height),
            default_panel_style(),
        )
        root.set_clip_to_bounds()
        var panel = root.add_column(FRACTAL_PANEL_ID, panel_height, 14.0, 10.0)
        root.set_clip_children(panel)
        var viewport_height = panel_height - 12.0
        if viewport_height < 180.0:
            viewport_height = 180.0
        var content = root.add_portal_to(
            panel,
            FRACTAL_SCROLL_ID,
            viewport_height,
            4.0,
            10.0,
            0.0,
        )
        root.set_accessibility_label(content, "Fractal explorer content")
        root.add_label_to(content, FRACTAL_TITLE_ID, "Line Fractal Explorer", 34.0)

        var status = root.add_row_to(content, FRACTAL_STATUS_ID, 0.0, 28.0, 0.0, 18.0)
        root.add_label_to(
            status,
            FRACTAL_STATUS_PRESET_ID,
            String("Preset: ", fractal_preset_name(self.preset_id)),
            26.0,
        )
        root.add_label_to(
            status,
            FRACTAL_STATUS_DEPTH_ID,
            String("Depth: ", self.depth),
            26.0,
        )
        root.add_label_to(
            status,
            FRACTAL_STATUS_SEGMENTS_ID,
            self.estimated_segments_label(),
            26.0,
        )
        root.set_container_alignment(status, JUSTIFY_START, ALIGN_CENTER)

        root.add_label_to(content, FRACTAL_CLASSIC_LABEL_ID, "Classic Presets", 24.0)
        self.build_preset_grid(root, content, FRACTAL_CLASSIC_GRID_ID, FRACTAL_GROUP_CLASSIC)
        root.add_label_to(content, FRACTAL_EXPERIMENT_LABEL_ID, "Experimental Presets", 24.0)
        self.build_preset_grid(root, content, FRACTAL_EXPERIMENT_GRID_ID, FRACTAL_GROUP_EXPERIMENT)

        var reset = ButtonControl(
            FRACTAL_RESET_ID,
            "Reset current preset",
            34.0,
        )
        root.add_to(content, reset.node())
        root.set_intrinsic_width(FRACTAL_RESET_ID)

        var controls = root.add_row_to(
            content,
            FRACTAL_CONTROL_ROW_ID,
            0.0,
            44.0,
            0.0,
            12.0,
        )
        root.add_label_to(controls, FRACTAL_DEPTH_LABEL_ID, "Depth", 30.0)
        root.add_button_to(controls, FRACTAL_DEPTH_DOWN_ID, "-", 34.0)
        var input = TextInputControl(
            FRACTAL_DEPTH_INPUT_ID,
            self.depth_input.text,
            self.depth_input.cursor,
            self.depth_input.anchor,
            36.0,
        )
        input.set_composition(
            self.depth_input.composition,
            self.depth_input.composition_selection_start,
            self.depth_input.composition_selection_end,
        )
        root.add_to(controls, input.node())
        root.set_fixed_width(FRACTAL_DEPTH_INPUT_ID, 80.0)
        root.add_button_to(controls, FRACTAL_DEPTH_UP_ID, "+", 34.0)
        root.add_checkbox_to(
            controls,
            FRACTAL_GUIDES_ID,
            "Show guides",
            self.show_guides,
            32.0,
        )
        root.add_checkbox_to(
            controls,
            FRACTAL_RANDOM_ID,
            "Random colors",
            self.random_colors,
            32.0,
        )
        root.set_container_alignment(controls, JUSTIFY_START, ALIGN_CENTER)

        root.add_canvas_to(
            content,
            FRACTAL_CANVAS_ID,
            "Interactive line fractal editor",
            FRACTAL_CANVAS_HEIGHT,
        )
        root.set_fixed_width(FRACTAL_CANVAS_ID, FRACTAL_CANVAS_WIDTH)
        root.set_accessibility_label(
            FRACTAL_CANVAS_ID,
            "Interactive line fractal editor with draggable generator points and baseline",
        )
        root.set_accessibility_hint(
            FRACTAL_CANVAS_ID,
            "Drag red handles or scaffold points to shape the generator; drag blue handles or the baseline to reposition it",
        )
        root.add_label_to(
            content,
            FRACTAL_HELP_ID,
            "Drag red handles or the red scaffold to shape the generator. Drag blue handles or the blue line to reposition the baseline. Double-click a docked endpoint to reveal its inner generator handle.",
            48.0,
        )
        root.set_wrap_text(FRACTAL_HELP_ID)
        root.layout()
        return root^

    def build_preset_grid(
        self,
        mut root: ColumnView,
        parent_id: Int,
        grid_id: Int,
        group: Int,
    ):
        _ = root.add_grid_to(
            parent_id,
            grid_id,
            FRACTAL_PRESET_GRID_HEIGHT,
            FRACTAL_PRESET_GRID_COLUMNS,
            0.0,
            8.0,
        )
        for index in range(FRACTAL_PRESET_COUNT):
            if fractal_preset_group(index) != group:
                continue
            var label = fractal_preset_name(index)
            var active = index == self.preset_id
            if active:
                label = String("✓ ", label)
            var style = default_button_style()
            if active:
                style.fill = Color(0.10, 0.34, 0.62, 1.0)
                style.border = Color(0.35, 0.74, 1.0, 1.0)
                style.border_width = 1.0
            var button = ButtonControl(
                FRACTAL_PRESET_BUTTON_BASE + index,
                label,
                34.0,
                style,
                not active,
            )
            root.add_to(grid_id, button.node())
            root.set_accessibility_label(
                FRACTAL_PRESET_BUTTON_BASE + index,
                fractal_preset_name(index),
            )
            root.set_accessibility_value(
                FRACTAL_PRESET_BUTTON_BASE + index,
                String("Preset ", index + 1),
            )

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        if event.kind == FRAME_TICK_KIND:
            self.last_click_age += event.delta_seconds
            if self.last_click_age > FRACTAL_DOUBLE_CLICK_SECONDS:
                self.last_click_endpoint = -1
            return False

        if event.target == FRACTAL_DEPTH_INPUT_ID:
            if event.kind == COMPOSITION_UPDATE_KIND:
                self.depth_input.set_composition(
                    event.text,
                    event.selection_start,
                    event.selection_end,
                )
                return True
            if event.kind == COMPOSITION_END_KIND:
                if not self.depth_input.has_composition():
                    return False
                self.depth_input.clear_composition()
                return True
            if event.kind == TEXT_INPUT_KIND:
                var changed: Bool
                if event.replacement_start >= 0 and event.replacement_end >= 0:
                    changed = self.depth_input.replace_text_range(
                        event.text,
                        event.replacement_start,
                        event.replacement_end,
                    )
                else:
                    changed = self.depth_input.insert_text(event.text)
                if changed:
                    var parsed = _parse_depth(self.depth_input.text)
                    if parsed >= 0:
                        _ = self.set_depth(parsed)
                return changed
            if event.kind == KEY_DOWN_KIND:
                if event.key == KEY_ENTER:
                    var parsed = _parse_depth(self.depth_input.text)
                    if parsed >= 0:
                        return self.set_depth(parsed)
                    self.depth_input.set_text(String(self.depth))
                    return True
                return self.depth_input.handle_key(event.key, event.modifiers)
            return False

        if event.target == FRACTAL_DEPTH_DOWN_ID and _is_activation(event):
            return self.set_depth(self.depth - 1)
        if event.target == FRACTAL_DEPTH_UP_ID and _is_activation(event):
            return self.set_depth(self.depth + 1)
        if event.target == FRACTAL_RESET_ID and _is_activation(event):
            self.reset_current_preset()
            return True
        if event.target == FRACTAL_GUIDES_ID and _is_activation(event):
            self.show_guides = not self.show_guides
            return True
        if event.target == FRACTAL_RANDOM_ID and _is_activation(event):
            self.random_colors = not self.random_colors
            return True

        if (
            event.target >= FRACTAL_PRESET_BUTTON_BASE
            and event.target < FRACTAL_PRESET_BUTTON_BASE + FRACTAL_PRESET_COUNT
            and _is_activation(event)
        ):
            var next_preset = event.target - FRACTAL_PRESET_BUTTON_BASE
            if next_preset == self.preset_id:
                return False
            self.preset_id = next_preset
            self.geometry = fractal_preset_geometry(next_preset)
            self.endpoint0_revealed = False
            self.endpoint1_revealed = False
            self.reset_render_progress()
            return True

        if event.target == FRACTAL_CANVAS_ID:
            return self.update_canvas(event, view)
        return False

    def update_canvas(mut self, event: Event, view: ColumnView) -> Bool:
        var canvas = view.bounds_for(FRACTAL_CANVAS_ID)
        var local = Point(event.position.x - canvas.x, event.position.y - canvas.y)
        if event.kind == POINTER_DOWN_KIND:
            var baseline_index = self.baseline_hit(local)
            if baseline_index >= 0:
                var same_endpoint = baseline_index == self.last_click_endpoint
                if (
                    same_endpoint
                    and self.last_click_age <= FRACTAL_DOUBLE_CLICK_SECONDS
                    and _distance(local, self.last_click_position) <= FRACTAL_HIT_RADIUS
                    and (
                        (baseline_index == 0 and self.geometry.endpoint0_docked)
                        or (baseline_index == 1 and self.geometry.endpoint1_docked)
                    )
                ):
                    if baseline_index == 0:
                        self.endpoint0_revealed = not self.endpoint0_revealed
                    else:
                        self.endpoint1_revealed = not self.endpoint1_revealed
                    self.last_click_endpoint = -1
                    return True
                self.last_click_endpoint = baseline_index
                self.last_click_position = local
                self.last_click_age = 0.0
            else:
                self.last_click_endpoint = -1
            var target = self.hit_test(local)
            if target != FRACTAL_TARGET_NONE:
                self.drag_target = target
                self.drag_anchor = local
                self.drag_start_geometry = self.geometry.clone()
                self.dragging = True
                return True
            return False

        if event.kind == POINTER_MOVE_KIND or event.kind == DRAG_UPDATE_KIND:
            if not self.dragging:
                return False
            self.last_click_endpoint = -1
            var delta = Point(
                local.x - self.drag_anchor.x,
                local.y - self.drag_anchor.y,
            )
            self.geometry = _apply_drag(self.drag_start_geometry, self.drag_target, delta)
            self.reset_render_progress()
            return True

        if event.kind == DRAG_BEGIN_KIND:
            return self.dragging

        if event.kind == POINTER_UP_KIND or event.kind == DROP_KIND or event.kind == POINTER_CANCEL_KIND:
            var changed = self.dragging
            self.drag_target = FRACTAL_TARGET_NONE
            self.dragging = False
            return changed
        return False

    def baseline_hit(self, point: Point) -> Int:
        if _distance(point, self.geometry.baseline_start) <= FRACTAL_HIT_RADIUS:
            return 0
        if _distance(point, self.geometry.baseline_end) <= FRACTAL_HIT_RADIUS:
            return 1
        return -1

    def hit_test(self, point: Point) -> Int:
        if self.geometry.endpoint0_docked and self.endpoint0_revealed:
            if _distance(point, self.geometry.generator_points[0]) <= FRACTAL_NESTED_ENDPOINT_RADIUS + FRACTAL_NESTED_HIT_TOLERANCE:
                return FRACTAL_TARGET_ENDPOINT_BASE
        if self.geometry.endpoint1_docked and self.endpoint1_revealed:
            var last = len(self.geometry.generator_points) - 1
            if _distance(point, self.geometry.generator_points[last]) <= FRACTAL_NESTED_ENDPOINT_RADIUS + FRACTAL_NESTED_HIT_TOLERANCE:
                return FRACTAL_TARGET_ENDPOINT_BASE + 1

        var base0_distance = _distance(point, self.geometry.baseline_start)
        if base0_distance <= FRACTAL_BASELINE_RADIUS:
            var nested_claims = self.geometry.endpoint0_docked and self.endpoint0_revealed
            if not nested_claims or base0_distance > FRACTAL_NESTED_ENDPOINT_RADIUS + FRACTAL_NESTED_HIT_TOLERANCE - 1.0:
                return FRACTAL_TARGET_BASELINE_POINT_BASE
        var base1_distance = _distance(point, self.geometry.baseline_end)
        if base1_distance <= FRACTAL_BASELINE_RADIUS:
            var nested_claims = self.geometry.endpoint1_docked and self.endpoint1_revealed
            if not nested_claims or base1_distance > FRACTAL_NESTED_ENDPOINT_RADIUS + FRACTAL_NESTED_HIT_TOLERANCE - 1.0:
                return FRACTAL_TARGET_BASELINE_POINT_BASE + 1

        for index in range(len(self.geometry.generator_points)):
            var endpoint_hidden = (
                (index == 0 and self.geometry.endpoint0_docked and not self.endpoint0_revealed)
                or (
                    index == len(self.geometry.generator_points) - 1
                    and self.geometry.endpoint1_docked
                    and not self.endpoint1_revealed
                )
            )
            if endpoint_hidden:
                continue
            if _distance(point, self.geometry.generator_points[index]) <= FRACTAL_HIT_RADIUS:
                return FRACTAL_TARGET_GENERATOR_BASE + index

        for index in range(len(self.geometry.generator_points) - 1):
            if _point_to_segment_distance(
                point,
                self.geometry.generator_points[index],
                self.geometry.generator_points[index + 1],
            ) <= FRACTAL_HIT_RADIUS:
                return FRACTAL_TARGET_GENERATOR_SHAPE
        if _point_to_segment_distance(
            point,
            self.geometry.baseline_start,
            self.geometry.baseline_end,
        ) <= FRACTAL_HIT_RADIUS:
            return FRACTAL_TARGET_BASELINE
        return FRACTAL_TARGET_NONE

    def set_depth(mut self, value: Int) -> Bool:
        var next = value
        if next < 0:
            next = 0
        if next > FRACTAL_MAX_DEPTH:
            next = FRACTAL_MAX_DEPTH
        var depth_changed = next != self.depth
        var input_changed = self.depth_input.text != String(next)
        self.depth = next
        self.depth_input.set_text(String(next))
        if depth_changed:
            self.reset_render_progress()
        return depth_changed or input_changed

    def reset_current_preset(mut self):
        self.geometry = fractal_preset_geometry(self.preset_id)
        self.endpoint0_revealed = False
        self.endpoint1_revealed = False
        self.reset_render_progress()

    def reset_render_progress(mut self):
        self.local_segments = _local_segments(self.geometry)
        self.pending_segments = List[FractalSegmentJob]()
        self.rendered_segments = List[FractalSegment]()
        if len(self.geometry.generator_points) >= 2:
            self.pending_segments.append(
                FractalSegmentJob(
                    self.geometry.baseline_start,
                    self.geometry.baseline_end,
                    self.depth,
                )
            )

    def advance_render(mut self, budget: Int = FRACTAL_RENDER_BATCH) -> Bool:
        if len(self.pending_segments) == 0:
            return False
        var safe_budget = budget if budget > 0 else 1
        var processed = 0
        while processed < safe_budget and len(self.pending_segments) > 0:
            var last_index = len(self.pending_segments) - 1
            var job = self.pending_segments[last_index]
            _ = self.pending_segments.pop(last_index)
            if (
                job.depth <= 0
                or len(self.local_segments) == 0
                or _distance(job.start, job.end) <= FRACTAL_MIN_SEGMENT_LENGTH
            ):
                if len(self.rendered_segments) >= FRACTAL_MAX_RENDERED_SEGMENTS:
                    self.pending_segments = List[FractalSegmentJob]()
                    break
                self.rendered_segments.append(FractalSegment(job.start, job.end))
            else:
                var child_depth = job.depth - 1
                var dx = job.end.x - job.start.x
                var dy = job.end.y - job.start.y
                var perpendicular_x = -dy
                var perpendicular_y = dx
                var child_index = len(self.local_segments) - 1
                while child_index >= 0:
                    var local = self.local_segments[child_index]
                    var child_start = Point(
                        job.start.x + dx * local.start.x + perpendicular_x * local.start.y,
                        job.start.y + dy * local.start.x + perpendicular_y * local.start.y,
                    )
                    var child_end = Point(
                        job.start.x + dx * local.end.x + perpendicular_x * local.end.y,
                        job.start.y + dy * local.end.x + perpendicular_y * local.end.y,
                    )
                    self.pending_segments.append(
                        FractalSegmentJob(child_start, child_end, child_depth)
                    )
                    child_index -= 1
            processed += 1
        return processed > 0

    def render_complete(self) -> Bool:
        return len(self.pending_segments) == 0

    def rendered_segment_count(self) -> Int:
        return len(self.rendered_segments)

    def pending_job_count(self) -> Int:
        return len(self.pending_segments)

    def branch_factor(self) -> Int:
        var result = len(self.geometry.generator_points) - 1
        return result if result > 1 else 1

    def estimated_segments_label(self) -> String:
        if self.depth > 32:
            return "Segments: huge"
        var total: Int = 1
        var branch = self.branch_factor()
        for _ in range(self.depth):
            if total > 999999999999 / branch:
                return "Segments: huge"
            total *= branch
        return String("Segments: ", total)

    def build_scene(self, canvas_bounds: Rect) -> Scene:
        """Build a backend-neutral snapshot of the current fractal canvas."""
        var scene = Scene()
        var canvas_fill = Color(246.0 / 255.0, 242.0 / 255.0, 233.0 / 255.0, 1.0)
        var preview_fill = Color(1.0, 1.0, 1.0, 0.92)
        var border = Color(204.0 / 255.0, 188.0 / 255.0, 160.0 / 255.0, 1.0)
        scene.append_rect(FRACTAL_CANVAS_ID, canvas_bounds, canvas_fill)
        var preview = Rect(
            canvas_bounds.x + FRACTAL_PREVIEW_X,
            canvas_bounds.y + FRACTAL_PREVIEW_Y,
            FRACTAL_PREVIEW_WIDTH,
            FRACTAL_PREVIEW_HEIGHT,
        )
        scene.append_rect(FRACTAL_CANVAS_ID + 1, preview, preview_fill)
        scene.append_line(
            FRACTAL_CANVAS_ID + 2,
            Point(preview.x, preview.y),
            Point(preview.x + preview.width, preview.y),
            border,
            1.0,
        )
        scene.append_line(
            FRACTAL_CANVAS_ID + 3,
            Point(preview.x + preview.width, preview.y),
            Point(preview.x + preview.width, preview.y + preview.height),
            border,
            1.0,
        )
        scene.append_line(
            FRACTAL_CANVAS_ID + 4,
            Point(preview.x + preview.width, preview.y + preview.height),
            Point(preview.x, preview.y + preview.height),
            border,
            1.0,
        )
        scene.append_line(
            FRACTAL_CANVAS_ID + 5,
            Point(preview.x, preview.y + preview.height),
            Point(preview.x, preview.y),
            border,
            1.0,
        )
        for index in range(len(self.rendered_segments)):
            var segment = self.rendered_segments[index]
            var color = Color(28.0 / 255.0, 96.0 / 255.0, 99.0 / 255.0, 1.0)
            if self.random_colors:
                color = _random_line_color(segment.start, segment.end)
            scene.append_line(
                FRACTAL_CANVAS_ID + 100 + index,
                Point(canvas_bounds.x + segment.start.x, canvas_bounds.y + segment.start.y),
                Point(canvas_bounds.x + segment.end.x, canvas_bounds.y + segment.end.y),
                color,
                1.0,
            )
        scene.append_line(
            FRACTAL_CANVAS_ID + 2,
            Point(canvas_bounds.x + self.geometry.baseline_start.x, canvas_bounds.y + self.geometry.baseline_start.y),
            Point(canvas_bounds.x + self.geometry.baseline_end.x, canvas_bounds.y + self.geometry.baseline_end.y),
            Color(55.0 / 255.0, 108.0 / 255.0, 171.0 / 255.0, 1.0),
            3.0,
        )
        if self.show_guides:
            for index in range(len(self.geometry.generator_points) - 1):
                scene.append_line(
                    FRACTAL_CANVAS_ID + 10000 + index,
                    Point(canvas_bounds.x + self.geometry.generator_points[index].x, canvas_bounds.y + self.geometry.generator_points[index].y),
                    Point(canvas_bounds.x + self.geometry.generator_points[index + 1].x, canvas_bounds.y + self.geometry.generator_points[index + 1].y),
                    Color(186.0 / 255.0, 57.0 / 255.0, 39.0 / 255.0, 1.0),
                    2.0,
                )

            # The browser hosts this component through the scene contract,
            # while the standalone example uses the richer canvas painter.
            # Keep the editable scaffold and endpoint affordances in the
            # shared scene so both hosts expose the same interaction model.
            var handle_base = FRACTAL_CANVAS_ID + 20000
            for index in range(len(self.geometry.generator_points)):
                var is_first = index == 0
                var is_last = index == len(self.geometry.generator_points) - 1
                var point = self.geometry.generator_points[index]
                var center = Point(
                    canvas_bounds.x + point.x,
                    canvas_bounds.y + point.y,
                )
                if is_first and self.geometry.endpoint0_docked:
                    _append_scene_docked_endpoint(
                        scene,
                        handle_base + index * 4,
                        center,
                        self.endpoint0_revealed,
                    )
                elif is_last and self.geometry.endpoint1_docked:
                    _append_scene_docked_endpoint(
                        scene,
                        handle_base + index * 4,
                        center,
                        self.endpoint1_revealed,
                    )
                else:
                    _append_scene_circle(
                        scene,
                        handle_base + index * 4,
                        center,
                        FRACTAL_HANDLE_RADIUS,
                        Color(215.0 / 255.0, 83.0 / 255.0, 63.0 / 255.0, 1.0),
                    )

        var baseline_handle_base = FRACTAL_CANVAS_ID + 21000
        for index in range(2):
            var point = self.geometry.baseline_start if index == 0 else self.geometry.baseline_end
            var center = Point(canvas_bounds.x + point.x, canvas_bounds.y + point.y)
            var docked = self.geometry.endpoint0_docked if index == 0 else self.geometry.endpoint1_docked
            var revealed = self.endpoint0_revealed if index == 0 else self.endpoint1_revealed
            if docked:
                _append_scene_docked_endpoint(
                    scene,
                    baseline_handle_base + index * 4,
                    center,
                    revealed,
                )
            else:
                _append_scene_circle(
                    scene,
                    baseline_handle_base + index * 4,
                    center,
                    FRACTAL_BASELINE_RADIUS,
                    Color(87.0 / 255.0, 140.0 / 255.0, 201.0 / 255.0, 1.0),
                )
        return scene^

    def paint_canvas[Painter: FractalCanvasPainter](
        self,
        mut painter: Painter,
        canvas_bounds: Rect,
        clip_bounds: Rect,
    ) raises:
        """Paint the live snapshot into a host canvas."""
        painter.set_canvas_bounds(canvas_bounds)
        var clip = canvas_bounds.intersection(clip_bounds)
        painter.begin(clip)
        if clip.width <= 0.0 or clip.height <= 0.0:
            painter.end()
            return
        painter.fill_rect(
            canvas_bounds,
            Color(246.0 / 255.0, 242.0 / 255.0, 233.0 / 255.0, 1.0),
            Color(0.0, 0.0, 0.0, 0.0),
            0.0,
        )
        var preview = Rect(
            canvas_bounds.x + FRACTAL_PREVIEW_X,
            canvas_bounds.y + FRACTAL_PREVIEW_Y,
            FRACTAL_PREVIEW_WIDTH,
            FRACTAL_PREVIEW_HEIGHT,
        )
        painter.fill_rect(
            preview,
            Color(1.0, 1.0, 1.0, 0.92),
            Color(204.0 / 255.0, 188.0 / 255.0, 160.0 / 255.0, 1.0),
            1.0,
        )
        painter.begin_line_geometry()
        var color = Color(28.0 / 255.0, 96.0 / 255.0, 99.0 / 255.0, 1.0)
        if not self.random_colors:
            painter.line_batch(
                self.rendered_segments,
                Point(canvas_bounds.x, canvas_bounds.y),
                color,
                1.0,
            )
        else:
            for index in range(len(self.rendered_segments)):
                var segment = self.rendered_segments[index]
                painter.line(
                    Point(canvas_bounds.x + segment.start.x, canvas_bounds.y + segment.start.y),
                    Point(canvas_bounds.x + segment.end.x, canvas_bounds.y + segment.end.y),
                    _random_line_color(segment.start, segment.end),
                    1.0,
                )
        painter.end_line_geometry()

        var baseline_start = Point(
            canvas_bounds.x + self.geometry.baseline_start.x,
            canvas_bounds.y + self.geometry.baseline_start.y,
        )
        var baseline_end = Point(
            canvas_bounds.x + self.geometry.baseline_end.x,
            canvas_bounds.y + self.geometry.baseline_end.y,
        )
        painter.line(
            baseline_start,
            baseline_end,
            Color(55.0 / 255.0, 108.0 / 255.0, 171.0 / 255.0, 1.0),
            3.0,
        )
        if self.show_guides:
            for index in range(len(self.geometry.generator_points) - 1):
                var start = self.geometry.generator_points[index]
                var end = self.geometry.generator_points[index + 1]
                painter.line(
                    Point(canvas_bounds.x + start.x, canvas_bounds.y + start.y),
                    Point(canvas_bounds.x + end.x, canvas_bounds.y + end.y),
                    Color(186.0 / 255.0, 57.0 / 255.0, 39.0 / 255.0, 1.0),
                    2.0,
                )
            for index in range(len(self.geometry.generator_points)):
                var is_first = index == 0
                var is_last = index == len(self.geometry.generator_points) - 1
                var point = self.geometry.generator_points[index]
                var center = Point(canvas_bounds.x + point.x, canvas_bounds.y + point.y)
                if is_first and self.geometry.endpoint0_docked:
                    self.paint_docked_endpoint(painter, center, self.endpoint0_revealed)
                elif is_last and self.geometry.endpoint1_docked:
                    self.paint_docked_endpoint(painter, center, self.endpoint1_revealed)
                else:
                    painter.circle(
                        center,
                        FRACTAL_HANDLE_RADIUS,
                        Color(215.0 / 255.0, 83.0 / 255.0, 63.0 / 255.0, 1.0),
                        Color(0.0, 0.0, 0.0, 0.0),
                        0.0,
                    )
        for index in range(2):
            var center = baseline_start if index == 0 else baseline_end
            var docked = self.geometry.endpoint0_docked if index == 0 else self.geometry.endpoint1_docked
            var revealed = self.endpoint0_revealed if index == 0 else self.endpoint1_revealed
            if docked:
                self.paint_docked_endpoint(painter, center, revealed)
            else:
                painter.circle(
                    center,
                    FRACTAL_BASELINE_RADIUS,
                    Color(87.0 / 255.0, 140.0 / 255.0, 201.0 / 255.0, 1.0),
                    Color(0.0, 0.0, 0.0, 0.0),
                    0.0,
                )
        painter.end()

    def paint_docked_endpoint[Painter: FractalCanvasPainter](
        self,
        mut painter: Painter,
        center: Point,
        red_active: Bool,
    ) raises:
        var outer = Color(87.0 / 255.0, 140.0 / 255.0, 201.0 / 255.0, 1.0)
        var inner = Color(184.0 / 255.0, 49.0 / 255.0, 90.0 / 255.0, 1.0)
        var ring = Color(230.0 / 255.0, 238.0 / 255.0, 250.0 / 255.0, 1.0)
        if not red_active:
            outer = Color(184.0 / 255.0, 49.0 / 255.0, 90.0 / 255.0, 1.0)
            inner = Color(87.0 / 255.0, 140.0 / 255.0, 201.0 / 255.0, 1.0)
            ring = Color(250.0 / 255.0, 227.0 / 255.0, 235.0 / 255.0, 1.0)
        painter.circle(
            center,
            FRACTAL_BASELINE_RADIUS,
            outer,
            ring,
            1.0,
        )
        painter.circle(
            center,
            FRACTAL_NESTED_ENDPOINT_RADIUS,
            inner,
            Color(0.0, 0.0, 0.0, 0.0),
            0.0,
        )

    def clipboard_copy(mut self, target: Int, view: ColumnView) -> String:
        if target == FRACTAL_DEPTH_INPUT_ID:
            return self.depth_input.selected_text()
        return ""

    def clipboard_cut(mut self, target: Int, view: ColumnView) -> String:
        if target == FRACTAL_DEPTH_INPUT_ID:
            return self.depth_input.selected_text() if self.depth_input.cut_selection() else ""
        return ""

    def clipboard_paste(mut self, target: Int, text: String, view: ColumnView) -> Bool:
        if target == FRACTAL_DEPTH_INPUT_ID:
            return self.depth_input.insert_text(text)
        return False


def _is_activation(event: Event) -> Bool:
    return event.kind == CLICK_KIND or (
        event.kind == ACTION_KIND and event.action_id == ACTION_PRESS
    )


def _parse_depth(value: String) -> Int:
    if value.count_codepoints() == 0:
        return -1
    var result = 0
    for index in range(value.count_codepoints()):
        var glyph = String(value[codepoint=index:index + 1])
        var code = ord(glyph)
        if code < ord("0") or code > ord("9"):
            return -1
        result = result * 10 + code - ord("0")
        if result > FRACTAL_MAX_DEPTH:
            return FRACTAL_MAX_DEPTH
    return result
