"""Contract test for the portable canvas SceneRenderer adapter."""

from moxi import (
    CANVAS_RENDER_INVALID_BOUNDS,
    CANVAS_RENDER_UNBALANCED_CLIP,
    CANVAS_RENDER_UNBALANCED_LAYER,
    CanvasSceneRenderer,
    Color,
    Point,
    Rect,
    Scene,
    Transform,
    test_check,
)


def main() raises:
    var background = Color(0.05, 0.05, 0.05, 1.0)
    var scene = Scene()
    scene.push_clip(1, Rect(2.0, 2.0, 6.0, 6.0))
    scene.append_rect(
        2,
        Rect(0.0, 0.0, 12.0, 12.0),
        Color(1.0, 0.0, 0.0, 1.0),
    )
    scene.pop_clip()
    scene.append_rounded_rect(
        3,
        Rect(10.0, 1.0, 8.0, 8.0),
        Color(0.0, 0.0, 1.0, 1.0),
        2.0,
    )
    scene.append_line(
        4,
        Point(1.0, 12.0),
        Point(8.0, 12.0),
        Color(0.0, 1.0, 0.0, 1.0),
        1.0,
    )
    scene.append_linear_gradient(
        5,
        Rect(10.0, 12.0, 12.0, 4.0),
        Point(10.0, 0.0),
        Point(22.0, 0.0),
        Color(0.0, 0.0, 0.0, 1.0),
        Color(1.0, 1.0, 1.0, 1.0),
    )
    scene.push_layer(6, Rect(20.0, 1.0, 3.0, 3.0), 0.5)
    scene.append_rect(
        7,
        Rect(20.0, 1.0, 3.0, 3.0),
        Color(1.0, 1.0, 0.0, 1.0),
    )
    scene.pop_layer()
    scene.append_transform(8, Transform().translated(24.0, 16.0))
    scene.append_rect(
        9,
        Rect(0.0, 0.0, 3.0, 3.0),
        Color(0.0, 1.0, 0.0, 1.0),
    )
    scene.reset_transform()
    scene.append_text(
        10,
        "fallback",
        Rect(0.0, 18.0, 8.0, 3.0),
        Color(1.0, 1.0, 1.0, 1.0),
    )
    scene.append_image(11, 101, Rect(8.0, 18.0, 8.0, 3.0))
    scene.append_path(
        12,
        "M0,0 L4,0 L4,4 Z",
        Rect(16.0, 18.0, 4.0, 4.0),
        Color(1.0, 0.0, 1.0, 1.0),
        Color(1.0, 1.0, 1.0, 1.0),
        1.0,
    )

    var renderer = CanvasSceneRenderer(32, 24, background)
    var capabilities = renderer.backend_capabilities()
    test_check(capabilities.available)
    test_check(capabilities.clipping)
    test_check(renderer.width == 32)
    test_check(renderer.height == 24)
    renderer.render_scene(scene)

    test_check(renderer.frame_count == 1)
    test_check(renderer.command_count == scene.count())
    test_check(renderer.fallback_count == 3)
    test_check(renderer.error_count() == 0)
    test_check(renderer.checksum() > 0)

    # The red rectangle is clipped to (2, 2)-(8, 8).
    test_check(renderer.pixel(1, 1).red < 0.2)
    test_check(renderer.pixel(3, 3).red > 0.8)
    # The rounded rectangle, line, and gradient exercise the canvas primitives.
    test_check(renderer.pixel(14, 5).blue > 0.8)
    test_check(renderer.pixel(4, 12).green > 0.5)
    test_check(renderer.pixel(21, 14).red > renderer.pixel(10, 14).red + 0.4)
    # The translated green rectangle lands at (24, 16)-(27, 19).
    test_check(renderer.pixel(25, 17).green > 0.8)

    var bytes = renderer.rgba_bytes()
    test_check(len(bytes) == 32 * 24 * 4)
    test_check(bytes[0] > 0)
    var first_checksum = renderer.checksum()
    renderer.write_png("/tmp/moxi-canvas-renderer-test.png")
    renderer.write_bmp("/tmp/moxi-canvas-renderer-test.bmp")

    # Re-rendering must clear canvas state and remain deterministic.
    renderer.render_scene(scene)
    test_check(renderer.frame_count == 2)
    test_check(renderer.checksum() == first_checksum)

    var bad_clip = Scene()
    bad_clip.pop_clip(20)
    renderer.render_scene(bad_clip)
    test_check(renderer.has_error())
    test_check(renderer.error_count() == 1)
    test_check(renderer.error_code() == CANVAS_RENDER_UNBALANCED_CLIP)
    test_check(renderer.error_message().count_codepoints() > 0)

    var bad_bounds = Scene()
    bad_bounds.append_rect(
        21,
        Rect(0.0, 0.0, 0.0, 4.0),
        Color(1.0, 0.0, 0.0, 1.0),
    )
    renderer.render_scene(bad_bounds)
    test_check(renderer.error_code() == CANVAS_RENDER_INVALID_BOUNDS)

    var bad_layer = Scene()
    bad_layer.push_layer(22, Rect(0.0, 0.0, 4.0, 4.0), 0.5)
    renderer.render_scene(bad_layer)
    test_check(renderer.error_code() == CANVAS_RENDER_UNBALANCED_LAYER)

    print("Moxi canvas-renderer checksum: ", first_checksum)
    print("Moxi canvas-renderer test passed")
