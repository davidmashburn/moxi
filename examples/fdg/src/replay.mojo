"""Finite, opt-in replay of the real app for reproducible capture evidence."""
from std.ffi import external_call
from moxi import App, Rect, Point, Event, PointerEvent, ScrollEvent, ClickEvent
from moxi.event import POINTER_DOWN_KIND, POINTER_MOVE_KIND, POINTER_CANCEL_KIND
from graph_app import GraphApp, CANVAS, FIND, NEIGHBORS
from graph_export import export_graph

comptime REPLAY_INITIAL = 0
comptime REPLAY_INTERACTION = 1
comptime REPLAY_RESULT = 2
comptime REPLAY_RECOVERY = 3

@no_inline
def replay_action(mut app: App[GraphApp], phase: Int, directory: String) raises:
    var bounds = app.view.bounds_for(CANVAS)
    if phase == REPLAY_INITIAL:
        app.component.graph.paused = True
        var query = app.component.graph.nodes[0].id
        app.component.query.set_text(query)
        var find = app.view.bounds_for(FIND)
        _ = app.dispatch(Event(ClickEvent(Point(find.x + 5, find.y + 5))))
        var neighbors = app.view.bounds_for(NEIGHBORS)
        _ = app.dispatch(Event(ClickEvent(Point(neighbors.x + 5, neighbors.y + 5))))
    elif phase == REPLAY_INTERACTION:
        var p = app.component.screen(0, bounds)
        _ = app.dispatch(Event(PointerEvent(POINTER_DOWN_KIND, p)))
        _ = app.dispatch(Event(PointerEvent(POINTER_MOVE_KIND, Point(p.x + 65, p.y - 30))))
        _ = app.dispatch(Event(PointerEvent(POINTER_CANCEL_KIND, p)))
        _ = app.dispatch(Event(ScrollEvent(p, Point(0, 3))))
        app.component.message = "Replayed drag/cancel and zoom; selection retained"
    elif phase == REPLAY_RESULT:
        export_graph(app.component, bounds, String(directory, "/current.svg"))
        export_graph(app.component, bounds, String(directory, "/current.png"))
        export_graph(app.component, bounds, String(directory, "/current.pdf"))
        app.component.message = "Saved current state as SVG / PNG / PDF"
    elif phase == REPLAY_RECOVERY:
        var rejected = False
        try:
            export_graph(app.component, bounds, String(directory, "/rejected.jpg"))
        except:
            rejected = True
        if not rejected:
            raise Error("Replay expected unsupported-format rejection")
        app.component.message = "Recovered: unsupported .jpg rejected; SVG still available"
        export_graph(app.component, bounds, String(directory, "/recovered.svg"))
    app.rebuild()

def capture_frame(var path: String) raises:
    var c_path = path.as_c_string_span()
    if external_call["fdg_capture_frame", Int32](c_path.ptr()) != 0:
        raise Error("Native content capture failed")
