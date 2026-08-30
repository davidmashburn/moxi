"""Headless plotting showcase using the portable Moxi scene contract."""

from moxi import (
    Color,
    Point,
    Rect,
    SoftwareSceneRenderer,
    make_plot_scenario,
)


def main() raises:
    var plot = make_plot_scenario(Rect(0.0, 0.0, 640.0, 420.0))
    var scene = plot.build_scene()
    var renderer = SoftwareSceneRenderer(640, 420)
    renderer.render_scene(scene)
    var hit = plot.hit_test(Point(48.0, 28.0), 12.0)
    print("Moxi plot scene commands: ", scene.count())
    print("Moxi plot scene checksum: ", renderer.checksum())
    print("Moxi plot hit: ", hit.found())
