"""Native, runnable demonstration of the inert NotImplemented pattern."""

from moxi import App, Rect, WindowConfig
from moxi.macos import MacOSRenderer, MacOSWindow
from moxi_demo.not_implemented_demo import NotImplementedDemo


def main() raises:
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    window.open(WindowConfig("Moxi Not Implemented Pattern", 600.0, 620.0))
    var size = window.size()
    var app = App[NotImplementedDemo](
        NotImplementedDemo(), Rect(0.0, 0.0, size.width, size.height),
    )
    app.run(window, renderer)
