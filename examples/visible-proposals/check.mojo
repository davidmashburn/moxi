"""Replay the experiment through the displayed window's native AX buttons."""
from std.ffi import external_call
from model import Workbench
from window import open_window
from moxi import App
from moxi.authoring import HandlerHost
from moxi.event import NONE_KIND
from moxi.macos import MacOSWindow, MacOSRenderer

comptime FitApp = App[HandlerHost[Workbench]]


def control(app: FitApp, label: String, enabled: Bool = True) raises -> Int:
    var snapshot = app.accessibility()
    for node in snapshot.nodes:
        if node.label == label and node.enabled == enabled:
            return node.id
    raise Error("Missing control or wrong state: " + label)


def press(mut app: FitApp, mut window: MacOSWindow, mut renderer: MacOSRenderer, label: String) raises:
    external_call["moxi_lifecycle_press", NoneType](Int32(control(app, label)))
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
    _ = control(app, "Apply", False)
    _ = control(app, "Live revision 0    Gain 1    Offset 0")
    capture("01-initial.png")

    press(app, window, renderer, "Request fit proposal")
    _ = control(app, "Live revision 0    Gain 1    Offset 0")
    _ = control(app, "Gain: 1 to 3")
    _ = control(app, "Offset: 0 to 4")
    _ = control(app, "Request fit proposal", False)
    capture("02-inspect.png")

    press(app, window, renderer, "Reject")
    _ = control(app, "Rejected. Live values preserved.")
    _ = control(app, "Live revision 0    Gain 1    Offset 0")
    _ = control(app, "Apply", False)
    capture("03-reject.png")

    press(app, window, renderer, "Request fit proposal")
    press(app, window, renderer, "Increase live gain")
    _ = control(app, "Proposed fit from revision 0")
    _ = control(app, "Gain: 1 to 3")
    _ = control(app, "Live revision 1    Gain 2    Offset 0")
    capture("04-edited.png")

    press(app, window, renderer, "Apply")
    _ = control(app, "Stale proposal rejected. Request a fresh fit.")
    _ = control(app, "Live revision 1    Gain 2    Offset 0")
    _ = control(app, "Apply", False)
    capture("05-stale.png")

    press(app, window, renderer, "Request fit proposal")
    _ = control(app, "Gain: 2 to 3")
    _ = control(app, "Proposed fit from revision 1")
    press(app, window, renderer, "Apply")
    _ = control(app, "Live revision 2    Gain 3    Offset 4")
    _ = control(app, "Applied both fit parameters.")
    _ = control(app, "Apply", False)
    capture("06-applied.png")
    print("PASS: inspect, reject, edit, stale refusal and fresh apply")
