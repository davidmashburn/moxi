"""Spatial/path/cancellation checks independent of native input delivery."""
from std.collections import List
from moxi import Rect, Point
from moxi_canvas import *
from moxi_canvas.geometry import GeometryCache
from moxi_canvas.native import clip_scene
from moxi.scene import Scene
from moxi.style import Color
from canvas_demo.fixtures import freeform_graph

def check(value: Bool, message: String) raises:
    if not value:
        raise Error(message)

def main() raises:
    var source = Scene()
    source.push_clip(1, Rect(10, 20, 100, 100))
    source.append_rect(1, Rect(-100, -100, 400, 400), Color(1, 1, 1, 1))
    source.append_line(2, Point(-100, 70), Point(200, 70), Color(1, 1, 1, 1), 2)
    source.pop_clip()
    var clipped = clip_scene(source, Rect(0, 0, 500, 500))
    check(clipped.count() == 2 and clipped.command(0).bounds.x == 10 and clipped.command(0).bounds.width == 100, "native rectangle clip")
    check(abs(clipped.command(1).point_start.x - 11) < 0.001 and abs(clipped.command(1).point_end.x - 109) < 0.001, "native line stroke clip")
    var doc = CanvasDocument()
    doc.add(CanvasObject(1, Rect(-500, 80, 120, 180), "Left"))
    doc.add(CanvasObject(2, Rect(1500, 80, 120, 180), "Right"))
    doc.add_port(Port(11, 1, PortDirection.OUTPUT, 1, 0.5))
    doc.add_port(Port(20, 2, PortDirection.INPUT, 0, 0.5))
    check(doc.connect(GraphEdge(1, 11, 20, "crossing", PathKind.STRAIGHT), ConnectionPolicy()) == "", "valid edge")
    var camera = Camera(Rect(0, 0, 1000, 700))
    var cache = GeometryCache()
    var snapshot = CanvasSnapshot(doc, camera, -1, cache)
    check(len(snapshot.visible) == 0 and len(snapshot.edges) == 1, "offscreen endpoints keep crossing edge")
    check(snapshot.hit_edge(Point(500, 176)) == 1, "screen edge tolerance")
    check(snapshot.hit_edge(Point(500, 178)) == -1, "outside screen edge tolerance")
    var writes = cache.object_hits.writes
    var routes = cache.routes
    snapshot = CanvasSnapshot(doc, camera, -1, cache)
    check(cache.object_hits.writes == writes and cache.routes == routes, "unchanged publication has zero index writes/reroutes")
    for zoom in List[Float64]([0.1, 1.0, 4.0]):
        camera.zoom_at(zoom, Point(0, 0))
        snapshot = CanvasSnapshot(doc, camera, -1, cache)
        var port = camera.point(doc.anchor(11))
        check(snapshot.hit_port(Point(port.x + 10, port.y)) == 11, "screen port radius at zoom extremes")
        check(snapshot.hit_port(Point(port.x + 15, port.y), 11) == 11, "port hysteresis retention")
        check(snapshot.hit_port(Point(port.x + 17, port.y), 11) == -1, "port hysteresis release")
    var state = CanvasState(Camera(Rect(0, 0, 1000, 700)))
    state.select(1)
    state.begin(doc, SessionKind.MOVE, Point(500, 200), 7)
    _ = state.motion(doc, Point(995, 200), 7)
    var before = state.preview(doc).world_bounds(1)
    var projected_before = state.camera.rect(before)
    check(state.autopan(doc, 1), "edge autopan active")
    var after = state.preview(doc).world_bounds(1)
    var projected_after = state.camera.rect(after)
    check(abs(projected_after.x - projected_before.x) < 0.01, "autopan preserves grabbed screen point")
    check(abs(state.camera.x) <= 12.01, "autopan timestep bounded")
    state.cancel()
    check(not state.autopan(doc, 1), "cancel stops autopan")
    state.begin(doc, SessionKind.MOVE, Point(500, 200), 7)
    _ = state.motion(doc, Point(550, 220), 8)
    check(not state.active, "foreign pointer cannot manipulate")
    doc.remove_port(11)
    var committed = state.commit(doc)
    check(not committed and state.history.cursor == 0, "port deletion invalidates in-flight session")
    cache.prune(doc)
    snapshot = CanvasSnapshot(doc, camera, -1, cache)
    check(len(snapshot.edges) == 0 and len(cache.edges) == 0, "deleted paths and cache removed")
    var canvas = freeform_graph()
    canvas.state.select(1)
    _ = canvas.command(CanvasCommand.MOVE)
    var unchanged = canvas.document
    var unchanged_revision = canvas.document.revision
    check(not canvas.propose_destination(unchanged, "No-op", unchanged_revision), "semantic no-op rejected")
    _ = canvas.command(CanvasCommand.COMMIT)
    check(canvas.state.history.cursor == 0, "semantic no-op adds no history")
    _ = canvas.command(CanvasCommand.MOVE)
    var proposal = canvas.document
    var object = proposal.objects[0]
    object.bounds.x += 42
    proposal.objects[0] = object
    var revision = canvas.document.revision
    check(canvas.propose_destination(proposal, "Consumer semantic destination", revision), "application destination accepted")
    _ = canvas.localized_view(Rect(0, 0, 1000, 700))
    check(canvas.presentation_document().world_bounds(1).x == proposal.world_bounds(1).x, "semantic destination uses published geometry")
    _ = canvas.command(CanvasCommand.CANCEL)
    check(canvas.document.world_bounds(1).x != proposal.world_bounds(1).x and canvas.state.history.cursor == 0, "semantic cancel no history")
    _ = canvas.command(CanvasCommand.MOVE)
    check(canvas.propose_destination(proposal, "Consumer semantic destination", revision), "semantic re-offer")
    _ = canvas.command(CanvasCommand.COMMIT)
    check(canvas.document.world_bounds(1).x == proposal.world_bounds(1).x and canvas.state.history.cursor == 1, "semantic commit one transaction")
    _ = canvas.command(CanvasCommand.UNDO)
    check(canvas.document.world_bounds(1).x != proposal.world_bounds(1).x, "semantic undo")
    print("geometry contract PASS: offscreen crossings, zoom hit tolerance, hysteresis, incremental cache/index, bounded autopan, pointer ownership, stale deletion, semantic destinations")
