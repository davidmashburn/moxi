"""First-class, backend-neutral plotting primitives for Moxi.

Plots own data/configuration and emit `Scene` commands. They do not know about
windows, GPU APIs, or a particular text engine, so the same plot can be used
by the software oracle, the macOS Metal path, SVG/Web export, and native
overlays.
"""

from std.collections import List
from std.math import exp, log, pow, sqrt

from .geometry import Point, Rect
from .scene import Scene
from .style import Color
from .accessibility import AccessibilitySnapshot, ROLE_CANVAS, ROLE_LABEL, Semantics
from .plot_data import COLUMN_CATEGORY, COLUMN_STRING, PlotDataTable
from .plot_render import PlotRenderPacket


comptime PLOT_LINE = 1
comptime PLOT_SCATTER = 2
comptime PLOT_BAR = 3
comptime PLOT_DOT = 4
comptime PLOT_AREA = 5
comptime PLOT_RULE = 6
comptime PLOT_ERROR_BAR = 7
comptime PLOT_RECT = 8
comptime PLOT_TEXT = 9
comptime PLOT_STEP = 10
comptime PLOT_TICK = 11
comptime PLOT_INTERVAL = 12
comptime PLOT_BUBBLE = 13
comptime PLOT_BAND = 14
comptime PLOT_COLUMN = 15
comptime PLOT_HISTOGRAM = 16
comptime PLOT_DENSITY = 17
comptime PLOT_ECDF = 18
comptime PLOT_BOX = 19
comptime PLOT_HEATMAP = 20
comptime PLOT_HEXBIN = 21
comptime PLOT_REGRESSION = 22

comptime SCALE_LINEAR = 1
comptime SCALE_LOG = 2
comptime SCALE_POWER = 3
comptime SCALE_SQRT = 4
comptime SCALE_TEMPORAL = 5
comptime SCALE_ORDINAL = 6
comptime SCALE_BAND = 7
comptime SCALE_SYMLOG = 8
comptime SCALE_POINT = 9
comptime SCALE_THRESHOLD = 10
comptime SCALE_QUANTILE = 11
comptime SCALE_QUANTIZE = 12
comptime SCALE_SEQUENTIAL = 13
comptime SCALE_DIVERGING = 14
comptime SCALE_CATEGORICAL = 15

comptime PLOT_COMPOSITION_LAYER = 1
comptime PLOT_COMPOSITION_HORIZONTAL = 2
comptime PLOT_COMPOSITION_VERTICAL = 3


def _category_color(value: String) -> Color:
    """Choose a deterministic, readable color for a categorical value."""
    var hash = 0
    for index in range(value.count_codepoints()):
        hash = (hash * 31 + ord(value[codepoint=index])) % 6
    if hash == 0:
        return Color(0.25, 0.75, 1.0, 1.0)
    if hash == 1:
        return Color(1.0, 0.45, 0.30, 1.0)
    if hash == 2:
        return Color(0.40, 0.85, 0.55, 1.0)
    if hash == 3:
        return Color(0.95, 0.65, 0.20, 1.0)
    if hash == 4:
        return Color(0.75, 0.45, 1.0, 1.0)
    return Color(1.0, 0.75, 0.35, 1.0)


def _tooltip_for_row(data: PlotDataTable, fields: String, row: Int) -> String:
    """Format comma-separated field names for a point tooltip."""
    if fields.count_codepoints() == 0:
        return ""
    var result = ""
    var start = 0
    var length = fields.count_codepoints()
    for cursor in range(length + 1):
        if cursor == length or fields[codepoint=cursor] == ",":
            if cursor > start:
                var field = String(fields[codepoint=start:cursor])
                if result.count_codepoints() > 0:
                    result += " | "
                result += String(field, "=", data.string_field_at(field, row))
            start = cursor + 1
    return result


def _symlog(value: Float32) -> Float32:
    var magnitude = value if value >= 0.0 else -value
    var transformed = Float32(log(1.0 + magnitude))
    return transformed if value >= 0.0 else -transformed


def _symexp(value: Float32) -> Float32:
    var magnitude = value if value >= 0.0 else -value
    var transformed = Float32(exp(magnitude) - 1.0)
    return transformed if value >= 0.0 else -transformed


struct PlotPoint(ImplicitlyCopyable):
    """One data-space point."""

    var x: Float32
    var y: Float32
    var row_key: Int
    var facet_value: String
    var facet_column_value: String
    var panel_index: Int
    var x2: Float32
    var y2: Float32
    var has_x2: Bool
    var has_y2: Bool
    var size: Float32
    var opacity: Float32
    var text: String
    var tooltip: String
    var color: Color
    var has_color: Bool
    var stat_low: Float32
    var stat_high: Float32
    var stat_median: Float32
    var has_statistics: Bool

    def __init__(out self, x: Float32, y: Float32, row_key: Int = -1):
        self.x = x
        self.y = y
        self.row_key = row_key
        self.facet_value = ""
        self.facet_column_value = ""
        self.panel_index = 0
        self.x2 = x
        self.y2 = y
        self.has_x2 = False
        self.has_y2 = False
        self.size = 6.0
        self.opacity = 1.0
        self.text = ""
        self.tooltip = ""
        self.color = Color(0.0, 0.0, 0.0, 0.0)
        self.has_color = False
        self.stat_low = y
        self.stat_high = y
        self.stat_median = y
        self.has_statistics = False

    def set_facet(mut self, value: String):
        self.facet_value = value

    def set_facet_column(mut self, value: String):
        self.facet_column_value = value

    def set_extent(mut self, x2: Float32, y2: Float32, has_x2: Bool = True, has_y2: Bool = True):
        self.x2 = x2
        self.y2 = y2
        self.has_x2 = has_x2
        self.has_y2 = has_y2

    def set_visuals(
        mut self,
        size: Float32,
        opacity: Float32,
        text: String = "",
        tooltip: String = "",
    ):
        self.size = size if size > 0.0 else 1.0
        var safe_opacity = opacity
        if safe_opacity < 0.0:
            safe_opacity = 0.0
        if safe_opacity > 1.0:
            safe_opacity = 1.0
        self.opacity = safe_opacity
        self.text = text
        self.tooltip = tooltip

    def set_color(mut self, color: Color):
        self.color = color
        self.has_color = True

    def set_statistics(
        mut self,
        low: Float32,
        high: Float32,
        median: Float32,
    ):
        self.stat_low = low
        self.stat_high = high
        self.stat_median = median
        self.has_statistics = True


