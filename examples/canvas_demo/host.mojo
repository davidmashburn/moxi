"""Executable host and reproducible real-view capture replay shared by both demos."""
from std.ffi import external_call
from std.sys import argv
from std.time import perf_counter_ns
from moxi import App, Component, Rect, Point, Event, WindowConfig
from moxi.event import *
from moxi.macos import MacOSWindow, MacOSRenderer, MacOSCanvasSceneRenderer, MacOSClipboard
from moxi_canvas import CanvasView, CanvasCommand, dispatch_canvas, invoke_canvas
from moxi_canvas.native import render_canvas, canvas_accessibility


def capture[Child: Component & Deinitable](mut app: App[CanvasView[Child]], mut window: MacOSWindow, mut paint: MacOSRenderer, mut graph: MacOSCanvasSceneRenderer, path: String) raises:
    render_canvas(app, paint, graph)
    window.pump()
    var owned = path
    if external_call["moxi_canvas_capture", Int32](owned.as_c_string_span().ptr()) != 1:
        raise Error(String("Native view capture failed: ", path))
    print("Captured", path)


def key[Child: Component & Deinitable](mut app: App[CanvasView[Child]], code: Int, modifiers: Int = 0):
    var event = Event()
    event.kind = KEY_DOWN_KIND
    event.key = code
    event.modifiers = modifiers
    _ = dispatch_canvas(app, event)


