"""PlotView/PlotControl integration contract test."""

from std.math import isfinite
from moxi import (
    App,
    CanvasSceneRenderer,
    CLICK_KIND,
    Color,
    Event,
    Point,
    POINTER_MOVE_KIND,
    PointerEvent,
    Rect,
    SvgSceneRenderer,
    TypedSubtreeExecutor,
    test_check,
)
from moxi_plot import (
    PlotControl,
    PlotDataTable,
    PlotSpec,
    PlotView,
)
from moxi_plot.plot_marks import PLOT_ARC_DIAGRAM
from moxi_plot.plot_point import PlotPoint
from moxi_plot.plot_spec_types import PlotLayoutVersion
from moxi_plot.plot_view import PLOT_VIEW_CANVAS_ID


def check_arc_graphics(mut view: PlotView) raises -> String:
    # Keep keyed marks even when the drawable area collapses, so selection
    # remains projected onto the source and can be restored on enlargement.
    test_check(len(view.runtime.plot.series) == 1)
    test_check(len(view.runtime.plot.series[0].points) == 6)
    for row in range(3):
        var edge = view.runtime.plot.series[0].points[row]
        test_check(edge.interactive and edge.row_key == 10 + row)
        test_check(len(edge.vertices) == 49)
    for point in view.runtime.plot.series[0].points:
        test_check(isfinite(point.x) and isfinite(point.y))
        test_check(isfinite(point.x2) and isfinite(point.y2))
        for vertex in point.vertices:
            test_check(isfinite(vertex.x) and isfinite(vertex.y))
            var screen = view.runtime.plot.screen_point(PlotPoint(vertex.x, vertex.y))
            test_check(isfinite(screen.x) and isfinite(screen.y))
    var bounds = view.runtime.plot.bounds
    var scene = view.build_scene()
    var svg = SvgSceneRenderer(Int(bounds.width), Int(bounds.height))
    svg.render_scene(scene)
    var markup = svg.markup()
    test_check("nan" not in markup and "inf" not in markup)
    var canvas = CanvasSceneRenderer(Int(bounds.width), Int(bounds.height), Color(1, 1, 1, 1))
    canvas.render_scene(scene)
    test_check(canvas.error_count() == 0)
    return markup^


def check_arc_collapsed_resize() raises:
    var data = PlotDataTable()
    _ = data.add_string_column("source")
    _ = data.add_string_column("target")
    _ = data.add_float64_column("weight")
    var names: List[String] = ["A", "B", "C"]
    var targets: List[String] = ["C", "A", "B"]
    for row in range(3):
        _ = data.append_with_key(10 + row, Float32(row), Float32(row + 1))
        _ = data.set_string_field("source", row, names[row])
        _ = data.set_string_field("target", row, targets[row])
        _ = data.set_float64_field("weight", row, Float64(row + 1))
    var spec = PlotSpec()
    _ = spec.add_catalog_mark(PLOT_ARC_DIAGRAM, "Edges", "source", "weight", x2_field="target")
    spec.layers[0].layout_version = PlotLayoutVersion.SPECIALIZED
    _ = spec.add_click_select()
    var view = PlotView(spec, data, Rect(0, 0, 640, 420))
    var apex = view.runtime.plot.series[0].points[0].vertices[24]
    var click = Event()
    click.kind = CLICK_KIND
    click.position = view.runtime.plot.screen_point(PlotPoint(apex.x, apex.y))
    test_check(view.dispatch(click))
    var original_csv = view.data_table_csv()
    var original_spec = view.spec.to_json()
    var original_version = view.data.version()
    for ordinary in [Rect(0, 0, 640, 420), Rect(0, 0, 960, 420), Rect(0, 0, 420, 640), Rect(0, 0, 1200, 240)]:
        view.set_bounds(ordinary)
        var before = check_arc_graphics(view)
        # Exact margin limits, below the limits, and both axes together.
        for collapsed in [Rect(0, 0, 640, 80), Rect(0, 0, 640, 40), Rect(0, 0, 80, 420), Rect(0, 0, 40, 420), Rect(0, 0, 80, 80), Rect(0, 0, 40, 40), Rect(0, 0, 640, 0), Rect(0, 0, 0, 420), Rect(0, 0, 0, 0)]:
            view.set_bounds(collapsed)
            test_check(view.runtime.plot.plot_area.width == 0 or view.runtime.plot.plot_area.height == 0)
            var current = check_arc_graphics(view)
            var fresh = PlotView(spec, data, collapsed)
            fresh.runtime.set_linked_selection(view.runtime.selection())
            test_check(check_arc_graphics(fresh) == current)
            test_check(view.data_table_csv() == original_csv)
            test_check(view.spec.to_json() == original_spec)
            test_check(view.data.version() == original_version)
            test_check(view.selected_count() == 1 and view.runtime.selected.row_key == 10)
            test_check(view.runtime.selection().contains(10))
            view.set_bounds(ordinary)
            test_check(check_arc_graphics(view) == before)
            test_check(view.selected_count() == 1 and view.runtime.selected.row_key == 10)
    print("Moxi arc collapsed-resize test passed (both axes and restoration)")


