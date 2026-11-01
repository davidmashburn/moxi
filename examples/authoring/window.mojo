"""Interactive authoring counter through the existing App event loop."""
from counter import Counter
from moxi import App, Rect, WindowConfig
from moxi.authoring import HandlerHost
from moxi.macos import MacOSRenderer, MacOSWindow


def main() raises:
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    window.open(WindowConfig("Moxi authoring counter", 384.0, 184.0))
    var size = window.size()
    var app = App(HandlerHost(Counter()), Rect(0, 0, size.width, size.height))
    app.run(window, renderer)
