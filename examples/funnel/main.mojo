"""Replay the sorted stage inspector with the real PlotView event dispatcher."""
from std.time import perf_counter
from moxi import Rect, Point, Color, Event, CLICK_KIND, KEY_DOWN_KIND, KEY_RIGHT, KEY_ENTER, KEY_ESCAPE, SvgSceneRenderer, test_check
from moxi_plot.plot_spec import PlotSpec
from moxi_plot.plot_view import PlotView
from moxi_plot.plot_spec_types import PlotLayoutVersion
from moxi_plot.plot_marks import PLOT_FUNNEL
from moxi_plot.plot_data import PlotDataTable


def main() raises:
    var spec = PlotSpec()
    _ = spec.add_catalog_mark(PLOT_FUNNEL, "Pipeline", "stage", "y")
    spec.layers[0].layout_version = PlotLayoutVersion.SPECIALIZED
    _ = spec.add_click_select()
    _ = spec.add_keyboard()
    var data = PlotDataTable()
    _ = data.add_string_column("stage")
    var stages: List[String] = ["A", "B", "C"]
    var values: List[Float32] = [3, 9, 6]
    for i in range(3):
        _ = data.append_with_key(10 + i, Float32(i), values[i])
        _ = data.set_string_field("stage", i, stages[i])
    test_check(spec.validate_data(data))
    var view = PlotView(spec, data, Rect(0, 0, 640, 420))
    var svg = SvgSceneRenderer(640, 420)
    svg.render_scene(view.build_scene())
    with open("native.svg", "w") as output:
        output.write(svg.markup())
    var semantics = view.runtime.plot.accessibility()
    test_check(semantics.node_for_id(500000).label == "B")
    var keys: List[Int] = [11, 12, 10]
    var click = Event()
    click.kind = CLICK_KIND
    for rank in range(3):
        var p = view.runtime.plot.series[0].points[rank]
        test_check(p.row_key == keys[rank] and len(p.vertices) == 4)
        p.x = 0
        p.y = 2.5 - Float32(rank)
        click.position = view.runtime.plot.screen_point(p)
        test_check(view.dispatch(click))
        test_check(view.runtime.selected.row_key == keys[rank])
    var selected = SvgSceneRenderer(640, 420)
    selected.render_scene(view.build_scene())
    with open("selected.svg", "w") as output:
        output.write(selected.markup())
    with open("source.csv", "w") as output:
        output.write(view.data_table_csv())
    _ = data.patch_key(10, 0, 12)
    test_check(view.replace_data(data))
    test_check(view.runtime.plot.series[0].points[0].row_key == 10)
    click.position = Point(click.position.x, view.runtime.plot.plot_area.y + 10)
    test_check(view.dispatch(click))
    test_check(view.runtime.selected.row_key == 10)
    var key = Event()
    key.kind = KEY_DOWN_KIND
    key.key = KEY_ESCAPE
    test_check(view.dispatch(key))
    key.key = KEY_RIGHT
    test_check(view.dispatch(key))
    test_check(view.runtime.hovered.row_key == 10)
    key.key = KEY_RIGHT
    test_check(view.dispatch(key))
    test_check(view.runtime.hovered.row_key == 11)
    key.key = KEY_ENTER
    test_check(view.dispatch(key))
    test_check(view.runtime.selected.row_key == 11)
    var updated = SvgSceneRenderer(640, 420)
    updated.render_scene(view.build_scene())
    with open("updated.svg", "w") as output:
        output.write(updated.markup())
    print("Clicked B, C, A by stable key. Updated A to 12 and selected it at the top.")
    # Stable ties, zero-area stages and invalid measures use the same public entry.
    _ = data.patch_key(10, 0, 9)
    _ = data.patch_key(12, 2, 0)
    test_check(view.replace_data(data))
    test_check(view.runtime.plot.series[0].points[0].row_key == 10)
    test_check(view.runtime.plot.series[0].points[1].row_key == 11)
    test_check(not view.runtime.plot.series[0].points[2].interactive)
    _ = data.patch_key(10, 0, -1)
    test_check(not spec.validate_data(data))
    _ = data.patch_key(10, 0, 0)
    _ = data.patch_key(11, 1, 0)
    test_check(not spec.validate_data(data))
    _ = data.patch_key(10, 0, 3)
    _ = data.patch_key(11, 1, 9)
    _ = data.patch_key(12, 2, 6)
    var start = perf_counter()
    var commands = 0
    for _ in range(100):
        var sample = PlotView(spec, data, Rect(0, 0, 640, 420))
        commands += sample.build_scene().count()
    print("100 native PlotView builds and Scenes: ", perf_counter() - start, "; commands=", commands)
    # Adjacent Float64 values must sort before conversion to screen coordinates.
    _ = data.add_float64_column("amount")
    _ = data.set_float64_field("amount", 0, 1.0)
    _ = data.set_float64_field("amount", 1, 1.000000001)
    _ = data.set_float64_field("amount", 2, 1.0e100)
    var wide = PlotSpec()
    _ = wide.add_catalog_mark(PLOT_FUNNEL, "Pipeline", "stage", "amount")
    wide.layers[0].layout_version = PlotLayoutVersion.SPECIALIZED
    test_check(wide.validate_data(data))
    var sorted = PlotView(wide, data, Rect(0, 0, 640, 420))
    test_check(sorted.runtime.plot.series[0].points[0].row_key == 12)
    test_check(sorted.runtime.plot.series[0].points[1].row_key == 11)
    _ = data.add_int_column("count")
    for i in range(3):
        _ = data.set_int_field("count", i, Int64(9007199254740992) + Int64(i == 1))
    wide.layers[0].y_field = "count"
    var counts = PlotView(wide, data, Rect(0, 0, 640, 420))
    test_check(counts.runtime.plot.series[0].points[0].row_key == 11)
    test_check(counts.runtime.plot.series[0].points[1].row_key == 10)
    test_check(counts.runtime.plot.series[0].points[2].row_key == 12)
