"""Structural parity contract shared by software, canvas, and SVG renderers."""

from moxi import (
    CanvasSceneRenderer,
    Color,
    Point,
    Rect,
    Scene,
    SoftwareSceneRenderer,
    SvgSceneRenderer,
    Transform,
    test_check,
)


def make_scene() -> Scene:
    var scene = Scene()
    scene.append_rect(
        1,
        Rect(0.0, 0.0, 40.0, 30.0),
        Color(0.08, 0.08, 0.12, 1.0),
    )
    scene.push_clip(2, Rect(3.0, 3.0, 24.0, 18.0))
    scene.append_rounded_rect(
        3,
        Rect(4.0, 4.0, 18.0, 12.0),
        Color(0.2, 0.4, 0.9, 1.0),
        3.0,
    )
    scene.append_line(
        4,
        Point(4.0, 18.0),
        Point(24.0, 5.0),
        Color(1.0, 0.8, 0.2, 1.0),
        2.0,
    )
    scene.pop_clip()
    scene.append_linear_gradient(
        5,
        Rect(2.0, 23.0, 34.0, 5.0),
        Point(2.0, 23.0),
        Point(36.0, 23.0),
        Color(0.1, 0.1, 0.1, 1.0),
        Color(0.8, 0.8, 0.8, 1.0),
    )
    scene.append_transform(6, Transform().translated(29.0, 4.0))
    scene.append_rect(
        7,
        Rect(0.0, 0.0, 7.0, 7.0),
        Color(0.2, 0.9, 0.3, 0.9),
    )
    scene.reset_transform()
    scene.append_text(
        8,
        "unsupported text",
        Rect(1.0, 1.0, 10.0, 3.0),
        Color(1.0, 1.0, 1.0, 1.0),
    )
    return scene^


def main() raises:
    var software_scene = make_scene()
    var canvas_scene = make_scene()
    var svg_scene = make_scene()
    var count = software_scene.count()
    test_check(count == canvas_scene.count())
    test_check(count == svg_scene.count())

    for index in range(count):
        var software_command = software_scene.command(index)
        var canvas_command = canvas_scene.command(index)
        var svg_command = svg_scene.command(index)
        test_check(software_command.kind == canvas_command.kind)
        test_check(software_command.kind == svg_command.kind)
        test_check(software_command.bounds.x == canvas_command.bounds.x)
        test_check(software_command.bounds.y == canvas_command.bounds.y)
        test_check(software_command.bounds.width == canvas_command.bounds.width)
        test_check(software_command.bounds.height == canvas_command.bounds.height)

    var software = SoftwareSceneRenderer(40, 30)
    var canvas = CanvasSceneRenderer(
        40,
        30,
        Color(0.0, 0.0, 0.0, 0.0),
    )
    var svg = SvgSceneRenderer(40, 30)
    software.render_scene(software_scene)
    canvas.render_scene(canvas_scene)
    svg.render_scene(svg_scene)

    test_check(software.frame_count == 1)
    test_check(canvas.frame_count == 1)
    test_check(canvas.command_count == count)
    test_check(canvas.fallback_count == 1)
    test_check(software.checksum() > 0)
    test_check(canvas.checksum() > 0)
    test_check(svg.frame_count == 1)
    test_check(svg.markup().count_codepoints() > 100)
    print("Moxi canvas scene parity test passed")
