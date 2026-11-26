"""Atomic source updates and viewport-fitted arc geometry through PlotView."""
from std.math import abs, sqrt
from std.sys import argv
from moxi import Rect, Point, Color, Event, CLICK_KIND, SvgSceneRenderer, CanvasSceneRenderer, test_check
from moxi_plot.plot_data import PlotDataTable
from moxi_plot.plot_marks import PLOT_PARALLEL, PLOT_BUMP, PLOT_ARC_DIAGRAM
from moxi_plot.plot_point import PlotPoint
from moxi_plot.plot_spec import PlotSpec
from moxi_plot.plot_spec_types import PlotLayoutVersion
from moxi_plot.plot_view import PlotView


def require(condition: Bool, message: String) raises:
    if not condition: raise Error(message)


def source() -> PlotDataTable:
    var data = PlotDataTable()
    _ = data.add_string_column("name")
    _ = data.add_string_column("target")
    _ = data.add_float64_column("score")
    _ = data.add_float64_column("next")
    var names: List[String] = ["A", "B", "C"]
    var targets: List[String] = ["C", "A", "B"]
    for row in range(3):
        _ = data.append_with_key(10+row, Float32(row), Float32(row+1))
        _ = data.set_string_field("name", row, names[row])
        _ = data.set_string_field("target", row, targets[row])
        _ = data.set_float64_field("score", row, Float64(row+1))
        _ = data.set_float64_field("next", row, Float64(3-row))
    return data^


def specification(mark: Int) -> PlotSpec:
    var spec = PlotSpec()
    _ = spec.add_catalog_mark(mark, "Records", "name", "score", x2_field="target" if mark == PLOT_ARC_DIAGRAM else "")
    spec.layers[0].layout_version = PlotLayoutVersion.SPECIALIZED
    if mark != PLOT_ARC_DIAGRAM: spec.layers[0].series_fields_json = "[\"next\"]"
    _ = spec.add_click_select()
    return spec^


def svg(mut view: PlotView) raises -> String:
    var renderer = SvgSceneRenderer(Int(view.runtime.plot.bounds.width), Int(view.runtime.plot.bounds.height))
    renderer.render_scene(view.build_scene())
    return renderer.markup()


def select_first(mut view: PlotView) raises:
    var point = view.runtime.plot.series[0].points[0]
    for candidate in view.runtime.plot.series[0].points:
        if candidate.interactive:
            point = candidate
            break
    require(point.interactive and len(point.vertices) > 0, "missing selectable trace")
    var vertex = point.vertices[24] if view.spec.layers[0].mark == PLOT_ARC_DIAGRAM else point.vertices[0]
    var click = Event()
    click.kind = CLICK_KIND
    click.position = view.runtime.plot.screen_point(PlotPoint(vertex.x, vertex.y))
    require(view.dispatch(click) and view.runtime.selected.row_key == 10, "source-key click failed")


def state(mut view: PlotView) raises -> String:
    # Include committed/pending sources, geometry, selection and scheduler state.
    return String(view.data.version(), "|", view.data_table_csv(), "|", view.spec.to_json(), "|", svg(view),
                  "|", view.runtime.selected.row_key, "|", view.selected_count(), "|", view.reactive_dirty(),
                  "|", view.pending_data_valid, "|", view.pending_spec_valid, "|", view.pending_data.version(),
                  "|", view.pending_data.table.csv(), "|", view.pending_spec.to_json(),
                  "|", view.reactive_work_counters().invalidation_count,
                  "|", view.reactive_work_counters().dirty_consumed)


def check_invalid_updates(mark: Int, queue_data: Bool = False, queue_spec: Bool = False) raises:
    var data = source()
    var spec = specification(mark)
    var view = PlotView(spec, data, Rect(0,0,640,420))
    select_first(view)
    var changed = data.clone()
    _ = changed.set_float64_field("score", 0, 4)
    var queued_spec = spec.clone()
    queued_spec.title = "Queued valid spec"
    if queue_spec: require(view.request_spec(queued_spec, changed), "valid spec was rejected")
    elif queue_data: require(view.request_data(changed), "valid data was rejected")
    var before = state(view)
    # Both the primary measure and the additional parallel/bump dimension must
    # reject invalid input before touching a pending replacement.
    var fields: List[String] = ["score"]
    if mark != PLOT_ARC_DIAGRAM: fields.append("next")
    for field in fields:
        var invalid = data.clone()
        _ = invalid.set_float64_field(field, 0, Float64(1)/Float64(0))
        require(not spec.validate_data(invalid), "invalid fixture unexpectedly validated")
        require(not view.replace_data(invalid), "replace_data accepted infinity")
        require(state(view) == before, "replace_data changed retained state")
        require(not view.request_data(invalid), "request_data accepted infinity")
        require(state(view) == before, "request_data changed retained state")
        require(not view.request_spec(spec, invalid), "request_spec accepted infinity")
        require(state(view) == before, "request_spec changed retained state")
        view.replace_spec(spec, invalid)
        require(state(view) == before, "replace_spec changed retained state")
    require(view.rebuild_if_dirty() == (queue_spec or queue_data), "pending rebuild was lost or introduced")
    if queue_spec or queue_data:
        require(view.data.table.csv() == changed.csv(), "rebuild committed the rejected source")
        require(not view.pending_spec_valid and not view.pending_data_valid and not view.reactive_dirty(), "rebuild left pending state")
    else:
        require(state(view) == before, "clean rebuild changed state")
        require(view.replace_data(changed), "valid eager update was rejected")
        require(view.data.table.csv() == changed.csv(), "valid eager source missing")
    require(len(view.runtime.plot.series[0].points) > 0, "valid update erased geometry")


