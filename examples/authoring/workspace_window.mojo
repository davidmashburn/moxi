"""Try the nested workspace through the production macOS event loop."""
from workspace import Workspace
from moxi import App, Rect, WindowConfig
from moxi.authoring import HandlerHost
from moxi.macos import MacOSRenderer, MacOSWindow


def main() raises:
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    window.open(WindowConfig("Moxi authoring workspace", 640.0, 720.0))
    var size = window.size()
    var app = App(HandlerHost(Workspace()), Rect(0, 0, size.width, size.height))
    app.run(window, renderer)
