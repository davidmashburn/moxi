from std.ffi import external_call
from std.sys import argv
from cohort import CohortScreen
from moxi import App, Point, Rect, WindowConfig
from moxi.capability_types import CALLER_AGENT, CALLER_SYSTEM, CAPABILITY_DISABLED
from moxi.event import NONE_KIND
from moxi.macos import MacOSRenderer, MacOSWindow


def check(condition: Bool, message: String) raises:
    if not condition:
        raise Error(message)


def snapshot(name: String):
    var filename = name
    external_call["cohort_snapshot", NoneType](filename.as_c_string_span().ptr())


def drain(mut app: App[CohortScreen], mut window: MacOSWindow, mut renderer: MacOSRenderer) raises:
    var event = window.poll_event()
    while event.kind != NONE_KIND:
        _ = app.dispatch(event)
        event = window.poll_event()
    app.render(renderer)


def main() raises:
    var args = argv()
    var mode = String("") if len(args) == 1 else String(args[1])
    check(len(args) <= 2, "Usage: notebook [--script|--agent|--replay]")
    var screen = CohortScreen()
    if mode == "--script" or mode == "--agent":
        var caller = CALLER_SYSTEM if mode == "--script" else CALLER_AGENT
        var result = screen.collect(caller, "Script" if caller == CALLER_SYSTEM else "Agent")
        if not result.completed():
            print(result.recovery_hint)
            external_call["exit", NoneType](Int32(1))
        print(result.output)
        return
    check(len(args) == 1 or mode == "--replay", "Usage: notebook [--script|--agent|--replay]")
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    window.open(WindowConfig("Moxi | Field notebook", 460, 342))
    var size = window.size()
    var app = App(screen, Rect(0, 0, size.width, size.height))
    if mode != "--replay":
        app.run(window, renderer)
        return
    app.render(renderer)
    snapshot("01-ready.png")
    for i in range(2):
        var id = app.component.button_id()
        var button = app.view.bounds_for(id)
        var x = button.x + button.width / 2
        var y = button.y + button.height / 2
        check(app.hit_test(Point(x, y)) == id, "Button hit target")
        external_call["cohort_mouse", NoneType](x, y, Int32(1))
        drain(app, window, renderer)
        if i == 0:
            check(app.pressed_id() == id, "Pointer down")
            snapshot("02-pressed.png")
        external_call["cohort_mouse", NoneType](x, y, Int32(0))
        drain(app, window, renderer)
        check(app.component.button_id() != id and app.component.notebook.writes == i+1, "Rebuilt target")
        check(app.component.notebook.member_ids() == "[104,318]" and app.component.status == "Button / Saved cohort", "Mouse result")
    snapshot("03-button.png")

    # Use a fresh model so a previous success cannot mask a broken input route.
    app = App(CohortScreen(), app.root_bounds)
    app.render(renderer)
    external_call["cohort_shortcut", NoneType]()
    drain(app, window, renderer)
    check(app.component.notebook.writes == 1 and app.component.status == "Keyboard / Saved cohort", "Shortcut result")
    var expected = app.component.notebook.member_ids()
    check(expected == "[104,318]", "Keyboard members")
    snapshot("04-shortcut.png")
    app = App(CohortScreen(), app.root_bounds)
    var scripted = app.component.collect(CALLER_SYSTEM, "Script")
    check(scripted.completed() and scripted.output == expected, "Script equivalence")
    app.rebuild()
    app.render(renderer)
    snapshot("05-script.png")
    var rejected = app.component.collect(CALLER_AGENT, "Agent")
    check(rejected.status == CAPABILITY_DISABLED and not rejected.executed, "Caller rejected")
    check(app.component.notebook.member_ids() == expected and app.component.notebook.writes == 1, "Rejected mutation")
    app.rebuild()
    app.render(renderer)
    snapshot("06-denied.png")
    print("PASS native button, rebuilt ID, F2, script equivalence and read-only rejection")
