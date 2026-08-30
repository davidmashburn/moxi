"""Shared wrapped-text scenario used by the demo and contract test."""

from .component import Component
from .event import Event
from .geometry import Rect
from .layout import ALIGN_START
from .style import default_panel_style, default_surface_style
from .view import ColumnView


comptime WRAPPED_TITLE_ID = 1
comptime WRAPPED_BODY_ID = 2


struct WrappedTextState(Component):
    """A small screen demonstrating opt-in wrapping and intrinsic height."""

    def __init__(out self):
        pass

    def build(self, bounds: Rect) -> ColumnView:
        var column = ColumnView(bounds, 24.0, 12.0)
        var panel_width = bounds.width - 32.0
        var panel_height = bounds.height - 32.0
        if panel_width < 0.0:
            panel_width = 0.0
        if panel_height < 0.0:
            panel_height = 0.0
        column.set_surface_style(default_surface_style())
        column.set_panel(
            0,
            Rect(bounds.x + 16.0, bounds.y + 16.0, panel_width, panel_height),
            default_panel_style(),
        )
        column.set_cross_alignment(ALIGN_START)
        column.add_label(WRAPPED_TITLE_ID, "Moxi Text Layout", 30.0)
        column.add_label(
            WRAPPED_BODY_ID,
            "Moxi uses a deterministic estimate for wrapped text. Resize the window or change the width to see the body reflow while the retained identity stays stable.",
            0.0,
        )
        var body_width = bounds.width - 64.0
        if body_width < 0.0:
            body_width = 0.0
        column.set_preferred_width(WRAPPED_BODY_ID, body_width)
        column.set_wrap(WRAPPED_BODY_ID)
        column.set_intrinsic_height(WRAPPED_BODY_ID)
        column.layout()
        return column^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        return False
