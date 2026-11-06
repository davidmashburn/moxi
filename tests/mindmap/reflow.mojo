from moxi import Event
from moxi.event import FRAME_TICK_KIND
from moxi_mindmap.application import MindMapApp
from moxi_mindmap.reflow import MotionPolicy, NeighborReflow
from moxi_mindmap.fixtures import useful_map
from moxi_mindmap.codec import encode
from moxi_mindmap.commands import MapCommand

def main() raises:
    var map = MindMapApp(useful_map())
    map.select(5)
    map.begin_move()
    map.propose(2, 1)
    var prior = map.app.component.presentation_document()
    map.finish_move()
    var committed = encode(map.doc)
    if not map.reflow.active or map.history.generation != 1:
        raise Error("Move must commit once and animate affected neighbors")
    var moving = map.app.component.document.world_bounds(5)
    var final_moving = map.reflow.target.world_bounds(5)
    if moving.x != final_moving.x or moving.y != final_moving.y:
        raise Error("Moved branch must not lag behind final input")
    var neighbor = -1
    for object in map.reflow.target.objects:
        var start = prior.world_bounds(object.id)
        if object.id != 5 and (start.x != object.bounds.x or start.y != object.bounds.y):
            neighbor = object.id
            break
    if neighbor < 0:
        raise Error("Fixture must move at least one neighbor")
    var start = map.app.component.document.world_bounds(neighbor)
    var target = map.reflow.target.world_bounds(neighbor)
    var event = Event()
    event.kind = FRAME_TICK_KIND
    event.delta_seconds = -1
    _ = map.dispatch(event)
    if map.reflow.elapsed != 0:
        raise Error("Invalid delta advanced reflow")
    event.delta_seconds = NeighborReflow.DURATION / 2
    _ = map.dispatch(event)
    var middle = map.app.component.document.world_bounds(neighbor)
    if not map.reflow.active or (middle.x == start.x and middle.y == start.y) or (middle.x == target.x and middle.y == target.y):
        raise Error("Neighbor must interpolate through an intermediate geometry")
    if encode(map.doc) != committed or map.history.generation != 1:
        raise Error("Animation changed semantic content or history")
    _ = map.dispatch(event)
    var final = map.app.component.document.world_bounds(neighbor)
    if map.reflow.active or final.x != target.x or final.y != target.y:
        raise Error("Reflow must terminate at exact final geometry")
    if not map.app.component.build(map.app.root_bounds).validate():
        raise Error("Animated shared geometry is invalid")
    map.execute(MapCommand.UNDO)
    # Revisions/ID high-water marks are intentionally monotonic across undo.
    if map.doc.topics[map.doc.at(5)].parent != 4:
        raise Error("Undo did not restore original parent")
    map.set_motion_policy(MotionPolicy.REDUCED)
    map.select(5)
    map.begin_move()
    map.propose(2, 1)
    map.finish_move()
    if map.reflow.active or map.doc.topics[map.doc.at(5)].parent != 2:
        raise Error("Reduced motion must reach the same state immediately")
    map.execute(MapCommand.UNDO)
    map.set_motion_policy(MotionPolicy.NEIGHBORS)
    map.select(5)
    map.begin_move()
    map.propose(2, 1)
    map.finish_move()
    _ = map.dispatch(event)
    map.execute(MapCommand.UNDO)
    if map.reflow.active or map.doc.topics[map.doc.at(5)].parent != 4:
        raise Error("Undo during animation must discard all derived motion")
    map.select(5)
    map.begin_move()
    map.propose(2, 1)
    var generation = map.history.generation
    map.cancel()
    if map.reflow.active or map.history.generation != generation:
        raise Error("Cancel must not animate or add history")
    print("mindmap neighbor reflow, history, cancellation and reduced-motion contracts pass")
