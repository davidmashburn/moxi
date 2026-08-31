"""Moxi Plot gallery: typed data, encodings, facets, and interactions."""

from moxi import (
    CHANNEL_COLOR,
    CHANNEL_OPACITY,
    CHANNEL_SIZE,
    CHANNEL_TOOLTIP,
    CHANNEL_X,
    Color,
    make_plot_data_fixture,
    PlotSpec,
    PlotView,
    Rect,
    SCALE_TEMPORAL,
    SoftwareSceneRenderer,
    TYPE_NOMINAL,
    plot_mark_name,
    plot_from_spec,
)


def main() raises:
    var data = make_plot_data_fixture()

    var spec = PlotSpec("Telemetry gallery")
    var line = spec.add_line("signal", "time", "value", Color(0.25, 0.75, 1.0, 1.0))
    _ = spec.encode(line, CHANNEL_COLOR, "series", TYPE_NOMINAL)
    _ = spec.set_tooltip_fields(line, "time,value,series,region")
    var dots = spec.add_dot("samples", "time", "value", Color(1.0, 0.45, 0.30, 1.0))
    _ = spec.encode(dots, CHANNEL_COLOR, "series", TYPE_NOMINAL)
    _ = spec.encode(dots, CHANNEL_SIZE, "size")
    _ = spec.encode(dots, CHANNEL_OPACITY, "opacity")
    _ = spec.encode(dots, CHANNEL_TOOLTIP, "time,value,series")
    spec.set_scale(CHANNEL_X, SCALE_TEMPORAL)
    spec.set_facet("region")
    _ = spec.add_hover(True, True)
    _ = spec.add_brush()
    _ = spec.add_pan_zoom()
    _ = spec.add_click_select()
    _ = spec.add_lasso()
    _ = spec.add_keyboard()

    var view = PlotView(spec, data, Rect(0.0, 0.0, 860.0, 520.0))
    var scene = view.build_scene()
    var packet = view.build_render_packet()
    var renderer = SoftwareSceneRenderer(860, 520)
    renderer.render_scene(scene)
    var main_checksum = renderer.checksum()

    # The gallery also exercises the statistical recipe boundary. Each recipe
    # owns its transformed table, so independent panels can be linked by row
    # keys without sharing mutable render state.
    var histogram_spec = PlotSpec("Histogram")
    _ = histogram_spec.add_histogram("distribution", "value", 8)
    var histogram = plot_from_spec(
        histogram_spec, data, Rect(0.0, 0.0, 420.0, 260.0)
    )
    renderer.render_scene(histogram.build_scene())
    var histogram_checksum = renderer.checksum()

    var box_spec = PlotSpec("Box summary")
    _ = box_spec.add_box("groups", "value", "series")
    var boxes = plot_from_spec(box_spec, data, Rect(0.0, 0.0, 420.0, 260.0))
    renderer.render_scene(boxes.build_scene())
    var box_checksum = renderer.checksum()

    var heatmap_spec = PlotSpec("Heatmap")
    _ = heatmap_spec.add_heatmap("density", "x", "value", 6, 6)
    var heatmap = plot_from_spec(
        heatmap_spec, data, Rect(0.0, 0.0, 420.0, 260.0)
    )
    renderer.render_scene(heatmap.build_scene())
    var heatmap_checksum = renderer.checksum()

    var regression_spec = PlotSpec("Regression")
    _ = regression_spec.add_regression("fit", "x", "value", 24)
    var regression = plot_from_spec(
        regression_spec, data, Rect(0.0, 0.0, 420.0, 260.0)
    )
    renderer.render_scene(regression.build_scene())
    var regression_checksum = renderer.checksum()

    print("Moxi Plot gallery")
    print("  layers: ", spec.layer_count(), " (", plot_mark_name(spec.layer(0).mark), ", ", plot_mark_name(spec.layer(1).mark), ")")
    print("  rows: ", data.row_count(), " facets: ", view.runtime.plot.facet_count())
    print("  scene commands: ", scene.count())
    print("  render packet lines/instances/batches/bytes: ", packet.line_count(), "/", packet.instance_count(), "/", packet.batch_count(), "/", packet.total_byte_count())
    print("  packet fallback required: ", packet.fallback_required)
    print("  checksum: ", main_checksum)
    print("  accessibility nodes: ", view.accessibility().count())
    print("  histogram rows/commands/checksum: ", histogram.point_count(1), "/", histogram.build_scene().count(), "/", histogram_checksum)
    print("  box rows/commands/checksum: ", boxes.point_count(1), "/", boxes.build_scene().count(), "/", box_checksum)
    print("  heatmap rows/commands/checksum: ", heatmap.point_count(1), "/", heatmap.build_scene().count(), "/", heatmap_checksum)
    print("  regression rows/commands/checksum: ", regression.point_count(1), "/", regression.build_scene().count(), "/", regression_checksum)
