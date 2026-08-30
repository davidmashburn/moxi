"""Contract tests for resource handles and the backend-neutral scene IR."""

from moxi import (
    Color,
    Point,
    Rect,
    RESOURCE_IMAGE,
    RESOURCE_FONT,
    RESOURCE_NONE,
    SCENE_IMAGE,
    SCENE_LINE,
    SCENE_RECT,
    SCENE_ROUNDED_RECT,
    SCENE_TEXT,
    ResourceStore,
    Scene,
)
from moxi.testing import test_check


def main():
    var resources = ResourceStore()
    var handle = resources.register_image(
        "assets/example.png",
        "Example image",
        64,
        48,
    )
    test_check(handle.kind == RESOURCE_IMAGE)
    test_check(handle.id == 1)
    test_check(resources.image_count() == 1)
    test_check(resources.has_image(handle.id))
    test_check(resources.image(handle.id).alt_text == "Example image")
    test_check(resources.image(999).id == RESOURCE_NONE)
    var font = resources.register_font("fonts/Inter.ttf", "Inter", 500)
    test_check(font.kind == RESOURCE_FONT)
    test_check(resources.font_count() == 1)
    test_check(resources.has_font(font.id))

    var scene = Scene()
    scene.append_rect(1, Rect(0.0, 0.0, 10.0, 10.0), Color(1.0, 0.0, 0.0, 1.0))
    scene.append_rounded_rect(
        2,
        Rect(1.0, 1.0, 8.0, 8.0),
        Color(0.0, 1.0, 0.0, 1.0),
        3.0,
    )
    scene.append_line(
        3,
        Point(0.0, 0.0),
        Point(10.0, 10.0),
        Color(0.0, 0.0, 1.0, 1.0),
        2.0,
    )
    scene.append_text(
        4,
        "Hello",
        Rect(0.0, 0.0, 40.0, 20.0),
        Color(1.0, 1.0, 1.0, 1.0),
    )
    scene.append_image(5, handle.id, Rect(2.0, 2.0, 64.0, 48.0))
    test_check(scene.count() == 5)
    test_check(scene.command(0).kind == SCENE_RECT)
    test_check(scene.command(1).kind == SCENE_ROUNDED_RECT)
    test_check(scene.command(2).kind == SCENE_LINE)
    test_check(scene.command(3).kind == SCENE_TEXT)
    test_check(scene.command(4).kind == SCENE_IMAGE)
    test_check(scene.command(4).resource_id == handle.id)
    test_check(scene.command(1).corner_radius == 3.0)

    print("Moxi resources-scene test passed")
