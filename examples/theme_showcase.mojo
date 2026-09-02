"""Interactive theme and component recipe showcase."""

from moxi import (
    App,
    Rect,
    ThemeShowcaseState,
    WindowConfig,
)
from moxi.macos import MacOSRenderer, MacOSWindow


def main() raises:
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    window.open(WindowConfig("Moxi Theme Showcase", 780.0, 480.0))
    var size = window.size()
    var app = App[ThemeShowcaseState](
        ThemeShowcaseState(),
        Rect(0.0, 0.0, size.width, size.height),
    )
    app.run(window, renderer)
