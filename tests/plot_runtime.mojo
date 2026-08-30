"""Interactive plot runtime contract test."""

from moxi import (
    CLICK_KIND,
    Color,
    Event,
    Point,
    PlotRuntime,
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
    var scroll = Event(ScrollEvent(Point(0.0, 10.0)))
    scroll.position = target
    test_check(runtime.dispatch(scroll))
    test_check(runtime.build_scene().count() > 0)
    print("Moxi plot-runtime test passed")
