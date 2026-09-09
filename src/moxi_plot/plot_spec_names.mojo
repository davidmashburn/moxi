"""Plot-spec vocabulary: encoding/type/transform/composition/interaction
kind constants and their string <-> int name mappings."""


from .plot_marks import (
    PLOT_ARC_DIAGRAM,
    PLOT_AREA,
    PLOT_BAND,
    PLOT_BAR,
    PLOT_BARBS,
    PLOT_BEESWARM,
    PLOT_BOX,
    PLOT_BUBBLE,
    PLOT_BULLET,
    PLOT_BUMP,
    PLOT_CALENDAR_HEATMAP,
    PLOT_CANDLESTICK,
    PLOT_CATALOG_FIRST,
    PLOT_CATALOG_LAST,
    PLOT_CHORD,
    PLOT_COLUMN,
    PLOT_CONTOUR,
    PLOT_CONTOURF,
    PLOT_CORRPLOT,
    PLOT_DENSITY,
    PLOT_DONUT,
    PLOT_DOT,
    PLOT_ECDF,
    PLOT_EFFECT_SCATTER,
    PLOT_ERROR_BAR,
    PLOT_FUNNEL,
    PLOT_GANTT,
    PLOT_GAUGE,
    PLOT_GRAPH,
    PLOT_GROUPED_BAR,
    PLOT_HEATMAP,
    PLOT_HEXBIN,
    PLOT_HISTOGRAM,
    PLOT_INTERVAL,
    PLOT_LINE,
    PLOT_LOLLIPOP,
    PLOT_MARIMEKKO,
    PLOT_NIGHTINGALE,
    PLOT_PARALLEL,
    PLOT_PIE,
    PLOT_POLAR,
    PLOT_POLAR_BAR,
    PLOT_POPULATION_PYRAMID,
    PLOT_PUNCHCARD,
    PLOT_RADAR,
    PLOT_RADIALBAR,
    PLOT_RECT,
    PLOT_REGRESSION,
    PLOT_RIDGELINE,
    PLOT_RULE,
    PLOT_SANKEY,
    PLOT_SCATTER,
    PLOT_SPAN_CHART,
    PLOT_STACKED_BAR,
    PLOT_STEP,
    PLOT_STREAMGRAPH,
    PLOT_SUNBURST,
    PLOT_TEXT,
    PLOT_TICK,
    PLOT_TREE,
    PLOT_TREEMAP,
    PLOT_TRICONTOUR,
    PLOT_VIOLIN,
    PLOT_WATERFALL,
)
from .plot_point import (
    SCALE_LINEAR,
    SCALE_LOG,
    SCALE_POWER,
    SCALE_SQRT,
    SCALE_TEMPORAL,
    SCALE_ORDINAL,
    SCALE_BAND,
    SCALE_SYMLOG,
    SCALE_POINT,
    SCALE_THRESHOLD,
    SCALE_QUANTILE,
    SCALE_QUANTIZE,
    SCALE_SEQUENTIAL,
    SCALE_DIVERGING,
    SCALE_CATEGORICAL,
)


comptime TYPE_QUANTITATIVE = 1
comptime TYPE_TEMPORAL = 2
comptime TYPE_NOMINAL = 3
comptime TYPE_ORDINAL = 4
comptime TYPE_BOOL = 5

comptime CHANNEL_X = 1
comptime CHANNEL_Y = 2
comptime CHANNEL_X2 = 3
comptime CHANNEL_Y2 = 4
comptime CHANNEL_COLOR = 5
comptime CHANNEL_FILL = 6
comptime CHANNEL_STROKE = 7
comptime CHANNEL_OPACITY = 8
comptime CHANNEL_SIZE = 9
comptime CHANNEL_SHAPE = 10
comptime CHANNEL_ANGLE = 11
comptime CHANNEL_RADIUS = 12
comptime CHANNEL_TEXT = 13
comptime CHANNEL_TOOLTIP = 14
comptime CHANNEL_HREF = 15
comptime CHANNEL_ORDER = 16
comptime CHANNEL_DETAIL = 17
comptime CHANNEL_KEY = 18
comptime CHANNEL_ROW = 19
comptime CHANNEL_COLUMN = 20
comptime CHANNEL_FACET = 21

