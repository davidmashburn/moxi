"""Behavioral replay of the public canvas through actual ordinary components."""
from std.collections import List
from moxi import App, Rect, Point, Event, test_check
from moxi.event import *
from moxi_canvas import *
from moxi_canvas.native import canvas_accessibility
from canvas_demo.fixtures import rich_probe, freeform_graph


def check(value: Bool, name: String) raises:
    if not value:
        raise Error(name)


def pointer(kind: Int, x: Float32, y: Float32, id: Int = 0) -> Event:
    var event = Event()
    event.kind = kind
    event.position = Point(x, y)
    event.pointer_id = id
    return event


def key(code: Int, modifiers: Int = 0) -> Event:
    var event = Event()
    event.kind = KEY_DOWN_KIND
    event.key = code
    event.modifiers = modifiers
    return event


def main() raises:
    var camera = Camera(Rect(17, 83, 900, 600))
    camera.x = 999500
    camera.y = -999500
    var point = WorldPoint(999523.25, -999480.5)
    for zoom in List[Float64]([0.1, 0.75, 1.0, 4.0]):
        camera.zoom = zoom
        var roundtrip = camera.unproject(camera.project(point))
        check(abs(roundtrip.x - point.x) < 0.001 and abs(roundtrip.y - point.y) < 0.001, "coordinate inverse")
    var anchor = Point(400, 300)
    var old = camera.unproject(WindowPoint(anchor.x, anchor.y))
    camera.zoom_at(1.5, anchor)
    var after = camera.unproject(WindowPoint(anchor.x, anchor.y))
    check(abs(old.x - after.x) < 0.001, "zoom anchor")
    var app = App(rich_probe(), Rect(0, 0, 1060, 780))
    var first = app.component.document.world_bounds(1)
    var input_bounds = app.view.bounds_for(11001)
    _ = dispatch_canvas(app, pointer(POINTER_DOWN_KIND, input_bounds.x + 20, input_bounds.y + 10))
    _ = dispatch_canvas(app, pointer(POINTER_UP_KIND, input_bounds.x + 20, input_bounds.y + 10))
    check(app.component.state.session == SessionKind.IDLE and app.runtime.focus_id() == 11001, "text owns pointer/focus")
    var input = Event()
    input.kind = TEXT_INPUT_KIND
    input.text = "!"
    _ = dispatch_canvas(app, input)
    check("!" in app.component.mounts[0].child.input.text, "text routed to ordinary child")
    _ = dispatch_canvas(app, key(KEY_A, MOD_COMMAND))
    _ = dispatch_canvas(app, key(KEY_C, MOD_COMMAND))
    check(app.clipboard_text() == app.component.mounts[0].child.input.text, "ordinary clipboard selection")
    var comp = Event()
    comp.kind = COMPOSITION_UPDATE_KIND
    comp.text = "仮"
    comp.selection_start = 0
    comp.selection_end = 1
    _ = dispatch_canvas(app, comp)
    check(app.component.mounts[0].child.input.has_composition(), "synthetic composition retained")
    _ = dispatch_canvas(app, key(KEY_ESCAPE))
    check(not app.component.mounts[0].child.input.has_composition() and app.component.editor == 1, "escape ends inner composition")
    _ = dispatch_canvas(app, key(KEY_ESCAPE))
    var content_port = app.component.document.anchor(11)
    var button = app.view.bounds_for(11002)
    _ = dispatch_canvas(app, pointer(POINTER_DOWN_KIND, button.x + 15, button.y + 10))
    _ = dispatch_canvas(app, pointer(POINTER_UP_KIND, button.x + 15, button.y + 10))
    check(app.component.mounts[0].child.clicks == 1, "button activation exactly once")
    check(app.component.document.anchor(11).y > content_port.y, "content growth atomically publishes port geometry")
    check(app.component.state.session == SessionKind.IDLE and app.component.control_pointer < 0, "button release clears capture")
    var slider = app.view.bounds_for(11003)
    _ = dispatch_canvas(app, pointer(POINTER_DOWN_KIND, slider.x + 10, slider.y + 10))
    _ = dispatch_canvas(app, pointer(POINTER_MOVE_KIND, slider.x + slider.width - 2, slider.y + 10))
    _ = dispatch_canvas(app, pointer(POINTER_UP_KIND, slider.x + slider.width - 2, slider.y + 10))
    check(app.component.mounts[0].child.slider.value > 90, "slider owns drag")
    check(app.component.document.world_bounds(1).x == first.x, "controls never move document")
    _ = invoke_canvas(app, CanvasCommand.LEAVE_CONTROLS)
    var cursor = app.component.state.history.cursor
    _ = dispatch_canvas(app, pointer(POINTER_DOWN_KIND, 80, 145))
    _ = dispatch_canvas(app, pointer(POINTER_MOVE_KIND, 82, 146))
    check(not app.component.state.active, "screen threshold")
    _ = dispatch_canvas(app, pointer(POINTER_MOVE_KIND, 140, 175))
    check(app.component.state.preview(app.component.document).world_bounds(1).x == first.x + 60, "move preview")
    var scroll = Event()
    scroll.kind = SCROLL_KIND
    scroll.position = Point(200, 200)
    scroll.scroll_delta = Point(0, 10)
    scroll.modifiers = MOD_COMMAND
    var zoom = app.component.state.camera.zoom
    _ = dispatch_canvas(app, scroll)
    check(app.component.state.camera.zoom == zoom, "zoom frozen during drag")
    _ = dispatch_canvas(app, key(KEY_ESCAPE))
    check(app.component.document.world_bounds(1).x == first.x and app.component.state.history.cursor == cursor, "cancel restores without history")
    _ = dispatch_canvas(app, pointer(POINTER_DOWN_KIND, 80, 145))
    _ = dispatch_canvas(app, pointer(POINTER_MOVE_KIND, 140, 175))
    _ = dispatch_canvas(app, pointer(POINTER_UP_KIND, 140, 175))
    check(app.component.document.world_bounds(1).x == first.x + 60 and app.component.state.history.cursor == cursor + 1, "raw release commits one undo")
    _ = invoke_canvas(app, CanvasCommand.UNDO)
    check(app.component.document.world_bounds(1).x == first.x, "move undo")
    _ = invoke_canvas(app, CanvasCommand.MOVE)
    for i in range(10):
        _ = dispatch_canvas(app, key(KEY_RIGHT))
    _ = dispatch_canvas(app, key(KEY_ENTER))
    check(app.component.document.world_bounds(1).x == first.x + 10 and app.component.state.history.cursor == cursor + 1, "repeat coalesced keyboard move")
    var old_port = app.component.document.anchor(11)
    _ = invoke_canvas(app, CanvasCommand.RESIZE)
    _ = dispatch_canvas(app, key(KEY_RIGHT, MOD_SHIFT))
    _ = dispatch_canvas(app, key(KEY_ENTER))
    check(app.component.document.anchor(11).x == old_port.x + 10, "resize publishes port")
    var before_builds = app.component.mounts[0].builds
    var other_builds = app.component.mounts[1].builds
    for i in range(10):
        _ = invoke_canvas(app, CanvasCommand.ZOOM_OUT)
    check(app.component.mounts[0].builds == before_builds and app.component.mounts[1].builds == other_builds, "camera does no component measurement")
    check(app.execution_work_counters().root_fallbacks == 0, "no root fallback")
    var ax = canvas_accessibility(app)
    for node in ax.nodes:
        if node.id == 11001:
            check(node.bounds.width <= app.view.bounds_for(11001).width, "semantics clip agrees")
    app.component.state.select(1)
    _ = invoke_canvas(app, CanvasCommand.MOVE)
    app.component.document.revision += 1
    _ = dispatch_canvas(app, key(KEY_RIGHT))
    _ = dispatch_canvas(app, key(KEY_ENTER))
    check(app.component.state.session == SessionKind.IDLE, "stale preview rejected")
    print("rich canvas contract PASS")
