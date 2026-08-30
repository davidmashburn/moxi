"""Native demo for Moxi's opt-in wrapped-text layout."""

from moxi import App, Rect, WindowConfig, WrappedTextState
from moxi.macos import MacOSRenderer, MacOSWindow


def main() raises:
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    window.open(WindowConfig("Moxi Wrapped Text", 560.0, 320.0))
    var size = window.size()
    var app = App[WrappedTextState](
        WrappedTextState(),
        Rect(0.0, 0.0, size.width, size.height),
    )
    app.run(window, renderer)