comptime TRANSFORM_FILTER_GREATER = 1
comptime TRANSFORM_FILTER_BETWEEN = 2
comptime TRANSFORM_SORT = 3
comptime TRANSFORM_LIMIT = 4
comptime TRANSFORM_CALCULATE = 5
comptime TRANSFORM_BIN = 6
comptime TRANSFORM_ROLLING_MEAN = 7
comptime TRANSFORM_IMPUTE = 8
comptime TRANSFORM_SAMPLE = 9
comptime TRANSFORM_STACK = 10
comptime TRANSFORM_AGGREGATE = 11
comptime TRANSFORM_GROUP = 12
comptime TRANSFORM_HISTOGRAM = 13
comptime TRANSFORM_DENSITY = 14
comptime TRANSFORM_ECDF = 15
comptime TRANSFORM_BOX = 16
comptime TRANSFORM_HEATMAP = 17
comptime TRANSFORM_HEXBIN = 18
comptime TRANSFORM_REGRESSION = 19

comptime COMPOSITION_LAYER = 1
comptime COMPOSITION_HORIZONTAL = 2
comptime COMPOSITION_VERTICAL = 3
comptime COMPOSITION_FACET = 4

comptime INTERACTION_HOVER = 1
comptime INTERACTION_BRUSH = 2
comptime INTERACTION_PAN_ZOOM = 3
comptime INTERACTION_CLICK_SELECT = 4
comptime INTERACTION_KEYBOARD = 5
comptime INTERACTION_LASSO = 6


def channel_name(channel: Int) -> String:
    if channel == CHANNEL_X:
        return "x"
    if channel == CHANNEL_Y:
        return "y"
    if channel == CHANNEL_X2:
        return "x2"
    if channel == CHANNEL_Y2:
        return "y2"
    if channel == CHANNEL_COLOR:
        return "color"
    if channel == CHANNEL_FILL:
        return "fill"
    if channel == CHANNEL_STROKE:
        return "stroke"
    if channel == CHANNEL_OPACITY:
        return "opacity"
    if channel == CHANNEL_SIZE:
        return "size"
    if channel == CHANNEL_SHAPE:
        return "shape"
    if channel == CHANNEL_ANGLE:
        return "angle"
    if channel == CHANNEL_RADIUS:
        return "radius"
    if channel == CHANNEL_TEXT:
        return "text"
    if channel == CHANNEL_TOOLTIP:
        return "tooltip"
    if channel == CHANNEL_HREF:
        return "href"
    if channel == CHANNEL_ORDER:
        return "order"
    if channel == CHANNEL_DETAIL:
        return "detail"
    if channel == CHANNEL_KEY:
        return "key"
    if channel == CHANNEL_ROW:
        return "row"
    if channel == CHANNEL_COLUMN:
        return "column"
    if channel == CHANNEL_FACET:
        return "facet"
    return "unknown"


def data_type_name(data_type: Int) -> String:
    if data_type == TYPE_TEMPORAL:
        return "temporal"
    if data_type == TYPE_NOMINAL:
        return "nominal"
    if data_type == TYPE_ORDINAL:
        return "ordinal"
    if data_type == TYPE_BOOL:
        return "boolean"
    return "quantitative"


