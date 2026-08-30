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
from .scene import Scene
from .style import Color


struct PlotRuntime:
    """Own viewport, hover, selection, and pointer-pan state for one plot."""

    var plot: Plot
    var hovered: PlotHit
    var selected: PlotHit
    var dragging: Bool
    var brushing: Bool
    var brush_additive: Bool
    var last_pointer: Point
    var brush_origin: Point
    var brush_current: Point
    var show_crosshair: Bool
    var show_tooltip: Bool
    var selected_hits: List[PlotHit]

    def __init__(out self, bounds: Rect):
        self.plot = Plot(bounds)
        self.hovered = PlotHit()
        self.selected = PlotHit()
        self.dragging = False
        self.brushing = False
        self.brush_additive = False
        self.last_pointer = Point(0.0, 0.0)
        self.brush_origin = Point(0.0, 0.0)
        self.brush_current = Point(0.0, 0.0)
        self.show_crosshair = True
        self.show_tooltip = True
        self.selected_hits = List[PlotHit]()

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

    def _hit_is_selected(self, hit: PlotHit) -> Bool:
        if not hit.found():
            return False
        for index in range(len(self.selected_hits)):
            var selected = self.selected_hits[index]
            if selected.series_id == hit.series_id and selected.row_key == hit.row_key:
                return True
        return False

    def _replace_selection(mut self, hit: PlotHit):
        self.selected_hits = List[PlotHit]()
        if hit.found():
            self.selected_hits.append(hit)
        self.selected = hit

    def _toggle_selection(mut self, hit: PlotHit):
        if not hit.found():
            return
        for index in range(len(self.selected_hits)):
            var selected = self.selected_hits[index]
            if selected.series_id == hit.series_id and selected.row_key == hit.row_key:
                _ = self.selected_hits.pop(index)
                if len(self.selected_hits) == 0:
                    self.selected = PlotHit()
                else:
                    self.selected = self.selected_hits[len(self.selected_hits) - 1]
                return
        self.selected_hits.append(hit)
        self.selected = hit

    def _apply_brush(mut self):
        var region = self._selection_rect()
        if not self.brush_additive:
            self.selected_hits = List[PlotHit]()
        for series_index in range(len(self.plot.series)):
            if not self.plot.series[series_index].visible:
                continue
            for point_index in range(self.plot.series[series_index].count()):
                var point = self.plot.series[series_index].points[point_index]
                var screen = self.plot.screen_point(point)
                if not region.contains(screen):
                    continue
                var hit = PlotHit()
                hit.series_id = self.plot.series[series_index].id
                hit.point_index = point_index
                hit.row_key = point.row_key
                hit.distance_squared = 0.0
                if not self._hit_is_selected(hit):
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

    def set_crosshair(mut self, enabled: Bool):
        self.show_crosshair = enabled

    def set_tooltip(mut self, enabled: Bool):
        self.show_tooltip = enabled

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
            if not self.plot.bounds.contains(event.position):
                return False
            self.brushing = (event.modifiers & MOD_SHIFT) != 0
            self.brush_additive = self.brushing and (
                (event.modifiers & MOD_COMMAND) != 0
                or (event.modifiers & MOD_CONTROL) != 0
            )
            self.dragging = not self.brushing
            self.last_pointer = event.position
            self.brush_origin = event.position
            self.brush_current = event.position
            return True
        if event.kind == POINTER_MOVE_KIND or event.kind == TOUCH_UPDATE_KIND:
            var changed = False
            if self.brushing:
                if (
                    self.brush_current.x != event.position.x
                    or self.brush_current.y != event.position.y
                ):
                    changed = True
                self.brush_current = event.position
            elif self.dragging:
                var delta = Point(
                    event.position.x - self.last_pointer.x,
                    event.position.y - self.last_pointer.y,
                )
                self.plot.pan(delta)
                self.last_pointer = event.position
                changed = True
            var next_hover = self.plot.hit_test(event.position)
            if self._hit_changed(self.hovered, next_hover):
                changed = True
            self.hovered = next_hover
            return changed
        if event.kind == POINTER_UP_KIND or event.kind == TOUCH_END_KIND:
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
            var next_selected = self.plot.hit_test(event.position)
            var before = len(self.selected_hits)
            if (event.modifiers & MOD_SHIFT) != 0:
                self._toggle_selection(next_selected)
            else:
                self._replace_selection(next_selected)
            var changed = self._hit_changed(self.selected, next_selected) or before != len(self.selected_hits)
            return changed
        if event.kind == SCROLL_KIND:
            if not self.plot.bounds.contains(event.position):
                return False
            var factor = 1.0 + event.scroll_delta.y * 0.01
            if factor < 0.1:
                factor = 0.1
            self.plot.zoom(factor, event.position)
            return True
        if event.kind == KEY_DOWN_KIND and event.key == KEY_ESCAPE:
            self.plot.reset_view()
            var changed = self.selected.found() or self.hovered.found() or len(self.selected_hits) > 0
            self.selected = PlotHit()
            self.hovered = PlotHit()
            self.selected_hits = List[PlotHit]()
            return changed or True
        if event.kind == KEY_DOWN_KIND:
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
        return scene^

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
        return snapshot^