def check_circles(view: PlotView) raises:
    var area = view.runtime.plot.plot_area
    for edge in view.runtime.plot.series[0].points:
        if not edge.interactive: continue
        require(len(edge.vertices) == 49, "arc vertex count changed")
        var first = view.runtime.plot.screen_point(PlotPoint(edge.vertices[0].x,edge.vertices[0].y))
        var last = view.runtime.plot.screen_point(PlotPoint(edge.vertices[48].x,edge.vertices[48].y))
        var center = Point((first.x+last.x)*0.5, first.y)
        var radius = (last.x-first.x)*0.5
        for vertex in edge.vertices:
            # Check raw vertices too: screen_point clamps outside the domain.
            require(vertex.x >= 0 and vertex.x <= 1 and vertex.y >= -0.00001 and vertex.y <= 1.00001, "arc exceeds the layout domain")
            var screen = view.runtime.plot.screen_point(PlotPoint(vertex.x,vertex.y))
            var dx = screen.x-center.x
            var dy = screen.y-center.y
            require(abs(sqrt(dx*dx+dy*dy)-radius)<0.002, "arc became an ellipse or a clipped semicircle")
            require(screen.x >= area.x-0.002 and screen.x <= area.x+area.width+0.002 and screen.y >= area.y-0.002 and screen.y <= area.y+area.height+0.002, "arc escaped the plot area")


def export(mut view: PlotView, output: String, name: String) raises:
    with open(output+"/"+name+".svg", "w") as f: f.write(svg(view))
    var canvas = CanvasSceneRenderer(Int(view.runtime.plot.bounds.width), Int(view.runtime.plot.bounds.height), Color(1,1,1,1))
    canvas.render_scene(view.build_scene())
    require(canvas.error_count() == 0, "native Canvas export failed")
    canvas.write_png(output+"/"+name+".png")


def check_resize(output: String) raises:
    var view = PlotView(specification(PLOT_ARC_DIAGRAM), source(), Rect(0,0,640,420))
    check_circles(view)
    select_first(view)
    export(view, output, "arc-default")
    var original_csv = view.data_table_csv()
    for bounds in [Rect(0,0,960,420), Rect(0,0,420,640), Rect(0,0,1200,240), Rect(0,0,640,420)]:
        view.set_bounds(bounds)
        require(view.runtime.selected.row_key == 10 and view.selected_count() == 1, "resize lost stable selection")
        require(view.data_table_csv() == original_csv, "resize changed the source")
        check_circles(view)
        var fresh = PlotView(specification(PLOT_ARC_DIAGRAM), source(), bounds)
        select_first(fresh)
        require(svg(view) == svg(fresh), "resized and fresh exports disagree")
        export(view, output, String("arc-resized-", Int(bounds.width), "x", Int(bounds.height)))


def check_fresh_wide(output: String) raises:
    var view = PlotView(specification(PLOT_ARC_DIAGRAM), source(), Rect(0,0,960,420))
    check_circles(view)
    for row in range(3):
        var edge = view.runtime.plot.series[0].points[row]
        var apex = edge.vertices[24]
        var click = Event()
        click.kind = CLICK_KIND
        click.position = view.runtime.plot.screen_point(PlotPoint(apex.x,apex.y))
        require(view.dispatch(click) and view.runtime.selected.row_key == 10+row, "wide arc apex lost source identity")
    export(view, output, "arc-fresh-wide")


def main() raises:
    var output = argv()[1] if len(argv()) > 1 else "/tmp"
    var failed = False
    for mark in [PLOT_PARALLEL, PLOT_BUMP, PLOT_ARC_DIAGRAM]:
        try:
            check_invalid_updates(mark)
            check_invalid_updates(mark, queue_data=True)
            check_invalid_updates(mark, queue_spec=True)
            print("PASS atomic updates", mark)
        except e:
            print("FAIL atomic updates", mark, e)
            failed = True
    try:
        check_resize(output)
        print("PASS arc resize")
    except e:
        print("FAIL arc resize", e)
        failed = True
    try:
        check_fresh_wide(output)
        print("PASS fresh wide arc")
    except e:
        print("FAIL fresh wide arc", e)
        failed = True
    test_check(not failed)
