"""Native demo for typed component slots and stable action routing."""

from moxi import App, ComposedState, Rect, WindowConfig
from moxi.macos import MacOSRenderer, MacOSWindow


def main() raises:
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    window.open(WindowConfig("Moxi Components", 480.0, 360.0))
    var size = window.size()
    var app = App[ComposedState](
        ComposedState(),
        Rect(0.0, 0.0, size.width, size.height),
    )
    app.run(window, renderer)
