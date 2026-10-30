"""Machine-local whole-frame cost of broad contexts in the heterogeneous app."""
from std.time import perf_counter_ns
from host import WorkbenchHost
from check import target
from workbench import LEFT
from moxi import App, Rect, Event, TextInputEvent, test_check


def sample[S: Bool](history: Int, index: Int):
    var app = App(WorkbenchHost[S](), Rect(0, 0, 800, 4000))
    for i in range(history):
        app.component.root.services.document.history.append("history-" + String(i))
    app.component.refresh()
    app.rebuild()
    var initial = app.paint()
    test_check(initial.count() > 0)
    var event = Event(TextInputEvent("Local", 0, 3))
    event.set_target(target(app, LEFT, 2))
    app.component.reset_counts()
    var start = perf_counter_ns()
    var handled = app.update(event)
    var commands = app.paint()
    var elapsed = perf_counter_ns() - start
    test_check(handled)
    test_check(app.component.root.left.draft == "Local")
    test_check(len(app.component.root.services.document.history) == history)
    test_check(commands.count() == initial.count())
    test_check(app.component.render_count() == (1 if S else 8))
    if index >= 0:
        print("FRAME", S, history, index, elapsed, commands.count(), app.component.render_count())


def main():
    for level in range(3):
        var history = 0 if level == 0 else (10000 if level == 1 else 100000)
        sample[True](history, -1)
        sample[False](history, -1)
        for i in range(3):
            sample[True](history, i)
            sample[False](history, i)
