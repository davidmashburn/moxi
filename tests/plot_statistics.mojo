"""Statistical plot recipes and derived-table contract tests."""

from moxi import (
    Color,
    PlotDataTable,
    PlotSpec,
    Rect,
    plot_from_spec,
    test_check,
)


def main() raises:
    var data = PlotDataTable()
    _ = data.add_category_column("group")
    var values = [
        Float32(1.0),
        Float32(2.0),
        Float32(2.5),
        Float32(3.0),
        Float32(4.0),
        Float32(5.0),
        Float32(6.0),
        Float32(7.0),
    ]
    for index in range(len(values)):
        _ = data.append(values[index], values[index] * 2.0)
        _ = data.set_category_field(
            "group",
            index,
            "west" if index < 4 else "east",
        )

    var histogram = data.histogram("x", 4)
    test_check(histogram.row_count() == 4)
    test_check(histogram.field_is_valid("x2", 0))
    test_check(histogram.float_field_at("count", 0) > 0.0)

    var density = data.density("x", 4)
    test_check(density.row_count() == 4)
    test_check(density.y_at(0) > 0.0)

    var ecdf = data.ecdf("x")
    test_check(ecdf.row_count() == data.row_count())
    test_check(ecdf.y_at(ecdf.row_count() - 1) == 1.0)

    var boxes = data.box_summary("y", "group")
    test_check(boxes.row_count() == 2)
    test_check(boxes.field_is_valid("low", 0))
    test_check(boxes.float_field_at("median", 0) >= boxes.y_at(0))

    var heatmap = data.heatmap("x", "y", 2, 2)
    test_check(heatmap.row_count() == 4)
    test_check(heatmap.field_is_valid("count", 0))
    test_check(heatmap.field_is_valid("x2", 0))
    test_check(heatmap.field_is_valid("y2", 0))

    var regression = data.regression("x", "y", 8)
    test_check(regression.row_count() == 8)
    test_check(regression.y_at(0) < regression.y_at(7))

    var histogram_spec = PlotSpec("Histogram")
    _ = histogram_spec.add_histogram("distribution", "x", 4)
    var histogram_plot = plot_from_spec(
        histogram_spec,
        data,
        Rect(0.0, 0.0, 320.0, 240.0),
    )
    test_check(histogram_plot.series_count() == 1)
    test_check(histogram_plot.build_scene().count() > 0)

    var box_spec = PlotSpec("Boxes")
    _ = box_spec.add_box("groups", "y", "group")
    var box_plot = plot_from_spec(
        box_spec,
        data,
        Rect(0.0, 0.0, 320.0, 240.0),
    )
    test_check(box_plot.series_count() == 1)
    test_check(box_plot.point_count(1) == 2)
    test_check(box_plot.build_scene().count() > 0)

    var heatmap_spec = PlotSpec("Heatmap")
    _ = heatmap_spec.add_heatmap("density", "x", "y", 2, 2)
    var heatmap_plot = plot_from_spec(
        heatmap_spec,
        data,
        Rect(0.0, 0.0, 320.0, 240.0),
    )
    test_check(heatmap_plot.point_count(1) == 4)
    test_check(heatmap_plot.build_scene().count() > 0)

    var regression_spec = PlotSpec("Regression")
    _ = regression_spec.add_regression("fit", "x", "y", 8)
    var regression_plot = plot_from_spec(
        regression_spec,
        data,
        Rect(0.0, 0.0, 320.0, 240.0),
    )
    test_check(regression_plot.point_count(1) == 8)
    test_check(regression_plot.build_scene().count() > 0)

    print("Moxi plot-statistics test passed")
