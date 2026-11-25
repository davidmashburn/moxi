"""RGBA scene snapshots and isolated AppKit/Metal bitmap presentation."""

from std.ffi import external_call
from std.math import abs

from moxi.backend import BACKEND_MACOS_APPKIT
from moxi.geometry import Point, Rect
from moxi.metal import MacOSMetalCanvasPainter, MacOSMetalRenderer
from moxi.native_window import NativeCanvasPainter, NativeCanvasSceneRenderer
from moxi.raster import RasterImage
from moxi.scene import SCENE_BITMAP, Scene, SceneRecorder
from moxi.style import Color
from moxi.testing import test_check


def expect_pixel[native: Bool](x: Int, y: Int, red: Int, green: Int, blue: Int):
    for channel in range(3):
        var actual: Int
        comptime if native:
            actual = Int(external_call["moxi_bitmap_probe_native_channel", Int32](
                Int32(x), Int32(y), Int32(channel)))
        else:
            actual = Int(external_call["moxi_bitmap_probe_metal_channel", Int32](
                Int32(x), Int32(y), Int32(channel)))
        var expected = red if channel == 0 else green if channel == 1 else blue
        if abs(actual - expected) > (8 if native else 2):
            print("Bitmap pixel mismatch", native, x, y, channel, actual, expected)
            test_check(False)


def curve_bitmap() -> RasterImage:
    var raster = RasterImage(2, 2)
    for pixel in range(4):
        raster.pixels[pixel * 4] = 255 if pixel < 2 else 0
        raster.pixels[pixel * 4 + 2] = 0 if pixel < 2 else 255
        raster.pixels[pixel * 4 + 3] = 128 if pixel < 2 else 255
    return raster^


