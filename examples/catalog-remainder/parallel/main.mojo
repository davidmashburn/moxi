from moxi import Rect, Event, CLICK_KIND, SvgSceneRenderer, test_check
from moxi_plot.plot_data import PlotDataTable
from moxi_plot.plot_marks import PLOT_PARALLEL
from moxi_plot.plot_spec import PlotSpec
from moxi_plot.plot_spec_types import PlotLayoutVersion
from moxi_plot.plot_view import PlotView


def main() raises:
    var data = PlotDataTable()
    _ = data.add_string_column("team")
    var teams: List[String] = ["East", "West"]
    for row in range(2):
        _ = data.append_with_key(10 + row, Float32(row), 0)
        _ = data.set_string_field("team", row, teams[row])
    var fields: List[String] = ["A", "B", "C"]
    var east: List[Float64] = [3, 9, 6]
    var west: List[Float64] = [8, 4, 7]
    for i in range(3):
        _ = data.add_float64_column(fields[i])
        _ = data.set_float64_field(fields[i], 0, east[i])
        _ = data.set_float64_field(fields[i], 1, west[i])
    var spec = PlotSpec()
    _ = spec.add_catalog_mark(PLOT_PARALLEL, "Teams", "team", "A")
    test_check(spec.validate_data(data))
    spec.layers[0].layout_version = PlotLayoutVersion.SPECIALIZED
    spec.layers[0].series_fields_json = "[\"B\",\"C\"]"
    _ = spec.add_click_select()
    test_check(spec.validate_data(data))
    var view = PlotView(spec, data, Rect(0, 0, 640, 420))
    var svg = SvgSceneRenderer(640, 420)
    svg.render_scene(view.build_scene())
    with open("native.svg", "w") as output: output.write(svg.markup())
    var checked = 0
    for i in range(len(view.runtime.plot.series[0].points)):
        var p = view.runtime.plot.series[0].points[i]
        if not p.interactive: continue
        test_check(len(p.vertices) == 3)
        for j in range(2):
            var probe = p.copy()
            var a = p.vertices[j]
            var b = p.vertices[j+1]
            probe.x = a.x + (b.x-a.x)*0.25
            probe.y = a.y + (b.y-a.y)*0.25
            var click = Event()
            click.kind = CLICK_KIND
            click.position = view.runtime.plot.screen_point(probe)
            test_check(view.dispatch(click) == (j == 0))
            test_check(view.runtime.selected.row_key == p.row_key)
            checked += 1
    test_check(checked == 4)
    _ = data.set_float64_field("B", 0, 4)
    test_check(view.replace_data(data))
    test_check(view.runtime.plot.series[0].points[3].vertices[1].y == 0.5)
    _ = data.add_int_column("count")
    for i in range(2):
        _ = data.set_int_field("count",i,Int64(9007199254740992)+Int64(i))
    spec.layers[0].series_fields_json = "[\"count\",\"C\"]"
    _ = data.set_float64_field("A",0,-1e308)
    _ = data.set_float64_field("A",1,1e308)
    var extreme = PlotView(spec,data,Rect(0,0,640,420))
    for row in range(2):
        var p = extreme.runtime.plot.series[0].points[3+row]
        test_check(p.vertices[0].y == Float32(row) and p.vertices[1].y == Float32(row))