def scale_kind_name(kind: Int) -> String:
    if kind == SCALE_LOG:
        return "log"
    if kind == SCALE_POWER:
        return "power"
    if kind == SCALE_SQRT:
        return "sqrt"
    if kind == SCALE_TEMPORAL:
        return "temporal"
    if kind == SCALE_ORDINAL:
        return "ordinal"
    if kind == SCALE_BAND:
        return "band"
    if kind == SCALE_SYMLOG:
        return "symlog"
    if kind == SCALE_POINT:
        return "point"
    if kind == SCALE_THRESHOLD:
        return "threshold"
    if kind == SCALE_QUANTILE:
        return "quantile"
    if kind == SCALE_QUANTIZE:
        return "quantize"
    if kind == SCALE_SEQUENTIAL:
        return "sequential"
    if kind == SCALE_DIVERGING:
        return "diverging"
    if kind == SCALE_CATEGORICAL:
        return "categorical"
    return "linear"


def transform_name(kind: Int) -> String:
    if kind == TRANSFORM_FILTER_BETWEEN:
        return "filter_between"
    if kind == TRANSFORM_SORT:
        return "sort"
    if kind == TRANSFORM_LIMIT:
        return "limit"
    if kind == TRANSFORM_CALCULATE:
        return "calculate"
    if kind == TRANSFORM_BIN:
        return "bin"
    if kind == TRANSFORM_ROLLING_MEAN:
        return "rolling_mean"
    if kind == TRANSFORM_IMPUTE:
        return "impute"
    if kind == TRANSFORM_SAMPLE:
        return "sample"
    if kind == TRANSFORM_STACK:
        return "stack"
    if kind == TRANSFORM_AGGREGATE:
        return "aggregate"
    if kind == TRANSFORM_GROUP:
        return "group"
    if kind == TRANSFORM_HISTOGRAM:
        return "histogram"
    if kind == TRANSFORM_DENSITY:
        return "density"
    if kind == TRANSFORM_ECDF:
        return "ecdf"
    if kind == TRANSFORM_BOX:
        return "box"
    if kind == TRANSFORM_HEATMAP:
        return "heatmap"
    if kind == TRANSFORM_HEXBIN:
        return "hexbin"
    if kind == TRANSFORM_REGRESSION:
        return "regression"
    return "filter_greater"


def composition_name(kind: Int) -> String:
    if kind == COMPOSITION_HORIZONTAL:
        return "horizontal"
    if kind == COMPOSITION_VERTICAL:
        return "vertical"
    if kind == COMPOSITION_FACET:
        return "facet"
    return "layer"


def interaction_name(kind: Int) -> String:
    if kind == INTERACTION_BRUSH:
        return "brush"
    if kind == INTERACTION_PAN_ZOOM:
        return "pan_zoom"
    if kind == INTERACTION_CLICK_SELECT:
        return "click_select"
    if kind == INTERACTION_KEYBOARD:
        return "keyboard"
    if kind == INTERACTION_LASSO:
        return "lasso"
    return "hover"


def _valid_channel(channel: Int) -> Bool:
    return channel >= CHANNEL_X and channel <= CHANNEL_FACET


def _valid_data_type(data_type: Int) -> Bool:
    return data_type >= TYPE_QUANTITATIVE and data_type <= TYPE_BOOL


def _valid_mark(mark: Int) -> Bool:
    return mark >= PLOT_LINE and mark <= PLOT_CATALOG_LAST


def _valid_scale(kind: Int) -> Bool:
    return kind >= SCALE_LINEAR and kind <= SCALE_CATEGORICAL


def _valid_transform(kind: Int) -> Bool:
    return kind >= TRANSFORM_FILTER_GREATER and kind <= TRANSFORM_REGRESSION


