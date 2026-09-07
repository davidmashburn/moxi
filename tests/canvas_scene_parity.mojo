"""Shared fixture parity contract for software, Canvas, and SVG renderers."""

from moxi import (
    CanvasSceneRenderer,
    Color,
    SoftwareSceneRenderer,
    SvgSceneRenderer,
    canonical_canvas_scene_fixtures,
    make_canvas_scene,
    test_check,
)


def check_fixture(fixture_index: Int) raises -> Int:
    var fixtures = canonical_canvas_scene_fixtures()
    var fixture = fixtures[fixture_index]
    # Scene values are consumed by renderers, so each backend receives a fresh
    # value produced by the same canonical descriptor rather than a copied
    # hand-written test scene.
    var software_scene = make_canvas_scene(fixture.id)
    var canvas_scene = make_canvas_scene(fixture.id)
    var svg_scene = make_canvas_scene(fixture.id)
    var count = software_scene.count()
    test_check(count == fixture.expected_commands)
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

    var software = SoftwareSceneRenderer(
        fixture.width,
        fixture.height,
        fixture.background,
    )
    var canvas = CanvasSceneRenderer(
        fixture.width,
        fixture.height,
        fixture.background,
    )
    var svg = SvgSceneRenderer(fixture.width, fixture.height)
    software.render_scene(software_scene)
    canvas.render_scene(canvas_scene)
    svg.render_scene(svg_scene)

    test_check(software.frame_count == 1)
    test_check(canvas.frame_count == 1)
    test_check(canvas.command_count == count)
    test_check(canvas.fallback_count == fixture.expected_fallbacks)
    test_check(canvas.error_count() == 0)
    var expected_software = 0
    var expected_canvas = 0
    if fixture.id == 0:
        expected_software = 4260825
        expected_canvas = 4055929
    elif fixture.id == 1:
        expected_software = 26255080
        expected_canvas = 26209374
    elif fixture.id == 2:
        expected_software = 25434784
        expected_canvas = 25720861
    elif fixture.id == 3:
        expected_software = 852464264
        expected_canvas = 853855300
    test_check(software.checksum() == expected_software)
    test_check(canvas.checksum() == expected_canvas)
    test_check(svg.frame_count == 1)
    test_check(svg.markup().count_codepoints() > 100)
    print(
        "Moxi canvas parity fixture ",
        fixture.name,
        ": commands=",
        count,
        " software=",
        software.checksum(),
        " canvas=",
        canvas.checksum(),
    )
    return canvas.checksum()


def main() raises:
    var fixtures = canonical_canvas_scene_fixtures()
    var dark_checksum = 0
    var light_checksum = 0
    for index in range(len(fixtures)):
        var checksum = check_fixture(index)
        if fixtures[index].id == 1:
            dark_checksum = checksum
        elif fixtures[index].id == 2:
            light_checksum = checksum
    # Theme state is a real visual input, not only metadata: the two canonical
    # palette fixtures must produce different raster output.
    test_check(dark_checksum != light_checksum)
    print("Moxi canvas scene parity test passed")
