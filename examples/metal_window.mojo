"""Visible Metal scene window demo."""

from moxi import (
    MacOSMetalRenderer,
    MacOSMetalWindow,
    Point,
    Rect,
    Scene,
    Color,
    WindowConfig,
)


def main() raises:
    var scene = Scene()
    scene.append_rounded_rect(
        1,
        Rect(36.0, 36.0, 560.0, 348.0),
        Color(0.10, 0.17, 0.36, 1.0),
        18.0,
    )
    for index in range(24):
        var x = 54.0 + Float32(index) * 22.0
        scene.append_line(
            100 + index,
            Point(x, 60.0),
            Point(570.0 - Float32(index) * 8.0, 350.0),
            Color(0.25, 0.75, 1.0, 0.85),
            2.0,
        )
    var renderer = MacOSMetalRenderer(640, 420)
    var window = MacOSMetalWindow()
    window.open(WindowConfig("Moxi Metal scene", 640.0, 420.0))
    if not renderer.is_ready() or not window.is_open():
        print("Moxi Metal window unavailable")
        renderer.shutdown()
        return
    while window.is_open():
        renderer.render_scene(scene)
        window.pump()
    renderer.shutdown()