def _mark_from_name(name: String) -> Int:
    if name == "line":
        return PLOT_LINE
    if name == "scatter":
        return PLOT_SCATTER
    if name == "bar":
        return PLOT_BAR
    if name == "dot":
        return PLOT_DOT
    if name == "area":
        return PLOT_AREA
    if name == "rule":
        return PLOT_RULE
    if name == "error_bar":
        return PLOT_ERROR_BAR
    if name == "rect":
        return PLOT_RECT
    if name == "text":
        return PLOT_TEXT
    if name == "step":
        return PLOT_STEP
    if name == "tick":
        return PLOT_TICK
    if name == "interval":
        return PLOT_INTERVAL
    if name == "bubble":
        return PLOT_BUBBLE
    if name == "band":
        return PLOT_BAND
    if name == "column":
        return PLOT_COLUMN
    if name == "histogram":
        return PLOT_HISTOGRAM
    if name == "density":
        return PLOT_DENSITY
    if name == "ecdf":
        return PLOT_ECDF
    if name == "box":
        return PLOT_BOX
    if name == "heatmap":
        return PLOT_HEATMAP
    if name == "hexbin":
        return PLOT_HEXBIN
    if name == "regression":
        return PLOT_REGRESSION
    if name == "grouped_bar":
        return PLOT_GROUPED_BAR
    if name == "stacked_bar":
        return PLOT_STACKED_BAR
    if name == "pie":
        return PLOT_PIE
    if name == "donut":
        return PLOT_DONUT
    if name == "lollipop":
        return PLOT_LOLLIPOP
    if name == "waterfall":
        return PLOT_WATERFALL
    if name == "candlestick":
        return PLOT_CANDLESTICK
    if name == "bullet":
        return PLOT_BULLET
    if name == "gantt":
        return PLOT_GANTT
    if name == "span_chart":
        return PLOT_SPAN_CHART
    if name == "beeswarm":
        return PLOT_BEESWARM
    if name == "violin":
        return PLOT_VIOLIN
    if name == "ridgeline":
        return PLOT_RIDGELINE
    if name == "nightingale":
        return PLOT_NIGHTINGALE
    if name == "polar":
        return PLOT_POLAR
    if name == "polar_bar":
        return PLOT_POLAR_BAR
    if name == "radialbar":
        return PLOT_RADIALBAR
    if name == "gauge":
        return PLOT_GAUGE
    if name == "radar":
        return PLOT_RADAR
    if name == "population_pyramid":
        return PLOT_POPULATION_PYRAMID
    if name == "parallel":
        return PLOT_PARALLEL
    if name == "contour":
        return PLOT_CONTOUR
    if name == "contourf":
        return PLOT_CONTOURF
    if name == "tricontour":
        return PLOT_TRICONTOUR
    if name == "corrplot":
        return PLOT_CORRPLOT
    if name == "calendar_heatmap":
        return PLOT_CALENDAR_HEATMAP
    if name == "punchcard":
        return PLOT_PUNCHCARD
    if name == "marimekko":
        return PLOT_MARIMEKKO
    if name == "funnel":
        return PLOT_FUNNEL
    if name == "bump":
        return PLOT_BUMP
    if name == "effect_scatter":
        return PLOT_EFFECT_SCATTER
    if name == "arc_diagram":
        return PLOT_ARC_DIAGRAM
    if name == "graph":
        return PLOT_GRAPH
    if name == "sankey":
        return PLOT_SANKEY
    if name == "sunburst":
        return PLOT_SUNBURST
    if name == "tree":
        return PLOT_TREE
    if name == "treemap":
        return PLOT_TREEMAP
    if name == "barbs":
        return PLOT_BARBS
    if name == "chord":
        return PLOT_CHORD
    if name == "streamgraph":
        return PLOT_STREAMGRAPH
    return 0


def _channel_from_name(name: String) -> Int:
    if name == "x":
        return CHANNEL_X
    if name == "y":
        return CHANNEL_Y
    if name == "x2":
        return CHANNEL_X2
    if name == "y2":
        return CHANNEL_Y2
    if name == "color":
        return CHANNEL_COLOR
    if name == "fill":
        return CHANNEL_FILL
    if name == "stroke":
        return CHANNEL_STROKE
    if name == "opacity":
        return CHANNEL_OPACITY
    if name == "size":
        return CHANNEL_SIZE
    if name == "shape":
        return CHANNEL_SHAPE
    if name == "angle":
        return CHANNEL_ANGLE
    if name == "radius":
        return CHANNEL_RADIUS
    if name == "text":
        return CHANNEL_TEXT
    if name == "tooltip":
        return CHANNEL_TOOLTIP
    if name == "href":
        return CHANNEL_HREF
    if name == "order":
        return CHANNEL_ORDER
    if name == "detail":
        return CHANNEL_DETAIL
    if name == "key":
        return CHANNEL_KEY
    if name == "row":
        return CHANNEL_ROW
    if name == "column":
        return CHANNEL_COLUMN
    if name == "facet":
        return CHANNEL_FACET
    return 0


