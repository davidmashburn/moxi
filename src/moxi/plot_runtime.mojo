"""Stateful plot interaction over the backend-neutral event vocabulary."""

from std.collections import List

from .accessibility import AccessibilitySnapshot, ROLE_LABEL, Semantics
from .event import (
    CLICK_KIND,
    KEY_DOWN_KIND,
    KEY_DOWN,
    KEY_ESCAPE,
    KEY_ENTER,
    KEY_LEFT,
    KEY_RIGHT,
    KEY_UP,
    KEY_SPACE,
    MOD_COMMAND,
    MOD_CONTROL,
    MOD_OPTION,
    MOD_SHIFT,
    POINTER_DOWN_KIND,
    POINTER_MOVE_KIND,
    POINTER_UP_KIND,
    SCROLL_KIND,
    TOUCH_BEGIN_KIND,
    TOUCH_END_KIND,
    TOUCH_UPDATE_KIND,
    Event,
)
from .geometry import Point, Rect
from .plotting import Plot, PlotHit
from .plot_render import PlotRenderPacket
from .plot_selection import PlotSelection
from .plot_spec import (
    INTERACTION_BRUSH,
    INTERACTION_CLICK_SELECT,
    INTERACTION_HOVER,
    INTERACTION_KEYBOARD,
    INTERACTION_LASSO,
    INTERACTION_PAN_ZOOM,
    PlotSpec,
)
from .scene import Scene
from .style import Color


comptime PLOT_INDEX_CELL_SIZE: Float32 = 32.0


struct PlotIndexCandidate(ImplicitlyCopyable):
    """A source point candidate returned by the screen-space index."""

    var series_index: Int
    var point_index: Int

    def __init__(out self, series_index: Int, point_index: Int):
        self.series_index = series_index
        self.point_index = point_index


struct PlotIndexCell:
    """Source references for one fixed-size screen-space bucket."""

    var series_indices: List[Int]
    var point_indices: List[Int]

    def __init__(out self):
        self.series_indices = List[Int]()
        self.point_indices = List[Int]()


