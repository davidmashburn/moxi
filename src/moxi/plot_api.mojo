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
    Plot,
    PlotHit,
    PlotPoint,
    PlotScale,
    PlotSeries,
)