struct PlotScale(ImplicitlyCopyable):
    """A clamped linear data-to-pixel transform."""

    var data_min: Float32
    var data_max: Float32
    var pixel_min: Float32
    var pixel_max: Float32
    var kind: Int
    var power: Float32

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
        self.kind = SCALE_LINEAR
        self.power = 2.0
        self.set_domain(data_min, data_max)

    def set_kind(mut self, kind: Int):
        if kind < SCALE_LINEAR or kind > SCALE_CATEGORICAL:
            self.kind = SCALE_LINEAR
        else:
            self.kind = kind
        # Log domains cannot contain zero or negative values. Keep the public
        # domain valid as soon as the scale kind changes, including when a
        # caller configures a scale after loading data.
        if self.kind == SCALE_LOG:
            self.set_domain(self.data_min, self.data_max)

    def set_power(mut self, power: Float32):
        self.power = power if power > 0.0 else 1.0

    def kind_name(self) -> String:
        if self.kind == SCALE_LOG:
            return "log"
        if self.kind == SCALE_POWER:
            return "power"
        if self.kind == SCALE_SQRT:
            return "sqrt"
        if self.kind == SCALE_TEMPORAL:
            return "temporal"
        if self.kind == SCALE_ORDINAL:
            return "ordinal"
        if self.kind == SCALE_BAND:
            return "band"
        if self.kind == SCALE_SYMLOG:
            return "symlog"
        if self.kind == SCALE_POINT:
            return "point"
        if self.kind == SCALE_THRESHOLD:
            return "threshold"
        if self.kind == SCALE_QUANTILE:
            return "quantile"
        if self.kind == SCALE_QUANTIZE:
            return "quantize"
        if self.kind == SCALE_SEQUENTIAL:
            return "sequential"
        if self.kind == SCALE_DIVERGING:
            return "diverging"
        if self.kind == SCALE_CATEGORICAL:
            return "categorical"
        return "linear"

    def set_domain(mut self, minimum: Float32, maximum: Float32):
        var lower = minimum
        var upper = maximum
        if lower > upper:
            var swap = lower
            lower = upper
            upper = swap
        if self.kind == SCALE_LOG:
            if lower <= 0.0:
                lower = 0.000001
            if upper <= lower:
                upper = lower * 10.0
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
        if self.kind == SCALE_LOG:
            var lower = self.data_min if self.data_min > 0.0 else 0.000001
            var safe_value = value if value > 0.0 else lower
            var upper = self.data_max if self.data_max > lower else lower * 10.0
            amount = Float32(
                (log(safe_value) - log(lower))
                / (log(upper) - log(lower))
            )
        elif self.kind == SCALE_SYMLOG:
            var lower = _symlog(self.data_min)
            var upper = _symlog(self.data_max)
            amount = (_symlog(value) - lower) / (upper - lower)
        elif self.kind == SCALE_POWER:
            var safe_amount = amount if amount > 0.0 else 0.0
            amount = Float32(pow(safe_amount, self.power))
        elif self.kind == SCALE_SQRT:
            var safe_amount = amount if amount > 0.0 else 0.0
            amount = Float32(sqrt(safe_amount))
        if amount < 0.0:
            amount = 0.0
        if amount > 1.0:
            amount = 1.0
        return self.pixel_min + amount * (self.pixel_max - self.pixel_min)

    def fraction(self, value: Float32) -> Float32:
        var span = self.pixel_max - self.pixel_min
        if span == 0.0:
            return 0.0
        return (self.map(value) - self.pixel_min) / span

    def domain_is_valid(self) -> Bool:
        if self.data_max <= self.data_min:
            return False
        if self.kind == SCALE_LOG and self.data_min <= 0.0:
            return False
        return True

    def range_is_valid(self) -> Bool:
        return self.pixel_max != self.pixel_min

    def inverse(self, pixel: Float32) -> Float32:
        """Map a pixel coordinate back into the unclamped data domain."""
        var pixel_span = self.pixel_max - self.pixel_min
        if pixel_span == 0.0:
            return self.data_min
        var amount = (pixel - self.pixel_min) / pixel_span
        if self.kind == SCALE_LOG:
            var lower = self.data_min if self.data_min > 0.0 else 0.000001
            var upper = self.data_max if self.data_max > lower else lower * 10.0
            return exp(log(lower) + amount * (log(upper) - log(lower)))
        if self.kind == SCALE_SYMLOG:
            var lower = _symlog(self.data_min)
            var upper = _symlog(self.data_max)
            return _symexp(lower + amount * (upper - lower))
        if self.kind == SCALE_POWER:
            var safe_power = self.power if self.power > 0.0 else 1.0
            var sign: Float32 = 1.0 if amount >= 0.0 else -1.0
            var magnitude = amount if amount >= 0.0 else -amount
            var powered = Float32(pow(magnitude, 1.0 / safe_power))
            return self.data_min + powered * sign * (self.data_max - self.data_min)
        if self.kind == SCALE_SQRT:
            var safe_amount = amount if amount >= 0.0 else 0.0
            return self.data_min + safe_amount * safe_amount * (self.data_max - self.data_min)
        return self.data_min + amount * (self.data_max - self.data_min)

    def pan_pixels(mut self, pixels: Float32):
        """Translate the domain by a logical pixel distance."""
        var pixel_span = self.pixel_max - self.pixel_min
        if pixel_span == 0.0:
            return
        var data_delta = pixels / pixel_span * (self.data_max - self.data_min)
        self.data_min -= data_delta
        self.data_max -= data_delta

    def zoom_at(mut self, factor: Float32, pixel: Float32):
        """Zoom around a pixel anchor without losing the current domain."""
        if factor <= 0.0 or factor == 1.0:
            return
        var safe_factor = factor
        if safe_factor < 0.1:
            safe_factor = 0.1
        if safe_factor > 10.0:
            safe_factor = 10.0
        var anchor = self.inverse(pixel)
        var minimum = anchor - (anchor - self.data_min) / safe_factor
        var maximum = anchor + (self.data_max - anchor) / safe_factor
        self.set_domain(minimum, maximum)

    def tick(self, index: Int, count: Int) -> Float32:
        """Return a scale-aware data-space tick value."""
        var safe_count = count if count > 0 else 1
        var safe_index = index
        if safe_index < 0:
            safe_index = 0
        if safe_index > safe_count:
            safe_index = safe_count
        var fraction = Float32(safe_index) / Float32(safe_count)
        if self.kind == SCALE_LOG:
            var lower = self.data_min if self.data_min > 0.0 else 0.000001
            var upper = self.data_max if self.data_max > lower else lower * 10.0
            return Float32(exp(log(lower) + fraction * (log(upper) - log(lower))))
        if self.kind == SCALE_POWER:
            return self.data_min + Float32(pow(fraction, 1.0 / self.power)) * (self.data_max - self.data_min)
        if self.kind == SCALE_SQRT:
            return self.data_min + fraction * fraction * (self.data_max - self.data_min)
        return self.data_min + (self.data_max - self.data_min) * fraction

    def ticks(self, count: Int) -> List[Float32]:
        """Return a deterministic list of scale-aware tick values."""
        var result = List[Float32]()
        var safe_count = count if count > 0 else 1
        for index in range(safe_count + 1):
            result.append(self.tick(index, safe_count))
        return result^

    def format(self, value: Float32) -> String:
        """Format a guide value through the current scale's portable fallback."""
        return String(value)


