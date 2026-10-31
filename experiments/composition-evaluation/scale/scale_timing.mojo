"""Serial timing probe for visible population and keyed mount churn.

Only this file is executed by the runner's ``--measure`` path.  Preparation
compiles it so the binary is ready, but does not run it.
"""
from std.time import perf_counter_ns

from moxi import ActionEvent, App, Event, Rect
from runtime import HandlerHost, require
from scale_model import (
    ScaleScreen,
    assert_churn_counts,
    assert_visible_counts,
    control_id,
)


comptime WARMUPS = 2
comptime SAMPLES = 5


def frame(mut app: App[HandlerHost[ScaleScreen]], event: Event) -> Tuple[Int, Int]:
    var start = perf_counter_ns()
    var handled = app.update(event)
    var middle = perf_counter_ns()
    var commands = app.paint()
    var end = perf_counter_ns()
    require(handled, "timed button event handled")
    require(commands.count() > 0, "timed paint produced commands")
    return (Int(middle - start), Int(end - middle))


def action_event(id: Int) -> Event:
    var event = Event(ActionEvent(id))
    event.set_target(id)
    return event


def churn_batch(mut app: App[HandlerHost[ScaleScreen]], cycles: Int) -> Tuple[Int, Int]:
    if cycles == 0:
        assert_churn_counts(app, 0)
        return (0, 0)

    var update_total = 0
    var paint_total = 0
    for _ in range(cycles):
        var start = perf_counter_ns()
        app.component.root.hide_first()
        app.component.refresh()
        app.rebuild()
        var middle = perf_counter_ns()
        var hidden = app.paint()
        var painted_hidden = perf_counter_ns()
        require(hidden.count() > 0, "hidden churn sample paint produced commands")

        var remount_start = perf_counter_ns()
        var fresh_key = app.component.root.remount_first()
        require(fresh_key >= 100000, "fresh churn sample key")
        app.component.refresh()
        app.rebuild()
        var remount_middle = perf_counter_ns()
        var remounted = app.paint()
        var end = perf_counter_ns()
        require(remounted.count() > 0, "remounted churn sample paint produced commands")

        update_total += Int(middle - start) + Int(remount_middle - remount_start)
        paint_total += Int(painted_hidden - middle) + Int(end - remount_middle)

    assert_churn_counts(app, cycles)
    return (update_total, paint_total)


def visible_case(count: Int):
    var app = App(HandlerHost(ScaleScreen(count)), Rect(0.0, 0.0, 960.0, 20000.0))
    var initial = app.paint()
    require(initial.count() > 0, "visible setup paint produced commands")
    var button_id = control_id(app, 1, 2)
    var event = action_event(button_id)
    for _ in range(WARMUPS):
        _ = frame(app, event)
    for sample in range(SAMPLES):
        var times = frame(app, event)
        print(
            "TIMING visible",
            count,
            sample,
            times[0],
            times[1],
            count * 4,
            count * 4,
            count * 4 + 1,
            count * 3,
        )
    assert_visible_counts(app, count)


def churn_case(cycles: Int):
    # Warmups run on throwaway hosts because every remount intentionally grows
    # the retained-slot history.  Each recorded sample starts from eight fresh
    # live children and therefore has the same baseline.
    for _ in range(WARMUPS):
        var warmup = App(HandlerHost(ScaleScreen(8)), Rect(0.0, 0.0, 960.0, 20000.0))
        var warmup_initial = warmup.paint()
        require(warmup_initial.count() > 0, "churn warmup setup paint produced commands")
        _ = churn_batch(warmup, cycles)
    for sample in range(SAMPLES):
        var sample_app = App(HandlerHost(ScaleScreen(8)), Rect(0.0, 0.0, 960.0, 20000.0))
        var sample_initial = sample_app.paint()
        require(sample_initial.count() > 0, "churn sample setup paint produced commands")
        var times = churn_batch(sample_app, cycles)
        print(
            "TIMING churn",
            cycles,
            sample,
            times[0],
            times[1],
            32,
            32 + cycles * 4,
            33 + cycles * 4,
            24,
        )


def main():
    visible_case(10)
    visible_case(100)
    visible_case(300)
    visible_case(1000)
    churn_case(0)
    churn_case(100)
    churn_case(1000)
    print("PASS timing probe; warmups", WARMUPS, "samples", SAMPLES)
