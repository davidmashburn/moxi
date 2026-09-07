"""Python value-boundary API for Moxi.

The package deliberately has no Mojo runtime dependency.  ``PlotSpec`` is the
same compact JSON contract emitted by the Mojo package, while ``Figure`` is a
portable reference renderer for notebooks, scripts, and export pipelines.
"""

from .figure import Figure, BackendCapabilities, plot, render
from .spec import CATALOG_MARKS, PlotSpec, PLOT_MARKS, PLOT_SPEC_VERSION

__version__ = "0.5.1"

__all__ = [
    "BackendCapabilities",
    "CATALOG_MARKS",
    "Figure",
    "PLOT_MARKS",
    "PLOT_SPEC_VERSION",
    "PlotSpec",
    "plot",
    "render",
]
