"""Inspectable declarative plot specification for the first Plot API."""


from std.collections import List


from moxi.json import json_fragment_is_valid, json_quote
from moxi.geometry import Rect
from moxi.style import Color
from .plot_data import PlotDataTable
from .plotting import Plot
from .plot_marks import (
    PLOT_AREA,
    PLOT_BAND,
    PLOT_BAR,
    PLOT_BOX,
    PLOT_BUBBLE,
    PLOT_CATALOG_FIRST,
    PLOT_CATALOG_LAST,
    PLOT_COLUMN,
    PLOT_DENSITY,
    PLOT_DOT,
    PLOT_ECDF,
    PLOT_ERROR_BAR,
    PLOT_GROUPED_BAR,
    PLOT_HEATMAP,
    PLOT_HEXBIN,
    PLOT_HISTOGRAM,
    PLOT_INTERVAL,
    PLOT_LINE,
    PLOT_RECT,
    PLOT_REGRESSION,
    PLOT_RULE,
    PLOT_SCATTER,
    PLOT_STACKED_BAR,
    PLOT_STEP,
    PLOT_TEXT,
    PLOT_TICK,
)
from .plot_spec_json import (
    _find_token,
    _read_number,
    _string_member,
    _number_member,
    _bool_member,
    _color_member,
    _object_array,
    _array_content,
)
from .plot_spec_names import (
    CHANNEL_COLOR,
    CHANNEL_FILL,
    CHANNEL_OPACITY,
    CHANNEL_SIZE,
    CHANNEL_STROKE,
    CHANNEL_TEXT,
    CHANNEL_TOOLTIP,
    CHANNEL_X,
    CHANNEL_X2,
    CHANNEL_Y,
    CHANNEL_Y2,
    COMPOSITION_FACET,
    COMPOSITION_LAYER,
    INTERACTION_BRUSH,
    INTERACTION_CLICK_SELECT,
    INTERACTION_HOVER,
    INTERACTION_KEYBOARD,
    INTERACTION_LASSO,
    INTERACTION_PAN_ZOOM,
    TRANSFORM_AGGREGATE,
    TRANSFORM_BIN,
    TRANSFORM_BOX,
    TRANSFORM_CALCULATE,
    TRANSFORM_DENSITY,
    TRANSFORM_ECDF,
    TRANSFORM_FILTER_BETWEEN,
    TRANSFORM_FILTER_GREATER,
    TRANSFORM_GROUP,
    TRANSFORM_HEATMAP,
    TRANSFORM_HEXBIN,
    TRANSFORM_HISTOGRAM,
    TRANSFORM_IMPUTE,
    TRANSFORM_LIMIT,
    TRANSFORM_REGRESSION,
    TRANSFORM_ROLLING_MEAN,
    TRANSFORM_SAMPLE,
    TRANSFORM_SORT,
    TRANSFORM_STACK,
    TYPE_QUANTITATIVE,
    channel_name,
    composition_name,
    data_type_name,
    interaction_name,
    scale_kind_name,
    transform_name,
    plot_mark_name,
    _valid_channel,
    _valid_data_type,
    _valid_mark,
    _valid_scale,
    _valid_transform,
    _mark_from_name,
    _channel_from_name,
    _data_type_from_name,
    _scale_from_name,
    _composition_from_name,
    _interaction_from_name,
    _transform_from_name,
)
from .plot_spec_types import (
    PlotEncoding,
    PlotTransform,
    _derived_field_available,
    PlotScaleSpec,
    PlotAnnotation,
    PlotInteraction,
    PlotLayer,
)


comptime PLOT_SPEC_VERSION = 1


def json_bool(value: Bool) -> String:
    return "true" if value else "false"


