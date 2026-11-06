from moxi_mindmap.model import *
from moxi_mindmap.application import MindMapApp, MapMode
from moxi_mindmap.commands import MapCommand
from moxi_mindmap.codec import encode
from moxi import Event, Point
from moxi_mindmap.fixtures import useful_map
from moxi.event import *

def main() raises:
    var map = MindMapApp(MindMapDocument("Root"))
    map.execute(MapCommand.CHILD)
    var event = Event()
    event.kind = TEXT_INPUT_KIND
    event.text = "日本語 · العربية · café"
    _ = map.dispatch(event)
    event.kind = KEY_DOWN_KIND
    event.key = KEY_ENTER
    _ = map.dispatch(event)
    if len(map.doc.topics) != 2 or map.doc.topics[1].text != "日本語 · العربية · café":
        raise Error("creation through shared canvas text controls")
    map.execute(MapCommand.SIBLING)
    map.finish_edit()
    map.select(2)
    var before = encode(map.doc)
    map.begin_move()
    map.close_search()
    map.propose(3, 0)
    if not map.app.component.has_destination:
        raise Error("Semantic geometry preview was rejected")
    map.cancel()
    if encode(map.doc) != before:
        raise Error("cancel changed document")
    map.begin_move()
    map.close_search()
    map.propose(3, 0)
    map.finish_move()
    if map.doc.topics[map.doc.at(2)].parent != 3:
        raise Error("reparent")
    map.execute(MapCommand.UNDO)
    if map.doc.topics[map.doc.at(2)].parent != 1:
        raise Error("one step undo")
    map = MindMapApp(useful_map())
    map.select(5)
    map.begin_move()
    map.close_search()
    map.propose(2, 1)
    if not map.app.component.has_destination:
        raise Error("Cross-side semantic edge/port preview rejected")
    var proposal = map.app.component.destination
    var revision = map.app.component.document.revision
    if map.app.component.propose_destination(proposal, "Not opted in", revision):
        raise Error("Geometry-only default accepted semantic graph change")
    var corrupt = proposal
    corrupt.ports[0].x = 2
    if map.app.component.propose_destination(corrupt, "Invalid anchor", revision, semantic_graph=True):
        raise Error("Semantic hook accepted invalid normalized anchor")
    corrupt = proposal
    corrupt.objects[0].title = "Unrelated content mutation"
    if map.app.component.propose_destination(corrupt, "Content change", revision, semantic_graph=True):
        raise Error("Semantic hook accepted unrelated content")
    corrupt = proposal
    corrupt.ports[0].object = 99999
    if map.app.component.propose_destination(corrupt, "Port ownership change", revision, semantic_graph=True):
        raise Error("Semantic hook accepted port ownership change")
    if map.app.component.propose_destination(proposal, "Stale revision", revision - 1, semantic_graph=True):
        raise Error("Semantic hook accepted stale revision")
    map.cancel()
    map.select(5)
    before = encode(map.doc)
    var generation = map.history.generation
    var source = map.app.component.state.camera.rect(map.app.component.document.world_bounds(5))
    var target = map.app.component.state.camera.rect(map.app.component.document.world_bounds(6))
    event = Event()
    event.kind = POINTER_DOWN_KIND
    event.position = Point(source.x + 25, source.y + 5)
    event.buttons = 1
    event.pointer_id = 9
    _ = map.dispatch(event)
    if map.mode != MapMode.MOVE:
        raise Error("Header pointer did not begin semantic branch move")
    event.kind = POINTER_MOVE_KIND
    event.position = Point(target.x + target.width / 2, target.y + target.height / 2)
    _ = map.dispatch(event)
    if map.destination != 6 or not map.app.component.has_destination or encode(map.doc) != before:
        raise Error("Pointer preview must be published without changing content")
    event.kind = POINTER_CANCEL_KIND
    _ = map.dispatch(event)
    if encode(map.doc) != before or map.history.generation != generation:
        raise Error("Pointer cancel changed semantic history")
    map.select(5)
    source = map.app.component.state.camera.rect(map.app.component.document.world_bounds(5))
    event.kind = POINTER_DOWN_KIND
    event.position = Point(source.x + source.width - 3, source.y + source.height - 3)
    _ = map.dispatch(event)
    if map.mode != MapMode.SPACING:
        raise Error("Shared resize handle did not enter spacing transaction")
    event.kind = POINTER_MOVE_KIND
    event.position.x += 60
    _ = map.dispatch(event)
    if encode(map.doc) != before or not map.app.component.has_destination:
        raise Error("Spacing preview mutated content or failed publication")
    event.kind = POINTER_CANCEL_KIND
    _ = map.dispatch(event)
    if encode(map.doc) != before or map.history.generation != generation:
        raise Error("Spacing cancellation changed content/history")
    map.select(5)
    map.begin_move()
    map.close_search()
    map.propose(6, 0)
    # A queued proposal must not survive a concurrent semantic generation.
    var concurrent = map.doc
    concurrent.topics[0].text = "Concurrent root"
    _ = map.history.commit(map.doc, concurrent, map.history.generation)
    map.finish_move()
    if map.doc.topics[map.doc.at(5)].parent != 4:
        raise Error("Stale queued destination committed")
    map.execute(MapCommand.EDIT)
    event = Event()
    event.kind = COMPOSITION_UPDATE_KIND
    event.text = "かな"
    _ = map.dispatch(event)
    event.kind = KEY_DOWN_KIND
    event.key = KEY_ESCAPE
    _ = map.dispatch(event)
    if map.mode != MapMode.EDIT:
        raise Error("Composition Escape escaped the ordinary editor")
    event.kind = COMPOSITION_END_KIND
    _ = map.dispatch(event)
    map.finish_edit(True)
    map.execute(MapCommand.EDIT)
    concurrent = map.doc
    concurrent.topics[0].text = "Newer work must survive stale editor"
    _ = map.history.commit(map.doc, concurrent, map.history.generation)
    before = encode(map.doc)
    map.finish_edit()
    if encode(map.doc) != before or map.mode != MapMode.IDLE:
        raise Error("Stale editor rolled back newer work")
    map.select(5)
    event.kind = KEY_DOWN_KIND
    event.key = KEY_F6
    _ = map.dispatch(event)
    event.key = KEY_ENTER
    _ = map.dispatch(event)
    if map.mode != MapMode.PALETTE:
        raise Error("Keyboard focus exit cannot open Commands")
    var overlay = map.app.component.build(map.app.root_bounds)
    if not overlay.validate():
        raise Error("Search overlay contains invalid published geometry or IDs")
    event.kind = TEXT_INPUT_KIND
    event.text = "Move branch"
    _ = map.dispatch(event)
    event.kind = KEY_DOWN_KIND
    event.key = KEY_ENTER
    _ = map.dispatch(event)
    event.kind = TEXT_INPUT_KIND
    event.text = "Research"
    _ = map.dispatch(event)
    event.kind = KEY_DOWN_KIND
    event.key = KEY_ENTER
    _ = map.dispatch(event)
    if map.mode != MapMode.MOVE or map.destination != 2:
        raise Error("Keyboard destination selection unavailable")
    event.key = KEY_ESCAPE
    _ = map.dispatch(event)
    event.key = KEY_TAB
    _ = map.dispatch(event)
    if map.mode != MapMode.EDIT:
        raise Error("Focus failed to return to map after keyboard destination")
    map.finish_edit(True)
    print("mindmap app: real canvas text event, keyboard create, semantic preview/cancel/commit/undo PASS")
