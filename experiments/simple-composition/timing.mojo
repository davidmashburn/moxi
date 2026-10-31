"""Whole-candidate cost, not an isolated caching comparison: topology differs."""
from std.time import perf_counter_ns
from screen import Workbench
from runtime import HandlerHost, require
from host import WorkbenchHost
from probe import target
from workbench import LEFT
from moxi import App, Component, Rect, Event, TextInputEvent, ActionEvent, PaintCommands


def frame[C: Component & Deinitable](mut app: App[C], event: Event) -> Tuple[Int, Int]:
    var start = perf_counter_ns()
    var handled = app.update(event)
    var middle = perf_counter_ns()
    var commands = app.paint()
    var end = perf_counter_ns()
    require(handled and commands.count() > 0, "timed event handled and painted")
    return (Int(middle - start), Int(end - middle))


def pair(history_size: Int, shared: Bool, sample: Int):
    var simple = App(HandlerHost(Workbench()), Rect(0, 0, 800, 4000))
    var cached = App(WorkbenchHost[True](), Rect(0, 0, 800, 4000))
    var forced = App(WorkbenchHost[False](), Rect(0, 0, 800, 4000))
    for i in range(history_size):
        simple.component.root.services.document.history.append("History " + String(i))
        cached.component.root.services.document.history.append("History " + String(i))
        forced.component.root.services.document.history.append("History " + String(i))
    simple.component.refresh()
    cached.component.refresh()
    forced.component.refresh()
    simple.rebuild()
    cached.rebuild()
    forced.rebuild()
    _ = simple.paint()
    _ = cached.paint()
    _ = forced.paint()
    var a = Event(TextInputEvent("Edited", 0, 1000000))
    var b = a
    var c = a
    a.set_target(target(simple, LEFT, 2 if shared else 4))
    b.set_target(target(cached, LEFT, 2 if shared else 4))
    c.set_target(target(forced, LEFT, 2 if shared else 4))
    if shared:
        require(simple.update(a) and cached.update(b) and forced.update(c), "prepare draft")
        _ = simple.paint()
        _ = cached.paint()
        _ = forced.paint()
        a = Event(ActionEvent(target(simple, LEFT, 5)))
        b = Event(ActionEvent(target(cached, LEFT, 5)))
        c = Event(ActionEvent(target(forced, LEFT, 5)))
        a.set_target(target(simple, LEFT, 5))
        b.set_target(target(cached, LEFT, 5))
        c.set_target(target(forced, LEFT, 5))
    var simple_time: Tuple[Int, Int]
    var cached_time: Tuple[Int, Int]
    var forced_time: Tuple[Int, Int]
    # Rotate all three positions. Setup/checks/destruction are outside timers.
    if sample % 3 == 0:
        simple_time = frame(simple, a)
        cached_time = frame(cached, b)
        forced_time = frame(forced, c)
    elif sample % 3 == 1:
        cached_time = frame(cached, b)
        forced_time = frame(forced, c)
        simple_time = frame(simple, a)
    else:
        forced_time = frame(forced, c)
        simple_time = frame(simple, a)
        cached_time = frame(cached, b)
    if shared:
        require(simple.component.root.services.document.name == "Edited", "simple commit")
        require(cached.component.root.services.document.name == "Edited", "cached commit")
        require(forced.component.root.services.document.name == "Edited", "forced commit")
    else:
        require(simple.component.root.left.note == "Edited", "simple local edit")
        require(cached.component.root.left.note == "Edited", "cached local edit")
        require(forced.component.root.left.note == "Edited", "forced local edit")
    if sample >= 0:
        print("TIMING", history_size, shared, sample, simple_time[0], simple_time[1], cached_time[0], cached_time[1], forced_time[0], forced_time[1])


def main():
    for h in range(2):
        var history_size = 0 if h == 0 else 10000
        for mode in range(2):
            var shared = mode == 1
            for sample in range(-2, 5):
                pair(history_size, shared, sample)
    print("PASS 60 candidate frames; local/shared effects verified")
