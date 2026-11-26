"""Wave A fixture harness, called by scripts/wave_a/verify.py's generated driver."""
from std.time import perf_counter
from moxi import Rect, Point, Color, Event, CLICK_KIND, KEY_DOWN_KIND, KEY_RIGHT, KEY_ENTER, KEY_ESCAPE, SCENE_TEXT, SoftwareSceneRenderer, CanvasSceneRenderer, SvgSceneRenderer, test_check
from moxi_plot.plot_spec import PlotSpec, plot_spec_from_json, plot_from_spec
from moxi_plot.plot_point import PlotGlyphKind
from moxi_plot.plot_data import PlotDataTable
from moxi_plot.plot_runtime import PlotRuntime
from moxi_plot.plot_view import PlotView
from moxi_plot.plot_data import COLUMN_STRING, COLUMN_CATEGORY
from moxi_plot.plot_spec_types import PlotLayoutVersion
from moxi_plot.plot_marks import PLOT_LOLLIPOP, PLOT_GROUPED_BAR, PLOT_STACKED_BAR, PLOT_POPULATION_PYRAMID
from moxi_plot.plot_spec_json import _string_array


def check_pyramid_chrome(spec: PlotSpec, data: PlotDataTable) raises:
    # Exercise the public resize path with the real fixture, including an offset
    # canvas. Sampling is presentation only: source labels and row hits survive.
    var wide = Rect(17, 23, 640, 480)
    var view = PlotView(spec, data, wide)
    var original = SvgSceneRenderer(680, 530)
    original.render_scene(view.build_scene())
    var csv = view.data_table_csv()
    var widths: List[Float32] = [180, 120, 320, 640]
    for width in widths:
        var height = Float32(150 if width < 320 else (240 if width == 320 else 480))
        var bounds = Rect(17, 23, width, height)
        view.set_bounds(bounds)
        var scene = view.runtime.plot.build_scene()
        var ticks = 0
        var categories = 0
        var legends = 0
        for index in range(scene.count()):
            var command = scene.commands[index]
            if command.kind != SCENE_TEXT:
                continue
            var box = command.bounds
            if command.has_text_style:
                test_check(Float32(command.text.count_codepoints() * 7) <= box.width)
            test_check(box.x >= bounds.x and box.y >= bounds.y)
            test_check(box.x + box.width <= bounds.x + bounds.width)
            test_check(box.y + box.height <= bounds.y + bounds.height)
            for previous in range(index):
                var other = scene.commands[previous]
                if other.kind == SCENE_TEXT:
                    test_check(box.x + box.width <= other.bounds.x or other.bounds.x + other.bounds.width <= box.x or box.y + box.height <= other.bounds.y or other.bounds.y + other.bounds.height <= box.y)
            if 700 <= command.id <= 705:
                ticks += 1
            if 900 <= command.id < 900 + data.row_count():
                categories += 1
            if 600 <= command.id <= 601:
                legends += 1
        test_check(ticks >= 1 and ticks <= 6)
        test_check(ticks < 6 if width < 320 else True)
        test_check(ticks == 6 if width == 640 else True)
        test_check(categories > 0 and categories <= data.row_count() and legends == 2)
        if data.row_count() == 4 or width == 640:
            test_check(categories == data.row_count())
        test_check(view.runtime.plot.title == spec.title)
        test_check(view.runtime.plot.accessibility().node_for_id(1).label == spec.title)
        test_check(view.data_table_csv() == csv)
        for row in range(data.row_count()):
            test_check(view.runtime.plot.series[0].category_labels[data.row_count()-1-row] == data.string_field_at("category", row))
        for index in range(len(view.runtime.plot.series[0].points)):
            var point = view.runtime.plot.series[0].points[index]
            var label = data.string_field_at("category", point.row_key)
            test_check(view.runtime.plot.accessibility().node_for_id(500000+index//2*2).value.find(label) >= 0)
            point.x = (point.x + point.x2) * 0.5
            point.y = (point.y + point.y2) * 0.5
            var hit = view.runtime.hit_test(view.runtime.plot.screen_point(point), 0)
            test_check(hit.found() and hit.row_key == point.row_key)
    view.set_bounds(wide)
    var restored = SvgSceneRenderer(680, 530)
    restored.render_scene(view.build_scene())
    test_check(original.markup() == restored.markup())


def check_case(name: String, document: String, data: PlotDataTable, output: String) raises:
    var spec = plot_spec_from_json(document)
    test_check(spec.validate())
    test_check(spec.validate_data(data))
    print("spec|", name, "|", spec.to_json())
    var plot = plot_from_spec(spec, data, Rect(0, 0, 640, 480))
    test_check(plot.series[0].has_layout_domain)
    test_check(plot.build_render_packet().fallback_required)
    var semantics = plot.accessibility()
    for index in range(len(plot.series[0].points)):
        var point = plot.series[0].points[index]
        if point.interactive:
            # Wave B contributor labels must not change Wave A's existing value.
            test_check(semantics.node_for_id(500000+index).value == point.tooltip)
            break
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
    # Text and swatches are plot chrome. Only marks contribute selection hits.
    for command in plot.build_scene().commands:
        if command.has_text_style:
            test_check(not runtime.hit_test(Point(command.bounds.x + 2, command.bounds.y + 3), 1).found())
    var renamed = data.clone()
    test_check(renamed.set_string_field(spec.layers[0].x_field, 0, "Edited"))
    test_check(view.replace_data(renamed))
    var updated_label = False
    for command in view.build_scene().commands:
        if command.has_text_style and command.text == "Edited":
            updated_label = True
    test_check(updated_label)
    test_check(view.replace_data(data))
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
    if mark == PLOT_POPULATION_PYRAMID:
        check_pyramid_chrome(spec, data)
        var small = plot_from_spec(spec, data, Rect(0, 0, 180, 150))
        var title = ""
        var zero = False
        var ticks = 0
        for command in small.build_scene().commands:
            if command.id == 400 or command.id == 401:
                title += (" " if title != "" else "") + command.text
            if 700 <= command.id <= 705:
                ticks += 1
                zero = zero or command.text == "0.0"
            if command.id == 601:
                test_check(command.text == "Right")
        test_check(title == spec.title and zero and ticks == 3)
        var long_labels = data.clone()
        _ = long_labels.set_string_field("category", 0, "Synthetic ages 0–19; complete source label")
        var long_title = spec.clone()
        long_title.title = "Synthetic population pyramid with a longer title"
        check_pyramid_chrome(long_title, long_labels)
        var dense = data.clone()
        for row in range(4, 16):
            _ = dense.append_with_key(row, 0, 0)
            _ = dense.set_string_field("category", row, String("Synthetic ages ", row))
            _ = dense.set_float_field("value", row, Float32(20 + row))
            _ = dense.set_float_field("right", row, Float32(15 + row))
        check_pyramid_chrome(spec, dense)
        var magnitude = data.clone()
        for row in range(data.row_count()):
            _ = magnitude.set_float_field("value", row, Float32(450000000000))
            _ = magnitude.set_float_field("right", row, Float32(350000000000))
        check_pyramid_chrome(spec, magnitude)
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
