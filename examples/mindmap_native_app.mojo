"""Real AppKit input loop and deterministic replay through the same public controller."""
from std.ffi import external_call
from std.sys import argv
from std.time import perf_counter_ns
from moxi import Event, WindowConfig, Point, Rect
from moxi.event import *
from moxi.macos import MacOSRenderer, MacOSCanvasSceneRenderer, MacOSClipboard
from moxi.native_instance import MacOSWindowInstance
from moxi_canvas.native import render_canvas
from moxi_mindmap.application import MindMapApp, MapMode
from moxi_mindmap.reflow import MotionPolicy
from moxi_mindmap.commands import MapCommand
from moxi_mindmap.model import MindMapDocument
from moxi_mindmap.history import MapHistory
from moxi_mindmap.codec import encode
from moxi_mindmap.storage import LocalFile, import_mm, choose_file, draft_file
from moxi_mindmap.fixtures import useful_map, large_map


def key(mut map: MindMapApp, code: Int, modifiers: Int = 0):
    var event = Event()
    event.kind = KEY_DOWN_KIND
    event.key = code
    event.modifiers = modifiers
    _ = map.dispatch(event)

def text(mut map: MindMapApp, value: String):
    var event = Event()
    event.kind = TEXT_INPUT_KIND
    event.text = value
    _ = map.dispatch(event)

def keyboard_destination(mut map: MindMapApp) raises:
    key(map, KEY_F6)
    key(map, KEY_ENTER)
    if map.mode != MapMode.PALETTE:
        raise Error("Keyboard toolbar could not open Commands")
    text(map, "Move branch")
    key(map, KEY_ENTER)
    text(map, "Research")
    key(map, KEY_ENTER)
    if map.mode != MapMode.MOVE or map.destination != 2:
        raise Error("Keyboard searchable destination unavailable")

def capture(mut map: MindMapApp, mut window: MacOSWindowInstance, mut paint: MacOSRenderer, mut graph: MacOSCanvasSceneRenderer, path: String) raises:
    window.activate()
    render_canvas(map.app, paint, graph)
    window.pump()
    var file = path
    if external_call["moxi_mm_capture", Int32](file.as_c_string_span().ptr()) != 1:
        raise Error("AppKit content-view capture failed")
    print("offscreen-render", file, "ordinary_commands", map.app.paint().count(), "visible_topics", map.layout.visible)

