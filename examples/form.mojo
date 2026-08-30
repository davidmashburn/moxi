"""Interactive 0.5 form demo for keyboard, focus, and text input."""

from moxi import App, FormState, Rect, WindowConfig
from moxi.macos import MacOSClipboard, MacOSRenderer, MacOSWindow


def main() raises:
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    var clipboard = MacOSClipboard()
    window.open(WindowConfig("Moxi Form", 520.0, 320.0))
    var size = window.size()
    var app = App[FormState](
        FormState(),
        Rect(0.0, 0.0, size.width, size.height),
    )
    app.run_with_clipboard(window, renderer, clipboard)