struct PlotSpec:
    """Versioned, serializable description independent of a renderer."""

    var version: Int
    var title: String
    var layers: List[PlotLayer]
    var encodings: List[PlotEncoding]
    var transforms: List[PlotTransform]
    var scales: List[PlotScaleSpec]
    var annotations: List[PlotAnnotation]
    var interactions: List[PlotInteraction]
    var composition: Int
    var facet_row: String
    var facet_column: String
    var shared_x_scale: Bool
    var shared_y_scale: Bool
    var valid: Bool
    var next_layer_id: Int
    var next_annotation_id: Int

    def __init__(out self, title: String = ""):
        self.version = PLOT_SPEC_VERSION
        self.title = title
        self.layers = List[PlotLayer]()
        self.encodings = List[PlotEncoding]()
        self.transforms = List[PlotTransform]()
        self.scales = List[PlotScaleSpec]()
        self.annotations = List[PlotAnnotation]()
        self.interactions = List[PlotInteraction]()
        self.composition = COMPOSITION_LAYER
        self.facet_row = ""
        self.facet_column = ""
        self.shared_x_scale = True
        self.shared_y_scale = True
        self.valid = True
        self.next_layer_id = 1
        self.next_annotation_id = 1

    def clone(self) -> PlotSpec:
        """Copy a specification for a long-lived view or cache boundary."""
        var result = PlotSpec(self.title)
        result.version = self.version
        result.composition = self.composition
        result.facet_row = self.facet_row
        result.facet_column = self.facet_column
        result.shared_x_scale = self.shared_x_scale
        result.shared_y_scale = self.shared_y_scale
        result.valid = self.valid
        result.next_layer_id = self.next_layer_id
        result.next_annotation_id = self.next_annotation_id
        for index in range(len(self.layers)):
            result.layers.append(self.layers[index])
        for index in range(len(self.encodings)):
            result.encodings.append(self.encodings[index])
        for index in range(len(self.transforms)):
            result.transforms.append(self.transforms[index])
        for index in range(len(self.scales)):
            result.scales.append(self.scales[index])
        for index in range(len(self.annotations)):
            result.annotations.append(self.annotations[index])
        for index in range(len(self.interactions)):
            result.interactions.append(self.interactions[index])
        return result^

    def add_layer(
        mut self,
        mark: Int,
        label: String,
        x_field: String,
        y_field: String,
        color: Color,
    ) -> Int:
        var id = self.next_layer_id
        self.next_layer_id += 1
        self.layers.append(PlotLayer(id, mark, label, x_field, y_field, color))
        if not _valid_mark(mark) or x_field.count_codepoints() == 0 or y_field.count_codepoints() == 0:
            self.valid = False
        self.encodings.append(
            PlotEncoding(id, CHANNEL_X, x_field, TYPE_QUANTITATIVE)
        )
        self.encodings.append(
            PlotEncoding(id, CHANNEL_Y, y_field, TYPE_QUANTITATIVE)
        )
        return id

    def add_catalog_mark(
        mut self,
        mark: Int,
        label: String,
        x_field: String = "x",
        y_field: String = "y",
        color: Color = Color(0.25, 0.75, 1.0, 1.0),
        x2_field: String = "",
        y2_field: String = "",
        size_field: String = "",
        color_field: String = "",
        fill_field: String = "",
        stroke_field: String = "",
        opacity_field: String = "",
        text_field: String = "",
        stat_low_field: String = "",
        stat_high_field: String = "",
        median_field: String = "",
        tooltip_fields: String = "",
    ) -> Int:
        """Add a catalog mark with the complete row-oriented channel set."""
        if mark < PLOT_CATALOG_FIRST or mark > PLOT_CATALOG_LAST:
            self.valid = False
        var id = self.add_layer(mark, label, x_field, y_field, color)
        var layer_index = self._layer_index(id)
        if layer_index != -1:
            self.layers[layer_index].x2_field = x2_field
            self.layers[layer_index].y2_field = y2_field
            self.layers[layer_index].size_field = size_field
            self.layers[layer_index].color_field = color_field
            self.layers[layer_index].fill_field = fill_field
            self.layers[layer_index].stroke_field = stroke_field
            self.layers[layer_index].opacity_field = opacity_field
            self.layers[layer_index].text_field = text_field
            self.layers[layer_index].stat_low_field = stat_low_field
            self.layers[layer_index].stat_high_field = stat_high_field
            self.layers[layer_index].median_field = median_field
            self.layers[layer_index].tooltip_fields = tooltip_fields
        if x2_field.count_codepoints() > 0:
            _ = self.encode(id, CHANNEL_X2, x2_field)
        if y2_field.count_codepoints() > 0:
            _ = self.encode(id, CHANNEL_Y2, y2_field)
        if size_field.count_codepoints() > 0:
            _ = self.encode(id, CHANNEL_SIZE, size_field)
        if color_field.count_codepoints() > 0:
            _ = self.encode(id, CHANNEL_COLOR, color_field)
        if fill_field.count_codepoints() > 0:
            _ = self.encode(id, CHANNEL_FILL, fill_field)
        if stroke_field.count_codepoints() > 0:
            _ = self.encode(id, CHANNEL_STROKE, stroke_field)
        if opacity_field.count_codepoints() > 0:
            _ = self.encode(id, CHANNEL_OPACITY, opacity_field)
        if text_field.count_codepoints() > 0:
            _ = self.encode(id, CHANNEL_TEXT, text_field)
        if tooltip_fields.count_codepoints() > 0:
            _ = self.encode(id, CHANNEL_TOOLTIP, tooltip_fields)
        return id

    def add_line(
        mut self,
        label: String,
        x_field: String = "x",
        y_field: String = "y",
        color: Color = Color(0.25, 0.75, 1.0, 1.0),
    ) -> Int:
        return self.add_layer(PLOT_LINE, label, x_field, y_field, color)

    def add_scatter(
        mut self,
        label: String,
        x_field: String = "x",
        y_field: String = "y",
        color: Color = Color(1.0, 0.45, 0.30, 1.0),
    ) -> Int:
        return self.add_layer(PLOT_SCATTER, label, x_field, y_field, color)

    def add_step(
        mut self,
        label: String,
        x_field: String = "x",
        y_field: String = "y",
        color: Color = Color(0.25, 0.75, 1.0, 1.0),
    ) -> Int:
        return self.add_layer(PLOT_STEP, label, x_field, y_field, color)

    def add_bubble(
        mut self,
        label: String,
        x_field: String = "x",
        y_field: String = "y",
        color: Color = Color(0.75, 0.45, 1.0, 1.0),
    ) -> Int:
        return self.add_layer(PLOT_BUBBLE, label, x_field, y_field, color)

    def add_band(
        mut self,
        label: String,
        x_field: String = "x",
        y_field: String = "y",
        color: Color = Color(0.30, 0.65, 0.95, 0.55),
    ) -> Int:
        return self.add_layer(PLOT_BAND, label, x_field, y_field, color)

    def add_column(
        mut self,
        label: String,
        x_field: String = "x",
        y_field: String = "y",
        color: Color = Color(0.40, 0.85, 0.55, 1.0),
    ) -> Int:
        return self.add_layer(PLOT_COLUMN, label, x_field, y_field, color)

    def add_tick(
        mut self,
        label: String,
        x_field: String = "x",
        y_field: String = "y",
        color: Color = Color(0.90, 0.92, 0.98, 1.0),
    ) -> Int:
        return self.add_layer(PLOT_TICK, label, x_field, y_field, color)

    def add_interval(
        mut self,
        label: String,
        x_field: String = "x",
        y_field: String = "y",
        color: Color = Color(0.95, 0.45, 0.35, 1.0),
    ) -> Int:
        return self.add_layer(PLOT_INTERVAL, label, x_field, y_field, color)

    def add_bar(
        mut self,
        label: String,
        x_field: String = "x",
        y_field: String = "y",
        color: Color = Color(0.40, 0.85, 0.55, 1.0),
    ) -> Int:
        return self.add_layer(PLOT_BAR, label, x_field, y_field, color)

    def add_grouped_bar(
        mut self,
        label: String,
        x_field: String = "x",
        y_field: String = "y",
        color: Color = Color(0.40, 0.85, 0.55, 1.0),
        x2_field: String = "",
        y2_field: String = "",
        size_field: String = "",
        color_field: String = "",
    ) -> Int:
        return self.add_catalog_mark(PLOT_GROUPED_BAR, label, x_field, y_field, color, x2_field, y2_field, size_field, color_field)

    def add_stacked_bar(
        mut self,
        label: String,
        x_field: String = "x",
        y_field: String = "y",
        color: Color = Color(0.40, 0.85, 0.55, 1.0),
        x2_field: String = "",
        y2_field: String = "",
        size_field: String = "",
        color_field: String = "",
    ) -> Int:
        return self.add_catalog_mark(PLOT_STACKED_BAR, label, x_field, y_field, color, x2_field, y2_field, size_field, color_field)

    def add_dot(
        mut self,
        label: String,
        x_field: String = "x",
        y_field: String = "y",
        color: Color = Color(0.95, 0.65, 0.20, 1.0),
    ) -> Int:
        return self.add_layer(PLOT_DOT, label, x_field, y_field, color)

    def add_area(
        mut self,
        label: String,
        x_field: String = "x",
        y_field: String = "y",
        color: Color = Color(0.30, 0.65, 0.95, 0.55),
    ) -> Int:
        return self.add_layer(PLOT_AREA, label, x_field, y_field, color)

    def add_rule(
        mut self,
        label: String,
        y_field: String = "y",
        color: Color = Color(0.95, 0.85, 0.35, 1.0),
    ) -> Int:
        return self.add_layer(PLOT_RULE, label, "x", y_field, color)

    def add_error_bar(
        mut self,
        label: String,
        x_field: String = "x",
        y_field: String = "y",
        color: Color = Color(0.95, 0.45, 0.35, 1.0),
    ) -> Int:
        return self.add_layer(PLOT_ERROR_BAR, label, x_field, y_field, color)

    def add_rect(
        mut self,
        label: String,
        x_field: String = "x",
        y_field: String = "y",
        color: Color = Color(0.45, 0.85, 0.55, 1.0),
    ) -> Int:
        return self.add_layer(PLOT_RECT, label, x_field, y_field, color)

    def add_text(
        mut self,
        label: String,
        x_field: String = "x",
        y_field: String = "y",
        color: Color = Color(0.90, 0.92, 0.98, 1.0),
    ) -> Int:
        return self.add_layer(PLOT_TEXT, label, x_field, y_field, color)

    def add_histogram(
        mut self,
        label: String,
        field: String,
        bins: Int = 10,
        color: Color = Color(0.30, 0.70, 0.95, 0.85),
    ) -> Int:
        """Add an equal-width histogram recipe over a numeric field."""
        var id = self.add_layer(PLOT_HISTOGRAM, label, "x", "y", color)
        var layer_index = self._layer_index(id)
        self.layers[layer_index].x2_field = "x2"
        var transform = PlotTransform(TRANSFORM_HISTOGRAM, field)
        transform.limit = bins if bins > 0 else 1
        self.transforms.append(transform)
        return id

    def add_density(
        mut self,
        label: String,
        field: String,
        bins: Int = 24,
        color: Color = Color(0.55, 0.45, 1.0, 1.0),
    ) -> Int:
        """Add a histogram-derived density line recipe."""
        var id = self.add_layer(PLOT_DENSITY, label, "x", "y", color)
        var transform = PlotTransform(TRANSFORM_DENSITY, field)
        transform.limit = bins if bins > 0 else 1
        self.transforms.append(transform)
        return id

    def add_ecdf(
        mut self,
        label: String,
        field: String,
        color: Color = Color(0.95, 0.65, 0.20, 1.0),
    ) -> Int:
        """Add an empirical cumulative distribution recipe."""
        var id = self.add_layer(PLOT_ECDF, label, "x", "y", color)
        self.transforms.append(PlotTransform(TRANSFORM_ECDF, field))
        return id

    def add_box(
        mut self,
        label: String,
        value_field: String,
        group_field: String = "",
        color: Color = Color(0.40, 0.85, 0.55, 0.90),
    ) -> Int:
        """Add a Tukey box-and-whisker recipe, optionally grouped."""
        var id = self.add_layer(PLOT_BOX, label, "group", "y", color)
        var layer_index = self._layer_index(id)
        self.layers[layer_index].y2_field = "y2"
        self.layers[layer_index].stat_low_field = "low"
        self.layers[layer_index].stat_high_field = "high"
        self.layers[layer_index].median_field = "median"
        var transform = PlotTransform(TRANSFORM_BOX, value_field)
        transform.second_field = group_field
        self.transforms.append(transform)
        return id

    def add_heatmap(
        mut self,
        label: String,
        x_field: String,
        y_field: String,
        x_bins: Int = 16,
        y_bins: Int = 12,
        color: Color = Color(0.25, 0.65, 1.0, 0.90),
    ) -> Int:
        """Add a rectangular density-bin heatmap recipe."""
        var id = self.add_layer(PLOT_HEATMAP, label, "x", "y", color)
        var layer_index = self._layer_index(id)
        self.layers[layer_index].x2_field = "x2"
        self.layers[layer_index].y2_field = "y2"
        self.layers[layer_index].color_field = "count"
        var transform = PlotTransform(TRANSFORM_HEATMAP, x_field)
        transform.second_field = y_field
        transform.limit = x_bins if x_bins > 0 else 1
        transform.window = y_bins if y_bins > 0 else 1
        self.transforms.append(transform)
        return id

    def add_hexbin(
        mut self,
        label: String,
        x_field: String,
        y_field: String,
        x_bins: Int = 16,
        y_bins: Int = 12,
        color: Color = Color(0.95, 0.45, 0.30, 0.90),
    ) -> Int:
        """Add a bounded rectangular hexbin-compatible density recipe."""
        var id = self.add_layer(PLOT_HEXBIN, label, "x", "y", color)
        var layer_index = self._layer_index(id)
        self.layers[layer_index].x2_field = "x2"
        self.layers[layer_index].y2_field = "y2"
        self.layers[layer_index].color_field = "count"
        var transform = PlotTransform(TRANSFORM_HEXBIN, x_field)
        transform.second_field = y_field
        transform.limit = x_bins if x_bins > 0 else 1
        transform.window = y_bins if y_bins > 0 else 1
        self.transforms.append(transform)
        return id

    def add_regression(
        mut self,
        label: String,
        x_field: String,
        y_field: String,
        samples: Int = 32,
        color: Color = Color(1.0, 0.75, 0.35, 1.0),
    ) -> Int:
        """Add an ordinary least-squares regression line recipe."""
        var id = self.add_layer(PLOT_REGRESSION, label, "x", "y", color)
        var transform = PlotTransform(TRANSFORM_REGRESSION, x_field)
        transform.second_field = y_field
        transform.limit = samples if samples > 1 else 2
        self.transforms.append(transform)
        return id

    def encode(
        mut self,
        layer_id: Int,
        channel: Int,
        field: String,
        data_type: Int = TYPE_QUANTITATIVE,
    ) -> Bool:
        var layer_index = self._layer_index(layer_id)
        if layer_index == -1 or not _valid_channel(channel) or not _valid_data_type(data_type) or field.count_codepoints() == 0:
            return False
        var found = False
        for index in range(len(self.encodings)):
            if (
                self.encodings[index].layer_id == layer_id
                and self.encodings[index].channel == channel
            ):
                self.encodings[index] = PlotEncoding(
                    layer_id, channel, field, data_type
                )
                found = True
                break
        if not found:
            self.encodings.append(PlotEncoding(layer_id, channel, field, data_type))
        if channel == CHANNEL_X:
            self.layers[layer_index].x_field = field
        elif channel == CHANNEL_Y:
            self.layers[layer_index].y_field = field
        elif channel == CHANNEL_X2:
            self.layers[layer_index].x2_field = field
        elif channel == CHANNEL_Y2:
            self.layers[layer_index].y2_field = field
        elif channel == CHANNEL_COLOR:
            self.layers[layer_index].color_field = field
        elif channel == CHANNEL_FILL:
            self.layers[layer_index].fill_field = field
        elif channel == CHANNEL_STROKE:
            self.layers[layer_index].stroke_field = field
        elif channel == CHANNEL_SIZE:
            self.layers[layer_index].size_field = field
        elif channel == CHANNEL_OPACITY:
            self.layers[layer_index].opacity_field = field
        elif channel == CHANNEL_TEXT:
            self.layers[layer_index].text_field = field
        elif channel == CHANNEL_TOOLTIP:
            self.layers[layer_index].tooltip_fields = field
        return True

    def encode_literal(mut self, layer_id: Int, channel: Int, literal: String) -> Bool:
        var layer_index = self._layer_index(layer_id)
        if layer_index == -1 or not _valid_channel(channel) or literal.count_codepoints() == 0:
            return False
        var encoding = PlotEncoding(layer_id, channel, "", TYPE_QUANTITATIVE)
        encoding.set_literal(literal)
        if channel == CHANNEL_SIZE:
            var size = _read_number(literal, 0)
            if size.ok:
                self.layers[layer_index].size = size.value if size.value > 0.0 else 1.0
        elif channel == CHANNEL_OPACITY:
            var opacity = _read_number(literal, 0)
            if opacity.ok:
                _ = self.set_layer_opacity(layer_id, opacity.value)
        for index in range(len(self.encodings)):
            if (
                self.encodings[index].layer_id == layer_id
                and self.encodings[index].channel == channel
            ):
                self.encodings[index] = encoding
                return True
        self.encodings.append(encoding)
        return True

    def encoding_count(self) -> Int:
        return len(self.encodings)

    def encoding(self, index: Int) -> PlotEncoding:
        return self.encodings[index]

    def _layer_index(self, layer_id: Int) -> Int:
        for index in range(len(self.layers)):
            if self.layers[index].id == layer_id:
                return index
        return -1

    def set_layer_size(mut self, layer_id: Int, size: Float32) -> Bool:
        var index = self._layer_index(layer_id)
        if index == -1:
            return False
        self.layers[index].size = size if size > 0.0 else 1.0
        return True

    def set_layer_line_width(mut self, layer_id: Int, width: Float32) -> Bool:
        var index = self._layer_index(layer_id)
        if index == -1:
            return False
        self.layers[index].line_width = width if width > 0.0 else 1.0
        return True

    def set_layer_opacity(mut self, layer_id: Int, opacity: Float32) -> Bool:
        var index = self._layer_index(layer_id)
        if index == -1:
            return False
        var value = opacity
        if value < 0.0:
            value = 0.0
        if value > 1.0:
            value = 1.0
        self.layers[index].opacity = value
        return True

    def set_tooltip_fields(mut self, layer_id: Int, fields: String) -> Bool:
        var index = self._layer_index(layer_id)
        if index == -1:
            return False
        self.layers[index].tooltip_fields = fields
        return True

    def add_filter_greater(mut self, field: String, threshold: Float32):
        var transform = PlotTransform(TRANSFORM_FILTER_GREATER, field)
        transform.value = threshold
        self.transforms.append(transform)

    def add_filter_between(
        mut self,
        field: String,
        minimum: Float32,
        maximum: Float32,
    ):
        var transform = PlotTransform(TRANSFORM_FILTER_BETWEEN, field)
        transform.value = minimum
        transform.second_value = maximum
        self.transforms.append(transform)

    def add_sort(mut self, field: String, descending: Bool = False):
        var transform = PlotTransform(TRANSFORM_SORT, field)
        transform.descending = descending
        self.transforms.append(transform)

    def add_limit(mut self, maximum_rows: Int):
        var transform = PlotTransform(TRANSFORM_LIMIT)
        transform.limit = maximum_rows
        self.transforms.append(transform)

    def add_calculate_constant(mut self, output_field: String, value: Float32):
        var transform = PlotTransform(TRANSFORM_CALCULATE)
        transform.output_field = output_field
        transform.value = value
        self.transforms.append(transform)

    def add_bin(mut self, field: String, output_field: String, width: Float32):
        var transform = PlotTransform(TRANSFORM_BIN, field)
        transform.output_field = output_field
        transform.value = width
        self.transforms.append(transform)

    def add_rolling_mean(mut self, field: String, output_field: String, window: Int):
        var transform = PlotTransform(TRANSFORM_ROLLING_MEAN, field)
        transform.output_field = output_field
        transform.window = window if window > 0 else 1
        self.transforms.append(transform)

    def add_impute(mut self, field: String, value: Float32):
        var transform = PlotTransform(TRANSFORM_IMPUTE, field)
        transform.value = value
        self.transforms.append(transform)

    def add_sample(mut self, maximum_rows: Int):
        var transform = PlotTransform(TRANSFORM_SAMPLE)
        transform.limit = maximum_rows
        self.transforms.append(transform)

    def add_stack(mut self, field: String, output_field: String = "stack"):
        var transform = PlotTransform(TRANSFORM_STACK, field)
        transform.output_field = output_field
        self.transforms.append(transform)

    def add_aggregate(
        mut self,
        group_field: String,
        value_field: String,
        output_field: String,
        mean: Bool = False,
    ):
        var transform = PlotTransform(TRANSFORM_AGGREGATE, group_field)
        transform.second_field = value_field
        transform.output_field = output_field
        transform.mean = mean
        self.transforms.append(transform)

    def add_group(mut self, group_field: String, output_field: String = "count"):
        var transform = PlotTransform(TRANSFORM_GROUP, group_field)
        transform.output_field = output_field
        self.transforms.append(transform)

    def transform_count(self) -> Int:
        return len(self.transforms)

    def transform(self, index: Int) -> PlotTransform:
        return self.transforms[index]

    def set_scale(
        mut self,
        channel: Int,
        kind: Int,
        power: Float32 = 2.0,
        tick_count: Int = 5,
        reverse: Bool = False,
    ):
        if not _valid_channel(channel) or channel != CHANNEL_X and channel != CHANNEL_Y or not _valid_scale(kind):
            self.valid = False
            return
        var next = PlotScaleSpec(channel, kind)
        next.power = power if power > 0.0 else 1.0
        next.tick_count = tick_count if tick_count > 0 else 1
        next.reverse = reverse
        for index in range(len(self.scales)):
            if self.scales[index].channel == channel:
                self.scales[index] = next
                return
        self.scales.append(next)

    def scale_count(self) -> Int:
        return len(self.scales)

    def scale(self, index: Int) -> PlotScaleSpec:
        return self.scales[index]

    def set_facet(mut self, row_field: String, column_field: String = ""):
        self.composition = COMPOSITION_FACET
        self.facet_row = row_field
        self.facet_column = column_field
        if row_field.count_codepoints() == 0:
            self.valid = False

    def set_composition(mut self, composition: Int):
        if composition < COMPOSITION_LAYER or composition > COMPOSITION_FACET:
            self.composition = COMPOSITION_LAYER
            self.valid = False
        else:
            self.composition = composition

    def set_shared_scales(mut self, x: Bool, y: Bool):
        self.shared_x_scale = x
        self.shared_y_scale = y

    def add_annotation(
        mut self,
        text: String,
        x: Float32,
        y: Float32,
        data_space: Bool = True,
    ) -> Int:
        var id = self.next_annotation_id
        self.next_annotation_id += 1
        self.annotations.append(PlotAnnotation(id, text, x, y, data_space))
        return id

    def add_interaction(
        mut self,
        kind: Int,
        x_only: Bool = False,
        y_only: Bool = False,
        crosshair: Bool = False,
        tooltip: Bool = False,
        additive: Bool = False,
    ) -> Bool:
        if kind < INTERACTION_HOVER or kind > INTERACTION_LASSO:
            self.valid = False
            return False
        var interaction = PlotInteraction(kind)
        interaction.x_only = x_only
        interaction.y_only = y_only
        interaction.crosshair = crosshair
        interaction.tooltip = tooltip
        interaction.additive = additive
        self.interactions.append(interaction)
        return True

    def add_hover(mut self, crosshair: Bool = True, tooltip: Bool = True) -> Bool:
        return self.add_interaction(
            INTERACTION_HOVER,
            False,
            False,
            crosshair,
            tooltip,
        )

    def add_brush(mut self, additive: Bool = False) -> Bool:
        return self.add_interaction(
            INTERACTION_BRUSH,
            False,
            False,
            False,
            False,
            additive,
        )

    def add_pan_zoom(mut self, x_only: Bool = False, y_only: Bool = False) -> Bool:
        return self.add_interaction(
            INTERACTION_PAN_ZOOM,
            x_only,
            y_only,
        )

    def add_click_select(mut self, additive: Bool = True) -> Bool:
        return self.add_interaction(
            INTERACTION_CLICK_SELECT,
            False,
            False,
            False,
            False,
            additive,
        )

    def add_keyboard(mut self) -> Bool:
        return self.add_interaction(INTERACTION_KEYBOARD)

    def add_lasso(mut self, additive: Bool = False) -> Bool:
        """Enable option-drag polygon selection in the runtime."""
        return self.add_interaction(
            INTERACTION_LASSO,
            False,
            False,
            False,
            False,
            additive,
        )

    def interaction_count(self) -> Int:
        return len(self.interactions)

    def interaction(self, index: Int) -> PlotInteraction:
        return self.interactions[index]

    def layer_count(self) -> Int:
        return len(self.layers)

    def is_valid(self) -> Bool:
        return self.valid

    def validate(mut self) -> Bool:
        """Validate the serializable grammar without requiring a data source."""
        var okay = self.valid
        if self.composition < COMPOSITION_LAYER or self.composition > COMPOSITION_FACET:
            okay = False
        if self.composition == COMPOSITION_FACET and self.facet_row.count_codepoints() == 0:
            okay = False
        for layer_index in range(len(self.layers)):
            var layer = self.layers[layer_index]
            if not _valid_mark(layer.mark) or layer.x_field.count_codepoints() == 0 or layer.y_field.count_codepoints() == 0:
                okay = False
            if layer.stat_low_field.count_codepoints() > 0 and layer.stat_high_field.count_codepoints() == 0:
                okay = False
            if layer.stat_high_field.count_codepoints() > 0 and layer.stat_low_field.count_codepoints() == 0:
                okay = False
            if layer.opacity < 0.0 or layer.opacity > 1.0 or layer.size <= 0.0 or layer.line_width <= 0.0:
                okay = False
        for encoding_index in range(len(self.encodings)):
            var encoding = self.encodings[encoding_index]
            if self._layer_index(encoding.layer_id) == -1 or not _valid_channel(encoding.channel) or not _valid_data_type(encoding.data_type):
                okay = False
            if not encoding.has_literal and encoding.field.count_codepoints() == 0:
                okay = False
            if encoding.has_literal and encoding.literal.count_codepoints() == 0:
                okay = False
        for transform_index in range(len(self.transforms)):
            var transform = self.transforms[transform_index]
            if not _valid_transform(transform.kind):
                okay = False
            if transform.kind != TRANSFORM_LIMIT and transform.kind != TRANSFORM_SAMPLE and transform.kind != TRANSFORM_CALCULATE and transform.field.count_codepoints() == 0:
                okay = False
            if transform.kind == TRANSFORM_CALCULATE and transform.output_field.count_codepoints() == 0:
                okay = False
            if (transform.kind == TRANSFORM_BIN or transform.kind == TRANSFORM_ROLLING_MEAN or transform.kind == TRANSFORM_STACK) and transform.output_field.count_codepoints() == 0:
                okay = False
            if (transform.kind == TRANSFORM_AGGREGATE or transform.kind == TRANSFORM_GROUP) and transform.output_field.count_codepoints() == 0:
                okay = False
            if transform.kind == TRANSFORM_AGGREGATE and transform.second_field.count_codepoints() == 0:
                okay = False
            if transform.kind == TRANSFORM_LIMIT or transform.kind == TRANSFORM_SAMPLE:
                if transform.limit < 0:
                    okay = False
            if transform.kind == TRANSFORM_ROLLING_MEAN and transform.window <= 0:
                okay = False
            if (
                transform.kind == TRANSFORM_HISTOGRAM
                or transform.kind == TRANSFORM_DENSITY
            ) and transform.limit <= 0:
                okay = False
            if (
                transform.kind == TRANSFORM_HEATMAP
                or transform.kind == TRANSFORM_HEXBIN
            ) and (
                transform.second_field.count_codepoints() == 0
                or transform.limit <= 0
                or transform.window <= 0
            ):
                okay = False
            if transform.kind == TRANSFORM_REGRESSION and (
                transform.second_field.count_codepoints() == 0
                or transform.limit <= 1
            ):
                okay = False
        for scale_index in range(len(self.scales)):
            var scale = self.scales[scale_index]
            if (scale.channel != CHANNEL_X and scale.channel != CHANNEL_Y) or not _valid_scale(scale.kind) or scale.power <= 0.0 or scale.tick_count <= 0:
                okay = False
        for interaction_index in range(len(self.interactions)):
            var interaction = self.interactions[interaction_index]
            if interaction.kind < INTERACTION_HOVER or interaction.kind > INTERACTION_LASSO:
                okay = False
            if interaction.x_only and interaction.y_only:
                okay = False
        self.valid = okay
        return okay

    def validate_data(mut self, data: PlotDataTable) -> Bool:
        """Validate field references against a concrete table."""
        var okay = self.validate()
        for layer_index in range(len(self.layers)):
            var layer = self.layers[layer_index]
            if (
                data.field_kind(layer.x_field) == 0
                and not _derived_field_available(self.transforms, layer.x_field)
            ) or (
                data.field_kind(layer.y_field) == 0
                and not _derived_field_available(self.transforms, layer.y_field)
            ):
                okay = False
            if layer.x2_field.count_codepoints() > 0 and data.field_kind(layer.x2_field) == 0 and not _derived_field_available(self.transforms, layer.x2_field):
                okay = False
            if layer.y2_field.count_codepoints() > 0 and data.field_kind(layer.y2_field) == 0 and not _derived_field_available(self.transforms, layer.y2_field):
                okay = False
            if layer.color_field.count_codepoints() > 0 and data.field_kind(layer.color_field) == 0 and not _derived_field_available(self.transforms, layer.color_field):
                okay = False
            if layer.fill_field.count_codepoints() > 0 and data.field_kind(layer.fill_field) == 0 and not _derived_field_available(self.transforms, layer.fill_field):
                okay = False
            if layer.stroke_field.count_codepoints() > 0 and data.field_kind(layer.stroke_field) == 0 and not _derived_field_available(self.transforms, layer.stroke_field):
                okay = False
            if layer.size_field.count_codepoints() > 0 and data.field_kind(layer.size_field) == 0 and not _derived_field_available(self.transforms, layer.size_field):
                okay = False
            if layer.opacity_field.count_codepoints() > 0 and data.field_kind(layer.opacity_field) == 0 and not _derived_field_available(self.transforms, layer.opacity_field):
                okay = False
            if layer.text_field.count_codepoints() > 0 and data.field_kind(layer.text_field) == 0 and not _derived_field_available(self.transforms, layer.text_field):
                okay = False
            if layer.stat_low_field.count_codepoints() > 0 and data.field_kind(layer.stat_low_field) == 0 and not _derived_field_available(self.transforms, layer.stat_low_field):
                okay = False
            if layer.stat_high_field.count_codepoints() > 0 and data.field_kind(layer.stat_high_field) == 0 and not _derived_field_available(self.transforms, layer.stat_high_field):
                okay = False
            if layer.median_field.count_codepoints() > 0 and data.field_kind(layer.median_field) == 0 and not _derived_field_available(self.transforms, layer.median_field):
                okay = False
        if self.facet_row.count_codepoints() > 0 and data.field_kind(self.facet_row) == 0:
            okay = False
        if self.facet_column.count_codepoints() > 0 and data.field_kind(self.facet_column) == 0:
            okay = False
        for transform_index in range(len(self.transforms)):
            var transform = self.transforms[transform_index]
            if transform.field.count_codepoints() > 0 and data.field_kind(transform.field) == 0 and not _derived_field_available(self.transforms, transform.field):
                okay = False
            if transform.second_field.count_codepoints() > 0 and data.field_kind(transform.second_field) == 0 and not _derived_field_available(self.transforms, transform.second_field):
                okay = False
        self.valid = okay
        return okay

    def layer(self, index: Int) -> PlotLayer:
        if index < 0 or index >= len(self.layers):
            return PlotLayer(-1, PLOT_LINE, "", "", "", Color(0.0, 0.0, 0.0, 0.0))
        return self.layers[index]

    def to_json(self) -> String:
        """Emit a stable inspection form for logs, tests, and persistence."""
        var result = String(
            "{\"version\":",
            self.version,
            ",\"title\":",
            json_quote(self.title),
            ",\"composition\":",
            json_quote(composition_name(self.composition)),
            ",\"facet\":{\"row\":",
            json_quote(self.facet_row),
            ",\"column\":",
            json_quote(self.facet_column),
            "},\"shared_scales\":{\"x\":",
            json_bool(self.shared_x_scale),
            ",\"y\":",
            json_bool(self.shared_y_scale),
            "},\"layers\":[",
        )
        for index in range(len(self.layers)):
            if index > 0:
                result += ","
            var layer = self.layers[index]
            result += String(
                "{\"id\":",
                layer.id,
                ",\"mark\":",
                json_quote(plot_mark_name(layer.mark)),
                ",\"label\":",
                json_quote(layer.label),
                ",\"x\":",
                json_quote(layer.x_field),
                ",\"y\":",
                json_quote(layer.y_field),
                ",\"x2\":",
                json_quote(layer.x2_field),
                ",\"y2\":",
                json_quote(layer.y2_field),
                ",\"color_field\":",
                json_quote(layer.color_field),
                ",\"fill_field\":",
                json_quote(layer.fill_field),
                ",\"stroke_field\":",
                json_quote(layer.stroke_field),
                ",\"size_field\":",
                json_quote(layer.size_field),
                ",\"opacity_field\":",
                json_quote(layer.opacity_field),
                ",\"text_field\":",
                json_quote(layer.text_field),
                ",\"stat_low_field\":",
                json_quote(layer.stat_low_field),
                ",\"stat_high_field\":",
                json_quote(layer.stat_high_field),
                ",\"median_field\":",
                json_quote(layer.median_field),
                ",\"line_width\":",
                layer.line_width,
                ",\"size\":",
                layer.size,
                ",\"opacity\":",
                layer.opacity,
                ",\"tooltip\":",
                json_quote(layer.tooltip_fields),
                ",\"color\":[",
                layer.color.red,
                ",",
                layer.color.green,
                ",",
                layer.color.blue,
                ",",
                layer.color.alpha,
                "]}",
            )
        result += "],\"encodings\":["
        for index in range(len(self.encodings)):
            if index > 0:
                result += ","
            var encoding = self.encodings[index]
            result += String(
                "{\"layer\":",
                encoding.layer_id,
                ",\"channel\":",
                json_quote(channel_name(encoding.channel)),
                ",\"field\":",
                json_quote(encoding.field),
                ",\"type\":",
                json_quote(data_type_name(encoding.data_type)),
                ",\"literal\":",
                json_quote(encoding.literal),
                ",\"has_literal\":",
                json_bool(encoding.has_literal),
                "}",
            )
        result += "],\"transforms\":["
        for index in range(len(self.transforms)):
            if index > 0:
                result += ","
            var transform = self.transforms[index]
            result += String(
                "{\"kind\":",
                json_quote(transform_name(transform.kind)),
                ",\"field\":",
                json_quote(transform.field),
                ",\"second_field\":",
                json_quote(transform.second_field),
                ",\"output_field\":",
                json_quote(transform.output_field),
                ",\"value\":",
                transform.value,
                ",\"second_value\":",
                transform.second_value,
                ",\"descending\":",
                json_bool(transform.descending),
                ",\"limit\":",
                transform.limit,
                ",\"window\":",
                transform.window,
                ",\"mean\":",
                json_bool(transform.mean),
                "}",
            )
        result += "],\"scales\":["
        for index in range(len(self.scales)):
            if index > 0:
                result += ","
            var scale = self.scales[index]
            result += String(
                "{\"channel\":",
                json_quote(channel_name(scale.channel)),
                ",\"kind\":",
                json_quote(scale_kind_name(scale.kind)),
                ",\"power\":",
                scale.power,
                ",\"ticks\":",
                scale.tick_count,
                ",\"reverse\":",
                json_bool(scale.reverse),
                "}",
            )
        result += "],\"interactions\":["
        for index in range(len(self.interactions)):
            if index > 0:
                result += ","
            var interaction = self.interactions[index]
            result += String(
                "{\"kind\":",
                json_quote(interaction_name(interaction.kind)),
                ",\"x_only\":",
                json_bool(interaction.x_only),
                ",\"y_only\":",
                json_bool(interaction.y_only),
                ",\"crosshair\":",
                json_bool(interaction.crosshair),
                ",\"tooltip\":",
                json_bool(interaction.tooltip),
                ",\"additive\":",
                json_bool(interaction.additive),
                "}",
            )
        result += "],\"annotations\":["
        for index in range(len(self.annotations)):
            if index > 0:
                result += ","
            var annotation = self.annotations[index]
            result += String(
                "{\"id\":",
                annotation.id,
                ",\"text\":",
                json_quote(annotation.text),
                ",\"x\":",
                annotation.x,
                ",\"y\":",
                annotation.y,
                ",\"data_space\":",
                json_bool(annotation.data_space),
                "}",
            )
        result += "]}"
        return result