def run_demo[Child: Component & Deinitable](canvas: CanvasView[Child], title: String) raises:
    var app = App(canvas, Rect(0, 0, 1060, 780))
    var window = MacOSWindow()
    window.open(WindowConfig(title, 1060, 780))
    var paint = MacOSRenderer()
    var graph = MacOSCanvasSceneRenderer()
    var args = argv()
    if len(args) == 3 and args[1] == "--capture":
        var path = args[2]
        capture(app, window, paint, graph, path + "/01-initial.png")
        var button = app.view.bounds_for(11002)
        pointer(app, POINTER_DOWN_KIND, button.x + 20, button.y + 10)
        pointer(app, POINTER_UP_KIND, button.x + 20, button.y + 10)
        var slider = app.view.bounds_for(11003)
        pointer(app, POINTER_DOWN_KIND, slider.x + 20, slider.y + 10)
        pointer(app, POINTER_MOVE_KIND, slider.x + slider.width * 0.8, slider.y + 10)
        pointer(app, POINTER_UP_KIND, slider.x + slider.width * 0.8, slider.y + 10)
        capture(app, window, paint, graph, path + "/10-control-ownership.png")
        app.component.state.select(1)
        _ = invoke_canvas(app, CanvasCommand.ENTER_CONTROLS)
        var input = Event()
        input.kind = TEXT_INPUT_KIND
        input.text = " · edited"
        _ = dispatch_canvas(app, input)
        capture(app, window, paint, graph, path + "/05-native-editor.png")
        var editor_id = external_call["moxi_canvas_editor_identity", UInt64]()
        if editor_id == 0:
            raise Error("No native NSTextField in focused canvas node")
        _ = invoke_canvas(app, CanvasCommand.ZOOM_OUT)
        app.component.parent_scroll = 90
        app.rebuild_localized()
        capture(app, window, paint, graph, path + "/06-zoom-clip.png")
        var bounds = app.view.bounds_for(11001)
        var ax = canvas_accessibility(app)
        var clipped = bounds
        for node in ax.nodes:
            if node.id == 11001:
                clipped = node.bounds
        var font: Float32 = 0
        for node in app.view.children:
            if node.id == 11001:
                font = node.style.font_size
        if external_call["moxi_canvas_editor_geometry", Int32](bounds.x, bounds.y, bounds.width, bounds.height, clipped.x, clipped.y, clipped.width, clipped.height, font) != 1:
            raise Error("Native editor/clip/font differ from published view and semantics")
        print("Native editor frame, clip, font agree with published geometry and semantics: PASS")
        if external_call["moxi_canvas_editor_identity", UInt64]() != editor_id:
            raise Error("Camera/scroll replaced native editor")
        print("Native editor identity survives zoom and parent scroll: PASS")
        app.component.parent_scroll = 0
        _ = invoke_canvas(app, CanvasCommand.RESET_ZOOM)
        _ = invoke_canvas(app, CanvasCommand.LEAVE_CONTROLS)
        _ = invoke_canvas(app, CanvasCommand.MOVE)
        for i in range(7):
            key(app, KEY_RIGHT, MOD_SHIFT)
        key(app, KEY_DOWN, MOD_SHIFT)
        capture(app, window, paint, graph, path + "/02-preview.png")
        key(app, KEY_ESCAPE)
        capture(app, window, paint, graph, path + "/11-cancel.png")
        _ = invoke_canvas(app, CanvasCommand.MOVE)
        for i in range(7):
            key(app, KEY_RIGHT, MOD_SHIFT)
        key(app, KEY_DOWN, MOD_SHIFT)
        key(app, KEY_ENTER)
        _ = invoke_canvas(app, CanvasCommand.RESIZE)
        for i in range(5):
            key(app, KEY_RIGHT, MOD_SHIFT)
        key(app, KEY_ENTER)
        capture(app, window, paint, graph, path + "/03-result.png")
        _ = invoke_canvas(app, CanvasCommand.UNDO)
        _ = invoke_canvas(app, CanvasCommand.UNDO)
        capture(app, window, paint, graph, path + "/04-recovery.png")
        if len(app.component.document.objects) >= 2:
            _ = invoke_canvas(app, CanvasCommand.CONNECT)
            app.component.state.target = 20
            _ = invoke_canvas(app, CanvasCommand.COMMIT)
            capture(app, window, paint, graph, path + "/07-invalid-edge.png")
            _ = invoke_canvas(app, CanvasCommand.CANCEL)
            if len(app.component.document.objects) > 2:
                _ = invoke_canvas(app, CanvasCommand.NEXT_EDGE)
                _ = invoke_canvas(app, CanvasCommand.NEXT_EDGE)
                _ = invoke_canvas(app, CanvasCommand.NEXT_EDGE)
                _ = invoke_canvas(app, CanvasCommand.DELETE)
            _ = invoke_canvas(app, CanvasCommand.NEXT_EDGE)
            _ = invoke_canvas(app, CanvasCommand.RECONNECT)
            app.component.state.target = 40 if len(app.component.document.objects) > 2 else 22
            _ = invoke_canvas(app, CanvasCommand.COMMIT)
            capture(app, window, paint, graph, path + "/08-reconnected.png")
            app.component.state.select(1)
            app.component.state.select(2, True)
            _ = invoke_canvas(app, CanvasCommand.GROUP)
            _ = invoke_canvas(app, CanvasCommand.MOVE)
            key(app, KEY_DOWN, MOD_SHIFT)
            key(app, KEY_ENTER)
            _ = invoke_canvas(app, CanvasCommand.FIT_ALL)
            capture(app, window, paint, graph, path + "/09-group-fit.png")
        print("Content builds:", app.component.mounts[0].builds, app.component.mounts[1].builds, "parent publications:", app.component.parent_builds)
        window.close()
        return
    var clipboard = MacOSClipboard()
    render_canvas(app, paint, graph)
    var prior_tick = perf_counter_ns()
    while window.is_open():
        window.pump()
        var changed = False
        var event = window.poll_event()
        while event.kind != NONE_KIND:
            if app.is_clipboard_command(event) and event.key == KEY_V:
                app.set_clipboard(clipboard.paste())
            changed = dispatch_canvas(app, event) or changed
            if app.is_clipboard_command(event) and (event.key == KEY_C or event.key == KEY_X):
                clipboard.copy(app.clipboard_text())
            event = window.poll_event()
        var tick = Event()
        tick.kind = FRAME_TICK_KIND
        var now = perf_counter_ns()
        tick.delta_seconds = Float32(Float64(now - prior_tick) / 1_000_000_000)
        prior_tick = now
        changed = dispatch_canvas(app, tick) or changed
        if changed:
            render_canvas(app, paint, graph)
        window.wait_for_work(1.0 / 60)
    app.component.state.cancel()
    window.close()


def pointer[Child: Component & Deinitable](mut app: App[CanvasView[Child]], kind: Int, x: Float32, y: Float32):
    var event = Event()
    event.kind = kind
    event.position = Point(x, y)
    event.pointer_id = 0
    _ = dispatch_canvas(app, event)
