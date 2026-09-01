"""PlotView/PlotControl integration contract test."""

from moxi import (
    CLICK_KIND,
    Color,
    Event,
    PlotControl,
    PlotDataTable,
    PlotSpec,
    PlotView,
    Point,
    POINTER_MOVE_KIND,
    PointerEvent,
    Rect,
    test_check,
)


def main():
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

    var control = PlotControl(spec, data, Rect(0.0, 0.0, 320.0, 240.0))
    test_check(control.build_scene().count() > 0)

    var inert_spec = PlotSpec("Inert")
    _ = inert_spec.add_line("series", "x", "y")
    var inert_view = PlotView(inert_spec, data, Rect(0.0, 0.0, 320.0, 240.0))
    test_check(not inert_view.dispatch(click))
    test_check(inert_view.selected_count() == 0)
    print("Moxi plot-view test passed")
