"""Repeated offscreen Metal scene workload for GPU comparisons."""

from moxi import (
    Color,
    ImageResource,
    MacOSMetalRenderer,
    Point,
    Rect,
    Scene,
    Transform,
)


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
    scene.append_text(
        31,
        "Moxi GPU • café 世界",
        Rect(24.0, 112.0, 180.0, 18.0),
        Color(0.92, 0.96, 1.0, 1.0),
    )
    scene.append_text(
        38,
        "RTL שלום مرحبا · é 😀",
        Rect(24.0, 336.0, 260.0, 18.0),
        Color(0.78, 0.88, 1.0, 1.0),
    )
    scene.append_path(
        32,
        "M 220 112 L 300 112 L 276 142 L 300 176 L 220 176 L 244 144 Z",
        Rect(220.0, 112.0, 80.0, 64.0),
        Color(0.95, 0.45, 0.18, 0.85),
        Color(1.0, 0.9, 0.45, 1.0),
        2.0,
    )
    scene.append_path(
        34,
        "M 320 176 C 332 112 380 96 410 132 S 468 152 492 112 L 492 176 Z",
        Rect(320.0, 96.0, 172.0, 80.0),
        Color(0.30, 0.72, 0.95, 0.42),
        Color(0.60, 0.90, 1.0, 1.0),
        2.0,
    )
    scene.append_path(
        35,
        "M 500 300 A 35 35 0 1 1 430 300 A 35 35 0 1 1 500 300 Z",
        Rect(430.0, 265.0, 70.0, 70.0),
        Color(0.50, 0.30, 0.85, 0.55),
        Color(0.80, 0.65, 1.0, 1.0),
        2.0,
    )
    scene.append_path(
        36,
        "M 40 200 L 180 200 L 180 330 L 40 330 Z M 82 238 L 138 238 L 138 292 L 82 292 Z",
        Rect(40.0, 200.0, 140.0, 130.0),
        Color(0.20, 0.80, 0.55, 0.72),
        Color(0.65, 1.0, 0.82, 1.0),
        2.0,
    )
    scene.append_path(
        37,
        "M 245 220 L 265 270 L 320 270 L 276 302 L 292 350 L 245 320 L 198 350 L 214 302 L 170 270 L 225 270 Z",
        Rect(170.0, 220.0, 150.0, 130.0),
        Color(0.95, 0.72, 0.20, 0.60),
        Color(1.0, 0.92, 0.55, 1.0),
        1.5,
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
    var image = ImageResource(
        901,
        "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericDocumentIcon.icns",
        "document icon",
        64,
        64,
    )
    if renderer.register_image(image):
        scene.append_image(33, image.id, Rect(320.0, 112.0, 64.0, 64.0))
    var passes = 100
    for _ in range(passes):
        renderer.render_scene(scene)
    print("Moxi Metal benchmark passes: ", renderer.frame_count())
    print("Moxi Metal benchmark scene commands: ", scene.count())
    print("Moxi Metal benchmark vertices/frame: ", renderer.vertex_count())
    print("Moxi Metal benchmark rects/frame: ", renderer.rendered_rect_count())
    print("Moxi Metal benchmark lines/frame: ", renderer.rendered_line_count())
    print("Moxi Metal benchmark clips/frame: ", renderer.clip_count())
    print("Moxi Metal benchmark text commands/frame: ", renderer.rendered_text_count())
    print("Moxi Metal benchmark text glyphs/frame: ", renderer.rendered_text_glyph_count())
    print("Moxi Metal benchmark text textures/frame: ", renderer.rendered_text_texture_count())
    print("Moxi Metal benchmark text cache hits/frame: ", renderer.rendered_text_texture_cache_hit_count())
    print("Moxi Metal benchmark text rasterizations/frame: ", renderer.rendered_text_texture_raster_count())
    print("Moxi Metal benchmark images/frame: ", renderer.rendered_image_count())
    print("Moxi Metal benchmark paths/frame: ", renderer.rendered_path_count())
    print("Moxi Metal benchmark fallback commands: ", renderer.fallback_command_count())
    print("Moxi Metal benchmark submissions/frame: ", renderer.draw_submission_count())
    print("Moxi Metal benchmark frame time ms: ", renderer.frame_time_ms())
    print("Moxi Metal benchmark CPU encode ms: ", renderer.cpu_encode_time_ms())
    print("Moxi Metal benchmark CPU wait ms: ", renderer.cpu_wait_time_ms())
    print("Moxi Metal benchmark GPU timing available: ", renderer.gpu_timing_available())
    print("Moxi Metal benchmark GPU time ms: ", renderer.gpu_time_ms())
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
