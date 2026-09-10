"""Composable plot view boundary for Moxi layout and event hosts."""

from moxi.accessibility import AccessibilitySnapshot
from moxi.component import Component
from moxi.column_view import ColumnView
from moxi.event import (
    CLICK_KIND,
    DRAG_BEGIN_KIND,
    DRAG_UPDATE_KIND,
    DROP_KIND,
    POINTER_CANCEL_KIND,
    POINTER_DOWN_KIND,
    POINTER_MOVE_KIND,
    POINTER_UP_KIND,
    SCROLL_KIND,
    TOUCH_BEGIN_KIND,
    TOUCH_END_KIND,
    TOUCH_UPDATE_KIND,
    Event,
)
from moxi.geometry import Rect
from .plot_data import PlotDataSnapshot, PlotDataTable
from .plot_runtime import PlotRuntime
from moxi.plot_render import PlotRenderPacket
from .plot_series import PlotHit
from .plot_spec import PlotSpec, plot_from_spec
from moxi.scene import Scene


comptime PLOT_VIEW_CANVAS_ID = 1


struct PlotView(Component):
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

    def build(self, bounds: Rect) -> ColumnView:
        """Build a canvas host so the plot can use Moxi's component runtime."""
        var root = ColumnView(bounds, 0.0, 0.0)
        root.add_canvas(PLOT_VIEW_CANVAS_ID, self.spec.title, bounds.height)
        root.layout()
        return root^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        """Dispatch through the component contract used by Moxi reactivity."""
        var canvas = view.bounds_for(PLOT_VIEW_CANVAS_ID)
        var pointer_event = (
            event.kind == CLICK_KIND
            or event.kind == POINTER_DOWN_KIND
            or event.kind == POINTER_MOVE_KIND
            or event.kind == POINTER_UP_KIND
            or event.kind == POINTER_CANCEL_KIND
            or event.kind == DRAG_BEGIN_KIND
            or event.kind == DRAG_UPDATE_KIND
            or event.kind == DROP_KIND
            or event.kind == SCROLL_KIND
            or event.kind == TOUCH_BEGIN_KIND
            or event.kind == TOUCH_UPDATE_KIND
            or event.kind == TOUCH_END_KIND
        )
        if pointer_event:
            if event.target != -1 and event.target != PLOT_VIEW_CANVAS_ID:
                return False
            if event.target == -1 and not canvas.contains(event.position):
                return False
        self.set_bounds(canvas)
        return self.dispatch(event)

    def update_retained(mut self, event: Event, view: ColumnView) -> Bool:
        """Update the scene without rebuilding its stable canvas host."""
        return self.update(event, view)

    def build_scene(self) -> Scene:
        """Build the current renderer-neutral scene."""
        return self.runtime.build_scene()

    def scene(mut self, bounds: Rect) -> Scene:
        """Update the plot viewport and return its current scene."""
        self.set_bounds(bounds)
        return self.build_scene()

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


struct PlotControl(Component):
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

    def build(self, bounds: Rect) -> ColumnView:
        return self.view.build(bounds)

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        return self.view.update(event, view)

    def update_retained(mut self, event: Event, view: ColumnView) -> Bool:
        return self.view.update_retained(event, view)

    def build_scene(self) -> Scene:
        return self.view.build_scene()

    def scene(mut self, bounds: Rect) -> Scene:
        return self.view.scene(bounds)

    def build_render_packet(mut self) -> PlotRenderPacket:
        return self.view.build_render_packet()

    def build_chrome_scene(self) -> Scene:
        return self.view.build_chrome_scene()

    def build_overlay_scene(self) -> Scene:
        return self.view.build_overlay_scene()

    def accessibility(self) -> AccessibilitySnapshot:
        return self.view.accessibility()
