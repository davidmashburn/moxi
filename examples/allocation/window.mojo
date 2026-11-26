from model import Workbench
from moxi import App, Rect, WindowConfig
from moxi.authoring import HandlerHost
from moxi.macos import MacOSWindow, MacOSRenderer


def open_window(mut window: MacOSWindow) raises -> App[HandlerHost[Workbench]]:
    window.open(WindowConfig("Orchard Commons | Plot allocation", 760, 690))
    var size = window.size()
    return App(HandlerHost(Workbench()), Rect(0, 0, size.width, size.height))


def main() raises:
    var window = MacOSWindow()
    var app = open_window(window)
    var renderer = MacOSRenderer()
    app.run(window, renderer)
