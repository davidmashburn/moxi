"""Declarative plot specification contract test."""

from moxi import PLOT_LINE, PlotDataTable, PlotSpec, Rect, plot_from_spec, plot_mark_name, test_check


def main():
    var spec = PlotSpec("Telemetry")
    _ = spec.add_line("CPU", "time", "value")
    _ = spec.add_scatter("Samples")
    test_check(spec.version == 1)
    test_check(spec.layer_count() == 2)
    test_check(spec.layer(0).x_field == "time")
    var json = spec.to_json()
    test_check(json.startswith("{\"version\":1"))
    test_check(plot_mark_name(PLOT_LINE) == "line")
    test_check(json.count_codepoints() > 100)

    var data = PlotDataTable()
    _ = data.append(0.0, 1.0)
    _ = data.append(1.0, 2.0)
    var plot = plot_from_spec(spec, data, Rect(0.0, 0.0, 320.0, 240.0))
    test_check(plot.series_count() == 2)
    test_check(plot.point_count(1) == 2)
    print("Moxi plot-spec test passed")
