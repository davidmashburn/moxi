"""Small component example showing Moxi's high-level lifecycle API."""

from moxi import App, ColumnView, Component, Rect, WindowConfig
from moxi.macos import MacOSRenderer, MacOSWindow


struct GreetingComponent(Component):
    def __init__(out self):
        pass

    def build(self, bounds: Rect) -> ColumnView:
        var view = ColumnView(bounds, 32.0, 8.0)
        view.add_label(1, "Hello from a Moxi component", 32.0)
        view.layout()
        return view^


def main() raises:
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    window.open(WindowConfig("Moxi Component", 384.0, 144.0))
    var size = window.size()
    var app = App[GreetingComponent](
        GreetingComponent(),
        Rect(0.0, 0.0, size.width, size.height),
    )
    app.render(renderer)
    window.run()
