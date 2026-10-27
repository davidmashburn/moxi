from std.ffi import external_call
from std.testing import assert_equal, assert_true
from moxi import App, Rect, Point, Event, ClickEvent, WindowConfig
from moxi.macos import MacOSWindow, MacOSRenderer, MacOSCanvasSceneRenderer
from graph_app import GraphApp, CANVAS, PAUSE
from layout import sample_graph
from main import render

def main() raises:
    var window = MacOSWindow()
    window.open(WindowConfig("FDG complete-frame regression", 900, 650))
    var renderer = MacOSRenderer()
    var canvas = MacOSCanvasSceneRenderer()
    var app = App[GraphApp](GraphApp(sample_graph()), Rect(0, 0, 900, 650))
    app.component.fit(app.view.bounds_for(CANVAS))
    external_call["fdg_probe_install", NoneType]()
    var deferred_frames = 0
    for frame in range(60):
        if frame % 3 == 0:
            var button = app.view.bounds_for(PAUSE)
            _ = app.dispatch(Event(ClickEvent(Point(button.x + 5, button.y + 5))))
        elif frame % 3 == 1:
            var node = app.component.screen(0, app.view.bounds_for(CANVAS))
            _ = app.dispatch(Event(ClickEvent(node)))
        _ = app.tick(1.0 / 60.0)
        render(app, renderer, canvas)
        assert_equal(window.command_overflow_count(), 0)
        deferred_frames += Int(external_call["fdg_probe_pending", Int32]())
        # Also inspect draws that AppKit schedules on the following pump.
        window.pump()
    var draws = external_call["fdg_probe_draw_count", Int32]()
    var blank = external_call["fdg_probe_blank_count", Int32]()
    external_call["fdg_close_window", NoneType]()
    print("Native frames: draws=", draws, " blank=", blank, " deferred=", deferred_frames)
    assert_true(draws >= 60)
    assert_equal(blank, 0)
    assert_equal(deferred_frames, 0)
