"""Named target adapter contract test."""

from moxi import (
    AndroidBackend,
    Color,
    IOSBackend,
    POINTER_DOWN_KIND,
    Point,
    Rect,
    Scene,
    SurfaceConfig,
    TOUCH_BEGIN_KIND,
    WebBackend,
    WINDOW_RESIZED_KIND,
    test_check,
)


def main() raises:
    var config = SurfaceConfig()
    var ios = IOSBackend()
    var android = AndroidBackend()
    var web = WebBackend()
    test_check(not ios.is_available())
    test_check(not android.is_available())
    test_check(not web.is_available())
    test_check(not ios.open(config))
    test_check(not android.open(config))
    test_check(not web.open(config))
    test_check(not web.set_scale_factor(2.0))

    var scene = Scene()
    scene.append_rect(1, Rect(0.0, 0.0, 12.0, 8.0), Color(1.0, 0.0, 0.0, 1.0))
    var ios_touch = ios.touch(TOUCH_BEGIN_KIND, 7, Point(4.0, 5.0))
    test_check(ios_touch.kind == TOUCH_BEGIN_KIND)
    test_check(ios_touch.pointer_id == 7)
    var android_resize = android.resize_event(320.0, 240.0)
    test_check(android_resize.kind == WINDOW_RESIZED_KIND)
    test_check(android.software_checksum(scene, 16, 12) > 0)
    var web_pointer = web.pointer(POINTER_DOWN_KIND, Point(2.0, 3.0), 9, 1)
    test_check(web_pointer.kind == POINTER_DOWN_KIND)
    test_check(web_pointer.pointer_id == 9)
    test_check(web.svg_frame(scene, 16, 12).count_codepoints() > 0)
    print("Moxi named-targets test passed")
