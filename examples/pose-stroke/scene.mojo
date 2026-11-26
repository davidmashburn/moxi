"""The pose consumer's renderer: widths enter Moxi's typed Scene path API."""

from std.math import isfinite
from std.sys import argv
from moxi import Color, Point, Scene, ScenePath, SvgSceneRenderer


def brush(width: Float32, color: Color) raises -> String:
    var path = ScenePath()
    path.move_to(Point(20, 51))
    path.quad_to(Point(92, 8), Point(165, 38))
    path.quad_to(Point(238, 68), Point(310, 37))
    path.quad_to(Point(382, 6), Point(455, 36))
    path.quad_to(Point(528, 66), Point(580, 30))
    var scene = Scene()
    scene.append_typed_path(1, path, Color(0, 0, 0, 0), color, width)
    var renderer = SvgSceneRenderer(600, 75)
    renderer.render_scene(scene)
    return renderer.markup()


def main() raises:
    var args = argv()
    if len(args) != 3:
        raise Error("expected direct and interpolated widths in [4,28] px")
    var direct = Float64(String(args[1]))
    var pose = Float64(String(args[2]))
    if not isfinite(direct) or not isfinite(pose) or direct < 4 or direct > 28 or pose < 4 or pose > 28:
        raise Error("widths must be finite and in [4,28] px")
    print(brush(Float32(direct), Color(0.157, 0.412, 0.384, 1)))
    print(brush(Float32(pose), Color(0.635, 0.294, 0.212, 1)))
