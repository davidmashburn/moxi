"""First-class, backend-neutral plotting primitives for Moxi.

Plots own data/configuration and emit `Scene` commands. They do not know about
windows, GPU APIs, or a particular text engine, so the same plot can be used
by the software oracle, a future Metal/WebGPU renderer, and native overlays.
"""

from std.collections import List

from .geometry import Point, Rect
from .scene import Scene
from .style import Color
from .accessibility import AccessibilitySnapshot, ROLE_CANVAS, ROLE_LABEL, Semantics


comptime PLOT_LINE = 1
comptime PLOT_SCATTER = 2
comptime PLOT_BAR = 3


struct PlotPoint(ImplicitlyCopyable):
    """One data-space point."""

    var x: Float32
    var y: Float32

    def __init__(out self, x: Float32, y: Float32):
        self.x = x
        self.y = y


struct PlotScale(ImplicitlyCopyable):
    """A clamped linear data-to-pixel transform."""

    var data_min: Float32
    var data_max: Float32
    var pixel_min: Float32
    var pixel_max: Float32

    def __init__(
        out self,
        data_min: Float32 = 0.0,
        data_max: Float32 = 1.0,
        pixel_min: Float32 = 0.0,
        pixel_max: Float32 = 1.0,
    ):
        self.data_min = data_min
        self.data_max = data_max
        self.pixel_min = pixel_min
        self.pixel_max = pixel_max
        self.set_domain(data_min, data_max)

    def set_domain(mut self, minimum: Float32, maximum: Float32):
        var lower = minimum
        var upper = maximum
        if lower > upper:
            var swap = lower
            lower = upper
            upper = swap
        if lower == upper:
            lower -= 0.5
            upper += 0.5
        self.data_min = lower
        self.data_max = upper

    def set_range(mut self, minimum: Float32, maximum: Float32):
        self.pixel_min = minimum
        self.pixel_max = maximum

    def map(self, value: Float32) -> Float32:
        var amount = (value - self.data_min) / (self.data_max - self.data_min)
        if amount < 0.0:
            amount = 0.0
        if amount > 1.0:
            amount = 1.0
        return self.pixel_min + amount * (self.pixel_max - self.pixel_min)

    def tick(self, index: Int, count: Int) -> Float32:
        """Return an evenly spaced data-space tick value."""
        var safe_count = count if count > 0 else 1
        var safe_index = index
        if safe_index < 0:
            safe_index = 0
        if safe_index > safe_count:
            safe_index = safe_count
        return self.data_min + (
            self.data_max - self.data_min
        ) * Float32(safe_index) / Float32(safe_count)


struct PlotSeries:
    """Stable identity, style, and points for one plotted series."""

    var id: Int
    var label: String
    var kind: Int
    var color: Color
    var line_width: Float32
    var points: List[PlotPoint]
    var visible: Bool

    def __init__(
        out self,
        id: Int,
        label: String,
        color: Color,
        kind: Int = PLOT_LINE,
    ):
        self.id = id
        self.label = label
        self.kind = kind
        self.color = color
        self.line_width = 2.0
        self.points = List[PlotPoint]()
        self.visible = True

    def append(mut self, point: PlotPoint):
        self.points.append(point)

    def count(self) -> Int:
        return len(self.points)


struct PlotHit(ImplicitlyCopyable):
    """Nearest point hit result for interaction and accessibility overlays."""

    var series_id: Int
    var point_index: Int
    var distance_squared: Float32

    def __init__(out self):
        self.series_id = -1
        self.point_index = -1
        self.distance_squared = 0.0

    def found(self) -> Bool:
        return self.series_id != -1 and self.point_index != -1


