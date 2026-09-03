"""Interactive plot runtime contract test."""

from moxi import (
    CLICK_KIND,
    ClickEvent,
    Color,
    DRAG_BEGIN_KIND,
    DRAG_UPDATE_KIND,
    DROP_KIND,
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

    # AppKit emits the backend-neutral drag aliases after pointer-down. The
    # plot must keep panning through that stream just as it does for the
    # explicit pointer lifecycle used by other hosts.
    var pan_start = Point(120.0, 100.0)
    var pan_end = Point(150.0, 118.0)
    test_check(runtime.dispatch(Event(PointerEvent(POINTER_DOWN_KIND, pan_start))))
    test_check(runtime.dispatch(Event(PointerEvent(DRAG_BEGIN_KIND, pan_start))))
    test_check(runtime.dispatch(Event(PointerEvent(DRAG_UPDATE_KIND, pan_end))))
    test_check(runtime.dispatch(Event(PointerEvent(DROP_KIND, pan_end))))

    # Indexed queries preserve the nearest-point result of the original
    # exhaustive implementation on a denser fixture.
    var dense = PlotRuntime(Rect(0.0, 0.0, 640.0, 420.0))
    var dense_series = dense.plot.add_series(
        "dense",
        Color(0.35, 0.85, 0.55, 1.0),
    )
    for index in range(2000):
        _ = dense.plot.add_point(
            dense_series,
            Float32(index) * 0.01,
            Float32(index % 97) * 0.02,
        )
    dense.plot.fit_to_data()
    var dense_target = dense.plot.screen_point(
        dense.plot.series[0].points[1999]
    )
    var indexed_hit = dense.hit_test(dense_target, 1.0)
    var exhaustive_hit = dense.plot.hit_test(dense_target, 1.0)
    test_check(indexed_hit.found())
    test_check(exhaustive_hit.found())
    test_check(indexed_hit.row_key == exhaustive_hit.row_key)
    test_check(dense.spatial_index_rebuilds() == 1)
    _ = dense.hit_test(dense_target, 1.0)
    test_check(dense.spatial_index_rebuilds() == 1)
    _ = dense.plot.set_point(dense_series, 1999, 0.0, 0.0)
    _ = dense.hit_test(dense_target, 1.0)
    test_check(dense.spatial_index_rebuilds() == 2)

    print("Moxi plot-runtime test passed")
