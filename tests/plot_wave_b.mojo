"""Wave B real Scene/Canvas, keyed interaction and atomic replacement harness."""
from std.time import perf_counter
from moxi import Rect, Point, Color, Event, CLICK_KIND, KEY_DOWN_KIND, KEY_RIGHT, KEY_ENTER, KEY_ESCAPE, CanvasSceneRenderer, SvgSceneRenderer, test_check
from moxi_plot.plot_spec import plot_spec_from_json, plot_from_spec
from moxi_plot.plot_point import PlotPoint, PlotGlyphKind
from moxi_plot.plot_data import PlotDataTable
from moxi_plot.plot_view import PlotView
from moxi_plot.plot_marks import PLOT_CONTOUR, PLOT_CONTOURF, PLOT_DONUT, PLOT_BEESWARM
from moxi_plot.plot_spec import PlotSpec
from moxi_plot.plot_spec_types import PlotLayoutVersion
from moxi.plot_selection import PlotSelection


def capture(mut view: PlotView, path: String) raises:
    var canvas = CanvasSceneRenderer(640,480,Color(1,1,1,1))
    canvas.render_scene(view.build_scene())
    test_check(canvas.error_count() == 0)
    canvas.write_png(path)


def check_case(name: String, document: String, data: PlotDataTable, output: String) raises:
    var spec = plot_spec_from_json(document)
    test_check(spec.validate() and spec.validate_data(data))
    print("spec|",name,"|",spec.to_json())
    var view = PlotView(spec,data,Rect(0,0,640,480))
    var plot = plot_from_spec(spec,data,Rect(0,0,640,480))
    test_check(plot.series[0].has_layout_domain and plot.build_render_packet().fallback_required)
    var identities = List[Int]()
    for i in range(len(plot.series[0].points)):
        var p = plot.series[0].points[i]
        print("glyph|",name,"|",p.glyph.value,"|",p.row_key,"|",p.part,"|",p.x,"|",p.y,"|",p.x2,"|",p.y2)
        for vertex in p.vertices:
            print("vertex|",name,"|",i,"|",vertex.x,"|",vertex.y)
        for key in p.source_keys:
            print("source|",name,"|",i,"|",key)
            var present = False
            for previous in identities:
                present = present or previous == key
            if not present:
                identities.append(key)
    test_check(len(identities) > 0)
    capture(view,output+"/"+name+"-canvas.png")
    var svg = SvgSceneRenderer(640,480)
    svg.render_scene(view.build_scene())
    with open(output+"/"+name+"-scene.svg","w") as f:
        f.write(svg.markup())
    # Find an actual hit on emitted geometry; overlapping shapes choose the last
    # nearest glyph. Assert source membership, never infer a hit from its bounds.
    var hit_position = Point(-100,-100)
    var found = False
    for p in plot.series[0].points:
        if not p.interactive or found:
            continue
        var candidate = PlotPoint((p.x+p.x2)*.5,(p.y+p.y2)*.5)
        if p.glyph.value == PlotGlyphKind.POLYGON.value and len(p.vertices) > 0:
            candidate.x = p.vertices[0].x
            candidate.y = p.vertices[0].y
        var screen = plot.screen_point(candidate)
        var hit = view.runtime.hit_test(screen,1)
        if hit.found():
            hit_position = screen
            found = True
    test_check(found)
    var hit = view.runtime.hit_test(hit_position,1)
    var member = False
    for key in identities:
        member = member or key == hit.row_key
    test_check(member)
    if spec.layers[0].mark == PLOT_DONUT:
        test_check(not view.runtime.hit_test(plot.screen_point(PlotPoint(0,0)),1).found())
    var click = Event()
    click.kind = CLICK_KIND
    click.position = hit_position
    test_check(view.dispatch(click) and view.selected_count() == 1)
    print("selection|",name,"|",hit.row_key,"|",hit_position.x,"|",hit_position.y)
    test_check(view.accessibility().count() >= len(identities)+2)
    capture(view,output+"/"+name+"-selected.png")
    with open(output+"/"+name+"-table.csv","w") as f:
        f.write(view.data_table_csv())
    var changed = data.clone()
    var field = spec.layers[0].y_field
    if spec.layers[0].mark == PLOT_CONTOUR or spec.layers[0].mark == PLOT_CONTOURF:
        field = spec.layers[0].y2_field
    _ = changed.set_float_field(field,0,data.float_field_at(field,0)+1.5)
    test_check(view.replace_data(changed))
    test_check(view.selected_count() == 0)
    capture(view,output+"/"+name+"-updated.png")
    var invalid = data.clone()
    _ = invalid.set_float_field(field,0,Float32(1)/Float32(0))
    test_check(not view.replace_data(invalid))
    test_check(not view.request_data(invalid))
    test_check(not view.request_spec(spec,invalid))
    view.replace_spec(spec,invalid)
    capture(view,output+"/"+name+"-rejected.png")
    test_check(view.replace_data(data))
    capture(view,output+"/"+name+"-restored.png")
    var key = Event()
    key.kind = KEY_DOWN_KIND
    key.key = KEY_RIGHT
    for expected in identities:
        test_check(view.dispatch(key))
        test_check(view.runtime.hovered.row_key == expected)
    key.key = KEY_ENTER
    test_check(view.dispatch(key) and view.selected_count() == 1)
    var linked = view.runtime.selection()
    view.runtime.set_linked_selection(linked)
    test_check(view.selected_count() == 1)
    key.key = KEY_ESCAPE
    test_check(view.dispatch(key) and view.selected_count() == 0)
    view.set_bounds(Rect(0,0,800,400))
    test_check(view.runtime.plot.plot_area.width != plot.plot_area.width)
    for sample in range(30):
        var start = perf_counter()
        var next = plot_from_spec(spec,data,Rect(0,0,640,480))
        var scene = next.build_scene()
        print("benchmark|",name,"|",sample,"|",perf_counter()-start,"|",scene.count())


