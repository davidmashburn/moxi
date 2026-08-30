"""First-class plot model and scene-output contract test."""

from moxi import (
    Color,
    PLOT_BAR,
    PLOT_LINE,
    Plot,
    Point,
    Rect,
    SoftwareSceneRenderer,
    test_check,
)


def main() raises:
    var plot = Plot(Rect(0.0, 0.0, 320.0, 240.0))
    plot.set_title("test plot")
    var line = plot.add_series(
        "line",
        Color(0.2, 0.8, 1.0, 1.0),
        PLOT_LINE,
    )
    var bars = plot.add_series(
        "bars",
        Color(1.0, 0.4, 0.2, 1.0),
        PLOT_BAR,
    )
    test_check(plot.add_point(line, 0.0, 0.0))
    test_check(plot.add_point(line, 1.0, 2.0))
    test_check(plot.add_point(line, 2.0, 1.0))
    test_check(plot.add_point(bars, 0.0, 1.0))
    test_check(plot.point_count(line) == 3)
    test_check(not plot.add_point(999, 0.0, 0.0))
    plot.fit_to_data()
    var scene = plot.build_scene()
    test_check(scene.count() > 10)
    var renderer = SoftwareSceneRenderer(320, 240)
    renderer.render_scene(scene)
    test_check(renderer.checksum() > 0)
    var hit = plot.hit_test(Point(48.0, 176.0), 200.0)
    test_check(hit.found())
    var empty = Plot(Rect(0.0, 0.0, 10.0, 10.0))
    empty.fit_to_data()
    test_check(empty.x_scale.data_max > empty.x_scale.data_min)
    print("Moxi plotting test passed")
