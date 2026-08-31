"""Small component example showing Moxi's high-level lifecycle API."""

from moxi import (
    App,
    Rect,
    SHOWCASE_HELLO_COMPONENT,
    ShowcaseState,
    WindowConfig,
)
from moxi.macos import MacOSRenderer, MacOSWindow


def main() raises:
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    window.open(WindowConfig("Moxi · Hello Component", 560.0, 320.0))
    var size = window.size()
    var app = App[ShowcaseState](
        ShowcaseState(SHOWCASE_HELLO_COMPONENT),
        Rect(0.0, 0.0, size.width, size.height),
    )
    app.run(window, renderer)
