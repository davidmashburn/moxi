"""Statistical, faceted, and linked-plot workload over the shared fixture."""

from moxi import (
    Color,
    PerformanceCounters,
    PlotLink,
    PlotRuntime,
    PlotSelection,
    PlotSpec,
    Rect,
    SoftwareSceneRenderer,
    make_plot_data_fixture,
    plot_from_spec,
)


def main() raises:
    var data = make_plot_data_fixture()
    var histogram_spec = PlotSpec("analytics histogram")
    _ = histogram_spec.add_histogram("histogram", "value", 16)
    var histogram = plot_from_spec(
        histogram_spec, data, Rect(0.0, 0.0, 640.0, 360.0)
    )

    var box_spec = PlotSpec("analytics boxes")
    _ = box_spec.add_box("boxes", "value", "series")
    var boxes = plot_from_spec(box_spec, data, Rect(0.0, 0.0, 640.0, 360.0))

    var heatmap_spec = PlotSpec("analytics heatmap")
    _ = heatmap_spec.add_heatmap("heatmap", "x", "value", 16, 12)
    var heatmap = plot_from_spec(
        heatmap_spec, data, Rect(0.0, 0.0, 640.0, 360.0)
    )

    var regression_spec = PlotSpec("analytics regression")
    _ = regression_spec.add_regression("regression", "x", "value", 64)
    var regression = plot_from_spec(
        regression_spec, data, Rect(0.0, 0.0, 640.0, 360.0)
    )

    var renderer = SoftwareSceneRenderer(640, 360)
    var metrics = PerformanceCounters()
    var passes = 20
    for _ in range(passes):
        var histogram_scene = histogram.build_scene()
        renderer.render_scene(histogram_scene)
        metrics.record_frame(0, 0, histogram_scene.count(), histogram_scene.count(), renderer.rasterized_pixels)
        var box_scene = boxes.build_scene()
        renderer.render_scene(box_scene)
        metrics.record_frame(0, 0, box_scene.count(), box_scene.count(), renderer.rasterized_pixels)
        var heatmap_scene = heatmap.build_scene()
        renderer.render_scene(heatmap_scene)
        metrics.record_frame(0, 0, heatmap_scene.count(), heatmap_scene.count(), renderer.rasterized_pixels)
        var regression_scene = regression.build_scene()
        renderer.render_scene(regression_scene)
        metrics.record_frame(0, 0, regression_scene.count(), regression_scene.count(), renderer.rasterized_pixels)

    # Exercise the same keyed-selection propagation used by linked dashboards.
    var source_runtime = PlotRuntime(Rect(0.0, 0.0, 640.0, 360.0))
    var target_runtime = PlotRuntime(Rect(0.0, 0.0, 640.0, 360.0))
    var source_series = source_runtime.plot.add_series(
        "source", Color(0.25, 0.75, 1.0, 1.0)
    )
    var target_series = target_runtime.plot.add_series(
        "target", Color(1.0, 0.45, 0.3, 1.0)
    )
    for index in range(data.row_count()):
        var key = data.key_at(index)
        var x = data.x_at(index)
        var y = data.y_at(index)
        _ = source_runtime.plot.add_point_with_key(source_series, x, y, key)
        _ = target_runtime.plot.add_point_with_key(target_series, y, x, key)
    source_runtime.plot.fit_to_data()
    target_runtime.plot.fit_to_data()
    var selected = PlotSelection()
    for index in range(0, data.row_count(), 3):
        _ = selected.add(data.key_at(index))
    source_runtime.set_linked_selection(selected)
    var link = PlotLink()
    link.capture(source_runtime)
    link.apply(target_runtime)

    print("Moxi analytics benchmark rows: ", data.row_count())
    print("Moxi analytics passes: ", passes)
    print("Moxi analytics histogram rows/commands: ", histogram.point_count(1), "/", histogram.build_scene().count())
    print("Moxi analytics box rows/commands: ", boxes.point_count(1), "/", boxes.build_scene().count())
    print("Moxi analytics heatmap rows/commands: ", heatmap.point_count(1), "/", heatmap.build_scene().count())
    print("Moxi analytics regression rows/commands: ", regression.point_count(1), "/", regression.build_scene().count())
    print("Moxi analytics linked selected: ", target_runtime.selected_count())
    print("Moxi analytics average operations/frame: ", metrics.average_operations())
    print("Moxi analytics checksum: ", renderer.checksum())
    print("Moxi analytics timing: /usr/bin/time reports wall-clock process time")
