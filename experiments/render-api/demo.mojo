from moxi import App, Rect, WindowConfig
from moxi.macos import MacOSClipboard, MacOSRenderer, MacOSWindow
from examples import Demo
from runtime import RenderHost


def main() raises:
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    var clipboard = MacOSClipboard()
    window.open(WindowConfig("Moxi Render Experiment", 520, 820))
    var size = window.size()
    var app = App[RenderHost[Demo]](RenderHost[Demo](Demo()), Rect(0, 0, size.width, size.height))
    app.run_with_clipboard(window, renderer, clipboard)
