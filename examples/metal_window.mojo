"""Visible Metal scene window demo."""

from moxi import (
    MacOSMetalRenderer,
    MacOSMetalWindow,
    Rect,
    SHOWCASE_METAL_WINDOW,
    ShowcaseState,
    WindowConfig,
)


def main() raises:
    var component = ShowcaseState(SHOWCASE_METAL_WINDOW)
    var renderer = MacOSMetalRenderer(640, 420)
    var window = MacOSMetalWindow()
    window.open(WindowConfig("Moxi Metal scene", 640.0, 420.0))
    if not renderer.is_ready() or not window.is_open():
        print("Moxi Metal window unavailable")
        renderer.shutdown()
        return
    while window.is_open():
        var scene = component.scene(Rect(0.0, 0.0, 640.0, 420.0))
        renderer.render_scene(scene)
        window.pump()
    renderer.shutdown()
