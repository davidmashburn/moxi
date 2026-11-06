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
    var graph = App(freeform_graph(), Rect(0, 0, 1060, 780))
    graph.component.state.select(1)
    var initial_revision = graph.component.document.revision
    var initial_history = graph.component.state.history.cursor
    check(not invoke_canvas(graph, CanvasCommand.UNGROUP), "ungrouping a plain node is a no-op")
    check(graph.component.document.revision == initial_revision and graph.component.state.history.cursor == initial_history, "no-op ungroup retains revision and history")
    check(graph.component.document.connect(GraphEdge(-1, 11, 20), graph.component.policy) == "Edge ID must be nonnegative", "reject sentinel edge identity")
    check(graph.component.document.revision == initial_revision, "invalid identity leaves document unchanged")
    _ = invoke_canvas(graph, CanvasCommand.CONNECT)
    graph.component.state.target = 20
    var committed = invoke_canvas(graph, CanvasCommand.COMMIT)
    check(not committed, "duplicate invalid edge")
    check(len(graph.component.document.edges) == 3, "invalid edge preserves graph")
    graph.component.state.selected_edge = 1
    _ = invoke_canvas(graph, CanvasCommand.RECONNECT)
    graph.component.state.target = 10
    committed = invoke_canvas(graph, CanvasCommand.COMMIT)
    check(not committed, "invalid reconnect self")
    check(graph.component.document.edges[0].target == 20, "old edge retained")
    graph.component.state.target = 40
    committed = invoke_canvas(graph, CanvasCommand.COMMIT)
    check(not committed, "capacity rejection")
    _ = invoke_canvas(graph, CanvasCommand.CANCEL)
    _ = invoke_canvas(graph, CanvasCommand.TOGGLE)
    graph.component.state.selected_edge = 3
    _ = invoke_canvas(graph, CanvasCommand.DELETE)
    graph.component.state.selected_edge = 1
    _ = invoke_canvas(graph, CanvasCommand.RECONNECT)
    graph.component.state.target = 40
    committed = invoke_canvas(graph, CanvasCommand.COMMIT)
    check(committed, "valid reconnect")
    check(graph.component.document.edges[0].target == 40, "reconnected endpoint")
    _ = invoke_canvas(graph, CanvasCommand.UNDO)
    check(graph.component.document.edges[0].target == 20, "reconnect undo")
    graph.component.state.select(1)
    graph.component.state.select(2, True)
    var world = graph.component.document.world_bounds(1)
    var grouped = invoke_canvas(graph, CanvasCommand.GROUP)
    check(grouped, "group")
    var group_id = graph.component.state.focus
    graph.component.state.select(1, True)
    _ = invoke_canvas(graph, CanvasCommand.MOVE)
    graph.component.state.nudge(20, 30)
    _ = invoke_canvas(graph, CanvasCommand.COMMIT)
    check(graph.component.document.world_bounds(1).x == world.x + 20, "group child not double moved")
    graph.component.state.select(group_id)
    grouped = invoke_canvas(graph, CanvasCommand.UNGROUP)
    check(grouped, "ungroup")
    check(graph.component.document.world_bounds(1).x == world.x + 20, "ungroup preserves world")
    var count = len(graph.component.document.objects)
    _ = invoke_canvas(graph, CanvasCommand.CREATE)
    check(len(graph.component.document.objects) == count + 1, "keyboard create")
    _ = invoke_canvas(graph, CanvasCommand.DELETE)
    _ = invoke_canvas(graph, CanvasCommand.UNDO)
    check(len(graph.component.document.objects) == count + 1, "delete undo")
    var map = graph.component.minimap()
    var old_camera = graph.component.state.camera.x
    _ = dispatch_canvas(graph, pointer(POINTER_DOWN_KIND, map.viewport.x + 5, map.viewport.y + 5))
    check(graph.component.state.camera.x != old_camera, "minimap pan")
    for host in List[HostPlatform]([HostPlatform.MACOS, HostPlatform.WINDOWS, HostPlatform.LINUX]):
        check(not binding_conflict(canvas_bindings(host), host), "platform bindings unique")
        check(resolve_modifier(ShortcutModifier.PRIMARY, host) == (MOD_COMMAND if host == HostPlatform.MACOS else MOD_CONTROL), "Primary mapping")
    print("graph contract PASS")
