"""Interactive 0.5 alignment demo."""

from moxi import AlignmentState, App, Rect, WindowConfig
from moxi.macos import MacOSRenderer, MacOSWindow


def main() raises:
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    window.open(WindowConfig("Moxi Alignment", 560.0, 320.0))
    var size = window.size()
    var app = App[AlignmentState](
        AlignmentState(),
        Rect(0.0, 0.0, size.width, size.height),
    )
    app.run(window, renderer)