def _data_type_from_name(name: String) -> Int:
    if name == "temporal":
        return TYPE_TEMPORAL
    if name == "nominal":
        return TYPE_NOMINAL
    if name == "ordinal":
        return TYPE_ORDINAL
    if name == "boolean":
        return TYPE_BOOL
    if name == "quantitative":
        return TYPE_QUANTITATIVE
    return 0


def _scale_from_name(name: String) -> Int:
    if name == "log":
        return SCALE_LOG
    if name == "power":
        return SCALE_POWER
    if name == "sqrt":
        return SCALE_SQRT
    if name == "temporal":
        return SCALE_TEMPORAL
    if name == "ordinal":
        return SCALE_ORDINAL
    if name == "band":
        return SCALE_BAND
    if name == "symlog":
        return SCALE_SYMLOG
    if name == "point":
        return SCALE_POINT
    if name == "threshold":
        return SCALE_THRESHOLD
    if name == "quantile":
        return SCALE_QUANTILE
    if name == "quantize":
        return SCALE_QUANTIZE
    if name == "sequential":
        return SCALE_SEQUENTIAL
    if name == "diverging":
        return SCALE_DIVERGING
    if name == "categorical":
        return SCALE_CATEGORICAL
    if name == "linear":
        return SCALE_LINEAR
    return 0


def _composition_from_name(name: String) -> Int:
    if name == "horizontal":
        return COMPOSITION_HORIZONTAL
    if name == "vertical":
        return COMPOSITION_VERTICAL
    if name == "facet":
        return COMPOSITION_FACET
    if name == "layer":
        return COMPOSITION_LAYER
    return 0


def _interaction_from_name(name: String) -> Int:
    if name == "brush":
        return INTERACTION_BRUSH
    if name == "pan_zoom":
        return INTERACTION_PAN_ZOOM
    if name == "click_select":
        return INTERACTION_CLICK_SELECT
    if name == "keyboard":
        return INTERACTION_KEYBOARD
    if name == "lasso":
        return INTERACTION_LASSO
    if name == "hover":
        return INTERACTION_HOVER
    return 0


def _transform_from_name(name: String) -> Int:
    if name == "filter_between":
        return TRANSFORM_FILTER_BETWEEN
    if name == "sort":
        return TRANSFORM_SORT
    if name == "limit":
        return TRANSFORM_LIMIT
    if name == "calculate":
        return TRANSFORM_CALCULATE
    if name == "bin":
        return TRANSFORM_BIN
    if name == "rolling_mean":
        return TRANSFORM_ROLLING_MEAN
    if name == "impute":
        return TRANSFORM_IMPUTE
    if name == "sample":
        return TRANSFORM_SAMPLE
    if name == "stack":
        return TRANSFORM_STACK
    if name == "aggregate":
        return TRANSFORM_AGGREGATE
    if name == "group":
        return TRANSFORM_GROUP
    if name == "histogram":
        return TRANSFORM_HISTOGRAM
    if name == "density":
        return TRANSFORM_DENSITY
    if name == "ecdf":
        return TRANSFORM_ECDF
    if name == "box":
        return TRANSFORM_BOX
    if name == "heatmap":
        return TRANSFORM_HEATMAP
    if name == "hexbin":
        return TRANSFORM_HEXBIN
    if name == "regression":
        return TRANSFORM_REGRESSION
    if name == "filter_greater":
        return TRANSFORM_FILTER_GREATER
    return 0


