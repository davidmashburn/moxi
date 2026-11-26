"""Emit the exact canonical chart at the logical dimensions of a captured frame."""
from std.sys import argv
from std.testing import assert_equal
from moxi.geometry import Rect
from moxi.layout_workbench_replay import layout_workbench_chart
from moxi.software import SoftwareSceneRenderer


def main() raises:
    var args = argv()
    assert_equal(len(args), 3)
    var width = Float32(Float64(String(args[1])))
    var height = Float32(Float64(String(args[2])))
    var scene = layout_workbench_chart(Rect(0, 0, width, height))
    var renderer = SoftwareSceneRenderer(Int(width), Int(height))
    renderer.render_scene(scene)
    assert_equal(renderer.command_count, 125)
    print(renderer.ppm())
