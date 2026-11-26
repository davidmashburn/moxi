"""Unequal sibling spacing must not let another trunk steal a terminal click."""
from std.collections import List
from moxi import Event, Point, Rect
from moxi.event import POINTER_DOWN_KIND, POINTER_UP_KIND, POINTER_CANCEL_KIND
from moxi_canvas import PathKind, EdgeHitPolicy, SessionKind
from moxi_mindmap.application import MindMapApp
from moxi_mindmap.commands import MapCommand
from moxi_mindmap.fixtures import uneven_dense_map, large_map


def main() raises:
    var doc = uneven_dense_map()
    var failures = 0
    for zoom in List[Float64]([1.0, 0.5]):
        var map = MindMapApp(doc, Rect(0, 0, 1800, 2000))
        map.app.component.state.camera.zoom = zoom
        map.app.rebuild_localized()
        var edges = map.app.component.publication.edges.copy()
        var checked = 0
        for edge in edges:
            if edge.id != 7 and edge.id != 15:
                continue
            if edge.path != PathKind.ORTHOGONAL or len(edge.points) != 4:
                raise Error("Dense ancestry must retain its orthogonal route")
            var last = len(edge.points) - 1
            var point = Point((edge.points[last - 1].x + edge.points[last].x) / 2, edge.points[last].y)
            var snapshot = map.app.component.publication
            if not map.app.component.interaction_clip().contains(point) or snapshot.hit_port(point) >= 0 or snapshot.hit_object(point) >= 0:
                raise Error("Regression midpoint must be eligible for edge selection")
            var geometry_wins = 0
            var eligible = 0
            for sample in range(101):
                var t = Float32(sample) / 100
                var p = Point(edge.points[last - 1].x * (1 - t) + edge.points[last].x * t, point.y)
                geometry_wins += Int(snapshot.hit_edge(p) == edge.id)
                eligible += Int(snapshot.hit_edge(p) == edge.id and snapshot.hit_port(p) < 0 and snapshot.hit_object(p) < 0)
            print("terminal centerline eligibility: zoom", zoom, "edge", edge.id, "geometry wins", geometry_wins, "outside ports/objects", eligible, "of 101")
            if geometry_wins != 101 or eligible == 0:
                raise Error("Every distinct terminal centerline must retain a usable edge target")
            var event = Event()
            event.kind = POINTER_DOWN_KIND
            event.pointer_id = 1
            event.position = point
            _ = map.dispatch(event)
            event.kind = POINTER_UP_KIND
            _ = map.dispatch(event)
            if map.app.component.state.selected_edge != edge.id:
                print("FAIL dense terminal pointer selection: zoom", zoom, "expected", edge.id, "got", map.app.component.state.selected_edge)
                failures += 1
                continue
            if snapshot.hit_edge(point) != edge.id:
                raise Error("Published hit geometry disagrees with public pointer selection")
            var scene = map.app.component.edge_scene()
            if scene.command(scene.count() - 2).id != edge.id:
                raise Error("Selected dense route must paint above shared strokes")
            # Endpoints remain ports; card headers remain object interactions.
            event.kind = POINTER_DOWN_KIND
            event.position = snapshot.ports.get(edge.id * 2, Point(0, 0))
            _ = map.dispatch(event)
            if map.app.component.state.session != SessionKind.CONNECT:
                raise Error("Terminal preference must not steal a port click")
            event.kind = POINTER_CANCEL_KIND
            _ = map.dispatch(event)
            var bounds = map.app.component.state.camera.rect(map.app.component.document.world_bounds(edge.id))
            event.kind = POINTER_DOWN_KIND
            event.position = Point(bounds.x + 20, bounds.y + 10)
            _ = map.dispatch(event)
            if not map.app.component.state.is_selected(edge.id) or map.app.component.state.selected_edge >= 0:
                raise Error("Terminal preference must not steal an object click")
            event.kind = POINTER_CANCEL_KIND
            _ = map.dispatch(event)
            checked += 1
        if failures == 0 and checked != 2:
            raise Error("Must exercise both root sides at each zoom")
    if failures:
        raise Error(String("Dense terminal pointer selection failures: ", failures))
    var threshold = MindMapApp(large_map(9))
    threshold.select(9)
    threshold.begin_move()
    threshold.close_search()
    threshold.propose(2, 0)
    if not threshold.app.component.has_destination or threshold.app.component.destination.edges[0].hit_policy != EdgeHitPolicy.SNAPSHOT_ORDER:
        raise Error("Downward threshold preview must restore ordinary ancestry policy")
    threshold.finish_move()
    threshold.settle_reflow()
    threshold.select(9)
    threshold.begin_move()
    threshold.close_search()
    threshold.propose(threshold.doc.root, 0)
    if not threshold.app.component.has_destination or threshold.app.component.destination.edges[0].hit_policy != EdgeHitPolicy.NEAREST_TERMINAL:
        raise Error("Upward threshold preview must publish dense terminal policy")
    threshold.finish_move()
    threshold.settle_reflow()
    if threshold.app.component.document.edges[0].hit_policy != EdgeHitPolicy.NEAREST_TERMINAL:
        raise Error("Threshold commit lost dense terminal policy")
    threshold.execute(MapCommand.UNDO)
    if threshold.app.component.document.edges[0].hit_policy != EdgeHitPolicy.SNAPSHOT_ORDER:
        raise Error("Threshold undo must restore ordinary ancestry policy")
    print("dense terminal hits PASS: public pointer down/up, both root sides, unequal spacing, zoom 1/0.5, selected overlay")
