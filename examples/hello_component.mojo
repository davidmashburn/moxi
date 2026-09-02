"""Small component example showing Moxi's high-level lifecycle API."""

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


comptime COMPONENT_TITLE_ID = 1
comptime COMPONENT_BODY_ID = 2


struct HelloComponent(Component):
    """A reusable component with no host-specific window code."""

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
        root.add_label(COMPONENT_TITLE_ID, "A reusable Moxi component", 34.0)
        root.add_label(
            COMPONENT_BODY_ID,
            "The host owns the window; this Component owns the view tree.",
            0.0,
        )
        root.set_preferred_width(COMPONENT_BODY_ID, bounds.width - 64.0)
        root.set_wrap_text(COMPONENT_BODY_ID)
        root.set_intrinsic_height(COMPONENT_BODY_ID)
        root.layout()
        return root^


def main() raises:
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    window.open(WindowConfig("Moxi · Hello Component", 560.0, 320.0))
    var size = window.size()
    var app = App[HelloComponent](
        HelloComponent(),
        Rect(0.0, 0.0, size.width, size.height),
    )
    app.run(window, renderer)