struct PlotRuntime:
    """Own viewport, indexed interaction, and pointer state for one plot.

    The source plot remains authoritative.  This runtime adds retained
    screen-space state around it: a spatial index for pointer queries and a
    packet cache for frames where only hover/selection overlays changed.
    """

    var plot: Plot
    var hovered: PlotHit
    var selected: PlotHit
    var dragging: Bool
    var brushing: Bool
    var brush_additive: Bool
    var lassoing: Bool
    var lasso_additive: Bool
    var last_pointer: Point
    var brush_origin: Point
    var brush_current: Point
    var show_crosshair: Bool
    var show_tooltip: Bool
    var selected_hits: List[PlotHit]
    var lasso_points: List[Point]
    var linked_selection: PlotSelection
    var hover_enabled: Bool
    var brush_enabled: Bool
    var pan_zoom_enabled: Bool
    var click_select_enabled: Bool
    var keyboard_enabled: Bool
    var lasso_enabled: Bool
    var pan_x_only: Bool
    var pan_y_only: Bool
    var brush_additive_default: Bool
    var click_additive_default: Bool
    var lasso_additive_default: Bool
    var index_revision: Int
    var index_origin_x: Float32
    var index_origin_y: Float32
    var index_columns: Int
    var index_rows: Int
    var index_cells: List[PlotIndexCell]
    var index_rebuild_count: Int
    var last_query_candidate_count: Int
    var cached_packet: PlotRenderPacket
    var cached_packet_revision: Int
    var packet_cache_valid: Bool
    var packet_rebuild_count: Int

    def __init__(out self, bounds: Rect):
        self.plot = Plot(bounds)
        self.hovered = PlotHit()
        self.selected = PlotHit()
        self.dragging = False
        self.brushing = False
        self.brush_additive = False
        self.lassoing = False
        self.lasso_additive = False
        self.last_pointer = Point(0.0, 0.0)
        self.brush_origin = Point(0.0, 0.0)
        self.brush_current = Point(0.0, 0.0)
        self.show_crosshair = True
        self.show_tooltip = True
        self.selected_hits = List[PlotHit]()
        self.lasso_points = List[Point]()
        self.linked_selection = PlotSelection()
        # Direct PlotRuntime users retain the original permissive behavior.
        # PlotView calls configure(spec) to opt into declarative gating.
        self.hover_enabled = True
        self.brush_enabled = True
        self.pan_zoom_enabled = True
        self.click_select_enabled = True
        self.keyboard_enabled = True
        self.lasso_enabled = True
        self.pan_x_only = False
        self.pan_y_only = False
        self.brush_additive_default = False
        self.click_additive_default = True
        self.lasso_additive_default = False
        self.index_revision = -1
        self.index_origin_x = 0.0
        self.index_origin_y = 0.0
        self.index_columns = 0
        self.index_rows = 0
        self.index_cells = List[PlotIndexCell]()
        self.index_rebuild_count = 0
        self.last_query_candidate_count = 0
        self.cached_packet = PlotRenderPacket(
            bounds,
            self.plot.plot_area,
        )
        self.cached_packet_revision = -1
        self.packet_cache_valid = False
        self.packet_rebuild_count = 0

    def configure(mut self, spec: PlotSpec):
        """Apply declarative interaction tools to this runtime.

        A spec with no interactions is intentionally inert.  This makes the
        serialized grammar an actual behavior contract while the lower-level
        PlotRuntime constructor remains convenient for imperative callers.
        """
        self.hover_enabled = False
        self.brush_enabled = False
        self.pan_zoom_enabled = False
        self.click_select_enabled = False
        self.keyboard_enabled = False
        self.lasso_enabled = False
        self.pan_x_only = False
        self.pan_y_only = False
        self.brush_additive_default = False
        self.click_additive_default = True
        self.lasso_additive_default = False
        self.show_crosshair = False
        self.show_tooltip = False
        for index in range(spec.interaction_count()):
            var interaction = spec.interaction(index)
            if interaction.kind == INTERACTION_HOVER:
                self.hover_enabled = True
                self.show_crosshair = interaction.crosshair
                self.show_tooltip = interaction.tooltip
            elif interaction.kind == INTERACTION_BRUSH:
                self.brush_enabled = True
                self.brush_additive_default = interaction.additive
            elif interaction.kind == INTERACTION_PAN_ZOOM:
                self.pan_zoom_enabled = True
                self.pan_x_only = interaction.x_only
                self.pan_y_only = interaction.y_only
            elif interaction.kind == INTERACTION_CLICK_SELECT:
                self.click_select_enabled = True
                self.click_additive_default = interaction.additive
            elif interaction.kind == INTERACTION_KEYBOARD:
                self.keyboard_enabled = True
            elif interaction.kind == INTERACTION_LASSO:
                self.lasso_enabled = True
                self.lasso_additive_default = interaction.additive

    def _hit_changed(self, left: PlotHit, right: PlotHit) -> Bool:
        return (
            left.series_id != right.series_id
            or left.point_index != right.point_index
            or left.row_key != right.row_key
        )

    def _selection_rect(self) -> Rect:
        var left = self.brush_origin.x
        var top = self.brush_origin.y
        var right = self.brush_current.x
        var bottom = self.brush_current.y
        if right < left:
            var swap = left
            left = right
            right = swap
        if bottom < top:
            var swap = top
            top = bottom
            bottom = swap
        return Rect(left, top, right - left, bottom - top)

    def _index_column(self, x: Float32) -> Int:
        var column = Int((x - self.index_origin_x) / PLOT_INDEX_CELL_SIZE)
        if column < 0:
            column = 0
        if column >= self.index_columns:
            column = self.index_columns - 1
        return column

    def _index_row(self, y: Float32) -> Int:
        var row = Int((y - self.index_origin_y) / PLOT_INDEX_CELL_SIZE)
        if row < 0:
            row = 0
        if row >= self.index_rows:
            row = self.index_rows - 1
        return row

    def _ensure_spatial_index(mut self):
        """Build a fixed screen-space grid only after model/viewport changes."""
        var width = self.plot.plot_area.width
        var height = self.plot.plot_area.height
        if width <= 0.0:
            width = 1.0
        if height <= 0.0:
            height = 1.0
        var columns = Int(width / PLOT_INDEX_CELL_SIZE)
        if Float32(columns) * PLOT_INDEX_CELL_SIZE < width:
            columns += 1
        var rows = Int(height / PLOT_INDEX_CELL_SIZE)
        if Float32(rows) * PLOT_INDEX_CELL_SIZE < height:
            rows += 1
        if columns < 1:
            columns = 1
        if rows < 1:
            rows = 1
        if (
            self.index_revision == self.plot.revision
            and self.index_origin_x == self.plot.plot_area.x
            and self.index_origin_y == self.plot.plot_area.y
            and self.index_columns == columns
            and self.index_rows == rows
        ):
            return

        self.index_origin_x = self.plot.plot_area.x
        self.index_origin_y = self.plot.plot_area.y
        self.index_columns = columns
        self.index_rows = rows
        self.index_cells = List[PlotIndexCell](capacity=columns * rows)
        for _ in range(columns * rows):
            self.index_cells.append(PlotIndexCell())

        for series_index in range(len(self.plot.series)):
            if not self.plot.series[series_index].visible:
                continue
            for point_index in range(self.plot.series[series_index].count()):
                var point = self.plot.series[series_index].points[point_index]
                if not self.plot.point_is_renderable(point):
                    continue
                var screen = self.plot.screen_point(point)
                var cell_index = (
                    self._index_row(screen.y) * self.index_columns
                    + self._index_column(screen.x)
                )
                self.index_cells[cell_index].series_indices.append(series_index)
                self.index_cells[cell_index].point_indices.append(point_index)
        self.index_revision = self.plot.revision
        self.index_rebuild_count += 1

    def _query_rect(mut self, region: Rect) -> List[PlotIndexCandidate]:
        """Return source candidates from grid cells overlapping ``region``."""
        var result = List[PlotIndexCandidate]()
        self.last_query_candidate_count = 0
        self._ensure_spatial_index()
        if self.index_columns == 0 or self.index_rows == 0:
            return result^

        var left = region.x
        var top = region.y
        var right = region.x + region.width
        var bottom = region.y + region.height
        var plot_left = self.plot.plot_area.x
        var plot_top = self.plot.plot_area.y
        var plot_right = plot_left + self.plot.plot_area.width
        var plot_bottom = plot_top + self.plot.plot_area.height
        if left < plot_left:
            left = plot_left
        if top < plot_top:
            top = plot_top
        if right > plot_right:
            right = plot_right
        if bottom > plot_bottom:
            bottom = plot_bottom
        if right < left or bottom < top:
            return result^

        var first_column = self._index_column(left)
        var last_column = self._index_column(right)
        var first_row = self._index_row(top)
        var last_row = self._index_row(bottom)
        for row in range(first_row, last_row + 1):
            for column in range(first_column, last_column + 1):
                var cell_index = row * self.index_columns + column
                for item in range(len(self.index_cells[cell_index].point_indices)):
                    result.append(
                        PlotIndexCandidate(
                            self.index_cells[cell_index].series_indices[item],
                            self.index_cells[cell_index].point_indices[item],
                        )
                    )
        self.last_query_candidate_count = len(result)
        return result^

    def _lasso_bounds(self) -> Rect:
        if len(self.lasso_points) == 0:
            return Rect(0.0, 0.0, 0.0, 0.0)
        var left = self.lasso_points[0].x
        var right = left
        var top = self.lasso_points[0].y
        var bottom = top
        for index in range(1, len(self.lasso_points)):
            var point = self.lasso_points[index]
            if point.x < left:
                left = point.x
            if point.x > right:
                right = point.x
            if point.y < top:
                top = point.y
            if point.y > bottom:
                bottom = point.y
        return Rect(left, top, right - left, bottom - top)

    def _hit_test_index(mut self, point: Point, tolerance: Float32 = 8.0) -> PlotHit:
        """Find the nearest mark by inspecting only nearby grid cells."""
        var result = PlotHit()
        var limit = tolerance if tolerance > 0.0 else 0.0
        var limit_squared = limit * limit
        var best = limit_squared
        var candidates = self._query_rect(
            Rect(point.x - limit, point.y - limit, limit * 2.0, limit * 2.0)
        )
        for candidate_index in range(len(candidates)):
            var candidate = candidates[candidate_index]
            var source_point = self.plot.series[candidate.series_index].points[
                candidate.point_index
            ]
            if not self.plot.point_is_renderable(source_point):
                continue
            var screen = self.plot.screen_point(source_point)
            var dx = point.x - screen.x
            var dy = point.y - screen.y
            var distance = dx * dx + dy * dy
            if distance <= best:
                best = distance
                result.series_id = self.plot.series[candidate.series_index].id
                result.point_index = candidate.point_index
                result.row_key = source_point.row_key
                result.distance_squared = distance
        return result

    def hit_test(mut self, point: Point, tolerance: Float32 = 8.0) -> PlotHit:
        """Indexed nearest-point query for interactive hosts."""
        return self._hit_test_index(point, tolerance)

    def spatial_index_rebuilds(self) -> Int:
        """Return how often the retained screen-space index was rebuilt."""
        return self.index_rebuild_count

    def last_query_candidates(self) -> Int:
        """Return candidates returned by the most recent indexed query."""
        return self.last_query_candidate_count

    def _hit_is_selected(self, hit: PlotHit) -> Bool:
        return hit.found() and self.linked_selection.contains(hit.row_key)

    def _replace_selection(mut self, hit: PlotHit):
        self.selected_hits = List[PlotHit]()
        self.linked_selection.clear()
        if hit.found():
            self.selected_hits.append(hit)
            _ = self.linked_selection.add(hit.row_key)
        self.selected = hit

    def _toggle_selection(mut self, hit: PlotHit):
        if not hit.found():
            return
        for index in range(len(self.selected_hits)):
            var selected = self.selected_hits[index]
            if selected.series_id == hit.series_id and selected.row_key == hit.row_key:
                _ = self.selected_hits.pop(index)
                _ = self.linked_selection.remove(hit.row_key)
                if len(self.selected_hits) == 0:
                    self.selected = PlotHit()
                else:
                    self.selected = self.selected_hits[len(self.selected_hits) - 1]
                return
        self.selected_hits.append(hit)
        _ = self.linked_selection.add(hit.row_key)
        self.selected = hit

    def _apply_brush(mut self):
        var region = self._selection_rect()
        if not self.brush_additive:
            self.selected_hits = List[PlotHit]()
            self.linked_selection.clear()
        var candidates = self._query_rect(region)
        for candidate_index in range(len(candidates)):
            var candidate = candidates[candidate_index]
            var point = self.plot.series[candidate.series_index].points[
                candidate.point_index
            ]
            var screen = self.plot.screen_point(point)
            if not region.contains(screen):
                continue
            var hit = PlotHit()
            hit.series_id = self.plot.series[candidate.series_index].id
            hit.point_index = candidate.point_index
            hit.row_key = point.row_key
            hit.distance_squared = 0.0
            if not self._hit_is_selected(hit):
                self.selected_hits.append(hit)
                _ = self.linked_selection.add(hit.row_key)
        if len(self.selected_hits) > 0:
            self.selected = self.selected_hits[len(self.selected_hits) - 1]
        else:
            self.selected = PlotHit()

    def _point_in_lasso(self, target: Point) -> Bool:
        """Use an even-odd winding test for a closed pointer polygon."""
        if len(self.lasso_points) < 3:
            return False
        var inside = False
        var previous = len(self.lasso_points) - 1
        for current in range(len(self.lasso_points)):
            var first = self.lasso_points[current]
            var second = self.lasso_points[previous]
            if first.y != second.y:
                var crosses = (first.y > target.y) != (second.y > target.y)
                if crosses:
                    var x_at_y = (
                        (second.x - first.x) * (target.y - first.y)
                        / (second.y - first.y)
                        + first.x
                    )
                    if target.x < x_at_y:
                        inside = not inside
            previous = current
        return inside

    def _apply_lasso(mut self):
        if not self.lasso_additive:
            self.selected_hits = List[PlotHit]()
            self.linked_selection.clear()
        var candidates = self._query_rect(self._lasso_bounds())
        for candidate_index in range(len(candidates)):
            var candidate = candidates[candidate_index]
            var point = self.plot.series[candidate.series_index].points[
                candidate.point_index
            ]
            if not self._point_in_lasso(self.plot.screen_point(point)):
                continue
            var hit = PlotHit()
            hit.series_id = self.plot.series[candidate.series_index].id
            hit.point_index = candidate.point_index
            hit.row_key = point.row_key
            if not self._hit_is_selected(hit):
                self.selected_hits.append(hit)
                _ = self.linked_selection.add(hit.row_key)
        if len(self.selected_hits) > 0:
            self.selected = self.selected_hits[len(self.selected_hits) - 1]
        else:
            self.selected = PlotHit()

    def _sync_linked_selection(mut self):
        self.linked_selection.clear()
        for index in range(len(self.selected_hits)):
            _ = self.linked_selection.add(self.selected_hits[index].row_key)

    def selection(self) -> PlotSelection:
        """Return the current stable-key selection for a linked view."""
        return self.linked_selection.clone()

    def set_linked_selection(mut self, selection: PlotSelection):
        """Project an external selection onto every matching local mark."""
        self.linked_selection = selection.clone()
        self.selected_hits = List[PlotHit]()
        for series_index in range(len(self.plot.series)):
            if not self.plot.series[series_index].visible:
                continue
            for point_index in range(self.plot.series[series_index].count()):
                var point = self.plot.series[series_index].points[point_index]
                if not selection.contains(point.row_key):
                    continue
                var hit = PlotHit()
                hit.series_id = self.plot.series[series_index].id
                hit.point_index = point_index
                hit.row_key = point.row_key
                hit.distance_squared = 0.0
                self.selected_hits.append(hit)
        if len(self.selected_hits) > 0:
            self.selected = self.selected_hits[len(self.selected_hits) - 1]
        else:
            self.selected = PlotHit()

    def _focus_first(mut self) -> Bool:
        for series_index in range(len(self.plot.series)):
            if not self.plot.series[series_index].visible:
                continue
            if self.plot.series[series_index].count() == 0:
                continue
            var hit = PlotHit()
            hit.series_id = self.plot.series[series_index].id
            hit.point_index = 0
            hit.row_key = self.plot.series[series_index].points[0].row_key
            self.hovered = hit
            return True
        return False

    def _move_focus(mut self, key: Int) -> Bool:
        if not self.hovered.found() and not self._focus_first():
            return False
        var series_index = self.plot.series_index(self.hovered.series_id)
        if series_index == -1:
            return False
        var next_series = series_index
        var next_point = self.hovered.point_index
        if key == KEY_LEFT:
            next_point -= 1
        elif key == KEY_RIGHT:
            next_point += 1
        elif key == KEY_UP:
            next_series -= 1
        elif key == KEY_DOWN:
            next_series += 1
        else:
            return False
        while next_series >= 0 and next_series < len(self.plot.series):
            if self.plot.series[next_series].visible and self.plot.series[next_series].count() > 0:
                if next_point < 0:
                    next_point = 0
                if next_point >= self.plot.series[next_series].count():
                    next_point = self.plot.series[next_series].count() - 1
                var hit = PlotHit()
                hit.series_id = self.plot.series[next_series].id
                hit.point_index = next_point
                hit.row_key = self.plot.series[next_series].points[next_point].row_key
                self.hovered = hit
                return True
            if key == KEY_UP:
                next_series -= 1
            elif key == KEY_DOWN:
                next_series += 1
            else:
                return False
        return False

    def selected_count(self) -> Int:
        """Return the number of stable data items in the current selection."""
        return len(self.selected_hits)

    def clear_selection(mut self):
        """Clear persistent selection without changing the viewport."""
        self.selected_hits = List[PlotHit]()
        self.selected = PlotHit()
        self.linked_selection.clear()

    def set_crosshair(mut self, enabled: Bool):
        self.show_crosshair = enabled

    def set_tooltip(mut self, enabled: Bool):
        self.show_tooltip = enabled

    def _has_pointer_gesture(self) -> Bool:
        return self.brush_enabled or self.pan_zoom_enabled or self.lasso_enabled

    def zoom_to_selection(mut self) -> Bool:
        """Fit both axes to the selected stable rows, if any are selected."""
        if len(self.selected_hits) == 0:
            return False
        var found = False
        var minimum_x: Float32 = 0.0
        var maximum_x: Float32 = 0.0
        var minimum_y: Float32 = 0.0
        var maximum_y: Float32 = 0.0
        for index in range(len(self.selected_hits)):
            var hit = self.selected_hits[index]
            var series_index = self.plot.series_index(hit.series_id)
            if series_index == -1 or hit.point_index < 0 or hit.point_index >= self.plot.series[series_index].count():
                continue
            var point = self.plot.series[series_index].points[hit.point_index]
            if not found:
                minimum_x = point.x
                maximum_x = point.x
                minimum_y = point.y
                maximum_y = point.y
                found = True
            else:
                if point.x < minimum_x:
                    minimum_x = point.x
                if point.x > maximum_x:
                    maximum_x = point.x
                if point.y < minimum_y:
                    minimum_y = point.y
                if point.y > maximum_y:
                    maximum_y = point.y
        if not found:
            return False
        self.plot.set_x_domain(minimum_x, maximum_x)
        self.plot.set_y_domain(minimum_y, maximum_y)
        return True

    def dispatch(mut self, event: Event) -> Bool:
        """Apply one pointer/scroll/key event and report visible state change."""
        if event.kind == POINTER_DOWN_KIND or event.kind == TOUCH_BEGIN_KIND:
            if not self.plot.bounds.contains(event.position) or not self._has_pointer_gesture():
                return False
            self.lassoing = self.lasso_enabled and (
                (event.modifiers & MOD_OPTION) != 0
            )
            self.lasso_additive = self.lassoing and (
                self.lasso_additive_default
                or
                (event.modifiers & MOD_COMMAND) != 0
                or (event.modifiers & MOD_CONTROL) != 0
            )
            self.lasso_points = List[Point]()
            if self.lassoing:
                self.lasso_points.append(event.position)
            self.brushing = self.brush_enabled and (
                (event.modifiers & MOD_SHIFT) != 0
            ) and not self.lassoing
            self.brush_additive = self.brushing and (
                self.brush_additive_default
                or
                (event.modifiers & MOD_COMMAND) != 0
                or (event.modifiers & MOD_CONTROL) != 0
            )
            self.dragging = self.pan_zoom_enabled and not self.brushing and not self.lassoing
            self.last_pointer = event.position
            self.brush_origin = event.position
            self.brush_current = event.position
            return self.brushing or self.lassoing or self.dragging
        if event.kind == POINTER_MOVE_KIND or event.kind == TOUCH_UPDATE_KIND:
            var changed = False
            if self.brushing:
                if (
                    self.brush_current.x != event.position.x
                    or self.brush_current.y != event.position.y
                ):
                    changed = True
                self.brush_current = event.position
            elif self.lassoing:
                self.lasso_points.append(event.position)
                changed = True
            elif self.dragging:
                var delta = Point(
                    event.position.x - self.last_pointer.x,
                    event.position.y - self.last_pointer.y,
                )
                if self.pan_x_only:
                    delta.y = 0.0
                if self.pan_y_only:
                    delta.x = 0.0
                self.plot.pan(delta)
                self.last_pointer = event.position
                changed = True
            var next_hover = self.hovered
            if self.brushing or self.lassoing or self.dragging:
                next_hover = PlotHit()
            elif self.hover_enabled and self.plot.bounds.contains(event.position):
                next_hover = self._hit_test_index(event.position)
            elif not self.hover_enabled:
                next_hover = PlotHit()
            if self._hit_changed(self.hovered, next_hover):
                changed = True
            self.hovered = next_hover
            return changed
        if event.kind == POINTER_UP_KIND or event.kind == TOUCH_END_KIND:
            if self.lassoing:
                self.lasso_points.append(event.position)
                self._apply_lasso()
                self.lassoing = False
                self.dragging = False
                return True
            if self.brushing:
                self.brush_current = event.position
                self._apply_brush()
                self.brushing = False
                self.dragging = False
                return True
            if not self.dragging:
                return False
            self.dragging = False
            return True
        if event.kind == CLICK_KIND:
            # App synthesizes a click from an in-bounds pointer release after
            # its generic control activation pass. Finish an active plot
            # gesture before treating that release as a point click.
            if self.lassoing:
                self.lasso_points.append(event.position)
                self._apply_lasso()
                self.lassoing = False
                self.dragging = False
                return True
            if self.brushing:
                self.brush_current = event.position
                self._apply_brush()
                self.brushing = False
                self.dragging = False
                return True
            if self.dragging:
                self.dragging = False
                return True
            if not self.click_select_enabled:
                return False
            var previous_selected = self.selected
            var next_selected = self._hit_test_index(event.position)
            var before = len(self.selected_hits)
            if self.click_additive_default and (event.modifiers & MOD_SHIFT) != 0:
                self._toggle_selection(next_selected)
            else:
                self._replace_selection(next_selected)
            var changed = self._hit_changed(previous_selected, next_selected) or before != len(self.selected_hits)
            return changed
        if event.kind == SCROLL_KIND:
            if not self.pan_zoom_enabled or not self.plot.bounds.contains(event.position):
                return False
            var factor = 1.0 + event.scroll_delta.y * 0.01
            if factor < 0.1:
                factor = 0.1
            self.plot.zoom(factor, event.position)
            return True
        if event.kind == KEY_DOWN_KIND and event.key == KEY_ESCAPE:
            if not self.keyboard_enabled:
                return False
            self.plot.reset_view()
            var changed = self.selected.found() or self.hovered.found() or len(self.selected_hits) > 0
            self.selected = PlotHit()
            self.hovered = PlotHit()
            self.selected_hits = List[PlotHit]()
            self.linked_selection.clear()
            return changed or True
        if event.kind == KEY_DOWN_KIND:
            if not self.keyboard_enabled:
                return False
            if event.key == KEY_LEFT or event.key == KEY_RIGHT or event.key == KEY_UP or event.key == KEY_DOWN:
                return self._move_focus(event.key)
            if event.key == KEY_ENTER:
                var next_selected = self.hovered
                var changed = self._hit_changed(self.selected, next_selected) or len(self.selected_hits) != 1
                self._replace_selection(next_selected)
                return changed
            if event.key == KEY_SPACE:
                var before = len(self.selected_hits)
                var focus_hit = self.hovered
                self._toggle_selection(focus_hit)
                return before != len(self.selected_hits)
        return False

    def build_scene(self) -> Scene:
        var scene = self.plot.build_scene()
        # Selected points are drawn after the plot so the state remains visible
        # even when a dense layer has painted over the original marker.
        for selection_index in range(len(self.selected_hits)):
            var selected_hit = self.selected_hits[selection_index]
            var selected_series_index = self.plot.series_index(selected_hit.series_id)
            if selected_series_index != -1 and selected_hit.point_index >= 0 and selected_hit.point_index < self.plot.series[selected_series_index].count():
                var selected_point = self.plot.series[selected_series_index].points[selected_hit.point_index]
                var selected_position = self.plot.screen_point(selected_point)
                scene.append_rounded_rect(
                    910000 + selection_index,
                    Rect(selected_position.x - 7.0, selected_position.y - 7.0, 14.0, 14.0),
                    Color(1.0, 0.8, 0.25, 0.95),
                    7.0,
                )
        if self.hovered.found():
            var series_index = self.plot.series_index(self.hovered.series_id)
            if series_index != -1 and self.hovered.point_index >= 0 and self.hovered.point_index < self.plot.series[series_index].count():
                var point = self.plot.series[series_index].points[self.hovered.point_index]
                var position = self.plot.screen_point(point)
                if self.show_crosshair:
                    scene.append_line(
                        900000,
                        Point(position.x, self.plot.plot_area.y),
                        Point(position.x, self.plot.plot_area.y + self.plot.plot_area.height),
                        Color(0.9, 0.95, 1.0, 0.55),
                        1.0,
                    )
                    scene.append_line(
                        900001,
                        Point(self.plot.plot_area.x, position.y),
                        Point(self.plot.plot_area.x + self.plot.plot_area.width, position.y),
                        Color(0.9, 0.95, 1.0, 0.55),
                        1.0,
                    )
                scene.append_rounded_rect(
                    900010 + self.hovered.series_id,
                    Rect(position.x - 5.0, position.y - 5.0, 10.0, 10.0),
                    Color(1.0, 1.0, 1.0, 0.9),
                    5.0,
                )
                if self.show_tooltip:
                    var tooltip = point.tooltip
                    if tooltip.count_codepoints() == 0:
                        tooltip = String(
                            self.plot.series[series_index].label,
                            "  x=",
                            point.x,
                            "  y=",
                            point.y,
                            "  key=",
                            point.row_key,
                        )
                    var tooltip_x = position.x + 10.0
                    var tooltip_y = position.y - 28.0
                    if tooltip_x + 190.0 > self.plot.bounds.x + self.plot.bounds.width:
                        tooltip_x = position.x - 200.0
                    if tooltip_y < self.plot.bounds.y:
                        tooltip_y = position.y + 10.0
                    scene.append_rounded_rect(
                        920000,
                        Rect(tooltip_x, tooltip_y, 190.0, 22.0),
                        Color(0.03, 0.04, 0.07, 0.92),
                        5.0,
                    )
                    scene.append_text(
                        920001,
                        tooltip,
                        Rect(tooltip_x + 6.0, tooltip_y + 3.0, 178.0, 16.0),
                        Color(0.95, 0.97, 1.0, 1.0),
                    )
        if self.brushing:
            var brush = self._selection_rect()
            scene.append_rect(
                930000,
                brush,
                Color(0.25, 0.65, 1.0, 0.20),
            )
        if self.lassoing and len(self.lasso_points) > 1:
            for index in range(1, len(self.lasso_points)):
                scene.append_line(
                    940000 + index,
                    self.lasso_points[index - 1],
                    self.lasso_points[index],
                    Color(0.95, 0.75, 0.30, 0.95),
                    1.5,
                )
            scene.append_line(
                940000 + len(self.lasso_points),
                self.lasso_points[len(self.lasso_points) - 1],
                self.lasso_points[0],
                Color(0.95, 0.75, 0.30, 0.95),
                1.5,
            )
        return scene^

    def _base_render_packet(mut self) -> PlotRenderPacket:
        """Return cached dense marks, rebuilding only after a plot revision."""
        if (
            not self.packet_cache_valid
            or self.cached_packet_revision != self.plot.revision
        ):
            self.cached_packet = self.plot.build_render_packet()
            self.cached_packet_revision = self.plot.revision
            self.packet_cache_valid = True
            self.packet_rebuild_count += 1
        return self.cached_packet.clone()

    def build_render_packet(mut self) -> PlotRenderPacket:
        """Build dense marks plus fast-path-safe interaction overlays."""
        var packet = self._base_render_packet()
        for selection_index in range(len(self.selected_hits)):
            var selected_hit = self.selected_hits[selection_index]
            var series_index = self.plot.series_index(selected_hit.series_id)
            if (
                series_index != -1
                and selected_hit.point_index >= 0
                and selected_hit.point_index < self.plot.series[series_index].count()
            ):
                var point = self.plot.series[series_index].points[selected_hit.point_index]
                packet.append_marker(
                    self.plot.screen_point(point),
                    14.0,
                    Color(1.0, 0.8, 0.25, 0.95),
                    1.0,
                )
        if self.hovered.found():
            var series_index = self.plot.series_index(self.hovered.series_id)
            if (
                series_index != -1
                and self.hovered.point_index >= 0
                and self.hovered.point_index < self.plot.series[series_index].count()
            ):
                var point = self.plot.series[series_index].points[self.hovered.point_index]
                var position = self.plot.screen_point(point)
                if self.show_crosshair:
                    packet.append_line(
                        Point(position.x, self.plot.plot_area.y),
                        Point(position.x, self.plot.plot_area.y + self.plot.plot_area.height),
                        Color(0.9, 0.95, 1.0, 0.55),
                        1.0,
                    )
                    packet.append_line(
                        Point(self.plot.plot_area.x, position.y),
                        Point(self.plot.plot_area.x + self.plot.plot_area.width, position.y),
                        Color(0.9, 0.95, 1.0, 0.55),
                        1.0,
                    )
                packet.append_marker(
                    position,
                    10.0,
                    Color(1.0, 1.0, 1.0, 0.9),
                    1.0,
                )
        if self.brushing:
            packet.append_rect(
                self._selection_rect(),
                Color(0.25, 0.65, 1.0, 0.20),
                1.0,
            )
        if self.lassoing:
            # Lasso paths are intentionally unclipped in the Scene contract;
            # keep that behavior until packets gain an explicit scope model.
            packet.fallback_required = True
        return packet^

    def build_overlay_scene(self) -> Scene:
        """Build interaction text that is intentionally separate from marks.

        Keeping tooltips out of the dense packet prevents a transient hover
        from invalidating the cached GPU mark layer.  Hosts draw this small
        scene after the packet; lasso paths still use the full Scene fallback.
        """
        var scene = Scene()
        if not self.hovered.found() or not self.show_tooltip:
            return scene^
        var series_index = self.plot.series_index(self.hovered.series_id)
        if (
            series_index == -1
            or self.hovered.point_index < 0
            or self.hovered.point_index >= self.plot.series[series_index].count()
        ):
            return scene^
        var point = self.plot.series[series_index].points[self.hovered.point_index]
        var position = self.plot.screen_point(point)
        var tooltip = point.tooltip
        if tooltip.count_codepoints() == 0:
            tooltip = String(
                self.plot.series[series_index].label,
                "  x=",
                point.x,
                "  y=",
                point.y,
                "  key=",
                point.row_key,
            )
        var tooltip_x = position.x + 10.0
        var tooltip_y = position.y - 28.0
        if tooltip_x + 190.0 > self.plot.bounds.x + self.plot.bounds.width:
            tooltip_x = position.x - 200.0
        if tooltip_y < self.plot.bounds.y:
            tooltip_y = position.y + 10.0
        scene.append_rounded_rect(
            920000,
            Rect(tooltip_x, tooltip_y, 190.0, 22.0),
            Color(0.03, 0.04, 0.07, 0.92),
            5.0,
        )
        scene.append_text(
            920001,
            tooltip,
            Rect(tooltip_x + 6.0, tooltip_y + 3.0, 178.0, 16.0),
            Color(0.95, 0.97, 1.0, 1.0),
        )
        return scene^

    def build_chrome_scene(self) -> Scene:
        """Build plot chrome while leaving dense marks to a fast renderer."""
        return self.plot.build_scene(False)

    def packet_rebuilds(self) -> Int:
        """Return the number of dense mark packet compilations."""
        return self.packet_rebuild_count

    def accessibility(self) -> AccessibilitySnapshot:
        var snapshot = self.plot.accessibility()
        if self.hovered.found():
            var hover = Semantics(20000, ROLE_LABEL, "Hovered data point")
            hover.parent_id = 1
            hover.focused = True
            hover.value = String(
                "series=",
                self.hovered.series_id,
                ", point=",
                self.hovered.point_index,
                ", key=",
                self.hovered.row_key,
            )
            snapshot.append(hover)
        if self.selected.found():
            var selection = Semantics(20001, ROLE_LABEL, "Selected data point")
            selection.parent_id = 1
            selection.selected = True
            selection.value = String(
                "series=",
                self.selected.series_id,
                ", point=",
                self.selected.point_index,
                ", key=",
                self.selected.row_key,
                ", selected-count=",
                len(self.selected_hits),
            )
            snapshot.append(selection)
        if self.lassoing:
            var lasso = Semantics(20002, ROLE_LABEL, "Lasso selection in progress")
            lasso.parent_id = 1
            lasso.value = String("vertices=", len(self.lasso_points))
            snapshot.append(lasso)
        return snapshot^
