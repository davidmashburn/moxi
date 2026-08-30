"""Shared typed component-slot scenario used by the demo and tests."""

from .app import COUNTER_INCREMENT_ACTION, CounterState
from .component import Component, ComponentSlot
from .event import Event
from .geometry import Rect
from .layout import ALIGN_START
from .style import default_panel_style, default_surface_style
from .view import ColumnView


comptime COMPOSED_TITLE_ID = 1
comptime COMPOSED_COUNTER_SLOT_ID = 10
comptime COMPOSED_COUNTER_ID_OFFSET = 1000


struct ComposedState(Component):
    """A parent component that owns and routes to a typed counter child."""

    var counter: ComponentSlot[CounterState]

    def __init__(out self):
        self.counter = ComponentSlot(
            CounterState(),
            COMPOSED_COUNTER_SLOT_ID,
            COMPOSED_COUNTER_ID_OFFSET,
        )

    def build(self, bounds: Rect) -> ColumnView:
        var root = ColumnView(bounds, 24.0, 12.0)
        var panel_width = bounds.width - 32.0
        var panel_height = bounds.height - 32.0
        if panel_width < 0.0:
            panel_width = 0.0
        if panel_height < 0.0:
            panel_height = 0.0
        root.set_surface_style(default_surface_style())
        root.set_panel(
            0,
            Rect(bounds.x + 16.0, bounds.y + 16.0, panel_width, panel_height),
            default_panel_style(),
        )
        root.set_cross_alignment(ALIGN_START)
        root.add_label(COMPOSED_TITLE_ID, "Typed component slot", 32.0)

        var child_width = bounds.width - 64.0
        var child_height = bounds.height - 88.0
        if child_width < 0.0:
            child_width = 0.0
        if child_height < 0.0:
            child_height = 0.0
        var child_view = self.counter.build(
            Rect(bounds.x + 32.0, bounds.y + 72.0, child_width, child_height)
        )
        root.add_component_view_to(
            -1,
            COMPOSED_COUNTER_SLOT_ID,
            child_view,
            COMPOSED_COUNTER_ID_OFFSET,
        )
        root.set_action(
            COMPOSED_COUNTER_ID_OFFSET + 3,
            COUNTER_INCREMENT_ACTION,
        )
        root.layout()
        return root^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        """Give targeted events to the child while preserving parent ownership."""
        return self.counter.route(event, view)

    def clipboard_copy(mut self, target: Int, view: ColumnView) -> String:
        return self.counter.clipboard_copy(target, view)

    def clipboard_cut(mut self, target: Int, view: ColumnView) -> String:
        return self.counter.clipboard_cut(target, view)

    def clipboard_paste(
        mut self,
        target: Int,
        text: String,
        view: ColumnView,
    ) -> Bool:
        return self.counter.clipboard_paste(target, text, view)
