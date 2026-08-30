"""Shared row scenario used by the row demo and headless tests."""

from .component import Component
from .controls import ButtonControl
from .event import CLICK_KIND, Event
from .geometry import Rect
from .style import default_panel_style, default_surface_style
from .view import ColumnView, make_row


comptime PREVIOUS_BUTTON_ID = 1
comptime NEXT_BUTTON_ID = 3


struct RowState(Component):
    """A small horizontal action bar exercising row layout and controls."""

    var selected: Int

    def __init__(out self):
        self.selected = 0

    def build(self, bounds: Rect) -> ColumnView:
        var row = make_row(bounds, 24.0, 16.0)
        var panel_width = bounds.width - 40.0
        var panel_height = bounds.height - 40.0
        if panel_width < 0.0:
            panel_width = 0.0
        if panel_height < 0.0:
            panel_height = 0.0
        row.set_surface_style(default_surface_style())
        row.set_panel(
            0,
            Rect(bounds.x + 20.0, bounds.y + 20.0, panel_width, panel_height),
            default_panel_style(),
        )

        var previous_text = "Previous"
        if self.selected == PREVIOUS_BUTTON_ID:
            previous_text = "Selected"
        var next_text = "Next"
        if self.selected == NEXT_BUTTON_ID:
            next_text = "Selected"
        var previous = ButtonControl(PREVIOUS_BUTTON_ID, previous_text, 44.0)
        row.add(previous.node())
        row.add_spacer(2, 32.0)
        var next = ButtonControl(NEXT_BUTTON_ID, next_text, 44.0)
        row.add(next.node())
        row.set_preferred_width(PREVIOUS_BUTTON_ID, 140.0)
        row.set_preferred_width(NEXT_BUTTON_ID, 140.0)
        row.layout()
        return row^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        if event.kind == CLICK_KIND and (
            event.target == PREVIOUS_BUTTON_ID
            or event.target == NEXT_BUTTON_ID
        ):
            self.selected = event.target
            return True
        return False
