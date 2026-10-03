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
from moxi.execution import ExecutionWorkCounters, LocalizedExecution
from .plot_data import PlotDataSnapshot, PlotDataTable
from .plot_runtime import PlotRuntime
from moxi.plot_render import PlotRenderPacket
from .plot_series import PlotHit
from .plot_spec import PlotSpec, plot_from_spec
from moxi.scene import Scene


comptime PLOT_VIEW_CANVAS_ID = 1


struct PlotView(Component):
    """Compile a ``PlotSpec`` and own its interactive runtime state.

    A plot is a scene-producing child rather than a ``ColumnView`` component,
    so it cannot be put directly into ``TypedSubtreeExecutor``. It still uses
    the same localized dependency scheduler: the view owns one execution
    scope, source/spec changes enqueue a dirty token, and a host explicitly
    consumes that token with ``rebuild_if_dirty()``. The existing
    ``replace_*`` methods remain eager compatibility shims over that boundary.
    """

    var runtime: PlotRuntime
    var data: PlotDataSnapshot
    var spec: PlotSpec
    var specification_version: Int
    var execution: LocalizedExecution
    var reactive_component_id: Int
    var reactive_scope_id: Int
    var pending_data: PlotDataSnapshot
    var pending_spec: PlotSpec
    var pending_data_valid: Bool
    var pending_spec_valid: Bool

    def __init__(
        out self,
        spec: PlotSpec,
        data: PlotDataTable,
        bounds: Rect,
        component_id: Int = 0,
        scope_id: Int = 0,
    ):
        self.runtime = PlotRuntime(bounds)
        self.data = data.snapshot()
        self.spec = spec.clone()
        self.runtime.plot = plot_from_spec(self.spec, self.data.table, bounds)
        self.runtime.configure(self.spec)
        self.specification_version = spec.version
        self.execution = LocalizedExecution()
        self.reactive_component_id = component_id if component_id >= 0 else 0
        self.reactive_scope_id = scope_id if scope_id >= 0 else 0
        var empty_pending_data = PlotDataTable()
        self.pending_data = PlotDataSnapshot(empty_pending_data)
        self.pending_spec = PlotSpec()
        self.pending_data_valid = False
        self.pending_spec_valid = False
        _ = self.execution.add_scope(self.reactive_scope_id)
        _ = self.execution.add_dependency(
            self.reactive_component_id,
            self.reactive_scope_id,
        )

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
        self.execution = LocalizedExecution()
        self.reactive_component_id = copy.reactive_component_id
        self.reactive_scope_id = copy.reactive_scope_id
        var empty_pending_data = PlotDataTable()
        self.pending_data = PlotDataSnapshot(empty_pending_data)
        self.pending_spec = PlotSpec()
        self.pending_data_valid = copy.pending_data_valid
        self.pending_spec_valid = copy.pending_spec_valid
        if self.pending_data_valid:
            self.pending_data = copy.pending_data.clone()
        if self.pending_spec_valid:
            self.pending_spec = copy.pending_spec.clone()
        _ = self.execution.add_scope(self.reactive_scope_id)
        _ = self.execution.add_dependency(
            self.reactive_component_id,
            self.reactive_scope_id,
        )
        if self.pending_data_valid or self.pending_spec_valid:
            _ = self.execution.invalidate_scope(self.reactive_scope_id)

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
        """Eagerly replace the declarative source and reset plot state."""
        self._clear_pending()
        _ = self.invalidate_reactive()
        _ = self.execution.take_dirty(self.reactive_component_id)
        self._replace_compiled(spec, data)
        _ = self.execution.clear_scope(self.reactive_scope_id)

    def _replace_compiled(mut self, spec: PlotSpec, data: PlotDataTable):
        """Commit a source/spec snapshot after scheduler dirty consumption."""
        self.data = data.snapshot()
        self.spec = spec.clone()
        var bounds = self.runtime.plot.bounds
        self.runtime.plot = plot_from_spec(self.spec, self.data.table, bounds)
        self.runtime.configure(self.spec)
        self.runtime.clear_selection()
        self.runtime.hovered = PlotHit()
        self.runtime.index_revision = -1
        self.runtime.packet_cache_valid = False
        self.runtime.cached_packet_revision = -1
        self.specification_version = spec.version

    def _clear_pending(mut self):
        """Release deferred snapshots after a local commit."""
        var empty_pending_data = PlotDataTable()
        self.pending_data = PlotDataSnapshot(empty_pending_data)
        self.pending_spec = PlotSpec()
        self.pending_data_valid = False
        self.pending_spec_valid = False

    def invalidate_reactive(mut self) -> Bool:
        """Invalidate this plot's localized dependency scope."""
        return self.execution.invalidate_scope(self.reactive_scope_id)

    def reactive_dirty(self) -> Bool:
        """Return whether the plot has an unconsumed local invalidation."""
        return self.execution.component_is_dirty(self.reactive_component_id)

    def request_spec(mut self, spec: PlotSpec, data: PlotDataTable) -> Bool:
        """Queue a declarative source replacement for a later local rebuild."""
        self.pending_spec = spec.clone()
        self.pending_data = data.snapshot()
        self.pending_spec_valid = True
        self.pending_data_valid = True
        return self.invalidate_reactive()

    def request_data(mut self, data: PlotDataTable) -> Bool:
        """Queue changed data and invalidate without compiling immediately."""
        if self.data.version() == data.version and not self.pending_spec_valid:
            return False
        self.pending_data = data.snapshot()
        self.pending_data_valid = True
        return self.invalidate_reactive()

    def rebuild_if_dirty(mut self) -> Bool:
        """Consume this plot's dirty token and commit any queued snapshots."""
        if not self.execution.take_dirty(self.reactive_component_id):
            return False

        var changed = False
        if self.pending_spec_valid:
            var next_spec = self.pending_spec.clone()
            var next_data = self.pending_data.table
            self._replace_compiled(next_spec, next_data)
            changed = True
        elif self.pending_data_valid:
            if self.pending_data.version() != self.data.version():
                var next_spec = self.spec.clone()
                var next_data = self.pending_data.table
                self._replace_compiled(next_spec, next_data)
                changed = True

        self._clear_pending()
        _ = self.execution.clear_scope(self.reactive_scope_id)
        return changed

    def replace_data(mut self, data: PlotDataTable) -> Bool:
        """Eagerly commit changed data without retaining a pending copy."""
        if self.data.version() == data.version:
            return False
        self._clear_pending()
        _ = self.invalidate_reactive()
        _ = self.execution.take_dirty(self.reactive_component_id)
        var current_spec = self.spec.clone()
        self._replace_compiled(current_spec, data)
        _ = self.execution.clear_scope(self.reactive_scope_id)
        return True

    def reactive_work_counters(self) -> ExecutionWorkCounters:
        """Expose localized invalidation/build accounting for hosts and tests."""
        return self.execution.work_counters()

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

    def replace_spec(mut self, spec: PlotSpec, data: PlotDataTable):
        self.view.replace_spec(spec, data)

    def request_spec(mut self, spec: PlotSpec, data: PlotDataTable) -> Bool:
        return self.view.request_spec(spec, data)

    def replace_data(mut self, data: PlotDataTable) -> Bool:
        return self.view.replace_data(data)

    def request_data(mut self, data: PlotDataTable) -> Bool:
        return self.view.request_data(data)

    def rebuild_if_dirty(mut self) -> Bool:
        return self.view.rebuild_if_dirty()

    def reactive_dirty(self) -> Bool:
        return self.view.reactive_dirty()

    def reactive_work_counters(self) -> ExecutionWorkCounters:
        return self.view.reactive_work_counters()
