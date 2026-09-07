"""Focused plotting import path.

The compatibility root still exposes legacy plotting names, but new callers
can depend on this smaller provisional surface instead of importing the whole
package boundary.
"""

from .geometry import Rect
from .plot_data import (
    COLUMN_CATEGORY,
    COLUMN_FLOAT32,
    COLUMN_FLOAT64,
    COLUMN_INT64,
    COLUMN_STRING,
    COLUMN_TIMESTAMP,
    PlotColumn,
    PlotDataSnapshot,
    PlotDataTable,
)
from .plot_link import PlotLink
from .plot_render import PlotRenderBatch, PlotRenderPacket
from .plot_runtime import PlotRuntime
from .plot_selection import PlotSelection, selection_from_keys
from .plot_spec import (
    PlotEncoding,
    PlotInteraction,
    PlotLayer,
    PlotScaleSpec,
    PlotSpec,
    PlotTransform,
    plot_from_spec,
    plot_spec_from_json,
)
from .plot_view import PlotControl, PlotView
from .plotting import (
    PLOT_AREA,
    PLOT_BAR,
    PLOT_BOX,
    PLOT_DENSITY,
    PLOT_ECDF,
    PLOT_HEATMAP,
    PLOT_LINE,
    PLOT_SCATTER,
    PLOT_GROUPED_BAR,
    PLOT_STACKED_BAR,
    PLOT_PIE,
    PLOT_DONUT,
    PLOT_LOLLIPOP,
    PLOT_WATERFALL,
    PLOT_CANDLESTICK,
    PLOT_BULLET,
    PLOT_GANTT,
    PLOT_SPAN_CHART,
    PLOT_BEESWARM,
    PLOT_VIOLIN,
    PLOT_RIDGELINE,
    PLOT_NIGHTINGALE,
    PLOT_POLAR,
    PLOT_POLAR_BAR,
    PLOT_RADIALBAR,
    PLOT_GAUGE,
    PLOT_RADAR,
    PLOT_POPULATION_PYRAMID,
    PLOT_PARALLEL,
    PLOT_CONTOUR,
    PLOT_CONTOURF,
    PLOT_TRICONTOUR,
    PLOT_CORRPLOT,
    PLOT_CALENDAR_HEATMAP,
    PLOT_PUNCHCARD,
    PLOT_MARIMEKKO,
    PLOT_FUNNEL,
    PLOT_BUMP,
    PLOT_EFFECT_SCATTER,
    PLOT_ARC_DIAGRAM,
    PLOT_GRAPH,
    PLOT_SANKEY,
    PLOT_SUNBURST,
    PLOT_TREE,
    PLOT_TREEMAP,
    PLOT_BARBS,
    PLOT_CHORD,
    PLOT_STREAMGRAPH,
    Plot,
    PlotHit,
    PlotPoint,
    PlotScale,
    PlotSeries,
)
