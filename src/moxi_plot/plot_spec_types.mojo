"""Plot-spec value types: encoding, transform, scale-spec, annotation,
interaction, and one mark layer."""


from std.collections import List


from moxi.style import Color
from .plot_point import SCALE_LINEAR
from .plot_spec_names import (
    TYPE_QUANTITATIVE,
    INTERACTION_HOVER,
    TRANSFORM_BOX,
    TRANSFORM_DENSITY,
    TRANSFORM_ECDF,
    TRANSFORM_HEATMAP,
    TRANSFORM_HEXBIN,
    TRANSFORM_HISTOGRAM,
    TRANSFORM_REGRESSION,
)


struct PlotEncoding(ImplicitlyCopyable):
    """A channel binding to a typed field or literal value."""

    var layer_id: Int
    var channel: Int
    var field: String
    var data_type: Int
    var literal: String
    var has_literal: Bool

    def __init__(
        out self,
        layer_id: Int,
        channel: Int,
        field: String,
        data_type: Int = TYPE_QUANTITATIVE,
    ):
        self.layer_id = layer_id
        self.channel = channel
        self.field = field
        self.data_type = data_type
        self.literal = ""
        self.has_literal = False

    def set_literal(mut self, value: String):
        self.literal = value
        self.has_literal = True


struct PlotTransform(ImplicitlyCopyable):
    """A pure, serializable transform in the compact plot dataflow."""

    var kind: Int
    var field: String
    var second_field: String
    var output_field: String
    var value: Float32
    var second_value: Float32
    var descending: Bool
    var limit: Int
    var window: Int
    var mean: Bool

    def __init__(out self, kind: Int, field: String = ""):
        self.kind = kind
        self.field = field
        self.second_field = ""
        self.output_field = ""
        self.value = 0.0
        self.second_value = 0.0
        self.descending = False
        self.limit = 0
        self.window = 1
        self.mean = False


def _derived_field_available(
    transforms: List[PlotTransform],
    field: String,
) -> Bool:
    """Return whether a recipe transform materializes a named output field."""
    for index in range(len(transforms)):
        var transform = transforms[index]
        if transform.output_field == field:
            return True
        if transform.kind == TRANSFORM_HISTOGRAM:
            if field == "x" or field == "y" or field == "x2" or field == "count":
                return True
        elif transform.kind == TRANSFORM_DENSITY or transform.kind == TRANSFORM_ECDF:
            if field == "x" or field == "y":
                return True
        elif transform.kind == TRANSFORM_BOX:
            if (
                field == "group"
                or field == "x"
                or field == "y"
                or field == "y2"
                or field == "low"
                or field == "high"
                or field == "median"
                or field == "count"
            ):
                return True
        elif transform.kind == TRANSFORM_HEATMAP or transform.kind == TRANSFORM_HEXBIN:
            if field == "x" or field == "y" or field == "x2" or field == "y2" or field == "count":
                return True
        elif transform.kind == TRANSFORM_REGRESSION:
            if field == "x" or field == "y":
                return True
    return False


struct PlotScaleSpec(ImplicitlyCopyable):
    """Serializable scale configuration for one positional channel."""

    var channel: Int
    var kind: Int
    var power: Float32
    var tick_count: Int
    var reverse: Bool

    def __init__(out self, channel: Int, kind: Int = SCALE_LINEAR):
        self.channel = channel
        self.kind = kind
        self.power = 2.0
        self.tick_count = 5
        self.reverse = False


struct PlotAnnotation(ImplicitlyCopyable):
    """A renderer-neutral label anchored in data or screen coordinates."""

    var id: Int
    var text: String
    var x: Float32
    var y: Float32
    var data_space: Bool

    def __init__(
        out self,
        id: Int,
        text: String,
        x: Float32,
        y: Float32,
        data_space: Bool = True,
    ):
        self.id = id
        self.text = text
        self.x = x
        self.y = y
        self.data_space = data_space


struct PlotInteraction(ImplicitlyCopyable):
    """Declarative interaction tool configuration."""

    var kind: Int
    var x_only: Bool
    var y_only: Bool
    var crosshair: Bool
    var tooltip: Bool
    var additive: Bool

    def __init__(out self, kind: Int):
        self.kind = kind
        self.x_only = False
        self.y_only = False
        self.crosshair = kind == INTERACTION_HOVER
        self.tooltip = kind == INTERACTION_HOVER
        self.additive = False


struct PlotLayer(ImplicitlyCopyable):
    """One mark layer with explicit field encodings."""

    var id: Int
    var mark: Int
    var label: String
    var x_field: String
    var y_field: String
    var x2_field: String
    var y2_field: String
    var color_field: String
    var fill_field: String
    var stroke_field: String
    var size_field: String
    var opacity_field: String
    var text_field: String
    var stat_low_field: String
    var stat_high_field: String
    var median_field: String
    var color: Color
    var line_width: Float32
    var size: Float32
    var opacity: Float32
    var tooltip_fields: String

    def __init__(
        out self,
        id: Int,
        mark: Int,
        label: String,
        x_field: String,
        y_field: String,
        color: Color,
    ):
        self.id = id
        self.mark = mark
        self.label = label
        self.x_field = x_field
        self.y_field = y_field
        self.x2_field = ""
        self.y2_field = ""
        self.color_field = ""
        self.fill_field = ""
        self.stroke_field = ""
        self.size_field = ""
        self.opacity_field = ""
        self.text_field = ""
        self.stat_low_field = ""
        self.stat_high_field = ""
        self.median_field = ""
        self.color = color
        self.line_width = 2.0
        self.size = 6.0
        self.opacity = 1.0
        self.tooltip_fields = ""


