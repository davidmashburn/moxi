"""Moxi Plot gallery: typed data, encodings, facets, and interactions."""

from moxi import (
    CHANNEL_COLOR,
    CHANNEL_OPACITY,
    CHANNEL_SIZE,
    CHANNEL_TOOLTIP,
    CHANNEL_X,
    Color,
    PlotDataTable,
    PlotSpec,
    PlotView,
    Rect,
    SCALE_TEMPORAL,
    SoftwareSceneRenderer,
    TYPE_NOMINAL,
    plot_mark_name,
)


def main() raises:
    var data = PlotDataTable()
    _ = data.add_timestamp_column("time")
    _ = data.add_float_column("value")
    _ = data.add_category_column("series")
    _ = data.add_category_column("region")
    _ = data.add_float_column("size")
    _ = data.add_float_column("opacity")
    for index in range(12):
        var key = data.append(Float32(index), Float32((index * 7) % 10))
        _ = data.set_int_field("time", index, Int64(1700000000 + index * 3600))
        _ = data.set_float_field("value", index, Float32((index * 7) % 10) + 1.0)
        _ = data.set_category_field("series", index, "A" if index % 2 == 0 else "B")
        _ = data.set_category_field("region", index, "north" if index < 6 else "south")
        _ = data.set_float_field("size", index, 4.0 + Float32(index % 4) * 2.0)
        _ = data.set_float_field("opacity", index, 0.55 + Float32(index % 3) * 0.2)
        _ = key

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
    _ = spec.add_keyboard()

    var view = PlotView(spec, data, Rect(0.0, 0.0, 860.0, 520.0))
    var scene = view.build_scene()
    var renderer = SoftwareSceneRenderer(860, 520)
    renderer.render_scene(scene)
    print("Moxi Plot gallery")
    print("  layers: ", spec.layer_count(), " (", plot_mark_name(spec.layer(0).mark), ", ", plot_mark_name(spec.layer(1).mark), ")")
    print("  rows: ", data.row_count(), " facets: ", view.runtime.plot.facet_count())
    print("  scene commands: ", scene.count())
    print("  checksum: ", renderer.checksum())
    print("  accessibility nodes: ", view.accessibility().count())
