"""Scripted App events rendered by AppKit; no live desktop input claim."""
from std.sys import argv
from std.ffi import external_call
from moxi import test_check, App, Rect, Event, ActionEvent, ACTION_PRESS, KeyEvent, KEY_TAB, KEY_ENTER, Point, ScrollEvent, INVALIDATE_ALL
from moxi.macos import MacOSRenderer
from moxi_demo.demo_browser import DemoBrowserState, DEMO_ENTRY_VIEW_BASE, DEMO_TAB_DEMO_ID
from moxi_demo.demo_style import DEMO_NOT_IMPLEMENTED_ID
from moxi_demo.not_implemented_demo import NotImplementedDemo, PATTERN_REPLACE_BUTTON_ID, PATTERN_FIRST_OFFSET

def act(target: Int) -> Event:
    var event = Event(ActionEvent(ACTION_PRESS))
    event.set_target(target)
    return event

def save(mut app: App[NotImplementedDemo], path: String, width: Int, height: Int) raises:
    var renderer = MacOSRenderer()
    var bounds = app.root_bounds
    app.invalidate(INVALIDATE_ALL, bounds)
    app.render(renderer)
    var name = path
    if external_call["n01_capture_save", Int32](name.as_c_string_span().ptr(), Int32(width), Int32(height)) != 1:
        raise Error("native capture failed")

def main() raises:
    var args = argv()
    if len(args) != 2:
        raise Error("Provide the output directory")
    var output = args[1]
    external_call["n01_capture_init", NoneType](Int32(600), Int32(620))
    var app = App(NotImplementedDemo(), Rect(0,0,600,620))
    save(app, output + "/initial.png",600,620)
    _ = app.dispatch(Event(KeyEvent(KEY_ENTER)))
    test_check(app.component.host_clicks == 1)
    save(app, output + "/interaction.png",600,620)
    _ = app.dispatch(act(PATTERN_REPLACE_BUTTON_ID))
    _ = app.dispatch(act(PATTERN_FIRST_OFFSET + 3))
    test_check(app.component.show_implemented_counter)
    test_check(app.component.counter.component.count == 1)
    save(app, output + "/result.png",600,620)
    _ = app.dispatch(act(PATTERN_REPLACE_BUTTON_ID))
    test_check(not app.component.show_implemented_counter)
    test_check(app.component.host_clicks == 1)
    save(app, output + "/recovery.png",600,620)
    _ = app.resize(Rect(0,0,280,620))
    save(app, output + "/narrow.png",280,620)
    _ = app.dispatch(Event(ScrollEvent(Point(10,10),Point(0,10000))))
    save(app, output + "/narrow-bottom.png",280,620)
    var browser = App(DemoBrowserState(), Rect(0,0,1100,760))
    _ = browser.dispatch(act(DEMO_ENTRY_VIEW_BASE + DEMO_NOT_IMPLEMENTED_ID))
    _ = browser.dispatch(act(DEMO_TAB_DEMO_ID))
    var renderer = MacOSRenderer()
    var bounds = browser.root_bounds
    browser.invalidate(INVALIDATE_ALL, bounds)
    browser.render(renderer)
    var path = output + "/playground.png"
    if external_call["n01_capture_save", Int32](path.as_c_string_span().ptr(),Int32(1100),Int32(760)) != 1:
        raise Error("Playground capture failed")
    print("Native renderer captures written")
