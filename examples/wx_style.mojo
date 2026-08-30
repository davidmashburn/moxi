"""Interactive wxPython-style teaching demo for Moxi."""

from moxi import App, Rect, ResourceStore, WindowConfig, WxStyleState
from moxi.macos import MacOSClipboard, MacOSRenderer, MacOSWindow


def main() raises:
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    var clipboard = MacOSClipboard()
    window.open(WindowConfig("Moxi wxPython-style demo", 560.0, 1100.0))
    var resources = ResourceStore()
    var app_icon = resources.register_image(
        "NSApplicationIcon",
        "Moxi application icon",
        72,
        72,
    )
    renderer.register_image(resources.image(app_icon.id))
    var size = window.size()
    var app = App[WxStyleState](
        WxStyleState(),
        Rect(0.0, 0.0, size.width, size.height),
    )
    app.run_with_clipboard(window, renderer, clipboard)
