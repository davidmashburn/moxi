"""Replay default row-layout specs for the three E06 families."""
from moxi import CLICK_KIND, Event, Rect, test_check
from moxi_plot.plot_data import PlotDataTable
from moxi_plot.plot_marks import PLOT_ARC_DIAGRAM, PLOT_BUMP, PLOT_PARALLEL
from moxi_plot.plot_point import PlotGlyphKind
from moxi_plot.plot_spec import PlotSpec
from moxi_plot.plot_view import PlotView


def main():
    var data = PlotDataTable()
    for row in range(3):
        _ = data.append_with_key(10 + row, Float32(row+1), Float32(2*row+1))
    for mark in [PLOT_PARALLEL, PLOT_BUMP, PLOT_ARC_DIAGRAM]:
        var spec = PlotSpec()
        _ = spec.add_catalog_mark(mark,"Legacy","x","y")
        _ = spec.add_click_select()
        test_check(spec.validate_data(data))
        var view = PlotView(spec,data,Rect(0,0,640,420))
        test_check(len(view.runtime.plot.series[0].points) == 3)
        for row in range(3):
            var point = view.runtime.plot.series[0].points[row]
            test_check(point.glyph.value == PlotGlyphKind.ROW.value)
            var click = Event()
            click.kind = CLICK_KIND
            click.position = view.runtime.plot.screen_point(point)
            test_check(view.dispatch(click))
            test_check(view.runtime.selected.row_key == 10+row)
