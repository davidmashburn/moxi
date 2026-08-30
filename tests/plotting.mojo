"""First-class plot model and scene-output contract test."""

from moxi import (
    Color,
    PLOT_BAR,
    PLOT_LINE,
    PLOT_SCATTER,
    Plot,
    PlotScale,
    Point,
    Rect,
    SoftwareSceneRenderer,
    SCALE_SYMLOG,
    make_plot_scenario,
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
    test_check(plot.set_series_line_width(line, 3.0))
    test_check(plot.set_point(line, 1, 1.0, 2.5))
    test_check(not plot.add_point(999, 0.0, 0.0))
    plot.fit_to_data()
    var scene = plot.build_scene()
    test_check(scene.count() > 10)
    var renderer = SoftwareSceneRenderer(320, 240)
    renderer.render_scene(scene)
    test_check(renderer.checksum() > 0)
    var semantics = plot.accessibility()
    test_check(semantics.count() == 3)
    test_check(semantics.is_valid())
    var hit = plot.hit_test(Point(48.0, 176.0), 200.0)
    test_check(hit.found())
    var empty = Plot(Rect(0.0, 0.0, 10.0, 10.0))
    empty.fit_to_data()
    test_check(empty.x_scale.data_max > empty.x_scale.data_min)
    var shared = make_plot_scenario(Rect(0.0, 0.0, 320.0, 240.0))
    test_check(shared.point_count(1) == 12)
    test_check(shared.build_scene().count() > 20)
    var scale = PlotScale(0.0, 10.0, 0.0, 100.0)
    test_check(scale.map(5.0) == 50.0)
    test_check(scale.inverse(50.0) == 5.0)
    scale.zoom_at(2.0, 50.0)
    test_check(scale.data_min == 2.5)
    test_check(scale.data_max == 7.5)
    var symlog = PlotScale(-10.0, 10.0, 0.0, 100.0)
    symlog.set_kind(SCALE_SYMLOG)
    test_check(symlog.map(0.0) == 50.0)
    test_check(symlog.domain_is_valid())
    test_check(len(symlog.ticks(4)) == 5)
    var dense = Plot(Rect(0.0, 0.0, 320.0, 240.0))
    var dense_id = dense.add_series("dense", Color(0.2, 0.8, 0.4, 1.0))
    for index in range(100):
        var value = Float32(index % 11)
        _ = dense.add_point(dense_id, Float32(index), value)
    dense.set_line_point_limit(20)
    var reduced = dense.line_indices(dense_id)
    test_check(len(reduced) <= 20)
    test_check(reduced[0] == 0)
    test_check(reduced[len(reduced) - 1] == 99)
    dense.set_scatter_point_limit(12)
    var scatter_id = dense.add_series("points", Color(0.9, 0.4, 0.2, 1.0), PLOT_SCATTER)
    for index in range(100):
        _ = dense.add_point(scatter_id, Float32(index), Float32(index % 5))
    test_check(len(dense.scatter_indices(scatter_id)) == 12)
    var faceted = Plot(Rect(0.0, 0.0, 320.0, 240.0))
    faceted.set_facet("region", "quarter")
    var facet_id = faceted.add_series("sales", Color(0.3, 0.7, 1.0, 1.0), PLOT_LINE)
    _ = faceted.add_point_with_key(facet_id, 0.0, 1.0, 10, "west", "q1")
    _ = faceted.add_point_with_key(facet_id, 1.0, 2.0, 11, "east", "q2")
    test_check(faceted.facet_count() == 2)
    test_check(faceted.facet_column_count() == 2)
    test_check(faceted.build_scene().count() > 0)
    print("Moxi plotting test passed")