struct Plot:
    """Declarative plot model with deterministic scene output."""

    var bounds: Rect
    var plot_area: Rect
    var x_scale: PlotScale
    var y_scale: PlotScale
    var series: List[PlotSeries]
    var title: String
    var background: Color
    var grid_color: Color
    var axis_color: Color
    var show_grid: Bool
    var show_legend: Bool
    var next_series_id: Int

    def __init__(out self, bounds: Rect):
        self.bounds = bounds
        self.plot_area = Rect(48.0, 28.0, 0.0, 0.0)
        self.x_scale = PlotScale()
        self.y_scale = PlotScale()
        self.series = List[PlotSeries]()
        self.title = ""
        self.background = Color(0.07, 0.09, 0.14, 1.0)
        self.grid_color = Color(0.25, 0.30, 0.40, 0.45)
        self.axis_color = Color(0.75, 0.80, 0.90, 0.9)
        self.show_grid = True
        self.show_legend = True
        self.next_series_id = 1
        self.update_plot_area()

    def update_plot_area(mut self):
        var width = self.bounds.width - 80.0
        var height = self.bounds.height - 64.0
        if width < 0.0:
            width = 0.0
        if height < 0.0:
            height = 0.0
        self.plot_area = Rect(
            self.bounds.x + 48.0,
            self.bounds.y + 28.0,
            width,
            height,
        )
        self.x_scale.set_range(
            self.plot_area.x,
            self.plot_area.x + self.plot_area.width,
        )
        self.y_scale.set_range(
            self.plot_area.y + self.plot_area.height,
            self.plot_area.y,
        )

    def set_bounds(mut self, bounds: Rect):
        self.bounds = bounds
        self.update_plot_area()

    def set_title(mut self, title: String):
        self.title = title

    def set_x_domain(mut self, minimum: Float32, maximum: Float32):
        self.x_scale.set_domain(minimum, maximum)

    def set_y_domain(mut self, minimum: Float32, maximum: Float32):
        self.y_scale.set_domain(minimum, maximum)

    def add_series(
        mut self,
        label: String,
        color: Color,
        kind: Int = PLOT_LINE,
    ) -> Int:
        var id = self.next_series_id
        self.next_series_id += 1
        self.series.append(PlotSeries(id, label, color, kind))
        return id

    def series_index(self, id: Int) -> Int:
        for index in range(len(self.series)):
            if self.series[index].id == id:
                return index
        return -1

    def add_point(mut self, series_id: Int, x: Float32, y: Float32) -> Bool:
        var index = self.series_index(series_id)
        if index == -1:
            return False
        self.series[index].append(PlotPoint(x, y))
        return True

    def point_count(self, series_id: Int) -> Int:
        var index = self.series_index(series_id)
        if index == -1:
            return 0
        return self.series[index].count()

    def set_series_visible(mut self, series_id: Int, visible: Bool) -> Bool:
        var index = self.series_index(series_id)
        if index == -1:
            return False
        self.series[index].visible = visible
        return True

    def set_series_line_width(mut self, series_id: Int, width: Float32) -> Bool:
        var index = self.series_index(series_id)
        if index == -1:
            return False
        self.series[index].line_width = width if width > 0.0 else 1.0
        return True

    def set_point(
        mut self,
        series_id: Int,
        point_index: Int,
        x: Float32,
        y: Float32,
    ) -> Bool:
        var index = self.series_index(series_id)
        if index == -1 or point_index < 0 or point_index >= self.series[index].count():
            return False
        self.series[index].points[point_index] = PlotPoint(x, y)
        return True

    def clear_series(mut self, series_id: Int) -> Bool:
        var index = self.series_index(series_id)
        if index == -1:
            return False
        self.series[index].points = List[PlotPoint]()
        return True

    def fit_to_data(mut self):
        """Fit linear domains to visible series, with safe empty/flat ranges."""
        var found = False
        var minimum_x: Float32 = 0.0
        var maximum_x: Float32 = 0.0
        var minimum_y: Float32 = 0.0
        var maximum_y: Float32 = 0.0
        for series_index in range(len(self.series)):
            if not self.series[series_index].visible:
                continue
            for point_index in range(len(self.series[series_index].points)):
                var point = self.series[series_index].points[point_index]
                if not found:
                    minimum_x = point.x
                    maximum_x = point.x
                    minimum_y = point.y
                    maximum_y = point.y
                    found = True
                else:
                    if point.x < minimum_x:
                        minimum_x = point.x
                    if point.x > maximum_x:
                        maximum_x = point.x
                    if point.y < minimum_y:
                        minimum_y = point.y
                    if point.y > maximum_y:
                        maximum_y = point.y
        if found:
            self.x_scale.set_domain(minimum_x, maximum_x)
            self.y_scale.set_domain(minimum_y, maximum_y)
        else:
            self.x_scale.set_domain(0.0, 1.0)
            self.y_scale.set_domain(0.0, 1.0)

    def _screen_point(self, point: PlotPoint) -> Point:
        return Point(self.x_scale.map(point.x), self.y_scale.map(point.y))

    def _grid_line_id(self, axis: Int, index: Int) -> Int:
        return 100 + axis * 10 + index

    def build_scene(self) -> Scene:
        """Build a complete plot scene for any Moxi scene renderer."""
        var scene = Scene()
        scene.append_rounded_rect(1, self.bounds, self.background, 12.0)
        scene.push_clip(2, self.plot_area)
        if self.show_grid:
            for index in range(1, 5):
                var fraction = Float32(index) / 5.0
                var x = self.plot_area.x + self.plot_area.width * fraction
                var y = self.plot_area.y + self.plot_area.height * fraction
                scene.append_line(
                    self._grid_line_id(0, index),
                    Point(x, self.plot_area.y),
                    Point(x, self.plot_area.y + self.plot_area.height),
                    self.grid_color,
                    1.0,
                )
                scene.append_line(
                    self._grid_line_id(1, index),
                    Point(self.plot_area.x, y),
                    Point(self.plot_area.x + self.plot_area.width, y),
                    self.grid_color,
                    1.0,
                )
        scene.append_line(
            150,
            Point(self.plot_area.x, self.plot_area.y + self.plot_area.height),
            Point(
                self.plot_area.x + self.plot_area.width,
                self.plot_area.y + self.plot_area.height,
            ),
            self.axis_color,
            1.0,
        )
        for index in range(0, 6):
            var fraction = Float32(index) / 5.0
            var x = self.plot_area.x + self.plot_area.width * fraction
            var y = self.plot_area.y + self.plot_area.height
            scene.append_line(
                160 + index,
                Point(x, y),
                Point(x, y + 5.0),
                self.axis_color,
                1.0,
            )
            scene.append_text(
                700 + index,
                String(self.x_scale.tick(index, 5)),
                Rect(x - 24.0, y + 6.0, 48.0, 16.0),
                self.axis_color,
            )
            var horizontal_y = self.plot_area.y + self.plot_area.height * (1.0 - fraction)
            scene.append_line(
                180 + index,
                Point(self.plot_area.x - 5.0, horizontal_y),
                Point(self.plot_area.x, horizontal_y),
                self.axis_color,
                1.0,
            )
            scene.append_text(
                720 + index,
                String(self.y_scale.tick(index, 5)),
                Rect(self.bounds.x + 2.0, horizontal_y - 8.0, 42.0, 16.0),
                self.axis_color,
            )
        scene.append_line(
            151,
            Point(self.plot_area.x, self.plot_area.y),
            Point(self.plot_area.x, self.plot_area.y + self.plot_area.height),
            self.axis_color,
            1.0,
        )

        for series_index in range(len(self.series)):
            if (
                not self.series[series_index].visible
                or self.series[series_index].count() == 0
            ):
                continue
            if self.series[series_index].kind == PLOT_BAR:
                var baseline = self.y_scale.map(0.0)
                var bar_width = self.plot_area.width / Float32(
                    self.series[series_index].count() * 2
                )
                if bar_width < 2.0:
                    bar_width = 2.0
                for point_index in range(self.series[series_index].count()):
                    var point = self._screen_point(
                        self.series[series_index].points[point_index]
                    )
                    var top = point.y if point.y < baseline else baseline
                    var bottom = point.y if point.y > baseline else baseline
                    scene.append_rect(
                        1000 + self.series[series_index].id * 100 + point_index,
                        Rect(point.x - bar_width * 0.5, top, bar_width, bottom - top),
                        self.series[series_index].color,
                    )
            else:
                for point_index in range(self.series[series_index].count()):
                    var point = self._screen_point(
                        self.series[series_index].points[point_index]
                    )
                    if self.series[series_index].kind == PLOT_SCATTER:
                        scene.append_rounded_rect(
                            2000 + self.series[series_index].id * 100 + point_index,
                            Rect(point.x - 3.0, point.y - 3.0, 6.0, 6.0),
                            self.series[series_index].color,
                            3.0,
                        )
                    if self.series[series_index].kind == PLOT_LINE and point_index > 0:
                        var previous = self._screen_point(
                            self.series[series_index].points[point_index - 1]
                        )
                        scene.append_line(
                            3000 + self.series[series_index].id * 100 + point_index,
                            previous,
                            point,
                            self.series[series_index].color,
                            self.series[series_index].line_width,
                        )
        scene.pop_clip()

        if self.title.count_codepoints() > 0:
            scene.append_text(
                400,
                self.title,
                Rect(self.bounds.x + 12.0, self.bounds.y + 4.0, self.bounds.width - 24.0, 20.0),
                self.axis_color,
            )
        if self.show_legend:
            var legend_x = self.bounds.x + 56.0
            var legend_y = self.bounds.y + self.bounds.height - 24.0
            for series_index in range(len(self.series)):
                if not self.series[series_index].visible:
                    continue
                scene.append_line(
                    500 + self.series[series_index].id,
                    Point(legend_x, legend_y + 7.0),
                    Point(legend_x + 14.0, legend_y + 7.0),
                    self.series[series_index].color,
                    self.series[series_index].line_width,
                )
                scene.append_text(
                    600 + self.series[series_index].id,
                    self.series[series_index].label,
                    Rect(legend_x + 18.0, legend_y, 100.0, 18.0),
                    self.axis_color,
                )
                legend_x += 128.0
        return scene^

    def hit_test(self, point: Point, tolerance: Float32 = 8.0) -> PlotHit:
        """Find the nearest data point within a screen-space tolerance."""
        var result = PlotHit()
        var limit = tolerance if tolerance > 0.0 else 0.0
        var limit_squared = limit * limit
        var best = limit_squared
        for series_index in range(len(self.series)):
            if not self.series[series_index].visible:
                continue
            for point_index in range(self.series[series_index].count()):
                var screen = self._screen_point(
                    self.series[series_index].points[point_index]
                )
                var dx = point.x - screen.x
                var dy = point.y - screen.y
                var distance = dx * dx + dy * dy
                if distance <= best:
                    best = distance
                    result.series_id = self.series[series_index].id
                    result.point_index = point_index
                    result.distance_squared = distance
        return result

    def accessibility(self) -> AccessibilitySnapshot:
        """Expose the plot and each series as a semantic canvas subtree."""
        var snapshot = AccessibilitySnapshot()
        var label = self.title if self.title.count_codepoints() > 0 else "Plot"
        var canvas = Semantics(1, ROLE_CANVAS, label)
        canvas.bounds = self.bounds
        canvas.value = String("series=", len(self.series))
        snapshot.append(canvas)
        for index in range(len(self.series)):
            var series = Semantics(
                10000 + self.series[index].id,
                ROLE_LABEL,
                self.series[index].label,
            )
            series.parent_id = 1
            series.bounds = self.plot_area
            series.value = String("points=", self.series[index].count())
            snapshot.append(series)
        return snapshot^