struct PlotSeries:
    """Stable identity, style, and points for one plotted series."""

    var id: Int
    var label: String
    var kind: Int
    var color: Color
    var line_width: Float32
    var marker_size: Float32
    var opacity: Float32
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
        self.marker_size = 6.0
        self.opacity = 1.0
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
    var row_key: Int
    var distance_squared: Float32

    def __init__(out self):
        self.series_id = -1
        self.point_index = -1
        self.row_key = -1
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
    var line_point_limit: Int
    var scatter_point_limit: Int
    var annotation_ids: List[Int]
    var annotation_texts: List[String]
    var annotation_x: List[Float32]
    var annotation_y: List[Float32]
    var annotation_data_space: List[Bool]
    var next_annotation_id: Int
    var facet_field: String
    var facet_column_field: String
    var facet_values: List[String]
    var facet_column_values: List[String]
    var facet_columns: Int
    var composition: Int
    var x_labels: List[String]
    var y_labels: List[String]
    var facet_x_scales: List[PlotScale]
    var facet_y_scales: List[PlotScale]
    var independent_x_scale: Bool
    var independent_y_scale: Bool

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
        self.line_point_limit = 0
        self.scatter_point_limit = 0
        self.annotation_ids = List[Int]()
        self.annotation_texts = List[String]()
        self.annotation_x = List[Float32]()
        self.annotation_y = List[Float32]()
        self.annotation_data_space = List[Bool]()
        self.next_annotation_id = 1
        self.facet_field = ""
        self.facet_column_field = ""
        self.facet_values = List[String]()
        self.facet_column_values = List[String]()
        self.facet_columns = 1
        self.composition = PLOT_COMPOSITION_LAYER
        self.x_labels = List[String]()
        self.y_labels = List[String]()
        self.facet_x_scales = List[PlotScale]()
        self.facet_y_scales = List[PlotScale]()
        self.independent_x_scale = False
        self.independent_y_scale = False
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

    def set_x_scale(mut self, kind: Int, power: Float32 = 2.0, reverse: Bool = False):
        self.x_scale.set_kind(kind)
        self.x_scale.set_power(power)
        if reverse:
            self.x_scale.set_range(
                self.plot_area.x + self.plot_area.width,
                self.plot_area.x,
            )
        else:
            self.x_scale.set_range(
                self.plot_area.x,
                self.plot_area.x + self.plot_area.width,
            )

    def set_y_scale(mut self, kind: Int, power: Float32 = 2.0, reverse: Bool = False):
        self.y_scale.set_kind(kind)
        self.y_scale.set_power(power)
        if reverse:
            self.y_scale.set_range(
                self.plot_area.y,
                self.plot_area.y + self.plot_area.height,
            )
        else:
            self.y_scale.set_range(
                self.plot_area.y + self.plot_area.height,
                self.plot_area.y,
            )

    def set_line_point_limit(mut self, limit: Int):
        """Enable pixel-aware line reduction at a bounded point count."""
        self.line_point_limit = limit if limit > 2 else 0

    def set_scatter_point_limit(mut self, limit: Int):
        """Bound scatter geometry while retaining all source rows for hits."""
        self.scatter_point_limit = limit if limit > 0 else 0

    def pan(mut self, delta: Point):
        self.x_scale.pan_pixels(delta.x)
        self.y_scale.pan_pixels(delta.y)

    def zoom(mut self, factor: Float32, anchor: Point):
        self.x_scale.zoom_at(factor, anchor.x)
        self.y_scale.zoom_at(factor, anchor.y)

    def reset_view(mut self):
        self.fit_to_data()

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

    def series_count(self) -> Int:
        return len(self.series)

    def add_point(mut self, series_id: Int, x: Float32, y: Float32) -> Bool:
        var index = self.series_index(series_id)
        if index == -1:
            return False
        return self.add_point_with_key(
            series_id,
            x,
            y,
            self.series[index].count(),
        )

    def add_point_with_key(
        mut self,
        series_id: Int,
        x: Float32,
        y: Float32,
        row_key: Int,
        facet_value: String = "",
        facet_column_value: String = "",
    ) -> Bool:
        var index = self.series_index(series_id)
        if index == -1:
            return False
        var point = PlotPoint(x, y, row_key)
        point.set_facet(facet_value)
        point.set_facet_column(facet_column_value)
        point.panel_index = index
        self.series[index].append(point)
        if facet_value.count_codepoints() > 0 and self._facet_index(facet_value) == -1:
            self.facet_values.append(facet_value)
        if facet_column_value.count_codepoints() > 0 and self._facet_column_index(facet_column_value) == -1:
            self.facet_column_values.append(facet_column_value)
        return True

    def add_table_series(
        mut self,
        data: PlotDataTable,
        label: String,
        color: Color,
        kind: Int = PLOT_LINE,
    ) -> Int:
        """Add valid x/y rows from a stable-key data source as a plot series."""
        return self.add_table_series_fields(data, label, color, kind, "x", "y")

    def _remember_x_label(mut self, value: String):
        if value.count_codepoints() == 0:
            return
        for index in range(len(self.x_labels)):
            if self.x_labels[index] == value:
                return
        self.x_labels.append(value)

    def _remember_y_label(mut self, value: String):
        if value.count_codepoints() == 0:
            return
        for index in range(len(self.y_labels)):
            if self.y_labels[index] == value:
                return
        self.y_labels.append(value)

    def add_table_series_fields(
        mut self,
        data: PlotDataTable,
        label: String,
        color: Color,
        kind: Int,
        x_field: String,
        y_field: String,
        size_field: String = "",
        opacity_field: String = "",
        text_field: String = "",
        color_field: String = "",
        tooltip_fields: String = "",
        x2_field: String = "",
        y2_field: String = "",
        stat_low_field: String = "",
        stat_high_field: String = "",
        median_field: String = "",
    ) -> Int:
        """Add valid rows using named fields and preserve row keys."""
        var id = self.add_series(label, color, kind)
        for index in range(data.row_count()):
            var valid_row = data.row_is_valid_fields(x_field, y_field, index)
            if x2_field.count_codepoints() > 0:
                valid_row = valid_row and data.field_is_valid(x2_field, index)
            if y2_field.count_codepoints() > 0:
                valid_row = valid_row and data.field_is_valid(y2_field, index)
            if stat_low_field.count_codepoints() > 0:
                valid_row = valid_row and data.field_is_valid(stat_low_field, index)
            if stat_high_field.count_codepoints() > 0:
                valid_row = valid_row and data.field_is_valid(stat_high_field, index)
            if median_field.count_codepoints() > 0:
                valid_row = valid_row and data.field_is_valid(median_field, index)
            if valid_row:
                var facet_value = ""
                if self.facet_field.count_codepoints() > 0 and data.field_is_valid(self.facet_field, index):
                    facet_value = data.string_field_at(self.facet_field, index)
                var facet_column_value = ""
                if self.facet_column_field.count_codepoints() > 0 and data.field_is_valid(self.facet_column_field, index):
                    facet_column_value = data.string_field_at(self.facet_column_field, index)
                var x_value = data.float_field_at(x_field, index)
                var y_value = data.float_field_at(y_field, index)
                if data.field_kind(x_field) == COLUMN_STRING or data.field_kind(x_field) == COLUMN_CATEGORY:
                    x_value = Float32(data.category_position(x_field, index))
                    self._remember_x_label(data.string_field_at(x_field, index))
                if data.field_kind(y_field) == COLUMN_STRING or data.field_kind(y_field) == COLUMN_CATEGORY:
                    y_value = Float32(data.category_position(y_field, index))
                    self._remember_y_label(data.string_field_at(y_field, index))
                _ = self.add_point_with_key(
                    id,
                    x_value,
                    y_value,
                    data.key_at(index),
                    facet_value,
                    facet_column_value,
                )
                var point_index = self.series[self.series_index(id)].count() - 1
                var point = self.series[self.series_index(id)].points[point_index]
                if x2_field.count_codepoints() > 0 or y2_field.count_codepoints() > 0:
                    var extent_x = data.float_field_at(x2_field, index) if x2_field.count_codepoints() > 0 else data.float_field_at(x_field, index)
                    var extent_y = data.float_field_at(y2_field, index) if y2_field.count_codepoints() > 0 else data.float_field_at(y_field, index)
                    if x2_field.count_codepoints() > 0 and (data.field_kind(x2_field) == COLUMN_STRING or data.field_kind(x2_field) == COLUMN_CATEGORY):
                        extent_x = Float32(data.category_position(x2_field, index))
                    if y2_field.count_codepoints() > 0 and (data.field_kind(y2_field) == COLUMN_STRING or data.field_kind(y2_field) == COLUMN_CATEGORY):
                        extent_y = Float32(data.category_position(y2_field, index))
                    point.set_extent(extent_x, extent_y, x2_field.count_codepoints() > 0, y2_field.count_codepoints() > 0)
                if (
                    stat_low_field.count_codepoints() > 0
                    or stat_high_field.count_codepoints() > 0
                    or median_field.count_codepoints() > 0
                ):
                    var statistic_low = data.float_field_at(
                        stat_low_field,
                        index,
                    ) if stat_low_field.count_codepoints() > 0 else y_value
                    var statistic_high = data.float_field_at(
                        stat_high_field,
                        index,
                    ) if stat_high_field.count_codepoints() > 0 else y_value
                    var statistic_median = data.float_field_at(
                        median_field,
                        index,
                    ) if median_field.count_codepoints() > 0 else y_value
                    point.set_statistics(
                        statistic_low,
                        statistic_high,
                        statistic_median,
                    )
                var point_size: Float32 = 6.0
                if size_field.count_codepoints() > 0 and data.field_is_valid(size_field, index):
                    point_size = data.float_field_at(size_field, index)
                var point_opacity: Float32 = 1.0
                if opacity_field.count_codepoints() > 0 and data.field_is_valid(opacity_field, index):
                    point_opacity = data.float_field_at(opacity_field, index)
                var point_text = ""
                if text_field.count_codepoints() > 0 and data.field_is_valid(text_field, index):
                    point_text = data.string_field_at(text_field, index)
                var tooltip = _tooltip_for_row(data, tooltip_fields, index)
                point.set_visuals(point_size, point_opacity, point_text, tooltip)
                if color_field.count_codepoints() > 0 and data.field_is_valid(color_field, index):
                    if data.field_kind(color_field) == COLUMN_STRING or data.field_kind(color_field) == COLUMN_CATEGORY:
                        point.set_color(_category_color(data.string_field_at(color_field, index)))
                    else:
                        var value = data.float_field_at(color_field, index)
                        var red = value if value > 0.0 else 0.0
                        if red > 1.0:
                            red = 1.0
                        point.set_color(Color(red, 0.35, 1.0 - red, 1.0))
                self.series[self.series_index(id)].points[point_index] = point
        return id

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

    def set_series_marker_size(mut self, series_id: Int, size: Float32) -> Bool:
        var index = self.series_index(series_id)
        if index == -1:
            return False
        self.series[index].marker_size = size if size > 0.0 else 1.0
        return True

    def set_series_opacity(mut self, series_id: Int, opacity: Float32) -> Bool:
        var index = self.series_index(series_id)
        if index == -1:
            return False
        var value = opacity
        if value < 0.0:
            value = 0.0
        if value > 1.0:
            value = 1.0
        self.series[index].opacity = value
        return True

    def set_point_visuals(
        mut self,
        series_id: Int,
        point_index: Int,
        size: Float32,
        opacity: Float32 = 1.0,
        text: String = "",
        tooltip: String = "",
    ) -> Bool:
        """Set per-row size, opacity, text, and tooltip presentation."""
        var index = self.series_index(series_id)
        if index == -1 or point_index < 0 or point_index >= self.series[index].count():
            return False
        var point = self.series[index].points[point_index]
        point.set_visuals(size, opacity, text, tooltip)
        self.series[index].points[point_index] = point
        return True

    def set_point_color(
        mut self, series_id: Int, point_index: Int, color: Color
    ) -> Bool:
        """Set a per-row color override used by supported glyph marks."""
        var index = self.series_index(series_id)
        if index == -1 or point_index < 0 or point_index >= self.series[index].count():
            return False
        var point = self.series[index].points[point_index]
        point.set_color(color)
        self.series[index].points[point_index] = point
        return True

    def add_annotation(
        mut self,
        text: String,
        x: Float32,
        y: Float32,
        data_space: Bool = True,
    ) -> Int:
        var id = self.next_annotation_id
        self.next_annotation_id += 1
        self.annotation_ids.append(id)
        self.annotation_texts.append(text)
        self.annotation_x.append(x)
        self.annotation_y.append(y)
        self.annotation_data_space.append(data_space)
        return id

    def set_facet(mut self, row_field: String, column_field: String = ""):
        self.facet_field = row_field
        self.facet_column_field = column_field
        self.facet_values = List[String]()
        self.facet_column_values = List[String]()
        for series_index in range(len(self.series)):
            for point_index in range(self.series[series_index].count()):
                var point = self.series[series_index].points[point_index]
                if point.facet_value.count_codepoints() > 0 and self._facet_index(point.facet_value) == -1:
                    self.facet_values.append(point.facet_value)
                if point.facet_column_value.count_codepoints() > 0 and self._facet_column_index(point.facet_column_value) == -1:
                    self.facet_column_values.append(point.facet_column_value)
        self._rebuild_facet_scales()

    def set_composition(mut self, composition: Int):
        if composition < PLOT_COMPOSITION_LAYER or composition > PLOT_COMPOSITION_VERTICAL:
            self.composition = PLOT_COMPOSITION_LAYER
        else:
            self.composition = composition

    def facet_count(self) -> Int:
        return len(self.facet_values)

    def facet_column_count(self) -> Int:
        return len(self.facet_column_values)

    def set_facet_scale_resolution(
        mut self,
        independent_x: Bool = False,
        independent_y: Bool = False,
    ):
        """Choose shared or per-panel domains for faceted plots."""
        self.independent_x_scale = independent_x
        self.independent_y_scale = independent_y
        self._rebuild_facet_scales()

    def facet_scales_are_independent(self) -> Bool:
        return self.independent_x_scale or self.independent_y_scale

    def _rebuild_facet_scales(mut self):
        if not self.facet_scales_are_independent() or self.facet_count() == 0:
            self.facet_x_scales = List[PlotScale]()
            self.facet_y_scales = List[PlotScale]()
            return
        var row_count = self.facet_count()
        var column_count = self.facet_column_count()
        if column_count < 1:
            column_count = 1
        self.facet_x_scales = List[PlotScale](capacity=row_count * column_count)
        self.facet_y_scales = List[PlotScale](capacity=row_count * column_count)
        for row_index in range(row_count):
            for column_index in range(column_count):
                var panel_x = self.x_scale
                var panel_y = self.y_scale
                var found_x = False
                var found_y = False
                var minimum_x: Float32 = 0.0
                var maximum_x: Float32 = 0.0
                var minimum_y: Float32 = 0.0
                var maximum_y: Float32 = 0.0
                for series_index in range(len(self.series)):
                    if not self.series[series_index].visible:
                        continue
                    for point_index in range(self.series[series_index].count()):
                        var point = self.series[series_index].points[point_index]
                        var point_row = self._facet_index(point.facet_value)
                        var point_column = self._facet_column_index(point.facet_column_value)
                        if point_row < 0:
                            point_row = 0
                        if point_column < 0:
                            point_column = 0
                        if point_row != row_index or point_column != column_index:
                            continue
                        if self.independent_x_scale and not (
                            self.x_scale.kind == SCALE_LOG and point.x <= 0.0
                        ):
                            if not found_x:
                                minimum_x = point.x
                                maximum_x = point.x
                                found_x = True
                            else:
                                if point.x < minimum_x:
                                    minimum_x = point.x
                                if point.x > maximum_x:
                                    maximum_x = point.x
                        if self.independent_y_scale and not (
                            self.y_scale.kind == SCALE_LOG and point.y <= 0.0
                        ):
                            if not found_y:
                                minimum_y = point.y
                                maximum_y = point.y
                                found_y = True
                            else:
                                if point.y < minimum_y:
                                    minimum_y = point.y
                                if point.y > maximum_y:
                                    maximum_y = point.y
                if found_x:
                    panel_x.set_domain(minimum_x, maximum_x)
                if found_y:
                    panel_y.set_domain(minimum_y, maximum_y)
                self.facet_x_scales.append(panel_x)
                self.facet_y_scales.append(panel_y)

    def _facet_index(self, value: String) -> Int:
        if self.facet_field.count_codepoints() == 0:
            return 0
        for index in range(len(self.facet_values)):
            if self.facet_values[index] == value:
                return index
        return -1

    def _facet_column_index(self, value: String) -> Int:
        if self.facet_column_field.count_codepoints() == 0:
            return 0
        for index in range(len(self.facet_column_values)):
            if self.facet_column_values[index] == value:
                return index
        return -1

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
        var previous = self.series[index].points[point_index]
        var next = PlotPoint(x, y, previous.row_key)
        next.set_facet(previous.facet_value)
        next.set_facet_column(previous.facet_column_value)
        next.panel_index = previous.panel_index
        next.set_extent(previous.x2, previous.y2, previous.has_x2, previous.has_y2)
        next.set_visuals(previous.size, previous.opacity, previous.text, previous.tooltip)
        if previous.has_color:
            next.set_color(previous.color)
        if previous.has_statistics:
            next.set_statistics(
                previous.stat_low,
                previous.stat_high,
                previous.stat_median,
            )
        self.series[index].points[point_index] = next
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
                if (self.x_scale.kind == SCALE_LOG and point.x <= 0.0) or (self.y_scale.kind == SCALE_LOG and point.y <= 0.0):
                    continue
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
        self._rebuild_facet_scales()

    def _screen_point(self, point: PlotPoint) -> Point:
        var x_scale = self.x_scale
        var y_scale = self.y_scale
        var facet_row_index = self._facet_index(point.facet_value)
        var facet_column_index = self._facet_column_index(point.facet_column_value)
        if facet_row_index < 0:
            facet_row_index = 0
        if facet_column_index < 0:
            facet_column_index = 0
        var facet_column_count = self.facet_column_count()
        if facet_column_count < 1:
            facet_column_count = 1
        var facet_scale_index = facet_row_index * facet_column_count + facet_column_index
        if self.independent_x_scale and facet_scale_index < len(self.facet_x_scales):
            x_scale = self.facet_x_scales[facet_scale_index]
        if self.independent_y_scale and facet_scale_index < len(self.facet_y_scales):
            y_scale = self.facet_y_scales[facet_scale_index]
        var x = x_scale.map(point.x)
        var y = y_scale.map(point.y)
        if self.composition == PLOT_COMPOSITION_HORIZONTAL and self.series_count() > 1:
            var panel_width = self.plot_area.width / Float32(self.series_count())
            x = self.plot_area.x + panel_width * Float32(point.panel_index) + x_scale.fraction(point.x) * panel_width
        elif self.composition == PLOT_COMPOSITION_VERTICAL and self.series_count() > 1:
            var panel_height = self.plot_area.height / Float32(self.series_count())
            y = self.plot_area.y + panel_height * Float32(point.panel_index + 1) - y_scale.fraction(point.y) * panel_height
        if self.facet_count() > 0:
            var row_count = self.facet_count()
            var column_count = self.facet_column_count()
            if column_count < 1:
                column_count = 1
            var facet_index = self._facet_index(point.facet_value)
            if facet_index < 0:
                facet_index = 0
            var facet_column_index = self._facet_column_index(point.facet_column_value)
            if facet_column_index < 0:
                facet_column_index = 0
            var panel_width = self.plot_area.width / Float32(column_count)
            var panel_height = self.plot_area.height / Float32(row_count)
            x = self.plot_area.x + panel_width * Float32(facet_column_index) + x_scale.fraction(point.x) * panel_width
            y = self.plot_area.y + panel_height * Float32(facet_index + 1) - y_scale.fraction(point.y) * panel_height
        return Point(x, y)

    def screen_point(self, point: PlotPoint) -> Point:
        """Expose the current data-to-pixel mapping for overlays and tools."""
        return self._screen_point(point)

    def point_is_renderable(self, point: PlotPoint) -> Bool:
        """Return whether a point has a valid value for the active scales."""
        if self.x_scale.kind == SCALE_LOG and point.x <= 0.0:
            return False
        if self.y_scale.kind == SCALE_LOG and point.y <= 0.0:
            return False
        return True

    def _line_indices_for_limit(self, series_id: Int, limit: Int) -> List[Int]:
        """Return bounded line indices while preserving per-bucket extrema."""
        var result = List[Int]()
        var series_index = self.series_index(series_id)
        if series_index == -1:
            return result^
        var count = self.series[series_index].count()
        if limit <= 2 or count <= limit:
            for index in range(count):
                result.append(index)
            return result^

        # Four representatives per bucket (first, min, max, last) retain
        # sharp extrema while bounding scene work for dense line data.
        var bucket_count = limit // 4
        if bucket_count < 1:
            bucket_count = 1
        for bucket in range(bucket_count):
            var start = bucket * count // bucket_count
            var end = (bucket + 1) * count // bucket_count
            if end <= start:
                end = start + 1
            if end > count:
                end = count
            var first = start
            var last = end - 1
            var minimum = start
            var maximum = start
            for index in range(start, end):
                if self.series[series_index].points[index].y < self.series[series_index].points[minimum].y:
                    minimum = index
                if self.series[series_index].points[index].y > self.series[series_index].points[maximum].y:
                    maximum = index
            var candidates = List[Int](capacity=4)
            candidates.append(first)
            if minimum != first and minimum != last:
                candidates.append(minimum)
            if maximum != first and maximum != last and maximum != minimum:
                candidates.append(maximum)
            if last != first:
                candidates.append(last)
            # Candidates from a bucket are small, so sort them locally and
            # append.  Buckets are already source-ordered; rebuilding the whole
            # result list for every candidate made reduction quadratic in the
            # output limit.
            for left in range(len(candidates)):
                for right in range(left + 1, len(candidates)):
                    if candidates[right] < candidates[left]:
                        var swap = candidates[left]
                        candidates[left] = candidates[right]
                        candidates[right] = swap
            for candidate_position in range(len(candidates)):
                var candidate = candidates[candidate_position]
                if len(result) == 0 or result[len(result) - 1] != candidate:
                    result.append(candidate)
        return result^

    def line_indices(self, series_id: Int) -> List[Int]:
        """Return the explicitly configured line reduction indices."""
        return self._line_indices_for_limit(series_id, self.line_point_limit)

    def packet_line_indices(self, series_id: Int) -> List[Int]:
        """Return line representatives sized to the current plot viewport.

        Four values per horizontal pixel preserve first/last plus local
        extrema.  An explicit ``set_line_point_limit`` remains the tighter
        application-level budget when one is configured.
        """
        var limit = self.line_point_limit
        if limit <= 0:
            limit = Int(self.plot_area.width)
            if limit < 1:
                limit = 1
            limit *= 4
        return self._line_indices_for_limit(series_id, limit)

    def scatter_indices(self, series_id: Int) -> List[Int]:
        """Return deterministic representatives for dense scatter geometry."""
        var result = List[Int]()
        var series_index = self.series_index(series_id)
        if series_index == -1:
            return result^
        var count = self.series[series_index].count()
        var limit = self.scatter_point_limit
        if limit <= 0 or count <= limit:
            for index in range(count):
                result.append(index)
            return result^
        for bucket in range(limit):
            var index = bucket * count // limit
            if index >= count:
                index = count - 1
            if len(result) == 0 or result[len(result) - 1] != index:
                result.append(index)
        return result^

    def packet_scatter_indices(self, series_id: Int) -> List[Int]:
        """Return one deterministic representative per screen-space cell.

        The packet can use a bounded viewport grid even when the legacy Scene
        path is left at full fidelity.  Source order and stable row keys remain
        intact in ``Plot`` for hit testing, selection, and accessibility.
        """
        var result = List[Int]()
        var series_index = self.series_index(series_id)
        if series_index == -1:
            return result^
        var count = self.series[series_index].count()
        var limit = self.scatter_point_limit
        if limit <= 0:
            var width = Int(self.plot_area.width)
            var height = Int(self.plot_area.height)
            if width < 1:
                width = 1
            if height < 1:
                height = 1
            limit = width * height // 4
            if limit < 1024:
                limit = 1024
        if count <= limit:
            for index in range(count):
                result.append(index)
            return result^

        var width = self.plot_area.width if self.plot_area.width > 0.0 else 1.0
        var height = self.plot_area.height if self.plot_area.height > 0.0 else 1.0
        var aspect = width / height
        var columns = Int(sqrt(Float32(limit) * aspect))
        if columns < 1:
            columns = 1
        if columns > limit:
            columns = limit
        var rows = limit // columns
        if rows < 1:
            rows = 1
        var cells = List[Int]()
        for _ in range(columns * rows):
            cells.append(-1)
        for index in range(count):
            var point = self.series[series_index].points[index]
            if not self.point_is_renderable(point):
                continue
            var screen = self._screen_point(point)
            var column = Int((screen.x - self.plot_area.x) / width * Float32(columns))
            var row = Int((screen.y - self.plot_area.y) / height * Float32(rows))
            if column < 0:
                column = 0
            if column >= columns:
                column = columns - 1
            if row < 0:
                row = 0
            if row >= rows:
                row = rows - 1
            var cell = row * columns + column
            if cells[cell] == -1:
                cells[cell] = index
        for cell in range(len(cells)):
            if cells[cell] != -1:
                result.append(cells[cell])
        return result^

    def _grid_line_id(self, axis: Int, index: Int) -> Int:
        return 100 + axis * 10 + index

    def build_render_packet(self) -> PlotRenderPacket:
        """Build the dense mark layer as ordered contiguous batches.

        This is an optional acceleration path.  The full ``Scene`` remains the
        portable fallback and still carries axes, labels, legends, annotations,
        and unsupported marks.  The packet contains screen-space line and
        instance data only, so a native renderer can cross the FFI boundary once
        per ordered batch while retaining the complete source data in ``Plot``.
        """
        var source_count = 0
        var emitted_count = 0
        for series_index in range(len(self.series)):
            source_count += self.series[series_index].count()
        var packet = PlotRenderPacket(self.bounds, self.plot_area)
        # Size the wire buffers from the mark families that will actually use
        # them.  In particular, a million-point scatter plot should reserve
        # for its viewport budget rather than for a hypothetical million line
        # segments and two million instances.  List growth remains available
        # for future marks with larger expansion.
        var line_capacity = 0
        var instance_capacity = 0
        var scatter_limit = self.scatter_point_limit
        if scatter_limit <= 0:
            var scatter_width = Int(self.plot_area.width)
            var scatter_height = Int(self.plot_area.height)
            if scatter_width < 1:
                scatter_width = 1
            if scatter_height < 1:
                scatter_height = 1
            scatter_limit = scatter_width * scatter_height // 4
            if scatter_limit < 1024:
                scatter_limit = 1024
        var line_limit = self.line_point_limit
        if line_limit <= 0:
            line_limit = Int(self.plot_area.width)
            if line_limit < 1:
                line_limit = 1
            line_limit *= 4
        for series_index in range(len(self.series)):
            var series_count = self.series[series_index].count()
            if not self.series[series_index].visible or series_count == 0:
                continue
            var kind = self.series[series_index].kind
            if kind == PLOT_AREA or kind == PLOT_BAND or kind == PLOT_TEXT:
                continue
            if kind == PLOT_BAR or kind == PLOT_COLUMN or kind == PLOT_HISTOGRAM:
                instance_capacity += series_count
            elif kind == PLOT_RULE:
                line_capacity += 1
            elif kind == PLOT_BOX:
                instance_capacity += series_count
                line_capacity += series_count * 4
            elif kind == PLOT_ERROR_BAR or kind == PLOT_INTERVAL or kind == PLOT_TICK:
                line_capacity += series_count
            elif (
                kind == PLOT_LINE
                or kind == PLOT_STEP
                or kind == PLOT_DENSITY
                or kind == PLOT_ECDF
                or kind == PLOT_REGRESSION
            ):
                var point_capacity = series_count if series_count < line_limit else line_limit
                if point_capacity > 1:
                    if kind == PLOT_STEP or kind == PLOT_ECDF:
                        line_capacity += (point_capacity - 1) * 2
                    else:
                        line_capacity += point_capacity - 1
            elif kind == PLOT_SCATTER or kind == PLOT_DOT or kind == PLOT_BUBBLE:
                var marker_capacity = series_count if series_count < scatter_limit else scatter_limit
                instance_capacity += marker_capacity
            elif kind == PLOT_RECT or kind == PLOT_HEATMAP or kind == PLOT_HEXBIN:
                instance_capacity += series_count
        packet.reserve(line_capacity, instance_capacity, len(self.series) * 2)
        for series_index in range(len(self.series)):
            var series_count = self.series[series_index].count()
            if not self.series[series_index].visible or series_count == 0:
                continue

            var kind = self.series[series_index].kind
            if (
                kind == PLOT_AREA
                or kind == PLOT_BAND
                or kind == PLOT_TEXT
            ):
                # Filled areas and text still use the ordered Scene path until
                # their dedicated GPU representations are available.
                packet.fallback_required = True
                continue

            if (
                kind == PLOT_BAR
                or kind == PLOT_COLUMN
                or kind == PLOT_HISTOGRAM
            ):
                var baseline = self.y_scale.map(0.0)
                var bar_width = self.plot_area.width / Float32(series_count * 2)
                if bar_width < 2.0:
                    bar_width = 2.0
                for point_index in range(series_count):
                    var source_point = self.series[series_index].points[point_index]
                    var point = self._screen_point(source_point)
                    var point_color = self.series[series_index].color
                    if source_point.has_color:
                        point_color = source_point.color
                    var current_width = bar_width
                    var bar_left = point.x - current_width * 0.5
                    if source_point.has_x2:
                        var extent_point = source_point
                        extent_point.x = source_point.x2
                        var extent = self._screen_point(extent_point)
                        bar_left = point.x if point.x < extent.x else extent.x
                        current_width = point.x - extent.x
                        if current_width < 0.0:
                            current_width = -current_width
                        if current_width < 1.0:
                            current_width = 1.0
                    var top = point.y if point.y < baseline else baseline
                    var bottom = point.y if point.y > baseline else baseline
                    packet.append_rect(
                        Rect(bar_left, top, current_width, bottom - top),
                        point_color,
                        self.series[series_index].opacity * source_point.opacity,
                    )
                    emitted_count += 1
                continue

            if kind == PLOT_RULE:
                var source_point = self.series[series_index].points[0]
                var screen = self._screen_point(source_point)
                var rule_color = self.series[series_index].color
                if source_point.has_color:
                    rule_color = source_point.color
                packet.append_line(
                    Point(self.plot_area.x, screen.y),
                    Point(self.plot_area.x + self.plot_area.width, screen.y),
                    rule_color,
                    self.series[series_index].line_width,
                    self.series[series_index].opacity * source_point.opacity,
                )
                emitted_count += 1
                continue

            if kind == PLOT_BOX:
                for point_index in range(series_count):
                    var source_point = self.series[series_index].points[point_index]
                    if not source_point.has_statistics:
                        continue
                    var point = self._screen_point(source_point)
                    var q3_point = source_point
                    q3_point.y = source_point.y2
                    var q3 = self._screen_point(q3_point)
                    var low_point = source_point
                    low_point.y = source_point.stat_low
                    var low = self._screen_point(low_point)
                    var high_point = source_point
                    high_point.y = source_point.stat_high
                    var high = self._screen_point(high_point)
                    var median_point = source_point
                    median_point.y = source_point.stat_median
                    var median = self._screen_point(median_point)
                    var point_color = self.series[series_index].color
                    if source_point.has_color:
                        point_color = source_point.color
                    var box_width = source_point.size
                    if box_width == 6.0:
                        box_width = 18.0
                    var left = point.x - box_width * 0.5
                    var top = point.y if point.y < q3.y else q3.y
                    var height = point.y - q3.y
                    if height < 0.0:
                        height = -height
                    var opacity = self.series[series_index].opacity * source_point.opacity
                    packet.append_rect(
                        Rect(left, top, box_width, height), point_color, opacity
                    )
                    packet.append_line(
                        Point(left, median.y),
                        Point(left + box_width, median.y),
                        self.axis_color,
                        self.series[series_index].line_width,
                        opacity,
                    )
                    packet.append_line(
                        Point(point.x, low.y),
                        Point(point.x, high.y),
                        point_color,
                        self.series[series_index].line_width,
                        opacity,
                    )
                    packet.append_line(
                        Point(left + box_width * 0.2, low.y),
                        Point(left + box_width * 0.8, low.y),
                        point_color,
                        self.series[series_index].line_width,
                        opacity,
                    )
                    packet.append_line(
                        Point(left + box_width * 0.2, high.y),
                        Point(left + box_width * 0.8, high.y),
                        point_color,
                        self.series[series_index].line_width,
                        opacity,
                    )
                    emitted_count += 1
                continue

            if kind == PLOT_ERROR_BAR or kind == PLOT_INTERVAL:
                for point_index in range(series_count):
                    var source_point = self.series[series_index].points[point_index]
                    var point = self._screen_point(source_point)
                    var end_point = source_point
                    if source_point.has_y2:
                        end_point.y = source_point.y2
                    var end_screen = self._screen_point(end_point)
                    var point_color = self.series[series_index].color
                    if source_point.has_color:
                        point_color = source_point.color
                    var error = self.series[series_index].marker_size * 1.5
                    var lower = point.y - error
                    var upper = point.y + error
                    if source_point.has_y2:
                        lower = point.y if point.y < end_screen.y else end_screen.y
                        upper = point.y if point.y > end_screen.y else end_screen.y
                    packet.append_line(
                        Point(point.x, lower),
                        Point(point.x, upper),
                        point_color,
                        self.series[series_index].line_width,
                        self.series[series_index].opacity * source_point.opacity,
                    )
                    emitted_count += 1
                continue

            var indices = List[Int]()
            var is_line = (
                kind == PLOT_LINE
                or kind == PLOT_STEP
                or kind == PLOT_DENSITY
                or kind == PLOT_ECDF
                or kind == PLOT_REGRESSION
            )
            var is_marker = (
                kind == PLOT_SCATTER
                or kind == PLOT_DOT
                or kind == PLOT_BUBBLE
            )
            if is_line:
                indices = self.packet_line_indices(self.series[series_index].id)
            elif is_marker:
                indices = self.packet_scatter_indices(self.series[series_index].id)
            else:
                for index in range(series_count):
                    indices.append(index)

            for rendered_index in range(len(indices)):
                var point_index = indices[rendered_index]
                var source_point = self.series[series_index].points[point_index]
                var point = self._screen_point(source_point)
                var point_color = self.series[series_index].color
                if source_point.has_color:
                    point_color = source_point.color
                var point_size = self.series[series_index].marker_size
                if source_point.size != 6.0:
                    point_size = source_point.size
                var opacity = self.series[series_index].opacity * source_point.opacity

                if is_marker:
                    packet.append_marker(point, point_size, point_color, opacity)
                elif (
                    kind == PLOT_RECT
                    or kind == PLOT_HEATMAP
                    or kind == PLOT_HEXBIN
                ):
                    var half_size = point_size * 0.5
                    var rect_end = source_point
                    if source_point.has_x2:
                        rect_end.x = source_point.x2
                    if source_point.has_y2:
                        rect_end.y = source_point.y2
                    var rect_end_screen = self._screen_point(rect_end)
                    var rect_left = point.x if point.x < rect_end_screen.x else rect_end_screen.x
                    var rect_top = point.y if point.y < rect_end_screen.y else rect_end_screen.y
                    var rect_width = point.x - rect_end_screen.x
                    if rect_width < 0.0:
                        rect_width = -rect_width
                    var rect_height = point.y - rect_end_screen.y
                    if rect_height < 0.0:
                        rect_height = -rect_height
                    if not source_point.has_x2:
                        rect_left = point.x - half_size
                        rect_width = point_size
                    if not source_point.has_y2:
                        rect_top = point.y - half_size
                        rect_height = point_size
                    if (
                        (kind == PLOT_HEATMAP or kind == PLOT_HEXBIN)
                        and source_point.size <= 0.0
                    ):
                        continue
                    packet.append_rect(
                        Rect(rect_left, rect_top, rect_width, rect_height),
                        point_color,
                        opacity,
                    )
                elif kind == PLOT_TICK:
                    packet.append_line(
                        Point(point.x, point.y - point_size),
                        Point(point.x, point.y + point_size),
                        point_color,
                        self.series[series_index].line_width,
                        opacity,
                    )

                if is_line and rendered_index > 0:
                    var previous_index = indices[rendered_index - 1]
                    var previous_source = self.series[series_index].points[previous_index]
                    if (
                        previous_source.facet_value == source_point.facet_value
                        and previous_source.facet_column_value == source_point.facet_column_value
                    ):
                        var previous = self._screen_point(previous_source)
                        if kind == PLOT_STEP or kind == PLOT_ECDF:
                            packet.append_line(
                                previous,
                                Point(point.x, previous.y),
                                point_color,
                                self.series[series_index].line_width,
                                opacity,
                            )
                            packet.append_line(
                                Point(point.x, previous.y),
                                point,
                                point_color,
                                self.series[series_index].line_width,
                                opacity,
                            )
                        else:
                            packet.append_line(
                                previous,
                                point,
                                point_color,
                                self.series[series_index].line_width,
                                opacity,
                            )
            emitted_count += len(indices)

        packet.source_point_count = source_count
        packet.emitted_point_count = emitted_count
        return packet^

    def build_scene(self, include_marks: Bool = True) -> Scene:
        """Build a complete plot scene for any Moxi scene renderer.

        ``include_marks=False`` keeps the plot chrome while leaving the dense
        mark layer to ``build_render_packet``.  This is the composition seam
        used by the Metal fast path; the default remains the complete portable
        scene.
        """
        var scene = Scene()
        scene.append_rounded_rect(1, self.bounds, self.background, 12.0)
        scene.push_clip(2, self.plot_area)
        if self.facet_count() > 0:
            var facet_height = self.plot_area.height / Float32(self.facet_count())
            var facet_column_count = self.facet_column_count()
            if facet_column_count < 1:
                facet_column_count = 1
            var facet_width = self.plot_area.width / Float32(facet_column_count)
            for facet_index in range(self.facet_count()):
                var facet_top = self.plot_area.y + facet_height * Float32(facet_index)
                scene.append_line(
                    60 + facet_index,
                    Point(self.plot_area.x, facet_top),
                    Point(self.plot_area.x + self.plot_area.width, facet_top),
                    self.grid_color,
                    1.0,
                )
                scene.append_text(
                    70 + facet_index,
                    self.facet_values[facet_index],
                    Rect(self.plot_area.x + 4.0, facet_top + 2.0, 120.0, 16.0),
                    self.axis_color,
                )
            for column_index in range(facet_column_count):
                var facet_left = self.plot_area.x + facet_width * Float32(column_index)
                scene.append_line(
                    80 + column_index,
                    Point(facet_left, self.plot_area.y),
                    Point(facet_left, self.plot_area.y + self.plot_area.height),
                    self.grid_color,
                    1.0,
                )
                if self.facet_column_count() > 0:
                    scene.append_text(
                        90 + column_index,
                        self.facet_column_values[column_index],
                        Rect(facet_left + 4.0, self.plot_area.y + 2.0, 120.0, 16.0),
                        self.axis_color,
                    )
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
            var x_tick_label = String(self.x_scale.tick(index, 5))
            if (self.x_scale.kind == SCALE_ORDINAL or self.x_scale.kind == SCALE_BAND) and len(self.x_labels) > 0:
                var label_index = Int(Float32(index) / 5.0 * Float32(len(self.x_labels)))
                if label_index >= len(self.x_labels):
                    label_index = len(self.x_labels) - 1
                x_tick_label = self.x_labels[label_index]
            scene.append_text(
                700 + index,
                x_tick_label,
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
            var y_tick_label = String(self.y_scale.tick(index, 5))
            if (self.y_scale.kind == SCALE_ORDINAL or self.y_scale.kind == SCALE_BAND) and len(self.y_labels) > 0:
                var label_index = Int(Float32(index) / 5.0 * Float32(len(self.y_labels)))
                if label_index >= len(self.y_labels):
                    label_index = len(self.y_labels) - 1
                y_tick_label = self.y_labels[label_index]
            scene.append_text(
                720 + index,
                y_tick_label,
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
            if not include_marks:
                continue
            if (
                not self.series[series_index].visible
                or self.series[series_index].count() == 0
            ):
                continue
            if (
                self.series[series_index].kind == PLOT_BAR
                or self.series[series_index].kind == PLOT_COLUMN
                or self.series[series_index].kind == PLOT_HISTOGRAM
            ):
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
                    var source_point = self.series[series_index].points[point_index]
                    var point_color = self.series[series_index].color
                    if source_point.has_color:
                        point_color = source_point.color
                    var bar_left = point.x - bar_width * 0.5
                    if source_point.has_x2:
                        var extent_point = source_point
                        extent_point.x = source_point.x2
                        var extent = self._screen_point(extent_point)
                        bar_left = point.x if point.x < extent.x else extent.x
                        bar_width = point.x - extent.x
                        if bar_width < 0.0:
                            bar_width = -bar_width
                        if bar_width < 1.0:
                            bar_width = 1.0
                    var top = point.y if point.y < baseline else baseline
                    var bottom = point.y if point.y > baseline else baseline
                    scene.append_rect(
                        1000 + self.series[series_index].id * 100 + point_index,
                        Rect(bar_left, top, bar_width, bottom - top),
                        point_color,
                    )
                    var bar_command = scene.commands[len(scene.commands) - 1]
                    bar_command.set_opacity(self.series[series_index].opacity * source_point.opacity)
                    scene.commands[len(scene.commands) - 1] = bar_command
            elif self.series[series_index].kind == PLOT_RULE:
                var point = self.series[series_index].points[0]
                var screen = self._screen_point(point)
                var rule_color = self.series[series_index].color
                if point.has_color:
                    rule_color = point.color
                scene.append_line(
                    1100 + self.series[series_index].id,
                    Point(self.plot_area.x, screen.y),
                    Point(self.plot_area.x + self.plot_area.width, screen.y),
                    rule_color,
                    self.series[series_index].line_width,
                )
                var rule_command = scene.commands[len(scene.commands) - 1]
                rule_command.set_opacity(self.series[series_index].opacity * point.opacity)
                scene.commands[len(scene.commands) - 1] = rule_command
            elif self.series[series_index].kind == PLOT_AREA or self.series[series_index].kind == PLOT_BAND:
                var area_indices = self.line_indices(self.series[series_index].id)
                if len(area_indices) > 0:
                    var first_point = self._screen_point(
                        self.series[series_index].points[area_indices[0]]
                    )
                    var last_point = self._screen_point(
                        self.series[series_index].points[area_indices[len(area_indices) - 1]]
                    )
                    var path_data = String("M ", first_point.x, " ", first_point.y)
                    for area_index in range(1, len(area_indices)):
                        var area_point = self._screen_point(
                            self.series[series_index].points[area_indices[area_index]]
                        )
                        path_data += String(" L ", area_point.x, " ", area_point.y)
                    var baseline = self.y_scale.map(0.0)
                    path_data += String(
                        " L ",
                        last_point.x,
                        " ",
                        baseline,
                        " L ",
                        first_point.x,
                        " ",
                        baseline,
                        " Z",
                    )
                    scene.append_path(
                        1200 + self.series[series_index].id,
                        path_data,
                        self.plot_area,
                        self.series[series_index].color,
                        Color(0.0, 0.0, 0.0, 0.0),
                        0.0,
                    )
                    var area_command = scene.commands[len(scene.commands) - 1]
                    area_command.set_opacity(self.series[series_index].opacity * self.series[series_index].points[area_indices[0]].opacity)
                    scene.commands[len(scene.commands) - 1] = area_command
            elif self.series[series_index].kind == PLOT_BOX:
                for point_index in range(self.series[series_index].count()):
                    var source_point = self.series[series_index].points[point_index]
                    if not source_point.has_statistics:
                        continue
                    var point = self._screen_point(source_point)
                    var q3_point = source_point
                    q3_point.y = source_point.y2
                    var q3 = self._screen_point(q3_point)
                    var low_point = source_point
                    low_point.y = source_point.stat_low
                    var low = self._screen_point(low_point)
                    var high_point = source_point
                    high_point.y = source_point.stat_high
                    var high = self._screen_point(high_point)
                    var median_point = source_point
                    median_point.y = source_point.stat_median
                    var median = self._screen_point(median_point)
                    var point_color = self.series[series_index].color
                    if source_point.has_color:
                        point_color = source_point.color
                    var box_width = source_point.size
                    if box_width == 6.0:
                        box_width = 18.0
                    var left = point.x - box_width * 0.5
                    var top = point.y if point.y < q3.y else q3.y
                    var height = point.y - q3.y
                    if height < 0.0:
                        height = -height
                    scene.append_rect(
                        1250 + self.series[series_index].id * 100 + point_index,
                        Rect(left, top, box_width, height),
                        point_color,
                    )
                    var box_command = scene.commands[len(scene.commands) - 1]
                    box_command.set_opacity(self.series[series_index].opacity * source_point.opacity)
                    scene.commands[len(scene.commands) - 1] = box_command
                    scene.append_line(
                        1260 + self.series[series_index].id * 100 + point_index,
                        Point(left, median.y),
                        Point(left + box_width, median.y),
                        self.axis_color,
                        self.series[series_index].line_width,
                    )
                    scene.append_line(
                        1270 + self.series[series_index].id * 100 + point_index,
                        Point(point.x, low.y),
                        Point(point.x, high.y),
                        point_color,
                        self.series[series_index].line_width,
                    )
                    scene.append_line(
                        1280 + self.series[series_index].id * 100 + point_index,
                        Point(left + box_width * 0.2, low.y),
                        Point(left + box_width * 0.8, low.y),
                        point_color,
                        self.series[series_index].line_width,
                    )
                    scene.append_line(
                        1290 + self.series[series_index].id * 100 + point_index,
                        Point(left + box_width * 0.2, high.y),
                        Point(left + box_width * 0.8, high.y),
                        point_color,
                        self.series[series_index].line_width,
                    )
            elif self.series[series_index].kind == PLOT_ERROR_BAR or self.series[series_index].kind == PLOT_INTERVAL:
                for point_index in range(self.series[series_index].count()):
                    var source_point = self.series[series_index].points[point_index]
                    var point = self._screen_point(source_point)
                    var end_point = source_point
                    if source_point.has_y2:
                        end_point.y = source_point.y2
                    var end_screen = self._screen_point(end_point)
                    var point_color = self.series[series_index].color
                    if source_point.has_color:
                        point_color = source_point.color
                    var error = self.series[series_index].marker_size * 1.5
                    var lower = point.y - error
                    var upper = point.y + error
                    if source_point.has_y2:
                        lower = point.y if point.y < end_screen.y else end_screen.y
                        upper = point.y if point.y > end_screen.y else end_screen.y
                    scene.append_line(
                        1300 + self.series[series_index].id * 100 + point_index,
                        Point(point.x, lower),
                        Point(point.x, upper),
                        point_color,
                        self.series[series_index].line_width,
                    )
                    var error_command = scene.commands[len(scene.commands) - 1]
                    error_command.set_opacity(self.series[series_index].opacity * source_point.opacity)
                    scene.commands[len(scene.commands) - 1] = error_command
            else:
                var line_indices = List[Int]()
                if (
                    self.series[series_index].kind == PLOT_LINE
                    or self.series[series_index].kind == PLOT_STEP
                    or self.series[series_index].kind == PLOT_DENSITY
                    or self.series[series_index].kind == PLOT_ECDF
                    or self.series[series_index].kind == PLOT_REGRESSION
                ):
                    line_indices = self.line_indices(self.series[series_index].id)
                elif (self.series[series_index].kind == PLOT_SCATTER or self.series[series_index].kind == PLOT_DOT or self.series[series_index].kind == PLOT_BUBBLE) and self.scatter_point_limit > 0:
                    line_indices = self.scatter_indices(self.series[series_index].id)
                else:
                    for index in range(self.series[series_index].count()):
                        line_indices.append(index)
                for rendered_index in range(len(line_indices)):
                    var point_index = line_indices[rendered_index]
                    var point = self._screen_point(
                        self.series[series_index].points[point_index]
                    )
                    var source_point = self.series[series_index].points[point_index]
                    var point_color = self.series[series_index].color
                    if source_point.has_color:
                        point_color = source_point.color
                    var point_size = self.series[series_index].marker_size
                    if source_point.size != 6.0:
                        point_size = source_point.size
                    var point_opacity = self.series[series_index].opacity * source_point.opacity
                    if self.series[series_index].kind == PLOT_SCATTER or self.series[series_index].kind == PLOT_DOT or self.series[series_index].kind == PLOT_BUBBLE:
                        scene.append_rounded_rect(
                            2000 + self.series[series_index].id * 100 + point_index,
                            Rect(
                                point.x - point_size * 0.5,
                                point.y - point_size * 0.5,
                                point_size,
                                point_size,
                            ),
                            point_color,
                            point_size * 0.5,
                        )
                        var marker_command = scene.commands[len(scene.commands) - 1]
                        marker_command.set_opacity(point_opacity)
                        scene.commands[len(scene.commands) - 1] = marker_command
                    elif (
                        self.series[series_index].kind == PLOT_RECT
                        or self.series[series_index].kind == PLOT_HEATMAP
                        or self.series[series_index].kind == PLOT_HEXBIN
                    ):
                        var half_size = point_size * 0.5
                        var rect_end = source_point
                        if source_point.has_x2:
                            rect_end.x = source_point.x2
                        if source_point.has_y2:
                            rect_end.y = source_point.y2
                        var rect_end_screen = self._screen_point(rect_end)
                        var rect_left = point.x if point.x < rect_end_screen.x else rect_end_screen.x
                        var rect_top = point.y if point.y < rect_end_screen.y else rect_end_screen.y
                        var rect_width = point.x - rect_end_screen.x
                        if rect_width < 0.0:
                            rect_width = -rect_width
                        var rect_height = point.y - rect_end_screen.y
                        if rect_height < 0.0:
                            rect_height = -rect_height
                        if not source_point.has_x2:
                            rect_left = point.x - half_size
                            rect_width = point_size
                        if not source_point.has_y2:
                            rect_top = point.y - half_size
                            rect_height = point_size
                        if (
                            (self.series[series_index].kind == PLOT_HEATMAP
                            or self.series[series_index].kind == PLOT_HEXBIN)
                            and source_point.size <= 0.0
                        ):
                            continue
                        scene.append_rect(
                            2100 + self.series[series_index].id * 100 + point_index,
                            Rect(rect_left, rect_top, rect_width, rect_height),
                            point_color,
                        )
                        var rect_command = scene.commands[len(scene.commands) - 1]
                        rect_command.set_opacity(point_opacity)
                        scene.commands[len(scene.commands) - 1] = rect_command
                    elif self.series[series_index].kind == PLOT_TEXT:
                        scene.append_text(
                            2200 + self.series[series_index].id * 100 + point_index,
                            source_point.text if source_point.text.count_codepoints() > 0 else self.series[series_index].label,
                            Rect(point.x, point.y, 120.0, 18.0),
                            point_color,
                        )
                        var text_command = scene.commands[len(scene.commands) - 1]
                        text_command.set_opacity(point_opacity)
                        scene.commands[len(scene.commands) - 1] = text_command
                    elif self.series[series_index].kind == PLOT_TICK:
                        scene.append_line(
                            2300 + self.series[series_index].id * 100 + point_index,
                            Point(point.x, point.y - point_size),
                            Point(point.x, point.y + point_size),
                            point_color,
                            self.series[series_index].line_width,
                        )
                        var tick_command = scene.commands[len(scene.commands) - 1]
                        tick_command.set_opacity(point_opacity)
                        scene.commands[len(scene.commands) - 1] = tick_command
                    if (
                        (
                            self.series[series_index].kind == PLOT_LINE
                            or self.series[series_index].kind == PLOT_STEP
                            or self.series[series_index].kind == PLOT_DENSITY
                            or self.series[series_index].kind == PLOT_ECDF
                            or self.series[series_index].kind == PLOT_REGRESSION
                        )
                        and rendered_index > 0
                        and self.series[series_index].points[line_indices[rendered_index - 1]].facet_value
                            == self.series[series_index].points[point_index].facet_value
                        and self.series[series_index].points[line_indices[rendered_index - 1]].facet_column_value
                            == self.series[series_index].points[point_index].facet_column_value
                    ):
                        var previous_index = line_indices[rendered_index - 1]
                        var previous = self._screen_point(
                            self.series[series_index].points[previous_index]
                        )
                        if (
                            self.series[series_index].kind == PLOT_STEP
                            or self.series[series_index].kind == PLOT_ECDF
                        ):
                            scene.append_line(
                                3000 + self.series[series_index].id * 200 + point_index * 2,
                                previous,
                                Point(point.x, previous.y),
                                point_color,
                                self.series[series_index].line_width,
                            )
                            var horizontal_command = scene.commands[len(scene.commands) - 1]
                            horizontal_command.set_opacity(point_opacity)
                            scene.commands[len(scene.commands) - 1] = horizontal_command
                            scene.append_line(
                                3001 + self.series[series_index].id * 200 + point_index * 2,
                                Point(point.x, previous.y),
                                point,
                                point_color,
                                self.series[series_index].line_width,
                            )
                            var vertical_command = scene.commands[len(scene.commands) - 1]
                            vertical_command.set_opacity(point_opacity)
                            scene.commands[len(scene.commands) - 1] = vertical_command
                        else:
                            scene.append_line(
                                3000 + self.series[series_index].id * 100 + point_index,
                                previous,
                                point,
                                point_color,
                                self.series[series_index].line_width,
                            )
                            var line_command = scene.commands[len(scene.commands) - 1]
                            line_command.set_opacity(point_opacity)
                            scene.commands[len(scene.commands) - 1] = line_command
        scene.pop_clip()

        for annotation_index in range(len(self.annotation_ids)):
            var annotation_position = Point(
                self.annotation_x[annotation_index],
                self.annotation_y[annotation_index],
            )
            if self.annotation_data_space[annotation_index]:
                annotation_position = Point(
                    self.x_scale.map(self.annotation_x[annotation_index]),
                    self.y_scale.map(self.annotation_y[annotation_index]),
                )
            scene.append_text(
                8000 + self.annotation_ids[annotation_index],
                self.annotation_texts[annotation_index],
                Rect(annotation_position.x, annotation_position.y, 180.0, 18.0),
                self.axis_color,
            )

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
                if not self.point_is_renderable(self.series[series_index].points[point_index]):
                    continue
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
                    result.row_key = self.series[series_index].points[point_index].row_key
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
