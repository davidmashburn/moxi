"""Repeated offscreen Metal scene workload for GPU comparisons."""

from moxi import Color, MacOSMetalRenderer, Point, Rect, Scene, Transform


def main() raises:
    var scene = Scene()
    scene.append_rect(
        1,
        Rect(20.0, 20.0, 520.0, 320.0),
        Color(0.10, 0.18, 0.42, 1.0),
    )
    scene.append_rounded_rect(
        2,
        Rect(32.0, 32.0, 120.0, 64.0),
        Color(0.15, 0.65, 0.95, 0.85),
        14.0,
    )
    scene.append_linear_gradient(
        3,
        Rect(180.0, 32.0, 180.0, 64.0),
        Point(180.0, 32.0),
        Point(360.0, 32.0),
        Color(0.15, 0.25, 0.70, 0.9),
        Color(0.85, 0.30, 0.25, 0.9),
    )
    scene.append_transform(4, Transform().translated(12.0, 8.0))
    scene.append_rect(
        5,
        Rect(420.0, 40.0, 80.0, 40.0),
        Color(0.30, 0.85, 0.45, 0.75),
    )
    scene.reset_transform()
    scene.push_clip(6, Rect(40.0, 110.0, 460.0, 180.0))
    scene.push_clip(7, Rect(80.0, 130.0, 360.0, 120.0))
    scene.append_rect(
        8,
        Rect(0.0, 0.0, 560.0, 360.0),
        Color(0.08, 0.12, 0.24, 0.35),
    )
    scene.pop_clip()
    scene.pop_clip()
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
    print("Moxi Metal benchmark rects/frame: ", renderer.rendered_rect_count())
    print("Moxi Metal benchmark lines/frame: ", renderer.rendered_line_count())
    print("Moxi Metal benchmark clips/frame: ", renderer.clip_count())
    print("Moxi Metal benchmark fallback commands: ", renderer.fallback_command_count())
    print("Moxi Metal benchmark submissions/frame: ", renderer.draw_submission_count())
    print("Moxi Metal benchmark vertex capacity: ", renderer.buffer_capacity())
    print("Moxi Metal benchmark checksum: ", renderer.checksum())

    # Force one growth step so the resource-lifetime path is exercised rather
    # than only documented. The scene remains bounded and deterministic.
    var growth_scene = Scene()
    for index in range(45000):
        var x = Float32(index % 300) * 1.8
        var y = Float32(index // 300) * 1.8
        growth_scene.append_rect(
            100000 + index,
            Rect(x, y, 1.0, 1.0),
            Color(0.2, 0.4, 0.8, 0.35),
        )
    renderer.render_scene(growth_scene)
    print("Moxi Metal growth commands: ", growth_scene.count())
    print("Moxi Metal growth vertices: ", renderer.vertex_count())
    print("Moxi Metal growth capacity: ", renderer.buffer_capacity())
    print("Moxi Metal buffer reallocations: ", renderer.buffer_reallocation_count())
    print("Moxi Metal growth submissions: ", renderer.draw_submission_count())
    print("Moxi Metal benchmark timing: /usr/bin/time reports wall-clock process time")
    renderer.shutdown()
