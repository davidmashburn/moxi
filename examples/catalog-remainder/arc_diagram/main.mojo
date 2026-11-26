from moxi import Rect, Event, CLICK_KIND, SvgSceneRenderer, test_check
from moxi_plot.plot_data import PlotDataTable
from moxi_plot.plot_marks import PLOT_ARC_DIAGRAM
from moxi_plot.plot_spec import PlotSpec
from moxi_plot.plot_spec_types import PlotLayoutVersion
from moxi_plot.plot_view import PlotView


def main() raises:
    var data = PlotDataTable()
    var sources: List[String] = ["A", "B", "C"]
    var targets: List[String] = ["C", "A", "B"]
    var weights: List[Float32] = [3, 9, 6]
    _ = data.add_string_column("source")
    _ = data.add_string_column("target")
    for row in range(3):
        _ = data.append_with_key(10 + row, Float32(row), weights[row])
        _ = data.set_string_field("source",row,sources[row])
        _ = data.set_string_field("target",row,targets[row])
    var spec = PlotSpec()
    _ = spec.add_catalog_mark(PLOT_ARC_DIAGRAM, "Edges", "source", "y", x2_field="target")
    spec.layers[0].layout_version = PlotLayoutVersion.SPECIALIZED
    _ = spec.add_click_select()
    test_check(spec.validate_data(data))
    var view = PlotView(spec, data, Rect(0, 0, 640, 420))
    var svg = SvgSceneRenderer(640,420)
    svg.render_scene(view.build_scene())
    with open("native.svg", "w") as output: output.write(svg.markup())
    test_check(len(view.runtime.plot.series[0].points) == 6)
    for row in range(3):
        var probe = view.runtime.plot.series[0].points[row]
        test_check(len(probe.vertices) == 49)
        probe.x = probe.vertices[24].x
        probe.y = probe.vertices[24].y
        var click = Event()
        click.kind = CLICK_KIND
        click.position = view.runtime.plot.screen_point(probe)
        test_check(view.dispatch(click))
        test_check(view.runtime.selected.row_key == 10+row)
    _ = data.set_string_field("target",0,"A")
    test_check(view.replace_data(data))
    test_check(len(view.runtime.plot.series[0].points) == 5)
    _ = data.patch_key(11,1,-1)
    test_check(not spec.validate_data(data))
