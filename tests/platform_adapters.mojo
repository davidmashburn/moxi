"""Cross-platform adapter failure-closed and headless lifecycle test."""

from moxi import (
    SurfaceConfig,
    android_backend,
    headless_backend,
    ios_backend,
    test_check,
    web_backend,
)


def main():
    var config = SurfaceConfig(100.0, 80.0, "adapter")
    var headless = headless_backend()
    test_check(headless.is_available())
    test_check(headless.open(config))
    test_check(headless.set_scale_factor(2.0))
    test_check(headless.surface.config.pixel_width() == 200)
    test_check(headless.begin_frame())
    test_check(headless.present())
    test_check(headless.close())

    var ios = ios_backend()
    test_check(not ios.is_available())
    test_check(not ios.open(config))
    test_check(ios.open_attempts == 1)
    var android = android_backend()
    test_check(not android.open(config))
    var web = web_backend()
    test_check(not web.open(config))
    print("Moxi platform-adapters test passed")