def main() raises:
    var raster = curve_bitmap()
    var scene = Scene()
    scene.append_rect(1, Rect(0, 0, 16, 16), Color(1, 1, 1, 1))
    scene.push_clip(2, Rect(4, 0, 8, 16))
    scene.append_bitmap(3, Rect(0, 0, 16, 16), raster)
    scene.pop_clip(4)
    scene.append_line(5, Point(0, 8), Point(16, 8), Color(0, 1, 0, 1), 2)
    var magenta = RasterImage(1, 1)
    magenta.pixels[0] = 255
    magenta.pixels[2] = 255
    magenta.pixels[3] = 255
    scene.append_bitmap(6, Rect(12, 12, 2, 2), magenta)
    scene.commands[5].set_opacity(0.5)
    raster.pixels[0] = 0
    test_check(scene.command(2).kind == SCENE_BITMAP)
    test_check(scene.command(2).raster.pixels[0] == 255)
    test_check(scene.command(0).raster.is_empty())
    var recorder = SceneRecorder()
    recorder.render_scene(scene)
    scene.commands[2].raster.pixels[0] = 254
    test_check(recorder.command(2).raster.pixels[0] == 255)
    scene.commands[2].raster.pixels[0] = 255

    external_call["moxi_bitmap_probe_native_contract", NoneType]()
    var painter = NativeCanvasPainter[BACKEND_MACOS_APPKIT]()
    painter.begin(Rect(0, 0, 16, 16))
    painter.fill_rect(Rect(0, 0, 16, 16), Color(1, 1, 1, 1), Color(0, 0, 0, 0), 0)
    painter.bitmap(curve_bitmap(), Rect(0, 0, 16, 16))
    painter.line(Point(0, 8), Point(16, 8), Color(0, 1, 0, 1), 2)
    painter.end()
    external_call["moxi_bitmap_probe_capture_native", NoneType]()
    expect_pixel[True](6, 2, 255, 127, 127)
    expect_pixel[True](6, 13, 0, 0, 255)
    expect_pixel[True](6, 8, 0, 255, 0)
    var native = NativeCanvasSceneRenderer[BACKEND_MACOS_APPKIT]()
    native.set_clip(Rect(0, 0, 16, 16))
    native.render_scene(scene)
    external_call["moxi_bitmap_probe_capture_native", NoneType]()
    expect_pixel[True](6, 2, 255, 127, 127)
    # This adapter applies its canvas clip; existing scene clip markers are ignored.
    # The half-opacity magenta bitmap therefore composites over the first blue one.
    expect_pixel[True](13, 13, 128, 0, 255)

    var metal = MacOSMetalRenderer(16, 16)
    if not metal.is_ready():
        print("Moxi bitmap contract passed; Metal unavailable, GPU pixels skipped")
        return
    # Exceed the three-frame ring to catch stale or prematurely overwritten uploads.
    for frame in range(8):
        for pixel in range(2):
            scene.commands[2].raster.pixels[pixel * 4] = 255 if frame % 2 else 0
            scene.commands[2].raster.pixels[pixel * 4 + 1] = 0 if frame % 2 else 255
        metal.render_scene(scene)
        external_call["moxi_bitmap_probe_capture_metal", NoneType]()
        expect_pixel[False](6, 2, 255 if frame % 2 else 127,
            127 if frame % 2 else 255, 127)
    test_check(metal.rendered_image_count() == 2)
    test_check(metal.fallback_command_count() == 0)
    external_call["moxi_bitmap_probe_capture_metal", NoneType]()
    expect_pixel[False](1, 2, 255, 255, 255)
    expect_pixel[False](6, 2, 255, 127, 127)
    expect_pixel[False](6, 13, 0, 0, 255)
    expect_pixel[False](6, 8, 0, 255, 0)
    expect_pixel[False](13, 13, 255, 127, 255)
    metal.shutdown()

    var gpu_painter = MacOSMetalCanvasPainter(16, 16)
    test_check(gpu_painter.is_ready())
    gpu_painter.origin = Point(100, 100)
    var green = RasterImage(1, 1)
    green.pixels[1] = 255
    green.pixels[3] = 255
    gpu_painter.begin(Rect(104, 100, 8, 16))
    gpu_painter.bitmap(green, Rect(100, 100, 16, 16))
    gpu_painter.end()
    gpu_painter.synchronize()
    external_call["moxi_bitmap_probe_capture_metal", NoneType]()
    expect_pixel[False](1, 2, 0, 0, 0)
    expect_pixel[False](6, 2, 0, 255, 0)

    # Bitmap and circle/ring submissions flush prior geometry. Every append must
    # retain that geometry in a distinct region of the frame's shared buffer.
    gpu_painter.origin = Point(0, 0)
    gpu_painter.begin(Rect(0, 0, 16, 16))
    gpu_painter.fill_rect(Rect(0, 0, 16, 16), Color(1, 1, 1, 1), Color(0, 0, 0, 0), 0)
    gpu_painter.bitmap(magenta, Rect(1, 12, 2, 2))
    gpu_painter.line(Point(0, 8), Point(16, 8), Color(0, 1, 0, 1), 2)
    gpu_painter.circle(Point(4, 4.5), 3, Color(1, 0, 0, 1), Color(0, 0, 1, 1), 2)
    gpu_painter.circle(Point(12, 12), 2, Color(0, 1, 1, 1), Color(0, 0, 0, 1), 2)
    gpu_painter.end()
    gpu_painter.synchronize()
    external_call["moxi_bitmap_probe_capture_metal", NoneType]()
    expect_pixel[False](14, 1, 255, 255, 255)
    expect_pixel[False](2, 13, 255, 0, 255)
    expect_pixel[False](8, 8, 0, 255, 0)
    expect_pixel[False](3, 3, 255, 0, 0)
    # Align the pixel center with +x to catch an unclosed circle center fan.
    expect_pixel[False](5, 4, 255, 0, 0)
    expect_pixel[False](7, 4, 0, 0, 255)
    expect_pixel[False](11, 11, 0, 255, 255)
    expect_pixel[False](14, 12, 0, 0, 0)
    gpu_painter.shutdown()

    # Ear-clipped concave polygons and even-odd compound paths also append to
    # the same geometry buffer after a bitmap has flushed its background.
    metal = MacOSMetalRenderer(16, 16)
    var paths = Scene()
    paths.append_rect(1, Rect(0, 0, 16, 16), Color(1, 1, 1, 1))
    paths.append_bitmap(2, Rect(1, 12, 2, 2), magenta)
    paths.append_path(3, "M 1 1 L 7 1 L 7 3 L 3 3 L 3 7 L 1 7 Z",
        Rect(1, 1, 6, 6), Color(1, 0, 0, 1), Color(0, 0, 0, 0), 0)
    paths.append_path(4,
        "M 9 9 L 15 9 L 15 15 L 9 15 Z M 11 11 L 13 11 L 13 13 L 11 13 Z",
        Rect(9, 9, 6, 6), Color(0, 1, 0, 1), Color(0, 0, 0, 0), 0)
    metal.render_scene(paths)
    test_check(metal.rendered_path_count() == 2)
    test_check(metal.fallback_command_count() == 0)
    external_call["moxi_bitmap_probe_capture_metal", NoneType]()
    expect_pixel[False](14, 1, 255, 255, 255)
    expect_pixel[False](2, 13, 255, 0, 255)
    expect_pixel[False](2, 2, 255, 0, 0)
    expect_pixel[False](2, 6, 255, 0, 0)
    expect_pixel[False](6, 6, 255, 255, 255)
    expect_pixel[False](10, 10, 0, 255, 0)
    expect_pixel[False](11, 11, 255, 255, 255)
    metal.shutdown()
    print("Moxi bitmap contract passed")
