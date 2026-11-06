"""Independent oracle: uses Moxi directly, never the browser ABI or JS bridge."""
from moxi import App, Rect, Point, Event, SvgSceneRenderer
from moxi.event import POINTER_DOWN_KIND, POINTER_MOVE_KIND, POINTER_UP_KIND, POINTER_CANCEL_KIND, FRAME_TICK_KIND, SCROLL_KIND, KEY_DOWN_KIND, KEY_RIGHT, KEY_ENTER, ACTION_KIND, TEXT_INPUT_KIND
from moxi.accessibility import ACTION_PRESS
from moxi.paint import scene_from_paint
from graph_app import GraphApp, CANVAS, PAUSE, RESTART, SEARCH, dispatch_graph_event
from layout import sample_graph
from std.sys import argv

def snapshot(app: App[GraphApp]):
    print("APP", app.component.selected, app.component.zoom, app.component.pan.x, app.component.pan.y, Int(app.component.graph.paused), app.component.graph.alpha, len(app.component.graph.nodes), len(app.component.graph.links))
    var bounds = app.view.bounds_for(CANVAS)
    for i in range(len(app.component.graph.nodes)):
        var node = app.component.graph.nodes[i]
        var p = app.component.screen(i, bounds)
        print("NODE", i, node.x, node.y, node.vx, node.vy, Int(node.pinned), p.x, p.y)

def event(mut app: App[GraphApp], kind: Int, x: Float32 = 0, y: Float32 = 0, value: Float32 = 0, key: Int = 0):
    print("EVENT", kind, x, y, value, key)
    var e = Event()
    e.kind = kind
    e.position = Point(x, y)
    e.scroll_delta = Point(0, value)
    e.key = key
    e.delta_seconds = 1.0 / 60.0
    if kind == ACTION_KIND:
        e.target = key
        e.action_id = Int(value)
    _ = dispatch_graph_event(app, e)

def svg(mut app: App[GraphApp], path: String) raises:
    var scene = scene_from_paint(app.paint())
    var graph = app.component.scene(app.view.bounds_for(CANVAS))
    for command in graph.commands:
        scene.append(command)
    var renderer = SvgSceneRenderer(Int(app.root_bounds.width), Int(app.root_bounds.height))
    renderer.render_scene(scene)
    with open(path, "w") as file:
        file.write(renderer.markup())
    app.clear_invalidation()

def main() raises:
    var args = argv()
    var app = App[GraphApp](GraphApp(sample_graph()), Rect(0, 0, 1000, 760))
    app.component.fit(app.view.bounds_for(CANVAS))
    snapshot(app)
    svg(app, String(args[1], "/native-initial.svg"))
    for _ in range(10):
        event(app, FRAME_TICK_KIND)
    snapshot(app)
    var p = app.component.screen(0, app.view.bounds_for(CANVAS))
    event(app, POINTER_DOWN_KIND, p.x, p.y)
    event(app, POINTER_MOVE_KIND, p.x + 35, p.y - 20)
    snapshot(app)
    event(app, POINTER_UP_KIND, p.x + 35, p.y - 20)
    event(app, KEY_DOWN_KIND, key=KEY_RIGHT)
    event(app, SCROLL_KIND, p.x, p.y, 3)
    snapshot(app)
    var bounds = app.view.bounds_for(CANVAS)
    event(app, POINTER_DOWN_KIND, bounds.x + 5, bounds.y + 5)
    event(app, POINTER_MOVE_KIND, bounds.x + 25, bounds.y + 30)
    event(app, POINTER_CANCEL_KIND, bounds.x + 25, bounds.y + 30)
    event(app, ACTION_KIND, value=ACTION_PRESS, key=PAUSE)
    for _ in range(3):
        event(app, FRAME_TICK_KIND)
    snapshot(app)
    print("RESIZE", 1100, 800)
    _ = app.resize(Rect(0, 0, 1100, 800))
    event(app, ACTION_KIND, value=ACTION_PRESS, key=RESTART)
    event(app, FRAME_TICK_KIND)
    snapshot(app)
    var search = app.view.bounds_for(SEARCH)
    event(app, POINTER_DOWN_KIND, search.x + 10, search.y + 10)
    event(app, POINTER_UP_KIND, search.x + 10, search.y + 10)
    var text = Event()
    text.kind = TEXT_INPUT_KIND
    text.text = "node-12"
    print("TEXT", text.text)
    _ = dispatch_graph_event(app, text)
    event(app, KEY_DOWN_KIND, key=KEY_ENTER)
    snapshot(app)
    svg(app, String(args[1], "/native-final.svg"))
