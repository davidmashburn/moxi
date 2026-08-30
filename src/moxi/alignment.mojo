"""Shared 0.5 alignment scenario used by the demo and contract test."""

from .component import Component
from .controls import ButtonControl, LabelControl
from .event import CLICK_KIND, Event
from .geometry import Rect
from .layout import ALIGN_CENTER, JUSTIFY_CENTER
from .style import default_panel_style, default_surface_style
from .view import ColumnView


comptime START_BUTTON_ID = 2
comptime CENTER_BUTTON_ID = 3
comptime END_BUTTON_ID = 4


struct AlignmentState(Component):
    """A small centered column exercising 0.5 alignment controls."""

    var selected: Int

    def __init__(out self):
        self.selected = CENTER_BUTTON_ID

    def build(self, bounds: Rect) -> ColumnView:
        var column = ColumnView(bounds, 24.0, 10.0)
        var panel_width = bounds.width - 40.0
        var panel_height = bounds.height - 40.0
        if panel_width < 0.0:
            panel_width = 0.0
        if panel_height < 0.0:
            panel_height = 0.0
        column.set_surface_style(default_surface_style())
        column.set_panel(
            0,
            Rect(bounds.x + 20.0, bounds.y + 20.0, panel_width, panel_height),
            default_panel_style(),
        )
        var title = LabelControl(1, "Moxi Alignment", 32.0)
        column.add(title.node())
        var start_text = "Start"
        if self.selected == START_BUTTON_ID:
            start_text = "Selected"
        var center_text = "Center"
        if self.selected == CENTER_BUTTON_ID:
            center_text = "Selected"
        var end_text = "End"
        if self.selected == END_BUTTON_ID:
            end_text = "Selected"
        column.add(ButtonControl(START_BUTTON_ID, start_text, 40.0).node())
        column.add(ButtonControl(CENTER_BUTTON_ID, center_text, 40.0).node())
        column.add(ButtonControl(END_BUTTON_ID, end_text, 40.0).node())
        column.set_preferred_width(1, 180.0)
        column.set_preferred_width(START_BUTTON_ID, 180.0)
        column.set_preferred_width(CENTER_BUTTON_ID, 180.0)
        column.set_preferred_width(END_BUTTON_ID, 180.0)
        column.set_main_alignment(JUSTIFY_CENTER)
        column.set_cross_alignment(ALIGN_CENTER)
        column.layout()
        return column^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        if event.kind == CLICK_KIND and (
            event.target == START_BUTTON_ID
            or event.target == CENTER_BUTTON_ID
            or event.target == END_BUTTON_ID
        ):
            self.selected = event.target
            return True
        return False
