"""Host-owned controls around two independent informational components."""

from moxi.app import CounterState
from moxi.component import Component, ComponentSlot
from moxi.column_view import ColumnView
from moxi.event import Event
from moxi.geometry import Rect
from moxi.not_implemented import NotImplemented
from .demo_style import _is_activation


comptime PATTERN_HOST_BUTTON_ID = 1
comptime PATTERN_REPLACE_BUTTON_ID = 2
comptime PATTERN_FIRST_SLOT_ID = 10
comptime PATTERN_SECOND_SLOT_ID = 11
comptime PATTERN_FIRST_OFFSET = 100
comptime PATTERN_SECOND_OFFSET = 200


struct NotImplementedDemo(Component):
    """Demonstrate inert content, surrounding input, and normal replacement."""

    var host_clicks: Int
    var show_implemented_counter: Bool
    var first: ComponentSlot[NotImplemented]
    var second: ComponentSlot[NotImplemented]
    var counter: ComponentSlot[CounterState]

    def __init__(out self):
        self.host_clicks = 0
        self.show_implemented_counter = False
        self.first = ComponentSlot(
            NotImplemented("Counter"), PATTERN_FIRST_SLOT_ID, PATTERN_FIRST_OFFSET,
        )
        self.second = ComponentSlot(
            NotImplemented(
                "Report export",
                "This application has no report exporter yet. You can still use the surrounding controls. Resize this window to read the explanation in a narrow panel.",
            ), PATTERN_SECOND_SLOT_ID, PATTERN_SECOND_OFFSET,
        )
        self.counter = ComponentSlot(
            CounterState(), PATTERN_FIRST_SLOT_ID, PATTERN_FIRST_OFFSET,
        )

    def build(self, bounds: Rect) -> ColumnView:
        var view = ColumnView(bounds, 16.0, 12.0)
        view.add_button(PATTERN_HOST_BUTTON_ID, "Host clicks: " + String(self.host_clicks), 40.0)
        var child_bounds = Rect(0.0, 0.0, max(bounds.width - 32.0, 0.0), 0.0)
        if self.show_implemented_counter:
            var child = self.counter.build(child_bounds)
            # Counter uses fixed control heights. Preserve its laid-out extent,
            # including bottom padding, instead of its smaller text intrinsic size.
            var last = child.child(child.child_count() - 1).bounds
            var height = last.y + last.height + child.layout_spec.padding
            view.add_component_view_to(-1, self.counter.slot_id, child, self.counter.id_offset, height)
        else:
            var child = self.first.build(child_bounds)
            view.add_component_view_to(-1, self.first.slot_id, child, self.first.id_offset)
        var second = self.second.build(child_bounds)
        view.add_component_view_to(-1, self.second.slot_id, second, self.second.id_offset)
        view.add_button(
            PATTERN_REPLACE_BUTTON_ID,
            "Restore unfinished counter" if self.show_implemented_counter else "Use implemented counter",
            40.0,
        )
        view.layout()
        return view^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        if _is_activation(event) and event.target == PATTERN_HOST_BUTTON_ID:
            self.host_clicks += 1
            return True
        if _is_activation(event) and event.target == PATTERN_REPLACE_BUTTON_ID:
            self.show_implemented_counter = not self.show_implemented_counter
            return True
        if self.show_implemented_counter:
            return self.counter.route(event, view)
        return False
