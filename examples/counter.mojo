"""Interactive composed counter demo using Moxi's component lifecycle."""

from moxi import App, CounterState, Rect, WindowConfig
from moxi.macos import MacOSRenderer, MacOSWindow


def main() raises:
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    window.open(WindowConfig("Moxi Counter", 384.0, 184.0))
    var size = window.size()
    var app = App[CounterState](
        CounterState(),
        Rect(0.0, 0.0, size.width, size.height),
    )
    app.run(window, renderer)
