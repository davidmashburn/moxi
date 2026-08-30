"""Stable-key selection, lasso, and linked-view contract tests."""

from moxi import (
    Color,
    Event,
    MOD_OPTION,
    PlotLink,
    PlotRuntime,
    PlotSelection,
    Point,
    PointerEvent,
    POINTER_DOWN_KIND,
    POINTER_MOVE_KIND,
    POINTER_UP_KIND,
    Rect,
    selection_from_keys,
    test_check,
)


def main() raises:
    var selected = PlotSelection()
    test_check(selected.add(10))
    test_check(not selected.add(10))
    test_check(selected.contains(10))
    test_check(not selected.toggle(10))
    test_check(not selected.contains(10))

    var source = selection_from_keys([1, 2, 2, 3])
    var other = selection_from_keys([2, 3, 4])
    test_check(source.count() == 3)
    test_check(source.union(other).count() == 4)
    test_check(source.intersect(other).count() == 2)

    var bounds = Rect(0.0, 0.0, 320.0, 240.0)
    var runtime = PlotRuntime(bounds)
    var series = runtime.plot.add_series(
        "points",
        Color(0.25, 0.75, 1.0, 1.0),
    )
    _ = runtime.plot.add_point_with_key(series, 0.0, 0.0, 101)
    _ = runtime.plot.add_point_with_key(series, 1.0, 1.0, 102)
    _ = runtime.plot.add_point_with_key(series, 2.0, 2.0, 103)
    runtime.plot.fit_to_data()
    var first = runtime.plot.screen_point(runtime.plot.series[0].points[0])
    var down = Event(
        __make_pointer(
            POINTER_DOWN_KIND,
            Point(first.x - 12.0, first.y - 12.0),
            MOD_OPTION,
        )
    )
    test_check(runtime.dispatch(down))
    var move_a = Event(
        __make_pointer(
            POINTER_MOVE_KIND,
            Point(first.x + 12.0, first.y - 12.0),
            MOD_OPTION,
        )
    )
    var move_b = Event(
        __make_pointer(
            POINTER_MOVE_KIND,
            Point(first.x + 12.0, first.y + 12.0),
            MOD_OPTION,
        )
    )
    var move_c = Event(
        __make_pointer(
            POINTER_MOVE_KIND,
            Point(first.x - 12.0, first.y + 12.0),
            MOD_OPTION,
        )
    )
    _ = runtime.dispatch(move_a)
    _ = runtime.dispatch(move_b)
    _ = runtime.dispatch(move_c)
    var up = Event(
        __make_pointer(
            POINTER_UP_KIND,
            Point(first.x - 12.0, first.y - 12.0),
            MOD_OPTION,
        )
    )
    test_check(runtime.dispatch(up))
    test_check(runtime.selected_count() == 1)
    test_check(runtime.selection().contains(101))

    var linked_runtime = PlotRuntime(bounds)
    var linked_series = linked_runtime.plot.add_series(
        "linked",
        Color(1.0, 0.45, 0.30, 1.0),
    )
    _ = linked_runtime.plot.add_point_with_key(linked_series, 0.0, 0.0, 101)
    _ = linked_runtime.plot.add_point_with_key(linked_series, 1.0, 1.0, 102)
    linked_runtime.plot.fit_to_data()
    var link = PlotLink()
    link.capture(runtime)
    link.apply(linked_runtime)
    test_check(linked_runtime.selected_count() == 1)
    test_check(linked_runtime.selection().contains(101))

    print("Moxi plot-selection test passed")


def __make_pointer(kind: Int, position: Point, modifiers: Int) -> PointerEvent:
    var event = PointerEvent(kind, position)
    event.set_modifiers(modifiers)
    return event^
