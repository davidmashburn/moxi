"""Interactive row demo for reusable controls and horizontal layout."""

from moxi import App, Rect, RowState, WindowConfig
from moxi.macos import MacOSRenderer, MacOSWindow


def main() raises:
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    window.open(WindowConfig("Moxi Row", 560.0, 180.0))
    var size = window.size()
    var app = App[RowState](
        RowState(),
        Rect(0.0, 0.0, size.width, size.height),
    )
    app.run(window, renderer)
