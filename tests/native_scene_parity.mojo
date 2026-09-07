"""Native Metal replay contract against the software scene oracle."""

from moxi import (
    Color,
    MacOSMetalRenderer,
    Point,
    Rect,
    Scene,
    SoftwareSceneRenderer,
    canonical_text_coretext_fixture,
    test_check,
)


def main() raises:
    var scene = Scene()
    scene.append_rect(
        1,
        Rect(4.0, 4.0, 80.0, 40.0),
        Color(0.12, 0.30, 0.80, 1.0),
    )
    scene.append_line(
        2,
        Point(8.0, 52.0),
        Point(84.0, 82.0),
        Color(0.95, 0.70, 0.15, 1.0),
        2.0,
    )
    scene.append_text(
        3,
        canonical_text_coretext_fixture(),
        Rect(8.0, 86.0, 112.0, 20.0),
        Color(0.95, 0.95, 1.0, 1.0),
    )

    var software = SoftwareSceneRenderer(
        128,
        112,
        Color(0.05, 0.07, 0.12, 1.0),
    )
    software.render_scene(scene)
    test_check(software.command_count == scene.count())
    test_check(software.checksum() > 0)

    var metal = MacOSMetalRenderer(128, 112)
    if not metal.is_ready():
        print("NATIVE_SCREENSHOT_SKIPPED")
        print("Moxi native scene parity skipped: Metal unavailable")
        return
    metal.render_scene(scene)
    # The replay contract is structural: command order/count and explicit
    # fallback accounting must agree. Pixel checksums remain a future masked
    # tolerance lane because GPU color space and text rasterization vary.
    test_check(metal.frame_count() >= 1)
    test_check(metal.rendered_rect_count() == 1)
    test_check(metal.rendered_line_count() == 1)
    test_check(metal.rendered_text_count() == 1)
    test_check(metal.rendered_text_glyph_count() > 0)
    test_check(metal.fallback_command_count() == 0)
    test_check(metal.checksum() != 0)
    test_check(
        metal.write_ppm("dist/native-artifacts/native-scene.ppm")
    )
    print("NATIVE_SCREENSHOT_CAPTURE dist/native-artifacts/native-scene.ppm")
    print("NATIVE_SCREENSHOT_SOFTWARE_BEGIN")
    print(software.ppm())
    print("NATIVE_SCREENSHOT_SOFTWARE_END")
    metal.shutdown()
    print("Moxi native scene parity passed")
