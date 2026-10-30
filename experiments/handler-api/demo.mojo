from moxi import App, Rect, WindowConfig
from moxi.macos import MacOSClipboard, MacOSRenderer, MacOSWindow
from examples import TwoForms
from runtime import HandlerHost


def main() raises:
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    var clipboard = MacOSClipboard()
    window.open(WindowConfig("Moxi Handler Experiment", 520, 900))
    var size = window.size()
    var app = App[HandlerHost[TwoForms]](HandlerHost[TwoForms](TwoForms()), Rect(0, 0, size.width, size.height))
    app.run_with_clipboard(window, renderer, clipboard)
