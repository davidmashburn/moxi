"""Inspectable declarative plot specification for the first Plot API."""

from std.collections import List

from .capability import json_quote
from .geometry import Rect
from .plot_data import PlotDataTable
from .plotting import PLOT_BAR, PLOT_LINE, PLOT_SCATTER, Plot
from .style import Color


comptime PLOT_SPEC_VERSION = 1


def plot_mark_name(mark: Int) -> String:
    if mark == PLOT_SCATTER:
        return "scatter"
    if mark == PLOT_BAR:
        return "bar"
    return "line"


struct PlotLayer(ImplicitlyCopyable):
    """One mark layer with explicit field encodings."""

    var id: Int
    var mark: Int
    var label: String
    var x_field: String
    var y_field: String
    var color: Color
    var line_width: Float32

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
        self.color = color
        self.line_width = 2.0


struct PlotSpec:
    """Versioned, serializable description independent of a renderer."""

    var version: Int
    var title: String
    var layers: List[PlotLayer]
    var next_layer_id: Int

    def __init__(out self, title: String = ""):
        self.version = PLOT_SPEC_VERSION
        self.title = title
        self.layers = List[PlotLayer]()
        self.next_layer_id = 1

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

    def add_bar(
        mut self,
        label: String,
        x_field: String = "x",
        y_field: String = "y",
        color: Color = Color(0.40, 0.85, 0.55, 1.0),
    ) -> Int:
        return self.add_layer(PLOT_BAR, label, x_field, y_field, color)

    def layer_count(self) -> Int:
        return len(self.layers)

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
            ",\"layers\":[",
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
                ",\"line_width\":",
                layer.line_width,
                "}",
            )
        result += "]}"
        return result


def plot_from_spec(
    spec: PlotSpec,
    data: PlotDataTable,
    bounds: Rect,
) -> Plot:
    """Compile the numeric x/y subset of a spec into the scene plot model."""
    var plot = Plot(bounds)
    plot.set_title(spec.title)
    for index in range(spec.layer_count()):
        var layer = spec.layer(index)
        var series_id = plot.add_table_series(
            data,
            layer.label,
            layer.color,
            layer.mark,
        )
        _ = plot.set_series_line_width(series_id, layer.line_width)
    plot.fit_to_data()
    return plot^