def check_resize_selection():
    var spec = PlotSpec()
    _ = spec.add_catalog_mark(PLOT_BEESWARM, "swarm")
    spec.layers[0].layout_version = PlotLayoutVersion.SPECIALIZED
    var data = PlotDataTable()
    _ = data.append(0, 0)
    _ = data.append(0, 0.01)
    _ = data.append(0, 1)
    var view = PlotView(spec, data, Rect(0, 0, 640, 80))
    var selection = PlotSelection()
    _ = selection.add(data.key_at(0))
    view.runtime.set_linked_selection(selection)
    var old_index = view.runtime.selected.point_index
    view.runtime.hovered = view.runtime.selected
    view.runtime.dragging = True
    view.set_bounds(Rect(0, 0, 640, 480))
    test_check(view.runtime.selected.point_index != old_index)
    test_check(view.runtime.selected.row_key == data.key_at(0))
    test_check(len(view.runtime.selected_hits) == 1)
    test_check(view.runtime.plot.series[0].points[view.runtime.selected.point_index].row_key == data.key_at(0))
    test_check(view.runtime.plot.series[0].points[view.runtime.selected_hits[0].point_index].row_key == data.key_at(0))
    test_check(view.runtime.selection().contains(data.key_at(0)))
    test_check(not view.runtime.hovered.found() and not view.runtime.dragging)
    # The viewport and hidden series survive subsequent recompilation too.
    view.runtime.plot.set_x_domain(-2, 2)
    view.runtime.plot.set_y_domain(-1, 2)
    view.runtime.plot.series[0].visible = False
    view.set_bounds(Rect(0, 0, 800, 400))
    test_check(view.runtime.plot.x_scale.data_min == -2)
    test_check(view.runtime.plot.y_scale.data_max == 2)
    test_check(not view.runtime.plot.series[0].visible)
    test_check(len(view.runtime.selected_hits) == 0)
    test_check(view.runtime.selection().contains(data.key_at(0)))


def main():
    check_resize_selection()
