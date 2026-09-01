"""Moxi Plot gallery: typed data, encodings, facets, and interactions."""

from moxi import (
    CHANNEL_COLOR,
    CHANNEL_OPACITY,
    CHANNEL_SIZE,
    CHANNEL_TOOLTIP,
    CHANNEL_X,
    ClickEvent,
    Color,
    Event,
    make_plot_data_fixture,
    MOD_SHIFT,
    PlotLink,
    PlotSpec,
    PlotView,
    PointerEvent,
    POINTER_DOWN_KIND,
    POINTER_MOVE_KIND,
    POINTER_UP_KIND,
    Point,
    Rect,
    SCALE_TEMPORAL,
    ScrollEvent,
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

    # Replay the same interactions a native host sends to PlotView. This keeps
    # the standalone demo useful in CI while the browser exposes the identical
    # trace to a person using the canvas.
    var first = view.runtime.plot.screen_point(
        view.runtime.plot.series[0].points[0]
    )
    var hover_changed = view.dispatch(
        Event(PointerEvent(POINTER_MOVE_KIND, first))
    )
    var click_changed = view.dispatch(Event(ClickEvent(first)))
    var zoom_before = view.runtime.plot.x_scale.data_max
    var scroll = Event(ScrollEvent(Point(0.0, 10.0)))
    scroll.position = first
    var zoom_changed = view.dispatch(scroll)
    var zoom_domain_changed = view.runtime.plot.x_scale.data_max != zoom_before
    var brush_start = Point(
        view.runtime.plot.bounds.x,
        view.runtime.plot.bounds.y,
    )
    var brush_end = Point(
        view.runtime.plot.bounds.x + view.runtime.plot.bounds.width - 1.0,
        view.runtime.plot.bounds.y + view.runtime.plot.bounds.height - 1.0,
    )
    var brush_down = Event(PointerEvent(POINTER_DOWN_KIND, brush_start))
    brush_down.modifiers = MOD_SHIFT
    _ = view.dispatch(brush_down)
    _ = view.dispatch(Event(PointerEvent(POINTER_MOVE_KIND, brush_end)))
    _ = view.dispatch(Event(PointerEvent(POINTER_UP_KIND, brush_end)))
    var brushed_count = view.selected_count()
    var interactive_scene = view.build_scene()
    renderer.render_scene(interactive_scene)
    var interactive_checksum = renderer.checksum()

    var linked_spec = PlotSpec("Linked source")
    _ = linked_spec.add_scatter("linked", "x", "y")
    _ = linked_spec.add_click_select()
    var linked_view = PlotView(
        linked_spec,
        data,
        Rect(0.0, 0.0, 320.0, 220.0),
    )
    var link = PlotLink()
    link.capture(view.runtime)
    link.apply(linked_view.runtime)
    var linked_count = linked_view.selected_count()

    # Mutating the source increments its version; replace_data() then rebuilds
    # the retained scene from the new snapshot and invalidates render caches.
    var reactive_data = data.clone()
    var source_version = reactive_data.version
    var next_value = reactive_data.float_field_at("value", 0) + 0.75
    _ = reactive_data.set_float_field("value", 0, next_value)
    var data_refreshed = view.replace_data(reactive_data)
    var refreshed_scene = view.build_scene()
    renderer.render_scene(refreshed_scene)
    var refreshed_checksum = renderer.checksum()

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
    print("  replay hover/click/zoom: ", hover_changed, "/", click_changed, "/", zoom_changed, " (domain max changed: ", zoom_domain_changed, ")")
    print("  brush selected / linked: ", brushed_count, " / ", linked_count)
    print("  interactive checksum: ", interactive_checksum)
    print("  reactive source version/refreshed/checksum: ", source_version, " -> ", reactive_data.version, " / ", data_refreshed, " / ", refreshed_checksum)
    print("  accessibility nodes: ", view.accessibility().count())
    print("  histogram rows/commands/checksum: ", histogram.point_count(1), "/", histogram.build_scene().count(), "/", histogram_checksum)
    print("  box rows/commands/checksum: ", boxes.point_count(1), "/", boxes.build_scene().count(), "/", box_checksum)
    print("  heatmap rows/commands/checksum: ", heatmap.point_count(1), "/", heatmap.build_scene().count(), "/", heatmap_checksum)
    print("  regression rows/commands/checksum: ", regression.point_count(1), "/", regression.build_scene().count(), "/", regression_checksum)
