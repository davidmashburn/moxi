"""Small component example showing Moxi's high-level lifecycle API."""

from moxi import App, Rect, WindowConfig
from moxi.macos import MacOSRenderer, MacOSWindow
from moxi_demo.hello import HelloComponent


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
