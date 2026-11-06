"""Fixed synthetic workloads; layout and scene construction only, no native paint."""
from std.time import perf_counter_ns
from moxi import Rect
from layout import Layout, Node, Link, MAX_NODES, MAX_LINKS
from graph_app import GraphApp

def measure(count: Int, edges: Int) raises:
    var graph = Layout()
    for i in range(count):
        # Benchmark-only construction above the production input cap. Same
        # solver and scene; no change to accepted graph capacity or algorithm.
        graph.nodes.append(Node(String(i), i % 6, i))
        graph.degrees.append(0)
    for i in range(edges):
        var a = i % count
        var b = (i * 7 + 1) % count
        graph.links.append(Link(a, b))
        graph.degrees[a] += 1
        graph.degrees[b] += 1
    for _ in range(30):
        graph.alpha = 1
        _ = graph.step()
    var start = perf_counter_ns()
    for _ in range(200):
        graph.alpha = 1
        _ = graph.step()
    var layout_ns = perf_counter_ns() - start
    var app = GraphApp(graph^)
    var bounds = Rect(0, 0, 1100, 720)
    app.fit(bounds)
    var checksum = 0
    for _ in range(30):
        var scene = app.scene(bounds)
        checksum += len(scene.commands)
    start = perf_counter_ns()
    for _ in range(200):
        var scene = app.scene(bounds)
        checksum += len(scene.commands)
    var scene_ns = perf_counter_ns() - start
    print("nodes=", count, " links=", edges, " layout_us=", Float64(layout_ns) / 200000.0,
          " scene_us=", Float64(scene_ns) / 200000.0, " checksum=", checksum)

def main() raises:
    print("warmup=30 samples=200; active simulation; scene excludes native painting")
    measure(77, 254)
    measure(256, 1024)
    measure(512, 2048)
    measure(1024, 4096)
    print("Production input caps unchanged: nodes=", MAX_NODES, " links=", MAX_LINKS, "; larger cases bypass validation only inside this benchmark; no native capacity claim")