def main() raises:
    check_arc_collapsed_resize()
    var data = PlotDataTable()
    _ = data.append(0.0, 1.0)
    _ = data.append(1.0, 2.0)
    var spec = PlotSpec("View")
    _ = spec.add_line("series", "x", "y", Color(0.2, 0.8, 1.0, 1.0))
    _ = spec.add_hover(False, True)
    _ = spec.add_click_select()
    var view = PlotView(spec, data, Rect(0.0, 0.0, 320.0, 240.0))
    var target = view.runtime.plot.screen_point(view.runtime.plot.series[0].points[0])
    var click = Event()
    click.kind = CLICK_KIND
    click.position = target
    test_check(view.dispatch(click))
    test_check(view.selected_count() == 1)
    var hover_changed = view.dispatch(Event(PointerEvent(POINTER_MOVE_KIND, target)))
    var view_packet = view.build_render_packet()
    var view_overlay = view.build_overlay_scene()
    test_check(hover_changed)
    test_check(not view_packet.fallback_required)
    test_check(view_overlay.count() == 2)
    test_check(view.runtime.packet_rebuilds() == 1)
    _ = view.build_render_packet()
    test_check(view.runtime.packet_rebuilds() == 1)
    test_check(view.build_scene().count() > 0)
    test_check(view.accessibility().count() == 4)
    test_check(view.data_table_csv().startswith("key,x,y"))
    var replacement = PlotDataTable()
    _ = replacement.append(10.0, 20.0)
    _ = view.replace_data(replacement)
    test_check(view.runtime.plot.point_count(1) == 1)
    test_check(not view.replace_data(replacement))

    # The localized path separates source mutation from plot compilation.
    # Until the host consumes the dirty token, the retained plot still shows
    # the previous snapshot.
    var deferred = replacement.clone()
    _ = deferred.append(11.0, 21.0)
    var counters_before = view.reactive_work_counters()
    test_check(view.request_data(deferred))
    test_check(view.reactive_dirty())
    test_check(
        view.reactive_work_counters().invalidation_count
        == counters_before.invalidation_count + 1
    )
    test_check(
        view.reactive_work_counters().dependency_visits
        == counters_before.dependency_visits + 1
    )
    test_check(view.runtime.plot.point_count(1) == 1)
    test_check(view.rebuild_if_dirty())
    test_check(not view.reactive_dirty())
    test_check(view.runtime.plot.point_count(1) == 2)
    test_check(
        view.reactive_work_counters().dirty_consumed
        == counters_before.dirty_consumed + 1
    )
    test_check(not view.rebuild_if_dirty())

    var deferred_spec = spec.clone()
    test_check(view.request_spec(deferred_spec, replacement))
    test_check(view.reactive_dirty())
    test_check(view.rebuild_if_dirty())
    test_check(not view.reactive_dirty())
    test_check(view.runtime.plot.point_count(1) == 1)

    var control = PlotControl(spec, data, Rect(0.0, 0.0, 320.0, 240.0))
    test_check(control.build_scene().count() > 0)

    # PlotView uses the generic typed reactive executor without rebuilding its
    # stable one-canvas view for each retained scene interaction.
    var reactive_view = PlotView(spec, data, Rect(0.0, 0.0, 320.0, 240.0))
    var reactive = TypedSubtreeExecutor[PlotView](
        reactive_view,
        Rect(0.0, 0.0, 320.0, 240.0),
        7,
        11,
    )
    test_check(reactive.dispatch(click))
    test_check(reactive.component.selected_count() == 1)
    var reactive_work = reactive.work_counters()
    test_check(reactive_work.invalidation_count == 1)
    test_check(reactive_work.dirty_consumed == 1)
    test_check(reactive_work.component_builds == 1)

    # The root App path uses the same retained update contract and therefore
    # avoids a root fallback for plot-only scene changes.
    var app_view = PlotView(spec, data, Rect(0.0, 0.0, 320.0, 240.0))
    var app = App[PlotView](app_view, Rect(0.0, 0.0, 320.0, 240.0))
    var build_count_before = app.execution_build_count(0)
    test_check(app.dispatch(click))
    test_check(app.component.selected_count() == 1)
    test_check(app.execution_work_counters().root_fallbacks == 0)

    # A retained update runs no builder, so the per-component build count must
    # not advance for the consumed invalidation.
    test_check(app.execution_build_count(0) == build_count_before)

    # The retained update settles inside its routed node, so the pending region
    # is that node rather than the whole root.
    var retained_region = app.pending_invalidation().bounds
    var canvas_bounds = app.view.bounds_for(PLOT_VIEW_CANVAS_ID)
    test_check(retained_region.width == canvas_bounds.width)
    test_check(retained_region.height == canvas_bounds.height)

    # An unrouted retained event keeps the conservative root region because the
    # owning node is not known at the App boundary.
    var unrouted = Event(PointerEvent(CLICK_KIND, Point(150.0, 120.0)))
    var unrouted_app_view = PlotView(spec, data, Rect(0.0, 0.0, 320.0, 240.0))
    var unrouted_app = App[PlotView](
        unrouted_app_view, Rect(0.0, 0.0, 320.0, 240.0)
    )
    _ = unrouted_app.dispatch(unrouted)

    var inert_spec = PlotSpec("Inert")
    _ = inert_spec.add_line("series", "x", "y")
    var inert_view = PlotView(inert_spec, data, Rect(0.0, 0.0, 320.0, 240.0))
    test_check(not inert_view.dispatch(click))
    test_check(inert_view.selected_count() == 0)
    print("Moxi plot-view test passed")
