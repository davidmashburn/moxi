"""Reproducible CPU measurements; deliberately separate from native presentation."""
from std.time import perf_counter_ns
from std.collections import List
from moxi import Component, ColumnView, Rect, Point
from moxi.scene import Scene
from moxi_canvas import *
from moxi_canvas.geometry import GeometryCache
from canvas_demo.nodes import RichNode

struct SimpleNode(Component):
    def __init__(out self):
        pass
    def build(self, bounds: Rect) -> ColumnView:
        var view = ColumnView(bounds, 4, 2)
        view.add_button(1, "Node", 25)
        view.layout()
        return view^

def fixture(count: Int, edges: Int, hub: Bool = False) raises -> CanvasDocument:
    var doc = CanvasDocument()
    for i in range(count):
        var id = i + 1
        doc.add(CanvasObject(id, Rect(Float32(i % 40) * 160, Float32(i // 40) * 120, 140, 100), String("Node ", id)))
        doc.add_port(Port(id * 2, id, PortDirection.INPUT, 0, 0.5))
        doc.add_port(Port(id * 2 + 1, id, PortDirection.OUTPUT, 1, 0.5))
    # Valid deterministic fixture bulk construction, not interactive policy cost.
    for i in range(edges):
        var a = 1 if hub else (i % count + 1)
        var b = (a + i // count) % count + 1
        if b == a:
            b = b % count + 1
        doc.edges.append(GraphEdge(i + 1, a * 2 + 1, b * 2, "", PathKind.STRAIGHT))
    doc.revision += 1
    return doc^

def consume(view: ColumnView, scene: Scene) -> Float64:
    # Read geometry after timing so every measured publication remains observable.
    var result: Float64 = 0
    for node in view.children:
        result += Float64(node.bounds.x + node.bounds.y + node.bounds.width)
    for i in range(scene.count()):
        var command = scene.command(i)
        result += Float64(command.bounds.x + command.bounds.y + command.point_end.x + command.point_end.y)
    return result

def report(name: String, mut samples: List[Float64]):
    for i in range(1, len(samples)):
        var j = i
        while j > 0 and samples[j] < samples[j - 1]:
            var value = samples[j]
            samples[j] = samples[j - 1]
            samples[j - 1] = value
            j -= 1
    print(name, "p95_ms", samples[(len(samples) * 95 - 1) // 100], "p99_ms", samples[(len(samples) * 99 - 1) // 100], "worst_ms", samples[len(samples) - 1])

def measure[Child: Component & Deinitable](doc: CanvasDocument, child: Child, name: String, visible_all: Bool) raises:
    var cold = perf_counter_ns()
    var canvas = CanvasView[Child](doc)
    for object in doc.objects:
        canvas.mount(object.id, child)
    var root = Rect(0, 0, 1200, 800)
    _ = canvas.localized_view(root)
    if visible_all:
        _ = canvas.command(CanvasCommand.FIT_ALL)
        # A large viewport intentionally makes all 1000 nodes visible at zoom >= .1.
        root = Rect(0, 0, 7000, 4000)
        _ = canvas.localized_view(root)
    print(name, "cold_ms", Float64(perf_counter_ns() - cold) / 1_000_000, "objects", len(doc.objects), "edges", len(doc.edges))
    var initial_builds = canvas.mounts[len(canvas.mounts) - 1].builds
    var samples = List[Float64]()
    var checksum: Float64 = 0
    for i in range(40):
        var start = perf_counter_ns()
        canvas.state.camera.pan(1, 0)
        var view = canvas.localized_view(root)
        var scene = canvas.scene()
        samples.append(Float64(perf_counter_ns() - start) / 1_000_000)
        checksum += consume(view, scene)
        if i == 39:
            print(name, "published_nodes", view.child_count(), "scene_commands", scene.count(), "cache_routes", canvas.geometry_cache.routes, "cache_hits", canvas.geometry_cache.hits, "index_writes", canvas.geometry_cache.object_hits.writes)
    report(name + " pan through scene construction (no native submission)", samples)
    samples.clear()
    var writes = canvas.geometry_cache.object_hits.writes
    for i in range(40):
        var start = perf_counter_ns()
        canvas.state.select(i % len(doc.objects) + 1)
        var view = canvas.localized_view(root)
        var scene = canvas.scene()
        samples.append(Float64(perf_counter_ns() - start) / 1_000_000)
        checksum += consume(view, scene)
    report(name + " selection through scene construction", samples)
    print(name, "selection_index_writes", canvas.geometry_cache.object_hits.writes - writes, "unrelated_measurements", canvas.mounts[len(canvas.mounts) - 1].builds - initial_builds)
    _ = canvas.command(CanvasCommand.MOVE)
    samples.clear()
    for i in range(40):
        var start = perf_counter_ns()
        canvas.state.nudge(1, 0)
        var view = canvas.localized_view(root)
        var scene = canvas.scene()
        samples.append(Float64(perf_counter_ns() - start) / 1_000_000)
        checksum += consume(view, scene)
    report(name + " drag preview through scene construction", samples)
    print(name, "published_geometry_checksum", checksum)
    var start = perf_counter_ns()
    _ = canvas.command(CanvasCommand.COMMIT)
    print(name, "transaction_ms", Float64(perf_counter_ns() - start) / 1_000_000, "history_snapshots", len(canvas.state.history.before) * 2, "history_objects", len(canvas.state.history.before) * len(doc.objects) * 2)

def main() raises:
    print("CPU only; native submission/GPU/presentation/allocation bytes NOT measured. Native ordered paint has a 1024-command cap. These results do not pass the 8ms native budget.")
    measure(fixture(100, 200), SimpleNode(), "simple-100", False)
    measure(fixture(1000, 2000), SimpleNode(), "simple-1000-visible", True)
    measure(fixture(100, 200), RichNode(), "rich-100", False)
    var start = perf_counter_ns()
    var doc = fixture(10000, 20000, True)
    var camera = Camera(Rect(0, 0, 1200, 800))
    var cache = GeometryCache()
    var snapshot = CanvasSnapshot(doc, camera, -1, cache)
    print("stress-10000 hub-20000 cold geometry_ms", Float64(perf_counter_ns() - start) / 1_000_000, "cached_edges", len(cache.edges), "visible_edges", len(snapshot.edges), "port_cells", len(cache.port_hits.cells))
    start = perf_counter_ns()
    var next = CanvasSnapshot(doc, camera, -1, cache)
    print("stress-10000 hot geometry_ms", Float64(perf_counter_ns() - start) / 1_000_000, "route_cache_hits", cache.hits, "published_edges", len(next.edges))
