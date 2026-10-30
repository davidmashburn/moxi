from moxi import App, Rect, WindowConfig
from moxi.macos import MacOSClipboard, MacOSRenderer, MacOSWindow
from settled import SettledNames


def main() raises:
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    var clipboard = MacOSClipboard()
    window.open(WindowConfig("Moxi Shared Child Experiment", 520, 430))
    var size = window.size()
    var app = App[SettledNames](SettledNames(), Rect(0, 0, size.width, size.height))
    app.run_with_clipboard(window, renderer, clipboard)
