"""Portable surface and future-target contract test."""

from moxi import (
    BACKEND_ANDROID,
    BACKEND_IOS,
    BACKEND_WEB,
    PlatformSurface,
    PlatformTarget,
    SurfaceConfig,
    test_check,
)


def main():
    var ios = PlatformTarget(BACKEND_IOS)
    test_check(ios.touch_input)
    test_check(ios.ime)
    test_check(ios.device_pixels)
    test_check(ios.is_planned_only())

    var android = PlatformTarget(BACKEND_ANDROID)
    test_check(android.touch_input)
    test_check(android.renderer_name == "gpu-surface")

    var web = PlatformTarget(BACKEND_WEB)
    test_check(web.browser_host)
    test_check(web.renderer_name == "canvas/webgpu")

    var config = SurfaceConfig(320.0, 200.0, "test")
    config.set_scale_factor(2.0)
    test_check(config.pixel_width() == 640)
    test_check(config.pixel_height() == 400)
    config.set_scale_factor(0.01)
    test_check(config.pixel_width() == 3)
    test_check(config.pixel_height() == 2)
    var surface = PlatformSurface(config)
    test_check(surface.attach())
    test_check(not surface.attach())
    test_check(surface.begin_frame())
    test_check(not surface.begin_frame())
    test_check(surface.end_frame())
    test_check(surface.frame_count == 1)
    test_check(surface.resize(640.0, 400.0))
    test_check(surface.resize_count == 1)
    test_check(surface.close())
    test_check(not surface.begin_frame())
    print("Moxi platform test passed")
