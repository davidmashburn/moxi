from moxi_mindmap.model import *
from moxi_mindmap.application import MindMapApp, MapMode
from moxi_mindmap.commands import MapCommand
from moxi_mindmap.codec import encode
from moxi import Event, Point
from moxi_mindmap.fixtures import useful_map, large_map
from moxi_mindmap.layout import MapLayout
from moxi_canvas.geometry import overlaps
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
    var proposed_layout = MapLayout()
    proposed_layout.compute(map.proposed)
    var final_branch = proposed_layout.boxes[5]
    var preview_branch = proposal.world_bounds(5)
    if preview_branch.x != final_branch.x or overlaps(preview_branch, proposal.world_bounds(3)):
        raise Error("Keyboard preview must show the destination lane without overlapping a stationary sibling")
    var shown_branch = map.app.component.state.camera.rect(preview_branch)
    if shown_branch.x < map.app.component.state.camera.viewport.x or shown_branch.y < map.app.component.state.camera.viewport.y:
        raise Error("Keyboard destination must be revealed inside the viewport")
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
    preview_branch = map.app.component.destination.world_bounds(5)
    var preview_parent = map.app.component.destination.world_bounds(6)
    if preview_branch.x < preview_parent.x + preview_parent.width:
        raise Error("Valid pointer destination must not hide the parent beneath the dragged card")
    event.kind = POINTER_CANCEL_KIND
    _ = map.dispatch(event)
    if encode(map.doc) != before or map.history.generation != generation:
        raise Error("Pointer cancel changed semantic history")
    map.select(4)
    map.begin_edit()
    var edit_before = encode(map.doc)
    var height_before = map.app.component.document.world_bounds(4).height
    var neighbor_mount = map.app.component.mount_index(6)
    var neighbor_builds = map.app.component.mounts[neighbor_mount].builds
    event = Event()
    event.kind = KEY_DOWN_KIND
    event.key = KEY_LEFT
    _ = map.dispatch(event)
    event.kind = TEXT_INPUT_KIND
    event.text = "!"
    _ = map.dispatch(event)
    if map.app.component.mounts[neighbor_mount].builds != neighbor_builds:
        raise Error("Caret and same-size text edits must not relayout neighboring controls")
    if "!" not in map.editor_text(map.app.component.mount_index(4)):
        raise Error("Same-size draft input was not dispatched")
    event = Event()
    event.kind = TEXT_INPUT_KIND
    event.text = " · 한국어 עברית 🙂\nAnother wrapped draft row"
    _ = map.dispatch(event)
    if map.app.component.document.world_bounds(4).height <= height_before or encode(map.doc) != edit_before:
        raise Error("Wrapped draft must grow its editor without committing semantic text")
    if overlaps(map.app.component.document.world_bounds(4), map.app.component.document.world_bounds(6)):
        raise Error("Growing the native editor must reflow its neighbor")
    var grown = map.app.component.state.camera.rect(map.app.component.document.world_bounds(4))
    var lower_edge = Point(grown.x + grown.width / 2, grown.y + grown.height - 2)
    if map.app.component.publication.hit_object(lower_edge) != 4:
        raise Error("Draft growth must republish hittable geometry after local text delivery")
    map.finish_edit(True)
    if encode(map.doc) != edit_before:
        raise Error("Cancelling a grown editor changed semantic content")
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
    event = Event()
    event.kind = KEY_DOWN_KIND
    event.key = 115
    event.modifiers = MOD_COMMAND | MOD_SHIFT
    _ = map.dispatch(event)
    if map.pending != MapCommand.SAVE_AS:
        raise Error("Save As shortcut unavailable")
    map.pending = MapCommand.NONE
    map.execute(MapCommand.SAVE_AS)
    if map.pending != MapCommand.SAVE_AS:
        raise Error("Save As command unavailable")
    map = MindMapApp(large_map(1000))
    if map.app.component.state.camera.zoom != 1 or map.app.paint().count() >= 1000:
        raise Error("Large maps must open at readable topic scale with viewport culling")
    print("mindmap app: real canvas text event, keyboard create, semantic preview/cancel/commit/undo PASS")

    var dense = MindMapApp(large_map(9))
    dense.select(9)
    dense.begin_move()
    dense.close_search()
    dense.propose(2, 0)
    if not dense.app.component.has_destination or dense.doc.topics[dense.doc.at(9)].parent != dense.doc.root:
        raise Error("Reparent preview across the route threshold lost its destination")
    dense.finish_move()
    if dense.doc.topics[dense.doc.at(9)].parent != 2:
        raise Error("Dense move did not commit")
    dense.execute(MapCommand.UNDO)
    if dense.doc.topics[dense.doc.at(9)].parent != dense.doc.root:
        raise Error("Dense move did not undo")
