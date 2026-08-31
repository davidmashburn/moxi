"""Host-side shell for a Mojo component that can be rebuilt during development.

The shell is an ordinary Moxi component.  A development host may attach a
reloadable scene module to its declared canvas, while layout, focus, and
accessibility remain in the retained Moxi tree.
"""

from .component import Component
from .event import Event
from .geometry import Rect
from .style import default_panel_style, default_surface_style
from .view import ColumnView


comptime LIVE_SCRIPT_TITLE_ID = 1
comptime LIVE_SCRIPT_BODY_ID = 2
comptime LIVE_SCRIPT_CANVAS_ID = 3
comptime LIVE_SCRIPT_STATUS_ID = 4
comptime LIVE_SCRIPT_DETAIL_ID = 5


struct LiveScriptState(Component):
    """A composable view shell for a reloadable Mojo scene component."""

    var reload_status: String

    def __init__(out self):
        self.reload_status = "Waiting for the first live module build."

    def set_status(mut self, status: String):
        self.reload_status = status

    def build(self, bounds: Rect) -> ColumnView:
        var root = ColumnView(bounds, 24.0, 12.0)
        root.set_surface_style(default_surface_style())
        var panel_bounds = Rect(
            bounds.x + 16.0,
            bounds.y + 16.0,
            bounds.width - 32.0,
            bounds.height - 32.0,
        )
        if panel_bounds.width < 0.0:
            panel_bounds.width = 0.0
        if panel_bounds.height < 0.0:
            panel_bounds.height = 0.0
        root.set_panel(0, panel_bounds, default_panel_style())

        root.add_label(
            LIVE_SCRIPT_TITLE_ID,
            "Editable Mojo component",
            34.0,
        )
        root.add_label(
            LIVE_SCRIPT_BODY_ID,
            "Save examples/editable_showcase.mojo and this component reloads its scene in the same window.",
            0.0,
        )
        root.set_preferred_width(LIVE_SCRIPT_BODY_ID, bounds.width - 64.0)
        root.set_wrap_text(LIVE_SCRIPT_BODY_ID)
        root.set_intrinsic_height(LIVE_SCRIPT_BODY_ID)

        var canvas_height = bounds.height - 190.0
        if canvas_height < 210.0:
            canvas_height = 210.0
        root.add_canvas(
            LIVE_SCRIPT_CANVAS_ID,
            "Reloadable component canvas",
            canvas_height,
        )
        root.set_accessibility_label(
            LIVE_SCRIPT_CANVAS_ID,
            "Reloadable Mojo component canvas",
        )
        root.set_accessibility_value(
            LIVE_SCRIPT_CANVAS_ID,
            "Edited source is rebuilt and swapped in place",
        )
        root.add_label(LIVE_SCRIPT_STATUS_ID, self.reload_status, 28.0)
        root.set_preferred_width(LIVE_SCRIPT_STATUS_ID, bounds.width - 64.0)
        root.set_wrap_text(LIVE_SCRIPT_STATUS_ID)
        root.set_intrinsic_height(LIVE_SCRIPT_STATUS_ID)
        root.add_label(
            LIVE_SCRIPT_DETAIL_ID,
            "The script exports moxi_live_frame(x, y, width, height) with a C ABI. Moxi keeps the host view tree and swaps only the module scene.",
            0.0,
        )
        root.set_preferred_width(LIVE_SCRIPT_DETAIL_ID, bounds.width - 64.0)
        root.set_wrap_text(LIVE_SCRIPT_DETAIL_ID)
        root.set_intrinsic_height(LIVE_SCRIPT_DETAIL_ID)
        root.layout()
        return root^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        return False
