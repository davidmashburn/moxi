"""Opt-in terminal ranking must preserve ordinary hit and publication contracts."""
from std.collections import List
from moxi import Point, Rect
from moxi_canvas import *
from moxi_canvas.geometry import GeometryCache
from canvas_demo.fixtures import freeform_graph


def check(value: Bool, message: String) raises:
    if not value:
        raise Error(message)


def close_routes(path: PathKind, policy: EdgeHitPolicy = EdgeHitPolicy.SNAPSHOT_ORDER) raises -> CanvasDocument:
    var doc = CanvasDocument()
    doc.add(CanvasObject(1, Rect(0, 0, 80, 64), "Source A"))
    doc.add(CanvasObject(2, Rect(100, 100, 80, 64), "Target A"))
    doc.add(CanvasObject(3, Rect(0, 0, 80, 64), "Source B"))
    doc.add(CanvasObject(4, Rect(100, 106, 80, 64), "Target B"))
    doc.add_port(Port(11, 1, PortDirection.OUTPUT, 0, 0))
    doc.add_port(Port(20, 2, PortDirection.INPUT, 0, 0))
    doc.add_port(Port(31, 3, PortDirection.OUTPUT, 0, 0))
    doc.add_port(Port(40, 4, PortDirection.INPUT, 0, 0))
    doc.edges.append(GraphEdge(1, 11, 20, path=path, hit_policy=policy))
    doc.edges.append(GraphEdge(2, 31, 40, path=path, hit_policy=policy))
    return doc^


def check_edge_hits() raises:
    var camera = Camera(Rect(0, 0, 500, 500))
    for path in List[PathKind]([PathKind.STRAIGHT, PathKind.CUBIC, PathKind.ORTHOGONAL]):
        var ordinary = close_routes(path)
        var snapshot = CanvasSnapshot(ordinary, camera)
        check(snapshot.hit_edge(Point(100, 100)) == 2, "ordinary overlapping edges retain snapshot order over distance")
        ordinary.edges[0].hit_policy = EdgeHitPolicy.NEAREST_TERMINAL
        snapshot = CanvasSnapshot(ordinary, camera)
        check(snapshot.hit_edge(Point(100, 100)) == 2, "topmost ordinary edge retains precedence over opted-in terminal")

    var doc = close_routes(PathKind.ORTHOGONAL, EdgeHitPolicy.NEAREST_TERMINAL)
    var cache = GeometryCache()
    var snapshot = CanvasSnapshot(doc, camera, -1, cache)
    check(snapshot.hit_edge(Point(75, 100)) == 1, "closest distinct terminal wins over later nearby terminal")
    check(snapshot.hit_edge(Point(75, 103)) == 2, "equal terminal distances retain snapshot order")
    check(snapshot.hit_edge(Point(50, 30)) == 2, "indistinguishable shared trunks retain snapshot order")
    check(snapshot.hit_edge(Point(75, 93)) == 1, "terminal keeps inclusive seven-point tolerance")
    check(snapshot.hit_edge(Point(75, 92.9)) == -1, "terminal does not expand hit tolerance")
    var copied = snapshot
    check(copied.edges[0].hit_policy == EdgeHitPolicy.NEAREST_TERMINAL and copied.hit_edge(Point(75, 100)) == 1, "snapshot copy retains terminal policy")

    # The later edge's trunk crosses the earlier edge's terminal exactly.
    doc.objects[3].bounds = Rect(150, 150, 80, 64)
    snapshot = CanvasSnapshot(doc, camera, -1, cache)
    check(snapshot.hit_edge(Point(75, 100)) == 1, "terminal wins over intersecting sibling trunk")
    var routes = cache.routes
    var writes = cache.edge_hits.writes
    doc.edges[0].hit_policy = EdgeHitPolicy.SNAPSHOT_ORDER
    snapshot = CanvasSnapshot(doc, camera, -1, cache)
    check(cache.routes == routes + 1 and cache.edge_hits.writes == writes, "policy-only mutation refreshes geometry without changing spatial bounds")
    check(snapshot.edges[0].hit_policy == EdgeHitPolicy.SNAPSHOT_ORDER and snapshot.hit_edge(Point(75, 100)) == 2, "cached policy cannot remain stale")

    # Coincident terminal segments cannot reveal intent; tie-breaking stays stable.
    doc.objects[3].bounds = Rect(100, 100, 80, 64)
    doc.edges[0].hit_policy = EdgeHitPolicy.NEAREST_TERMINAL
    snapshot = CanvasSnapshot(doc, camera, -1, cache)
    check(snapshot.hit_edge(Point(75, 100)) == 2, "coincident terminals retain snapshot order")

    var canvas = freeform_graph()
    canvas.state.select(1)
    _ = canvas.command(CanvasCommand.MOVE)
    var proposal = canvas.document
    proposal.objects[0].bounds.x += 42
    proposal.edges[0].hit_policy = EdgeHitPolicy.NEAREST_TERMINAL
    var revision = canvas.document.revision
    check(not canvas.propose_destination(proposal, "Unexpected policy change", revision), "ordinary geometry-only preview rejects policy mutation")
    check(canvas.propose_destination(proposal, "Semantic policy change", revision, semantic_graph=True), "semantic preview may reroute stable edges and their hit policy")
    _ = canvas.command(CanvasCommand.COMMIT)
    check(canvas.document.edges[0].hit_policy == EdgeHitPolicy.NEAREST_TERMINAL, "semantic commit retains hit policy")
    _ = canvas.command(CanvasCommand.UNDO)
    check(canvas.document.edges[0].hit_policy == EdgeHitPolicy.SNAPSHOT_ORDER, "undo restores hit policy")
    _ = canvas.command(CanvasCommand.MOVE)
    proposal = canvas.document
    proposal.edges[0].hit_policy = EdgeHitPolicy.NEAREST_TERMINAL
    check(canvas.propose_destination(proposal, "Policy-only semantic change", canvas.document.revision, semantic_graph=True), "semantic change detection includes hit policy")
    _ = canvas.command(CanvasCommand.CANCEL)
    print("edge hits PASS: opt-in nearest terminal, ordinary precedence, ties, shared trunks, tolerance, copy/cache and preview/undo")


def main() raises:
    check_edge_hits()
