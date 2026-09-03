"""Interactive ten-step Moxi walkthrough built on CapabilityBus."""

from moxi import (
    App,
    CapabilityWalkthroughState,
    Rect,
    WindowConfig,
)
from moxi.macos import MacOSRenderer, MacOSWindow


def main() raises:
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    window.open(WindowConfig("Moxi · Capability Bus Walkthrough", 900.0, 680.0))
    var size = window.size()
    var app = App[CapabilityWalkthroughState](
        CapabilityWalkthroughState(),
        Rect(0.0, 0.0, size.width, size.height),
    )
    app.run(window, renderer)
