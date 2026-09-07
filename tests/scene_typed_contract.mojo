"""Gate E3 contract tests for typed paths and text metadata."""

from moxi import (
    CanvasSceneRenderer,
    Color,
    Point,
    Rect,
    Scene,
    ScenePath,
    SceneTextStyle,
    SoftwareSceneRenderer,
    SvgSceneRenderer,
    TEXT_ALIGN_CENTER,
    test_check,
)


def has_token(value: String, token: String) -> Bool:
    var last = value.count_codepoints() - token.count_codepoints()
    for index in range(last + 1):
        if value[codepoint=index:index + token.count_codepoints()] == token:
            return True
    return False


def main() raises:
    var path = ScenePath()
    path.move_to(Point(3.0, 3.0))
    path.line_to(Point(21.0, 3.0))
    path.quad_to(Point(24.0, 12.0), Point(21.0, 21.0))
    path.cubic_to(
        Point(18.0, 24.0),
        Point(6.0, 24.0),
        Point(3.0, 21.0),
    )
    path.close()
    test_check(path.is_valid())
    test_check(path.count() == 5)
    test_check(path.bounds.x == 3.0)
    test_check(path.bounds.width == 21.0)

    var scene = Scene()
    scene.append_typed_path(
        1,
        path,
        Color(0.2, 0.6, 1.0, 1.0),
        Color(1.0, 1.0, 1.0, 1.0),
        1.5,
    )
    scene.append_text_styled(
        2,
        "typed text",
        Rect(2.0, 2.0, 80.0, 20.0),
        Color(1.0, 1.0, 1.0, 1.0),
        SceneTextStyle(
            "Inter",
            18.0,
            600,
            True,
            TEXT_ALIGN_CENTER,
        ),
    )
    test_check(scene.command(0).has_typed_path)
    test_check(scene.command(0).typed_path.count() == 5)
    test_check(scene.command(1).has_text_style)
    test_check(scene.command(1).text_style.family == "Inter")

    var canvas = CanvasSceneRenderer(32, 32)
    canvas.render_scene(scene)
    test_check(canvas.fallback_count == 1)
    test_check(canvas.checksum() > 0)

    var isolated = Scene()
    isolated.push_layer(3, Rect(0.0, 0.0, 32.0, 32.0), 0.5, True)
    isolated.append_rect(
        4,
        Rect(2.0, 2.0, 20.0, 20.0),
        Color(1.0, 0.0, 0.0, 1.0),
    )
    isolated.append_rect(
        5,
        Rect(8.0, 8.0, 20.0, 20.0),
        Color(0.0, 0.0, 1.0, 1.0),
    )
    isolated.pop_layer()
    var isolated_canvas = CanvasSceneRenderer(32, 32)
    isolated_canvas.render_scene(isolated)
    test_check(isolated_canvas.error_count() == 0)
    test_check(isolated_canvas.pixel(4, 4).red > 0.4)
    test_check(isolated_canvas.pixel(12, 12).blue > 0.2)
    var isolated_software = SoftwareSceneRenderer(32, 32)
    isolated_software.render_scene(isolated)
    test_check(isolated_software.pixel(4, 4).red > 0.4)
    test_check(isolated_software.pixel(12, 12).blue > 0.2)

    var svg = SvgSceneRenderer(32, 32)
    svg.render_scene(scene)
    test_check(has_token(svg.markup(), "Q "))
    test_check(has_token(svg.markup(), "font-family=\"Inter\""))
    print("Moxi typed scene contract test passed")
