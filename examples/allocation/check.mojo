"""Replay the experiment through the displayed window's native AX buttons."""
from std.ffi import external_call
from model import Workbench
from window import open_window
from moxi import App
from moxi.authoring import HandlerHost
from moxi.event import NONE_KIND
from moxi.macos import MacOSWindow, MacOSRenderer

comptime AllocationApp = App[HandlerHost[Workbench]]


def control(app: AllocationApp, label: String, enabled: Bool = True) raises -> Int:
    var snapshot = app.accessibility()
    for node in snapshot.nodes:
        if node.label == label and node.enabled == enabled:
            return node.id
    raise Error("Missing control or wrong state: " + label)


def press(mut app: AllocationApp, mut window: MacOSWindow, mut renderer: MacOSRenderer, label: String) raises:
    external_call["moxi_lifecycle_press", NoneType](Int32(control(app, label)))
    drain(app, window, renderer)


def drain(mut app: AllocationApp, mut window: MacOSWindow, mut renderer: MacOSRenderer) raises:
    window.pump()
    var event = window.poll_event()
    while event.kind != NONE_KIND:
        _ = app.dispatch(event)
        event = window.poll_event()
    app.render(renderer)


def capture(var name: String):
    external_call["moxi_lifecycle_snapshot", NoneType](name.as_c_string_span().ptr(), Int32(0))


def main() raises:
    var window = MacOSWindow()
    var app = open_window(window)
    var renderer = MacOSRenderer()
    app.render(renderer)
    _ = control(app, "No allocation promoted.")
    _ = control(app, "Commons    |    4 gardens   /   4 grove   /   4 play    |    Fern short 2   /   Ash short 1   /   Pip met")
    capture("01-baseline.png")
    press(app, window, renderer, "Fern: set garden minimum to 5")
    press(app, window, renderer, "Ash: set grove minimum to 6")
    press(app, window, renderer, "Pip: set play minimum to 5")
    _ = control(app, "Minimums: Fern 5 gardens   /   Ash 6 grove   /   Pip 5 play")
    press(app, window, renderer, "Ash: set grove minimum to 5")
    press(app, window, renderer, "Pip: set play minimum to 4")
    _ = control(app, "Commons    |    4 gardens   /   4 grove   /   4 play    |    Fern short 1   /   Ash short 1   /   Pip met")
    capture("02-preference.png")
    press(app, window, renderer, "All branches: set supply to 13")
    _ = control(app, "Orchard    |    7 gardens   /   3 grove   /   3 play    |    Fern met   /   Ash short 2   /   Pip short 1")
    _ = control(app, "Glade    |    4 gardens   /   6 grove   /   3 play    |    Fern short 1   /   Ash met   /   Pip short 1")
    _ = control(app, "Commons    |    5 gardens   /   4 grove   /   4 play    |    Fern met   /   Ash short 1   /   Pip met")
    capture("03-shared.png")
    press(app, window, renderer, "Commons: move one play plot to grove")
    _ = control(app, "Commons    |    5 gardens   /   5 grove   /   3 play    |    Fern met   /   Ash met   /   Pip short 1")
    capture("04-override.png")
    press(app, window, renderer, "Review a proposal")
    press(app, window, renderer, "Review Glade next")
    press(app, window, renderer, "Review Commons next")
    _ = control(app, "Promote Commons", False)
    var reason = String("Keep five garden and grove plots; revisit play space.")
    var id = control(app, "Decision reason")
    external_call["allocation_set_reason", NoneType](Int32(id), reason.as_c_string_span().ptr())
    drain(app, window, renderer)
    press(app, window, renderer, "Promote Commons")
    _ = control(app, reason)
    _ = control(app, "Fern met   /   Ash met   /   Pip short 1")
    capture("05-promoted.png")
    press(app, window, renderer, "Edit assumptions")
    press(app, window, renderer, "Commons: restore the play plot")
    _ = control(app, "Commons    |    5 gardens   /   4 grove   /   4 play    |    Fern met   /   Ash short 1   /   Pip met")
    _ = control(app, "Fern met   /   Ash met   /   Pip short 1")
    capture("06-retained.png")
    press(app, window, renderer, "Review a proposal")
    press(app, window, renderer, "Undo promotion")
    _ = control(app, "No allocation promoted.")
    _ = control(app, "Undo promotion", False)
    _ = control(app, "Commons    |    5 gardens   /   4 grove   /   4 play    |    Fern met   /   Ash short 1   /   Pip met")
    capture("07-undo.png")
    print("PASS allocation session: owners, inheritance, local transfer, decision snapshot, undo")