def plot_mark_name(mark: Int) -> String:
    if mark == PLOT_SCATTER:
        return "scatter"
    if mark == PLOT_BAR:
        return "bar"
    if mark == PLOT_DOT:
        return "dot"
    if mark == PLOT_AREA:
        return "area"
    if mark == PLOT_RULE:
        return "rule"
    if mark == PLOT_ERROR_BAR:
        return "error_bar"
    if mark == PLOT_RECT:
        return "rect"
    if mark == PLOT_TEXT:
        return "text"
    if mark == PLOT_STEP:
        return "step"
    if mark == PLOT_TICK:
        return "tick"
    if mark == PLOT_INTERVAL:
        return "interval"
    if mark == PLOT_BUBBLE:
        return "bubble"
    if mark == PLOT_BAND:
        return "band"
    if mark == PLOT_COLUMN:
        return "column"
    if mark == PLOT_HISTOGRAM:
        return "histogram"
    if mark == PLOT_DENSITY:
        return "density"
    if mark == PLOT_ECDF:
        return "ecdf"
    if mark == PLOT_BOX:
        return "box"
    if mark == PLOT_HEATMAP:
        return "heatmap"
    if mark == PLOT_HEXBIN:
        return "hexbin"
    if mark == PLOT_REGRESSION:
        return "regression"
    if mark == PLOT_GROUPED_BAR:
        return "grouped_bar"
    if mark == PLOT_STACKED_BAR:
        return "stacked_bar"
    if mark == PLOT_PIE:
        return "pie"
    if mark == PLOT_DONUT:
        return "donut"
    if mark == PLOT_LOLLIPOP:
        return "lollipop"
    if mark == PLOT_WATERFALL:
        return "waterfall"
    if mark == PLOT_CANDLESTICK:
        return "candlestick"
    if mark == PLOT_BULLET:
        return "bullet"
    if mark == PLOT_GANTT:
        return "gantt"
    if mark == PLOT_SPAN_CHART:
        return "span_chart"
    if mark == PLOT_BEESWARM:
        return "beeswarm"
    if mark == PLOT_VIOLIN:
        return "violin"
    if mark == PLOT_RIDGELINE:
        return "ridgeline"
    if mark == PLOT_NIGHTINGALE:
        return "nightingale"
    if mark == PLOT_POLAR:
        return "polar"
    if mark == PLOT_POLAR_BAR:
        return "polar_bar"
    if mark == PLOT_RADIALBAR:
        return "radialbar"
    if mark == PLOT_GAUGE:
        return "gauge"
    if mark == PLOT_RADAR:
        return "radar"
    if mark == PLOT_POPULATION_PYRAMID:
        return "population_pyramid"
    if mark == PLOT_PARALLEL:
        return "parallel"
    if mark == PLOT_CONTOUR:
        return "contour"
    if mark == PLOT_CONTOURF:
        return "contourf"
    if mark == PLOT_TRICONTOUR:
        return "tricontour"
    if mark == PLOT_CORRPLOT:
        return "corrplot"
    if mark == PLOT_CALENDAR_HEATMAP:
        return "calendar_heatmap"
    if mark == PLOT_PUNCHCARD:
        return "punchcard"
    if mark == PLOT_MARIMEKKO:
        return "marimekko"
    if mark == PLOT_FUNNEL:
        return "funnel"
    if mark == PLOT_BUMP:
        return "bump"
    if mark == PLOT_EFFECT_SCATTER:
        return "effect_scatter"
    if mark == PLOT_ARC_DIAGRAM:
        return "arc_diagram"
    if mark == PLOT_GRAPH:
        return "graph"
    if mark == PLOT_SANKEY:
        return "sankey"
    if mark == PLOT_SUNBURST:
        return "sunburst"
    if mark == PLOT_TREE:
        return "tree"
    if mark == PLOT_TREEMAP:
        return "treemap"
    if mark == PLOT_BARBS:
        return "barbs"
    if mark == PLOT_CHORD:
        return "chord"
    if mark == PLOT_STREAMGRAPH:
        return "streamgraph"
    return "line"


