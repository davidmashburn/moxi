"""Headless plotting showcase using the portable Moxi scene contract."""

from moxi import (
    Color,
    Plot,
    Point,
    Rect,
    SoftwareSceneRenderer,
    PLOT_LINE,
    PLOT_SCATTER,
)


def main() raises:
    var plot = Plot(Rect(0.0, 0.0, 640.0, 420.0))
    plot.set_title("Moxi plotting preview")
    var line = plot.add_series(
        "signal",
        Color(0.25, 0.72, 1.0, 1.0),
        PLOT_LINE,
    )
    var points = plot.add_series(
        "samples",
        Color(1.0, 0.45, 0.25, 1.0),
        PLOT_SCATTER,
    )
    for index in range(12):
        var x = Float32(index)
        var y = 0.5 + Float32((index * 7) % 5) * 0.35
        _ = plot.add_point(line, x, y)
        _ = plot.add_point(points, x, y + 0.2)
    plot.fit_to_data()
    var scene = plot.build_scene()
    var renderer = SoftwareSceneRenderer(640, 420)
    renderer.render_scene(scene)
    var hit = plot.hit_test(Point(48.0, 28.0), 12.0)
    print("Moxi plot scene commands: ", scene.count())
    print("Moxi plot scene checksum: ", renderer.checksum())
    print("Moxi plot hit: ", hit.found())
