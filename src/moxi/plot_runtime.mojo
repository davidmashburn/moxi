"""Stateful plot interaction over the backend-neutral event vocabulary."""

from .accessibility import AccessibilitySnapshot, ROLE_LABEL, Semantics
from .event import (
    CLICK_KIND,
    KEY_DOWN_KIND,
    KEY_ESCAPE,
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
    var last_pointer: Point

    def __init__(out self, bounds: Rect):
        self.plot = Plot(bounds)
        self.hovered = PlotHit()
        self.selected = PlotHit()
        self.dragging = False
        self.last_pointer = Point(0.0, 0.0)

    def _hit_changed(self, left: PlotHit, right: PlotHit) -> Bool:
        return (
            left.series_id != right.series_id
            or left.point_index != right.point_index
        )

    def dispatch(mut self, event: Event) -> Bool:
        """Apply one pointer/scroll/key event and report visible state change."""
        if event.kind == POINTER_DOWN_KIND or event.kind == TOUCH_BEGIN_KIND:
            if not self.plot.bounds.contains(event.position):
                return False
            self.dragging = True
            self.last_pointer = event.position
            return True
        if event.kind == POINTER_MOVE_KIND or event.kind == TOUCH_UPDATE_KIND:
            var changed = False
            if self.dragging:
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
            if not self.dragging:
                return False
            self.dragging = False
            return True
        if event.kind == CLICK_KIND:
            var next_selected = self.plot.hit_test(event.position)
            var changed = self._hit_changed(self.selected, next_selected)
            self.selected = next_selected
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
            var changed = self.selected.found() or self.hovered.found()
            self.selected = PlotHit()
            self.hovered = PlotHit()
            return changed or True
        return False

    def build_scene(self) -> Scene:
        var scene = self.plot.build_scene()
        if self.hovered.found():
            var series_index = self.plot.series_index(self.hovered.series_id)
            if series_index != -1:
                var point = self.plot.series[series_index].points[self.hovered.point_index]
                var position = self.plot.screen_point(point)
                scene.append_rounded_rect(
                    900000 + self.hovered.series_id,
                    Rect(position.x - 5.0, position.y - 5.0, 10.0, 10.0),
                    Color(1.0, 1.0, 1.0, 0.9),
                    5.0,
                )
        if self.selected.found():
            var series_index = self.plot.series_index(self.selected.series_id)
            if series_index != -1:
                var point = self.plot.series[series_index].points[self.selected.point_index]
                var position = self.plot.screen_point(point)
                scene.append_rounded_rect(
                    910000 + self.selected.series_id,
                    Rect(position.x - 7.0, position.y - 7.0, 14.0, 14.0),
                    Color(1.0, 0.8, 0.25, 0.95),
                    7.0,
                )
        return scene^

    def accessibility(self) -> AccessibilitySnapshot:
        var snapshot = self.plot.accessibility()
        if self.hovered.found():
            var hover = Semantics(20000, ROLE_LABEL, "Hovered data point")
            hover.parent_id = 1
            hover.value = String(
                "series=",
                self.hovered.series_id,
                ", point=",
                self.hovered.point_index,
            )
            snapshot.append(hover)
        if self.selected.found():
            var selection = Semantics(20001, ROLE_LABEL, "Selected data point")
            selection.parent_id = 1
            selection.value = String(
                "series=",
                self.selected.series_id,
                ", point=",
                self.selected.point_index,
            )
            snapshot.append(selection)
        return snapshot^