def replay(mut map: MindMapApp, mut window: MacOSWindowInstance, mut paint: MacOSRenderer, mut graph: MacOSCanvasSceneRenderer, path: String) raises:
    capture(map, window, paint, graph, path + "/01-initial.png")
    map.select(4)
    # Traverse the real AppKit keyDown -> native event queue boundary for F2.
    _ = external_call["moxi_mm_native_key", Int32](Int32(0xF705), Int32(0))
    var event = window.poll_event()
    while event.kind != NONE_KIND:
        _ = map.dispatch(event)
        event = window.poll_event()
    if map.mode != MapMode.EDIT:
        raise Error("AppKit F2 did not enter the ordinary editor")
    text(map, " · 한국어 עברית 🙂")
    capture(map, window, paint, graph, path + "/02-mixed-edit.png")
    key(map, KEY_ENTER)
    map.select(2)
    key(map, KEY_SPACE)
    map.execute(MapCommand.FIND)
    text(map, "العربية")
    capture(map, window, paint, graph, path + "/03-fold-search.png")
    key(map, KEY_ENTER)
    map.select(5)
    var before = encode(map.doc)
    keyboard_destination(map)
    capture(map, window, paint, graph, path + "/04-reparent-preview.png")
    key(map, KEY_ESCAPE)
    if encode(map.doc) != before:
        raise Error("Replay cancellation changed content")
    capture(map, window, paint, graph, path + "/05-cancel.png")
    keyboard_destination(map)
    key(map, KEY_ENTER)
    capture(map, window, paint, graph, path + "/06a-reflow-start.png")
    var tick = Event()
    tick.kind = FRAME_TICK_KIND
    tick.delta_seconds = 0.09
    _ = map.dispatch(tick)
    capture(map, window, paint, graph, path + "/06b-reflow-middle.png")
    _ = map.dispatch(tick)
    if map.reflow.active:
        raise Error("Neighbor animation did not settle")
    capture(map, window, paint, graph, path + "/06-reparent-result.png")
    map.execute(MapCommand.UNDO)
    capture(map, window, paint, graph, path + "/07-undo.png")
    map.set_motion_policy(MotionPolicy.REDUCED)
    map.select(5)
    keyboard_destination(map)
    key(map, KEY_ENTER)
    if map.reflow.active:
        raise Error("Reduced-motion replay animated")
    capture(map, window, paint, graph, path + "/07b-reduced-motion.png")
    map.execute(MapCommand.UNDO)
    map.set_motion_policy(MotionPolicy.NEIGHBORS)
    # Actual public pointer events hit the displayed topic header and destination.
    map.select(5)
    var source = map.app.component.state.camera.rect(map.app.component.document.world_bounds(5))
    var target = map.app.component.state.camera.rect(map.app.component.document.world_bounds(6))
    var pointer = Event()
    pointer.kind = POINTER_DOWN_KIND
    pointer.position = Point(source.x + 25, source.y + 5)
    pointer.buttons = 1
    pointer.pointer_id = 7
    _ = map.dispatch(pointer)
    pointer.kind = POINTER_MOVE_KIND
    pointer.position = Point(target.x + target.width / 2, target.y + target.height / 2)
    _ = map.dispatch(pointer)
    if map.destination != 6:
        raise Error("Native replay pointer destination missing")
    capture(map, window, paint, graph, path + "/08a-pointer-preview.png")
    pointer.kind = POINTER_CANCEL_KIND
    _ = map.dispatch(pointer)
    if encode(map.doc) != before:
        raise Error("Pointer capture loss changed content")
    capture(map, window, paint, graph, path + "/08a-pointer-cancel.png")
    pointer.kind = POINTER_DOWN_KIND
    pointer.position = Point(source.x + 25, source.y + 5)
    _ = map.dispatch(pointer)
    pointer.kind = POINTER_MOVE_KIND
    pointer.position = Point(target.x + target.width / 2, target.y + target.height / 2)
    _ = map.dispatch(pointer)
    pointer.kind = POINTER_UP_KIND
    _ = map.dispatch(pointer)
    if map.doc.topics[map.doc.at(5)].parent != 6:
        raise Error("Native replay pointer reparent failed")
    tick.delta_seconds = 0.18
    _ = map.dispatch(tick)
    capture(map, window, paint, graph, path + "/08b-pointer-result.png")
    map.execute(MapCommand.UNDO)
    capture(map, window, paint, graph, path + "/08c-pointer-undo.png")
    map.select(4)
    map.execute(MapCommand.SIDE)
    map.execute(MapCommand.SPACE_MORE)
    map.execute(MapCommand.FIT)
    capture(map, window, paint, graph, path + "/08-side-spacing.png")
    map.select(2)
    map.select(6, True)
    map.execute(MapCommand.CONNECT)
    map.execute(MapCommand.OUTLINE)
    capture(map, window, paint, graph, path + "/09-crosslink-outline.png")
    key(map, KEY_ESCAPE)
    var file = LocalFile(String("/tmp/moxi-d04-replay-", perf_counter_ns(), ".moxi"))
    file.save(map.doc)
    print("recovery_fixture", file.path)
    map.select(4)
    map.execute(MapCommand.EDIT)
    text(map, " · recovered draft")
    key(map, KEY_ENTER)
    file.save(map.doc, True)
    map.doc = file.load(True)
    map.history = MapHistory(map.doc)
    map.sync()
    map.status(file.report)
    capture(map, window, paint, graph, path + "/10-save-recovery.png")
    var imported = import_mm("tests/mindmap/fixtures/loss.mm")
    map = MindMapApp(imported[0])
    map.show_report(imported[1])
    capture(map, window, paint, graph, path + "/11-import-loss.png")
    key(map, KEY_ESCAPE)
    map = MindMapApp(large_map(1000, True))
    map.status("1,000 topics; folded root, one visible topic. Native expanded capacity is NOT accepted.")
    capture(map, window, paint, graph, path + "/12-large-folded.png")
    map = MindMapApp(large_map(1000))
    capture(map, window, paint, graph, path + "/13-large-expanded.png")
    print("PASS native AppKit F2 queue + public input replay, semantic cancel/undo, disk recovery and bounded import")

