"""Minimal visible Moxi demo using the shared embeddable component."""

from moxi import (
    App,
    Rect,
    SHOWCASE_HELLO_WINDOW,
    ShowcaseState,
    WindowConfig,
)
from moxi.macos import MacOSRenderer, MacOSWindow


def main() raises:
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    window.open(WindowConfig("Moxi · Hello Window", 560.0, 320.0))
    var size = window.size()
    var app = App[ShowcaseState](
        ShowcaseState(SHOWCASE_HELLO_WINDOW),
        Rect(0.0, 0.0, size.width, size.height),
    )
    app.run(window, renderer)
