"""Native window using the generated greeting form."""
from moxi import App, Rect, WindowConfig
from moxi.macos import MacOSClipboard, MacOSRenderer, MacOSWindow
from GreetingForm import GreetingForm


def main() raises:
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    var clipboard = MacOSClipboard()
    window.open(WindowConfig("Moxi Tags Experiment", 520.0, 600.0))
    var size = window.size()
    var app = App[GreetingForm](GreetingForm(), Rect(0, 0, size.width, size.height))
    app.run_with_clipboard(window, renderer, clipboard)
