"""Minimal visible Moxi demo built from an explicit Component."""

from moxi import (
    App,
    ColumnView,
    Component,
    Rect,
    default_panel_style,
    default_surface_style,
    WindowConfig,
)
from moxi.macos import MacOSRenderer, MacOSWindow


comptime HELLO_TITLE_ID = 1
comptime HELLO_BODY_ID = 2


struct HelloWindow(Component):
    """A complete Moxi component: state, view construction, and layout."""

    def __init__(out self):
        pass

    def build(self, bounds: Rect) -> ColumnView:
        var root = ColumnView(bounds, 24.0, 12.0)
        root.set_surface_style(default_surface_style())
        root.set_panel(
            0,
            Rect(
                bounds.x + 16.0,
                bounds.y + 16.0,
                bounds.width - 32.0,
                bounds.height - 32.0,
            ),
            default_panel_style(),
        )
        root.add_label(HELLO_TITLE_ID, "Hello from Moxi", 36.0)
        root.add_label(
            HELLO_BODY_ID,
            "This view is built by a Component and mounted by App.",
            0.0,
        )
        root.set_preferred_width(HELLO_BODY_ID, bounds.width - 64.0)
        root.set_wrap_text(HELLO_BODY_ID)
        root.set_intrinsic_height(HELLO_BODY_ID)
        root.layout()
        return root^


def main() raises:
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    window.open(WindowConfig("Moxi · Hello Window", 560.0, 320.0))
    var size = window.size()
    var app = App[HelloWindow](
        HelloWindow(),
        Rect(0.0, 0.0, size.width, size.height),
    )
    app.run(window, renderer)
