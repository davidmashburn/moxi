"""Declarative plot specification contract test."""

from moxi import (
    CHANNEL_COLOR,
    CHANNEL_X,
    PLOT_LINE,
    PlotDataTable,
    PlotSpec,
    Rect,
    SCALE_LOG,
    TYPE_NOMINAL,
    plot_from_spec,
    plot_spec_from_json,
    plot_mark_name,
    test_check,
)


def main():
    var spec = PlotSpec("Telemetry")
    _ = spec.add_line("CPU", "time", "value")
    var samples = spec.add_scatter("Samples")
    test_check(spec.encode(samples, CHANNEL_COLOR, "region", TYPE_NOMINAL))
    spec.set_scale(CHANNEL_X, SCALE_LOG, 2.0, 7)
    spec.add_filter_between("value", 2.0, 10.0)
    spec.add_sort("time", True)
    spec.add_limit(50)
    spec.set_facet("region")
    _ = spec.add_annotation("peak", 20.0, 8.0)
    test_check(spec.add_hover())
    test_check(spec.add_brush())
    test_check(spec.add_pan_zoom(True, False))
    test_check(spec.add_click_select())
    test_check(spec.add_keyboard())
    test_check(spec.version == 1)
    test_check(spec.layer_count() == 2)
    test_check(spec.layer(0).x_field == "time")
    var json = spec.to_json()
    test_check(json.startswith("{\"version\":1"))
    test_check(plot_mark_name(PLOT_LINE) == "line")
    test_check(json.count_codepoints() > 100)
    test_check(json.count_codepoints() > 500)

    var data = PlotDataTable()
    test_check(data.add_float_column("time"))
    test_check(data.add_float_column("value"))
    _ = data.append(0.0, 1.0)
    _ = data.append(1.0, 2.0)
    test_check(data.set_float_field("time", 0, 10.0))
    test_check(data.set_float_field("time", 1, 20.0))
    test_check(data.set_float_field("value", 0, 4.0))
    test_check(data.set_float_field("value", 1, 8.0))
    var plot = plot_from_spec(spec, data, Rect(0.0, 0.0, 320.0, 240.0))
    test_check(plot.series_count() == 2)
    test_check(plot.point_count(1) == 2)
    test_check(plot.series[0].points[0].x == 20.0)
    test_check(plot.series[0].points[0].row_key == 1)

    var decoded = plot_spec_from_json(json)
    test_check(decoded.is_valid())
    test_check(decoded.title == "Telemetry")
    test_check(decoded.layer_count() == 2)
    test_check(decoded.encoding_count() >= 4)
    test_check(decoded.transform_count() == 3)
    test_check(decoded.scale_count() == 1)
    test_check(decoded.facet_row == "region")
    test_check(decoded.annotations[0].text == "peak")
    test_check(decoded.interaction_count() == 5)
    test_check(spec.validate())

    var derived = PlotSpec("Derived")
    _ = derived.add_line("smoothed", "time", "mean")
    derived.add_rolling_mean("value", "mean", 2)
    derived.add_bin("time", "time_bin", 5.0)
    derived.add_calculate_constant("baseline", 1.0)
    derived.add_impute("value", 0.0)
    derived.add_sample(1)
    derived.add_stack("value", "running")
    test_check(derived.validate())
    var derived_plot = plot_from_spec(derived, data, Rect(0.0, 0.0, 320.0, 240.0))
    test_check(derived_plot.point_count(1) == 1)
    var derived_decoded = plot_spec_from_json(derived.to_json())
    test_check(derived_decoded.is_valid())
    test_check(derived_decoded.transform_count() == 6)
    var invalid = plot_spec_from_json("{\"version\":99,\"layers\":[]}")
    test_check(not invalid.is_valid())
    print("Moxi plot-spec test passed")
