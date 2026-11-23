from moxi import Event, Rect
from moxi.event import FRAME_TICK_KIND
from moxi_mindmap.application import MindMapApp
from moxi_mindmap.reflow import MotionPolicy, NeighborReflow
from moxi_mindmap.fixtures import useful_map
from moxi_mindmap.codec import encode
from moxi_mindmap.commands import MapCommand
from moxi_canvas import CanvasDocument, CanvasObject
from moxi_canvas.geometry import overlaps
from std.collections import List

def clear_of_moving_branch(map: MindMapApp) raises:
    var branch = map.app.component.document.world_bounds(5)
    var committed = map.reflow.target.world_bounds(5)
    if branch.x != committed.x or branch.y != committed.y:
        raise Error("Moved branch must remain at its committed destination during reflow")
    for item in map.app.component.document.objects:
        if item.id != 5 and not item.hidden and overlaps(branch, item.bounds):
            raise Error("Reflow neighbor overlaps the committed moved branch")

def trajectory_contract() raises:
    var previous = CanvasDocument()
    previous.add(CanvasObject(1, Rect(500, 10, 100, 80), "Moved branch"))
    previous.add(CanvasObject(2, Rect(500, 10, 100, 80), "Conflicting neighbor"))
    previous.add(CanvasObject(3, Rect(1000, 10, 100, 80), "Ordinary neighbor"))
    # A later collision also must not be introduced halfway through reflow.
    previous.add(CanvasObject(4, Rect(5, 10, 100, 80), "Crossing neighbor"))
    previous.add(CanvasObject(5, Rect(700, 10, 100, 80), "Second moved descendant"))
    var target = previous
    target.objects[1].bounds.y = 210
    target.objects[2].bounds.y = 210
    target.objects[3].bounds.x = 900
    var excluded = List[Int]([1, 5])
    var flow = NeighborReflow()
    flow.begin(previous, target, excluded)
    var result = target
    flow.apply(result)
    if result.objects[1].bounds.y <= previous.objects[1].bounds.y or result.objects[1].bounds.y >= target.objects[1].bounds.y:
        raise Error("A conflicting neighbor should start along its existing path when possible")
    if result.objects[2].bounds.y != previous.objects[2].bounds.y:
        raise Error("An ordinary neighbor must retain its original animation start")
    for step in range(19):
        flow.apply(result)
        for moving in excluded:
            for item in result.objects:
                if item.id not in excluded and overlaps(result.world_bounds(moving), item.bounds):
                    raise Error("A neighbor crossed a committed moved descendant during reflow")
        if step == 9 and (result.objects[2].bounds.y <= 10 or result.objects[2].bounds.y >= 210):
            raise Error("Ordinary neighbors must continue interpolating")
        _ = flow.advance(NeighborReflow.DURATION / 18)
    _ = flow.advance(NeighborReflow.DURATION)
    flow.apply(result)
    if flow.active or result.objects[1].bounds.y != target.objects[1].bounds.y:
        raise Error("Conflict avoidance must terminate at exact committed bounds")

def main() raises:
    var map = MindMapApp(useful_map())
    map.select(5)
    map.begin_move()
    map.propose(2, 1)
    var prior = map.app.component.presentation_document()
    map.finish_move()
    var committed = encode(map.doc)
    clear_of_moving_branch(map)
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
    clear_of_moving_branch(map)
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
    trajectory_contract()
    print("mindmap neighbor reflow, collision-free trajectories, history, cancellation and reduced-motion contracts pass")
