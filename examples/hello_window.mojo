"""Minimal visible Moxi demo built from an explicit Component."""

from moxi import App, Rect, WindowConfig
from moxi.macos import MacOSRenderer, MacOSWindow
from moxi_demo.hello import HelloWindow


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