def main() raises:
    var map = MindMapApp(useful_map())
    var window = MacOSWindowInstance()
    window.open(WindowConfig("Moxi · Mind map", 1180, 820), 80, 80)
    var paint = MacOSRenderer()
    var graph = MacOSCanvasSceneRenderer()
    var args = argv()
    if len(args) == 3 and args[1] == "--capture":
        replay(map, window, paint, graph, args[2])
        window.close()
        return
    var file = LocalFile()
    var draft = LocalFile()
    var saved_generation = map.history.generation
    var recovered_generation = saved_generation
    var clipboard = MacOSClipboard()
    window.activate()
    render_canvas(map.app, paint, graph)
    map.set_motion_policy(MotionPolicy.REDUCED if external_call["moxi_mm_reduced_motion", Int32]() else MotionPolicy.NEIGHBORS)
    var prior_tick = perf_counter_ns()
    while window.is_open():
        window.pump()
        var motion = MotionPolicy.REDUCED if external_call["moxi_mm_reduced_motion", Int32]() else MotionPolicy.NEIGHBORS
        var changed = motion != map.reflow.policy
        map.set_motion_policy(motion)
        var event = window.poll_event()
        while event.kind != NONE_KIND:
            var editing = map.mode == MapMode.EDIT
            if editing and map.app.is_clipboard_command(event) and event.key == KEY_V:
                map.app.set_clipboard(clipboard.paste())
            changed = map.dispatch(event) or changed
            if editing and map.app.is_clipboard_command(event) and (event.key == KEY_C or event.key == KEY_X):
                clipboard.copy(map.app.clipboard_text())
            event = window.poll_event()
        var pending = map.pending
        map.pending = MapCommand.NONE
        try:
            if pending == MapCommand.SAVE:
                if file.path == "":
                    file = LocalFile(choose_file(True))
                file.save(map.doc)
                saved_generation = map.history.generation
                map.status(file.report)
                changed = True
            elif pending == MapCommand.NEW or pending == MapCommand.OPEN or pending == MapCommand.IMPORT or pending == MapCommand.RECOVER:
                if saved_generation != map.history.generation:
                    raise Error("Save the current map before replacing it")
                if pending == MapCommand.NEW:
                    map = MindMapApp(MindMapDocument())
                    file = LocalFile()
                elif pending == MapCommand.IMPORT:
                    var imported = import_mm(choose_file(False))
                    map = MindMapApp(imported[0])
                    map.show_report(imported[1])
                    file = LocalFile()
                else:
                    var incoming = LocalFile(choose_file(False, pending == MapCommand.RECOVER))
                    var doc = incoming.load(pending == MapCommand.RECOVER)
                    map = MindMapApp(doc)
                    file = incoming^
                    map.status(file.report)
                saved_generation = -1 if pending == MapCommand.IMPORT or pending == MapCommand.RECOVER else map.history.generation
                recovered_generation = -1
                draft = LocalFile()
                changed = True
            if map.history.generation != recovered_generation:
                if file.path != "":
                    file.save(map.doc, True)
                else:
                    if draft.path == "":
                        draft = draft_file()
                    draft.save(map.doc, True)
                recovered_generation = map.history.generation
        except error:
            map.status(String(error))
            changed = True
        var tick = Event()
        tick.kind = FRAME_TICK_KIND
        var now = perf_counter_ns()
        tick.delta_seconds = Float32(Float64(now - prior_tick) / 1_000_000_000)
        prior_tick = now
        changed = map.dispatch(tick) or changed
        if changed:
            window.activate()
            render_canvas(map.app, paint, graph)
        window.wait(1.0 / 60)
    window.close()
