"""Contract test for the retained-paint to scene rendering seam."""

from moxi import (
    Color,
    ColumnRuntime,
    ColumnView,
    Point,
    Rect,
    SceneRecorder,
    SoftwareSceneRenderer,
    Scene,
    Transform,
    SCENE_IMAGE,
    SCENE_RECT,
    SCENE_TEXT,
    scene_from_paint,
    test_check,
)


def main() raises:
    var view = ColumnView(Rect(0.0, 0.0, 320.0, 180.0), 8.0, 4.0)
    view.add_label(1, "Scene text", 24.0)
    view.add_image(2, "Example", 9, 64.0)
    view.layout()
    var runtime = ColumnRuntime()
    runtime.reconcile(view)
    var scene = scene_from_paint(runtime.paint())
    test_check(scene.count() == 3)
    test_check(scene.command(0).kind == SCENE_RECT)
    test_check(scene.command(1).kind == SCENE_TEXT)
    test_check(scene.command(2).kind == SCENE_IMAGE)
    var recorder = SceneRecorder()
    recorder.render_scene(scene)
    test_check(recorder.count() == scene.count())
    test_check(recorder.frame_count == 1)

    var rich_scene = Scene()
    rich_scene.append_path(
        10,
        "M0,0 L10,0 L10,10 Z",
        Rect(0.0, 0.0, 10.0, 10.0),
        Color(1.0, 0.0, 0.0, 1.0),
        Color(1.0, 1.0, 1.0, 1.0),
        1.0,
    )
    rich_scene.append_linear_gradient(
        11,
        Rect(0.0, 0.0, 20.0, 20.0),
        Point(0.0, 0.0),
        Point(20.0, 0.0),
        Color(0.0, 0.0, 0.0, 1.0),
        Color(1.0, 1.0, 1.0, 1.0),
    )
    rich_scene.append_transform(12, Transform().translated(4.0, 5.0))
    test_check(rich_scene.count() == 3)
    var software = SoftwareSceneRenderer(
        24,
        24,
        Color(0.05, 0.05, 0.05, 1.0),
    )
    software.render_scene(rich_scene)
    test_check(software.frame_count == 1)
    test_check(software.command_count == 3)
    test_check(software.checksum() > 0)
    test_check(software.pixel(2, 2).red > 0.0)

    var scoped = Scene()
    scoped.push_clip(20, Rect(2.0, 2.0, 4.0, 4.0))
    scoped.append_rect(
        21,
        Rect(0.0, 0.0, 10.0, 10.0),
        Color(1.0, 0.0, 0.0, 1.0),
    )
    scoped.pop_clip()
    scoped.push_layer(22, Rect(0.0, 0.0, 4.0, 4.0), 0.5)
    scoped.append_rect(
        23,
        Rect(0.0, 0.0, 4.0, 4.0),
        Color(0.0, 0.0, 1.0, 1.0),
    )
    scoped.pop_layer()
    scoped.append_transform(24, Transform().translated(10.0, 10.0))
    scoped.append_rect(
        25,
        Rect(0.0, 0.0, 2.0, 2.0),
        Color(0.0, 1.0, 0.0, 1.0),
    )
    scoped.reset_transform()
    var scoped_renderer = SoftwareSceneRenderer(
        24,
        24,
        Color(0.05, 0.05, 0.05, 1.0),
    )
    scoped_renderer.render_scene(scoped)
    test_check(scoped_renderer.pixel(1, 1).red < 0.2)
    test_check(scoped_renderer.pixel(3, 3).red >= 0.45)
    test_check(scoped_renderer.pixel(1, 1).blue > 0.2)
    test_check(scoped_renderer.pixel(10, 10).green > 0.5)

    var primitives = Scene()
    primitives.append_rounded_rect(
        30,
        Rect(1.0, 1.0, 6.0, 6.0),
        Color(1.0, 0.0, 0.0, 1.0),
        2.0,
    )
    primitives.append_line(
        31,
        Point(1.0, 1.0),
        Point(7.0, 7.0),
        Color(0.0, 1.0, 0.0, 1.0),
        1.0,
    )
    var primitive_renderer = SoftwareSceneRenderer(10, 10)
    primitive_renderer.render_scene(primitives)
    test_check(primitive_renderer.pixel(3, 3).green > 0.5)
    test_check(primitive_renderer.pixel(1, 5).green < 0.1)
    test_check(primitive_renderer.pixel(1, 1).red < 0.1)
    test_check(primitive_renderer.pixel(2, 3).red > 0.1)
    print("Moxi scene-renderer test passed")
