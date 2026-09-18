"""Native custom-scene capacity regression for the data workbench plots."""

from std.ffi import external_call

from moxi import Color, Rect, Scene, test_check
from moxi.macos import MacOSCanvasSceneRenderer


comptime RECT_COUNT = 200_100


def main() raises:
    # Reset the native frame counters without opening an AppKit window.  The
    # workbench host uses the same custom-scene renderer in its frame path.
    external_call["moxi_window_begin_frame", NoneType]()

    var scene = Scene()
    for index in range(RECT_COUNT):
        var x = Float32(index % 512)
        var y = Float32(index // 512)
        scene.append_rect(
            index,
            Rect(x, y, 1.0, 1.0),
            Color(0.18, 0.42, 0.88, 1.0),
        )
    test_check(scene.count() == RECT_COUNT)

    var renderer = MacOSCanvasSceneRenderer()
    renderer.set_clip(Rect(0.0, 0.0, 512.0, 512.0))
    renderer.render_scene(scene)

    var overflow = Int(
        external_call["moxi_window_command_overflow_count", Int32]()
    )
    test_check(overflow == 0)
    print(
        "Moxi native workbench capacity passed: rects=",
        RECT_COUNT,
        " overflow=",
        overflow,
    )