def plot_spec_from_json(value: String) -> PlotSpec:
    """Parse the stable JSON emitted by ``PlotSpec.to_json``.

    This is intentionally a bounded parser for the versioned Moxi grammar. It
    rejects malformed JSON through the shared validator and ignores unknown
    members so newer producers can still be inspected by older clients.
    """
    var result = PlotSpec()
    if not json_fragment_is_valid(value, True):
        result.valid = False
        return result^
    var version = _number_member(value, "version")
    if not version.ok:
        result.valid = False
        return result^
    result.version = version.integer
    if result.version != PLOT_SPEC_VERSION:
        result.valid = False
    var title = _string_member(value, "title")
    if title.ok:
        result.title = title.value
    var composition = _string_member(value, "composition")
    if composition.ok:
        result.composition = _composition_from_name(composition.value)

    var facet_start = _find_token(value, "\"facet\":{")
    if facet_start != -1:
        var facet_content_start = facet_start + String("\"facet\":{").count_codepoints()
        var facet_end = _find_token(value, "}", facet_content_start)
        if facet_end != -1:
            var facet = String(value[codepoint=facet_content_start:facet_end])
            var row = _string_member(facet, "row")
            var column = _string_member(facet, "column")
            if row.ok:
                result.facet_row = row.value
            if column.ok:
                result.facet_column = column.value

    var shared_start = _find_token(value, "\"shared_scales\":{")
    if shared_start != -1:
        var shared_content_start = shared_start + String("\"shared_scales\":{").count_codepoints()
        var shared_end = _find_token(value, "}", shared_content_start)
        if shared_end != -1:
            var shared = String(value[codepoint=shared_content_start:shared_end])
            result.shared_x_scale = _bool_member(shared, "x")
            result.shared_y_scale = _bool_member(shared, "y")

    var layers_marker = "\"layers\":["
    var encodings_marker = "],\"encodings\":["
    var layers_start = _find_token(value, layers_marker)
    var layers_end = _find_token(value, encodings_marker, layers_start + layers_marker.count_codepoints())
    if layers_start == -1 or layers_end == -1:
        result.valid = False
        return result^
    var layers = _object_array(
        value,
        layers_start + layers_marker.count_codepoints(),
        layers_end,
    )
    for object_index in range(len(layers)):
        var object = layers[object_index]
        var id = _number_member(object, "id")
        var mark = _string_member(object, "mark")
        var label = _string_member(object, "label")
        var x = _string_member(object, "x")
        var y = _string_member(object, "y")
        if not id.ok or not mark.ok or not label.ok or not x.ok or not y.ok:
            result.valid = False
            continue
        var layer_id = result.add_layer(
            _mark_from_name(mark.value),
            label.value,
            x.value,
            y.value,
            _color_member(object),
        )
        var layer_index = result._layer_index(layer_id)
        result.layers[layer_index].id = id.integer
        if id.integer >= result.next_layer_id:
            result.next_layer_id = id.integer + 1
        var x2 = _string_member(object, "x2")
        var y2 = _string_member(object, "y2")
        var color_field = _string_member(object, "color_field")
        var fill_field = _string_member(object, "fill_field")
        var stroke_field = _string_member(object, "stroke_field")
        var size_field = _string_member(object, "size_field")
        var opacity_field = _string_member(object, "opacity_field")
        var text_field = _string_member(object, "text_field")
        var stat_low_field = _string_member(object, "stat_low_field")
        var stat_high_field = _string_member(object, "stat_high_field")
        var median_field = _string_member(object, "median_field")
        if x2.ok:
            result.layers[layer_index].x2_field = x2.value
        if y2.ok:
            result.layers[layer_index].y2_field = y2.value
        if color_field.ok:
            result.layers[layer_index].color_field = color_field.value
        if fill_field.ok:
            result.layers[layer_index].fill_field = fill_field.value
        if stroke_field.ok:
            result.layers[layer_index].stroke_field = stroke_field.value
        if size_field.ok:
            result.layers[layer_index].size_field = size_field.value
        if opacity_field.ok:
            result.layers[layer_index].opacity_field = opacity_field.value
        if text_field.ok:
            result.layers[layer_index].text_field = text_field.value
        if stat_low_field.ok:
            result.layers[layer_index].stat_low_field = stat_low_field.value
        if stat_high_field.ok:
            result.layers[layer_index].stat_high_field = stat_high_field.value
        if median_field.ok:
            result.layers[layer_index].median_field = median_field.value
        var line_width = _number_member(object, "line_width")
        var size = _number_member(object, "size")
        var opacity = _number_member(object, "opacity")
        if line_width.ok:
            result.layers[layer_index].line_width = line_width.value
        if size.ok:
            result.layers[layer_index].size = size.value
        if opacity.ok:
            result.layers[layer_index].opacity = opacity.value
        var tooltip = _string_member(object, "tooltip")
        if tooltip.ok:
            result.layers[layer_index].tooltip_fields = tooltip.value

    var transforms_marker = "],\"transforms\":["
    var scales_marker = "],\"scales\":["
    var interactions_marker = "],\"interactions\":["
    var annotations_marker = "],\"annotations\":["
    var encodings_start = layers_end + encodings_marker.count_codepoints()
    var encodings_end = _find_token(value, transforms_marker, encodings_start)
    if encodings_end != -1:
        var encodings = _object_array(value, encodings_start, encodings_end)
        for object_index in range(len(encodings)):
            var object = encodings[object_index]
            var layer = _number_member(object, "layer")
            var channel = _string_member(object, "channel")
            var field = _string_member(object, "field")
            var data_type = _string_member(object, "type")
            if layer.ok and channel.ok:
                var literal = _string_member(object, "literal")
                if _bool_member(object, "has_literal"):
                    if not result.encode_literal(layer.integer, _channel_from_name(channel.value), literal.value):
                        result.valid = False
                elif field.ok:
                    if not result.encode(
                        layer.integer,
                        _channel_from_name(channel.value),
                        field.value,
                        _data_type_from_name(data_type.value),
                    ):
                        result.valid = False
                else:
                    result.valid = False

    var transforms_end = _find_token(value, scales_marker, encodings_end + transforms_marker.count_codepoints())
    if encodings_end != -1 and transforms_end != -1:
        var transforms = _object_array(
            value,
            encodings_end + transforms_marker.count_codepoints(),
            transforms_end,
        )
        for object_index in range(len(transforms)):
            var object = transforms[object_index]
            var kind = _string_member(object, "kind")
            var field = _string_member(object, "field")
            if not kind.ok:
                continue
            var transform_kind = _transform_from_name(kind.value)
            if transform_kind == TRANSFORM_FILTER_BETWEEN:
                var minimum = _number_member(object, "value")
                var maximum = _number_member(object, "second_value")
                result.add_filter_between(field.value, minimum.value, maximum.value)
            elif transform_kind == TRANSFORM_SORT:
                result.add_sort(field.value, _bool_member(object, "descending"))
            elif transform_kind == TRANSFORM_LIMIT:
                result.add_limit(_number_member(object, "limit").integer)
            elif transform_kind == TRANSFORM_CALCULATE:
                var output_field = _string_member(object, "output_field")
                result.add_calculate_constant(output_field.value, _number_member(object, "value").value)
            elif transform_kind == TRANSFORM_BIN:
                var output_field = _string_member(object, "output_field")
                result.add_bin(field.value, output_field.value, _number_member(object, "value").value)
            elif transform_kind == TRANSFORM_ROLLING_MEAN:
                var output_field = _string_member(object, "output_field")
                result.add_rolling_mean(field.value, output_field.value, _number_member(object, "window").integer)
            elif transform_kind == TRANSFORM_IMPUTE:
                result.add_impute(field.value, _number_member(object, "value").value)
            elif transform_kind == TRANSFORM_SAMPLE:
                result.add_sample(_number_member(object, "limit").integer)
            elif transform_kind == TRANSFORM_STACK:
                var output_field = _string_member(object, "output_field")
                result.add_stack(field.value, output_field.value)
            elif transform_kind == TRANSFORM_AGGREGATE:
                var output_field = _string_member(object, "output_field")
                var second_field = _string_member(object, "second_field")
                result.add_aggregate(
                    field.value,
                    second_field.value,
                    output_field.value,
                    _bool_member(object, "mean"),
                )
            elif transform_kind == TRANSFORM_GROUP:
                var output_field = _string_member(object, "output_field")
                result.add_group(field.value, output_field.value)
            elif transform_kind == TRANSFORM_HISTOGRAM:
                var parsed_transform = PlotTransform(TRANSFORM_HISTOGRAM, field.value)
                parsed_transform.limit = _number_member(object, "limit").integer
                result.transforms.append(parsed_transform)
            elif transform_kind == TRANSFORM_DENSITY:
                var parsed_transform = PlotTransform(TRANSFORM_DENSITY, field.value)
                parsed_transform.limit = _number_member(object, "limit").integer
                result.transforms.append(parsed_transform)
            elif transform_kind == TRANSFORM_ECDF:
                result.transforms.append(PlotTransform(TRANSFORM_ECDF, field.value))
            elif transform_kind == TRANSFORM_BOX:
                var parsed_transform = PlotTransform(TRANSFORM_BOX, field.value)
                parsed_transform.second_field = _string_member(object, "second_field").value
                result.transforms.append(parsed_transform)
            elif transform_kind == TRANSFORM_HEATMAP:
                var parsed_transform = PlotTransform(TRANSFORM_HEATMAP, field.value)
                parsed_transform.second_field = _string_member(object, "second_field").value
                parsed_transform.limit = _number_member(object, "limit").integer
                parsed_transform.window = _number_member(object, "window").integer
                result.transforms.append(parsed_transform)
            elif transform_kind == TRANSFORM_HEXBIN:
                var parsed_transform = PlotTransform(TRANSFORM_HEXBIN, field.value)
                parsed_transform.second_field = _string_member(object, "second_field").value
                parsed_transform.limit = _number_member(object, "limit").integer
                parsed_transform.window = _number_member(object, "window").integer
                result.transforms.append(parsed_transform)
            elif transform_kind == TRANSFORM_REGRESSION:
                var parsed_transform = PlotTransform(TRANSFORM_REGRESSION, field.value)
                parsed_transform.second_field = _string_member(object, "second_field").value
                parsed_transform.limit = _number_member(object, "limit").integer
                result.transforms.append(parsed_transform)
            elif transform_kind == 0:
                result.valid = False
            else:
                result.add_filter_greater(field.value, _number_member(object, "value").value)

    var scales_end = _find_token(value, interactions_marker, transforms_end + scales_marker.count_codepoints())
    if transforms_end != -1 and scales_end != -1:
        var scales = _object_array(
            value,
            transforms_end + scales_marker.count_codepoints(),
            scales_end,
        )
        for object_index in range(len(scales)):
            var object = scales[object_index]
            var channel = _string_member(object, "channel")
            var kind = _string_member(object, "kind")
            if channel.ok and kind.ok:
                result.set_scale(
                    _channel_from_name(channel.value),
                    _scale_from_name(kind.value),
                    _number_member(object, "power").value,
                    _number_member(object, "ticks").integer,
                    _bool_member(object, "reverse"),
                )

    var interactions_end = _find_token(value, annotations_marker, scales_end + interactions_marker.count_codepoints())
    if scales_end != -1 and interactions_end != -1:
        var interactions = _object_array(
            value,
            scales_end + interactions_marker.count_codepoints(),
            interactions_end,
        )
        for object_index in range(len(interactions)):
            var object = interactions[object_index]
            var kind = _string_member(object, "kind")
            if not kind.ok:
                result.valid = False
                continue
            var interaction_kind = _interaction_from_name(kind.value)
            if interaction_kind == 0:
                result.valid = False
                continue
            var interaction = PlotInteraction(interaction_kind)
            interaction.x_only = _bool_member(object, "x_only")
            interaction.y_only = _bool_member(object, "y_only")
            interaction.crosshair = _bool_member(object, "crosshair")
            interaction.tooltip = _bool_member(object, "tooltip")
            interaction.additive = _bool_member(object, "additive")
            result.interactions.append(interaction)

    var annotation_end = _find_token(value, "]}", interactions_end + annotations_marker.count_codepoints())
    if interactions_end != -1 and annotation_end != -1:
        var annotations = _object_array(
            value,
            interactions_end + annotations_marker.count_codepoints(),
            annotation_end,
        )
        for object_index in range(len(annotations)):
            var object = annotations[object_index]
            var id = _number_member(object, "id")
            var text = _string_member(object, "text")
            if id.ok and text.ok:
                var annotation = PlotAnnotation(
                    id.integer,
                    text.value,
                    _number_member(object, "x").value,
                    _number_member(object, "y").value,
                    _bool_member(object, "data_space"),
                )
                result.annotations.append(annotation)
                if id.integer >= result.next_annotation_id:
                    result.next_annotation_id = id.integer + 1
    _ = result.validate()
    return result^


