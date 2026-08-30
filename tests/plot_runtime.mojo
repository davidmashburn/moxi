"""Interactive plot runtime contract test."""

from moxi import (
    CLICK_KIND,
    ClickEvent,
    Color,
    Event,
    KEY_ENTER,
    KEY_LEFT,
    KeyEvent,
    MOD_SHIFT,
    POINTER_DOWN_KIND,
    POINTER_MOVE_KIND,
    POINTER_UP_KIND,
    Point,
    PlotRuntime,
    PointerEvent,
    Rect,
    ScrollEvent,
    test_check,
)


def main():
    var runtime = PlotRuntime(Rect(0.0, 0.0, 320.0, 240.0))
    var series = runtime.plot.add_series("signal", Color(0.2, 0.8, 1.0, 1.0))
    _ = runtime.plot.add_point(series, 0.0, 0.0)
    _ = runtime.plot.add_point(series, 1.0, 1.0)
    runtime.plot.fit_to_data()
    var target = runtime.plot.screen_point(runtime.plot.series[0].points[0])
    var click = Event()
    click.kind = CLICK_KIND
    click.position = target
    test_check(runtime.dispatch(click))
    test_check(runtime.selected.found())
    test_check(runtime.accessibility().count() == 3)
    var second_target = runtime.plot.screen_point(runtime.plot.series[0].points[1])
    test_check(runtime.dispatch(Event(ClickEvent(second_target, MOD_SHIFT))))
    test_check(runtime.selected_count() == 2)
    test_check(runtime.dispatch(Event(ClickEvent(second_target, MOD_SHIFT))))
    test_check(runtime.selected_count() == 1)
    var brush_top = target.y if target.y < second_target.y else second_target.y
    var brush_bottom = target.y if target.y > second_target.y else second_target.y
    var brush_start = Point(target.x - 10.0, brush_top - 10.0)
    var brush_end = Point(second_target.x + 10.0, brush_bottom + 10.0)
    var brush_down = Event(PointerEvent(POINTER_DOWN_KIND, brush_start))
    brush_down.modifiers = MOD_SHIFT
    test_check(runtime.dispatch(brush_down))
    test_check(runtime.dispatch(Event(PointerEvent(POINTER_MOVE_KIND, brush_end))))
    test_check(runtime.dispatch(Event(PointerEvent(POINTER_UP_KIND, brush_end))))
    test_check(runtime.selected_count() == 2)
    test_check(runtime.dispatch(Event(KeyEvent(KEY_LEFT))))
    test_check(runtime.hovered.found())
    test_check(runtime.dispatch(Event(KeyEvent(KEY_ENTER))))
    test_check(runtime.selected_count() == 1)
    test_check(runtime.zoom_to_selection())
    var scroll = Event(ScrollEvent(Point(0.0, 10.0)))
    scroll.position = target
    test_check(runtime.dispatch(scroll))
    test_check(runtime.build_scene().count() > 0)
    print("Moxi plot-runtime test passed")
