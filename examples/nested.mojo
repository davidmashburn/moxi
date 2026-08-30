"""Interactive 0.5 nested-container demo."""

from moxi import App, NestedState, Rect, WindowConfig
from moxi.macos import MacOSClipboard, MacOSRenderer, MacOSWindow


def main() raises:
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    var clipboard = MacOSClipboard()
    window.open(WindowConfig("Moxi Nested", 560.0, 340.0))
    var size = window.size()
    var app = App[NestedState](
        NestedState(),
        Rect(0.0, 0.0, size.width, size.height),
    )
    app.run_with_clipboard(window, renderer, clipboard)
