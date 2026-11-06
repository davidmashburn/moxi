"""Wave A fixture harness, called by scripts/wave_a/verify.py's generated driver."""
from std.time import perf_counter
from moxi import Rect, Point, Color, Event, CLICK_KIND, KEY_DOWN_KIND, KEY_RIGHT, KEY_ENTER, KEY_ESCAPE, SoftwareSceneRenderer, CanvasSceneRenderer, SvgSceneRenderer, test_check
from moxi_plot.plot_spec import plot_spec_from_json, plot_from_spec
from moxi_plot.plot_point import PlotGlyphKind
from moxi_plot.plot_data import PlotDataTable
from moxi_plot.plot_runtime import PlotRuntime
from moxi_plot.plot_view import PlotView
from moxi_plot.plot_data import COLUMN_STRING, COLUMN_CATEGORY
from moxi_plot.plot_spec_types import PlotLayoutVersion
from moxi_plot.plot_marks import PLOT_LOLLIPOP, PLOT_GROUPED_BAR, PLOT_STACKED_BAR
from moxi_plot.plot_spec_json import _string_array


def check_case(name: String, document: String, data: PlotDataTable, output: String) raises:
    var spec = plot_spec_from_json(document)
    test_check(spec.validate())
    test_check(spec.validate_data(data))
    print("spec|", name, "|", spec.to_json())
    var plot = plot_from_spec(spec, data, Rect(0, 0, 640, 480))
    test_check(plot.series[0].has_layout_domain)
    test_check(plot.build_render_packet().fallback_required)
    for p in plot.series[0].points:
        print("glyph|", name, "|", p.glyph.value, "|", p.row_key, "|", p.part, "|", p.x, "|", p.y, "|", p.x2, "|", p.y2)
    var runtime = PlotRuntime(Rect(0, 0, 640, 480))
    runtime.plot = plot_from_spec(spec, data, Rect(0, 0, 640, 480))
    for index in range(len(plot.series[0].points)):
        var p = plot.series[0].points[index]
        if not p.interactive:
            continue
        var center = p
        center.x = (p.x+p.x2)*0.5
        center.y = (p.y+p.y2)*0.5
        var hit = runtime.hit_test(plot.screen_point(center), 1.0)
        test_check(hit.found())
        test_check(hit.row_key == p.row_key)
    var software = SoftwareSceneRenderer(640, 480, Color(1,1,1,1))
    var canvas = CanvasSceneRenderer(640, 480, Color(1,1,1,1))
    var svg = SvgSceneRenderer(640,480)
    software.render_scene(plot.build_scene())
    canvas.render_scene(plot.build_scene())
    svg.render_scene(plot.build_scene())
    test_check(canvas.error_count() == 0)
    canvas.write_png(output + "/" + name + "-canvas.png")
    with open(output + "/" + name + "-software.ppm", "w") as file:
        file.write(software.ppm())
    with open(output + "/" + name + "-scene.svg", "w") as file:
        file.write(svg.markup())
    # Real event dispatch, source table and atomic source update; offscreen replay.
    var view = PlotView(spec, data, Rect(0,0,640,480))
    var first = plot.series[0].points[0]
    first.x = (first.x+first.x2)*0.5
    first.y = (first.y+first.y2)*0.5
    var click = Event()
    click.kind = CLICK_KIND
    click.position = plot.screen_point(first)
    test_check(view.dispatch(click))
    test_check(view.selected_count() == 1)
    test_check(view.accessibility().count() >= data.row_count()+2)
    test_check(not view.runtime.plot.set_point(1,0,99,99))
    var selected = CanvasSceneRenderer(640,480,Color(1,1,1,1))
    selected.render_scene(view.build_scene())
    selected.write_png(output+"/"+name+"-selected.png")
    with open(output+"/"+name+"-table.csv", "w") as file:
        file.write(view.data_table_csv())
    print("selection|", name, "|", first.row_key, "|", click.position.x, "|", click.position.y)
    var changed = data.clone()
    for column_index in range(len(data.columns)):
        var field = data.columns[column_index].name
        if data.columns[column_index].kind == COLUMN_STRING or data.columns[column_index].kind == COLUMN_CATEGORY or field == spec.layers[0].total_field:
            continue
        for row in range(1):
            _ = changed.set_float_field(field, row, data.float_field_at(field,row)*1.25)
    test_check(spec.validate_data(changed))
    test_check(view.replace_data(changed))
    test_check(view.selected_count() == 0)
    var updated = CanvasSceneRenderer(640,480,Color(1,1,1,1))
    updated.render_scene(view.build_scene())
    updated.write_png(output+"/"+name+"-updated.png")
    test_check(view.replace_data(data))
    var restored = CanvasSceneRenderer(640,480,Color(1,1,1,1))
    restored.render_scene(view.build_scene())
    restored.write_png(output+"/"+name+"-restored.png")
    var key = Event()
    key.kind = KEY_DOWN_KIND
    key.key = KEY_RIGHT
    test_check(view.dispatch(key))
    test_check(view.runtime.hovered.row_key == data.key_at(0))
    test_check(view.dispatch(key))
    test_check(view.runtime.hovered.row_key == data.key_at(1))
    key.key = KEY_ENTER
    test_check(view.dispatch(key))
    test_check(view.selected_count() == 1)
    var linked = view.runtime.selection()
    view.runtime.set_linked_selection(linked)
    test_check(view.selected_count() == 1)
    key.key = KEY_ESCAPE
    test_check(view.dispatch(key))
    test_check(view.selected_count() == 0)
    var future = spec.clone()
    future.layers[0].layout_version = PlotLayoutVersion(99)
    test_check(not future.validate())
    var malformed = data.clone()
    _ = malformed.set_float_field(spec.layers[0].y_field,0,Float32(1.0)/Float32(0.0))
    var invalid_data_spec = spec.clone()
    test_check(not invalid_data_spec.validate_data(malformed))
    var mark = spec.layers[0].mark
    if mark == PLOT_LOLLIPOP or mark == PLOT_GROUPED_BAR or mark == PLOT_STACKED_BAR:
        var transposed = spec.clone()
        transposed.layers[0].horizontal = True
        var horizontal = plot_from_spec(transposed, data, Rect(0,0,640,480))
        test_check(len(horizontal.series[0].points) == len(plot.series[0].points))
        for index in range(len(plot.series[0].points)):
            var before = plot.series[0].points[index]
            var after = horizontal.series[0].points[index]
            test_check(after.x == before.y and after.y == before.x)
            test_check(after.x2 == before.y2 and after.y2 == before.x2)
    if mark == PLOT_STACKED_BAR:
        var percent = spec.clone()
        percent.layers[0].percent = True
        var signed_percent = percent.clone()
        test_check(not signed_percent.validate_data(data))  # Signed stacks cannot normalize.
        var positive = data.clone()
        for field in _string_array(percent.layers[0].series_fields_json):
            for row in range(data.row_count()):
                _ = positive.set_float_field(field, row, Float32(0.0) if row == 0 else Float32(2.0))
        test_check(percent.validate_data(positive))
        var normalized = plot_from_spec(percent, positive, Rect(0,0,640,480))
        for point in normalized.series[0].points:
            test_check(point.y >= 0.0 and point.y2 <= 100.0001)
            if point.row_key == data.key_at(0):
                test_check(point.y == 0.0 and point.y2 == 0.0)
    var start = perf_counter()
    var checksum = 0
    for _ in range(30):
        var next = plot_from_spec(spec, data, Rect(0,0,640,480))
        checksum += next.build_scene().count()
    print("benchmark|", name, "|", perf_counter()-start, "|", checksum)


def main():
    # Full fixture driver lives in scripts/wave_a/verify.py; keep standalone checks.
    var spec = plot_spec_from_json('{"version":1,"layers":[],"encodings":[],"transforms":[],"scales":[],"interactions":[],"annotations":[]}')
    test_check(len(spec.layers) == 0)
