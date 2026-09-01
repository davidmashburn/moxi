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


struct PlotView(ImplicitlyCopyable):
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

    def __init__(out self, *, copy: Self):
        """Copy the declarative boundary without sharing mutable buffers."""
        var bounds = copy.runtime.plot.bounds
        self.runtime = PlotRuntime(bounds)
        self.data = copy.data.clone()
        self.spec = copy.spec.clone()
        self.runtime.plot = plot_from_spec(
            self.spec,
            self.data.table,
            bounds,
        )
        self.runtime.configure(self.spec)
        self.specification_version = copy.specification_version

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
        if (
            self.runtime.plot.bounds.x == bounds.x
            and self.runtime.plot.bounds.y == bounds.y
            and self.runtime.plot.bounds.width == bounds.width
            and self.runtime.plot.bounds.height == bounds.height
        ):
            return
        self.runtime.plot.set_bounds(bounds)

    def replace_spec(mut self, spec: PlotSpec, data: PlotDataTable):
        """Replace the declarative source and reset compiled plot state."""
        self.data = data.snapshot()
        self.spec = spec.clone()
        var bounds = self.runtime.plot.bounds
        self.runtime.plot = plot_from_spec(spec, data, bounds)
        self.runtime.configure(self.spec)
        self.runtime.clear_selection()
        self.runtime.hovered = PlotHit()
        self.runtime.index_revision = -1
        self.runtime.packet_cache_valid = False
        self.runtime.cached_packet_revision = -1
        self.specification_version = spec.version

    def replace_data(mut self, data: PlotDataTable) -> Bool:
        """Recompile only when a reactive source version has changed."""
        if self.data.version() == data.version:
            return False
        var current_spec = self.spec.clone()
        self.replace_spec(current_spec, data)
        return True

    def reset_view(mut self):
        """Fit the current viewport to the current source data."""
        self.runtime.plot.reset_view()

    def clear_hover(mut self):
        """Clear transient hover state without changing selection."""
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
