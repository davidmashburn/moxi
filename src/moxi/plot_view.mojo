"""Composable plot view boundary for Moxi layout and event hosts."""

from .accessibility import AccessibilitySnapshot
from .event import Event
from .geometry import Rect
from .plot_data import PlotDataSnapshot, PlotDataTable
from .plot_runtime import PlotRuntime
from .plot_render import PlotRenderPacket
from .plotting import PlotHit
from .plot_spec import PlotSpec, plot_from_spec
from .scene import Scene


struct PlotView:
    """Compile a ``PlotSpec`` and own its interactive runtime state."""

    var runtime: PlotRuntime
    var data: PlotDataSnapshot
    var spec: PlotSpec
    var specification_version: Int

    def __init__(
        out self,
        spec: PlotSpec,
        data: PlotDataTable,
        bounds: Rect,
    ):
        self.runtime = PlotRuntime(bounds)
        self.data = data.snapshot()
        self.spec = spec.clone()
        self.runtime.plot = plot_from_spec(spec, data, bounds)
        self.runtime.configure(self.spec)
        self.specification_version = spec.version

    def dispatch(mut self, event: Event) -> Bool:
        """Forward a backend-neutral event and report whether state changed."""
        return self.runtime.dispatch(event)

    def build_scene(self) -> Scene:
        """Build the current renderer-neutral scene."""
        return self.runtime.build_scene()

    def build_render_packet(mut self) -> PlotRenderPacket:
        """Expose the optional dense-mark packet for a capable host."""
        return self.runtime.build_render_packet()

    def build_chrome_scene(self) -> Scene:
        """Build plot chrome for hosts that draw the packet separately."""
        return self.runtime.build_chrome_scene()

    def build_overlay_scene(self) -> Scene:
        """Build transient interaction text after a packet is drawn."""
        return self.runtime.build_overlay_scene()

    def accessibility(self) -> AccessibilitySnapshot:
        """Return the current semantic plot subtree."""
        return self.runtime.accessibility()

    def set_bounds(mut self, bounds: Rect):
        self.runtime.plot.set_bounds(bounds)

    def replace_data(mut self, data: PlotDataTable):
        """Recompile the scene from a new immutable data snapshot."""
        self.data = data.snapshot()
        var bounds = self.runtime.plot.bounds
        self.runtime.plot = plot_from_spec(self.spec, data, bounds)
        self.runtime.clear_selection()
        self.runtime.hovered = PlotHit()

    def selected_count(self) -> Int:
        return self.runtime.selected_count()

    def clear_selection(mut self):
        self.runtime.clear_selection()

    def data_table_csv(self) -> String:
        """Return the source table as a non-visual accessibility fallback."""
        return self.data.table.csv()


struct PlotControl:
    """Naming-compatible control wrapper for hosts that prefer a control API."""

    var view: PlotView

    def __init__(
        out self,
        spec: PlotSpec,
        data: PlotDataTable,
        bounds: Rect,
    ):
        self.view = PlotView(spec, data, bounds)

    def dispatch(mut self, event: Event) -> Bool:
        return self.view.dispatch(event)

    def build_scene(self) -> Scene:
        return self.view.build_scene()

    def build_render_packet(mut self) -> PlotRenderPacket:
        return self.view.build_render_packet()

    def build_chrome_scene(self) -> Scene:
        return self.view.build_chrome_scene()

    def build_overlay_scene(self) -> Scene:
        return self.view.build_overlay_scene()

    def accessibility(self) -> AccessibilitySnapshot:
        return self.view.accessibility()