def plot_from_spec(
    spec: PlotSpec,
    data: PlotDataTable,
    bounds: Rect,
) -> Plot:
    """Compile a versioned spec and pure transforms into a scene plot model."""
    var transformed = data.clone()
    for transform_index in range(spec.transform_count()):
        var transform = spec.transform(transform_index)
        if transform.kind == TRANSFORM_FILTER_GREATER:
            transformed = transformed.filter_greater(transform.field, transform.value)
        elif transform.kind == TRANSFORM_FILTER_BETWEEN:
            transformed = transformed.filter_between(
                transform.field,
                transform.value,
                transform.second_value,
            )
        elif transform.kind == TRANSFORM_SORT:
            transformed = transformed.sort_by(transform.field, transform.descending)
        elif transform.kind == TRANSFORM_LIMIT:
            transformed = transformed.limit_rows(transform.limit)
        elif transform.kind == TRANSFORM_CALCULATE:
            transformed = transformed.calculate_constant(transform.output_field, transform.value)
        elif transform.kind == TRANSFORM_BIN:
            transformed = transformed.bin_field(
                transform.field,
                transform.output_field,
                transform.value,
            )
        elif transform.kind == TRANSFORM_ROLLING_MEAN:
            transformed = transformed.rolling_mean(
                transform.field,
                transform.output_field,
                transform.window,
            )
        elif transform.kind == TRANSFORM_IMPUTE:
            transformed = transformed.impute(transform.field, transform.value)
        elif transform.kind == TRANSFORM_SAMPLE:
            transformed = transformed.sample_rows(transform.limit)
        elif transform.kind == TRANSFORM_STACK:
            transformed = transformed.stack(transform.field, transform.output_field)
        elif transform.kind == TRANSFORM_AGGREGATE:
            transformed = transformed.aggregate(
                transform.field,
                transform.second_field,
                transform.output_field,
                transform.mean,
            )
        elif transform.kind == TRANSFORM_GROUP:
            transformed = transformed.aggregate(
                transform.field,
                "",
                transform.output_field,
                False,
            )
        elif transform.kind == TRANSFORM_HISTOGRAM:
            transformed = transformed.histogram(
                transform.field,
                transform.limit,
            )
        elif transform.kind == TRANSFORM_DENSITY:
            transformed = transformed.density(
                transform.field,
                transform.limit,
            )
        elif transform.kind == TRANSFORM_ECDF:
            transformed = transformed.ecdf(transform.field)
        elif transform.kind == TRANSFORM_BOX:
            transformed = transformed.box_summary(
                transform.field,
                transform.second_field,
            )
        elif transform.kind == TRANSFORM_HEATMAP:
            transformed = transformed.heatmap(
                transform.field,
                transform.second_field,
                transform.limit,
                transform.window,
            )
        elif transform.kind == TRANSFORM_HEXBIN:
            transformed = transformed.heatmap(
                transform.field,
                transform.second_field,
                transform.limit,
                transform.window,
            )
        elif transform.kind == TRANSFORM_REGRESSION:
            transformed = transformed.regression(
                transform.field,
                transform.second_field,
                transform.limit,
            )
    var plot = Plot(bounds)
    plot.set_title(spec.title)
    plot.set_composition(spec.composition)
    if spec.facet_row.count_codepoints() > 0:
        plot.set_facet(spec.facet_row, spec.facet_column)
        plot.set_facet_scale_resolution(
            not spec.shared_x_scale,
            not spec.shared_y_scale,
        )
    for scale_index in range(spec.scale_count()):
        var scale = spec.scale(scale_index)
        if scale.channel == CHANNEL_X:
            plot.set_x_scale(scale.kind, scale.power, scale.reverse)
        elif scale.channel == CHANNEL_Y:
            plot.set_y_scale(scale.kind, scale.power, scale.reverse)
    for index in range(spec.layer_count()):
        var layer = spec.layer(index)
        var color_field = layer.color_field
        if color_field.count_codepoints() == 0:
            color_field = layer.fill_field
        if color_field.count_codepoints() == 0:
            color_field = layer.stroke_field
        var series_id = plot.add_table_series_fields(
            transformed,
            layer.label,
            layer.color,
            layer.mark,
            layer.x_field,
            layer.y_field,
            layer.size_field,
            layer.opacity_field,
            layer.text_field,
            color_field,
            layer.tooltip_fields,
            layer.x2_field,
            layer.y2_field,
            layer.stat_low_field,
            layer.stat_high_field,
            layer.median_field,
        )
        _ = plot.set_series_line_width(series_id, layer.line_width)
        _ = plot.set_series_marker_size(series_id, layer.size)
        _ = plot.set_series_opacity(series_id, layer.opacity)
    for annotation_index in range(len(spec.annotations)):
        var annotation = spec.annotations[annotation_index]
        _ = plot.add_annotation(
            annotation.text,
            annotation.x,
            annotation.y,
            annotation.data_space,
        )
    plot.fit_to_data()
    return plot^
