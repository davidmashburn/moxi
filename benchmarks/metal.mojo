"""Repeated offscreen Metal scene workload for GPU comparisons."""

from moxi import Color, MacOSMetalRenderer, Point, Rect, Scene


def main() raises:
    var scene = Scene()
    scene.append_rect(
        1,
        Rect(20.0, 20.0, 520.0, 320.0),
        Color(0.10, 0.18, 0.42, 1.0),
    )
    for index in range(64):
        var x = 24.0 + Float32(index) * 8.0
        scene.append_line(
            100 + index,
            Point(x, 24.0),
            Point(540.0 - x * 0.2, 336.0),
            Color(0.20, 0.75, 1.0, 0.8),
            1.0,
        )
    var renderer = MacOSMetalRenderer(560, 360)
    if not renderer.is_ready():
        print("Moxi Metal benchmark skipped: device unavailable")
        return
    var passes = 100
    for _ in range(passes):
        renderer.render_scene(scene)
    print("Moxi Metal benchmark passes: ", renderer.frame_count())
    print("Moxi Metal benchmark scene commands: ", scene.count())
    print("Moxi Metal benchmark vertices/frame: ", renderer.vertex_count())
    print("Moxi Metal benchmark checksum: ", renderer.checksum())
    print("Moxi Metal benchmark timing: /usr/bin/time reports wall-clock process time")
    renderer.shutdown()
