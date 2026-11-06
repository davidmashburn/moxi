"""Optional AppKit presenter. Uses ordinary Moxi controls and the existing ABI."""
from std.ffi import external_call
from std.collections import List
from moxi import App, Component, Rect, Point
from moxi.style import Color
from moxi.scene import Scene, SCENE_LINE, SCENE_TEXT, SCENE_RECT, SCENE_ROUNDED_RECT, SCENE_CLIP, SCENE_POP_CLIP
from moxi.paint import SURFACE_KIND

comptime NATIVE_ORDERED_CAPACITY = 1024
comptime NATIVE_LINE_CAPACITY = 32768
comptime NATIVE_TEXT_CAPACITY = 256
from moxi.accessibility import AccessibilitySnapshot
from moxi.macos import MacOSRenderer, MacOSCanvasSceneRenderer
from moxi.view_node import TEXT_INPUT_VIEW_KIND, SLIDER_KIND
from .surface import CanvasView, CONTROL_BASE, ID_STRIDE, SEARCH_PANEL_ID, SEARCH_LABEL_ID
from .model import ObjectKind


def clip_scene(scene: Scene, root: Rect) -> Scene:
    """Flatten clips for the existing native custom ABI's single global clip.

    Edge/slider segments are clipped analytically. Partially visible edge labels
    are omitted because this ABI cannot retain a separate glyph clip per label.
    Ordinary control text continues through the native control presenter.
    """
    var result = Scene()
    var clips = List[Rect]()
    clips.append(root)
    for i in range(scene.count()):
        var command = scene.command(i)
        var clip = clips[len(clips) - 1]
        if command.kind == SCENE_CLIP:
            clips.append(clip.intersection(command.bounds))
            continue
        if command.kind == SCENE_POP_CLIP:
            if len(clips) > 1:
                _ = clips.pop()
            continue
        if clip.width <= 0 or clip.height <= 0:
            continue
        if command.kind == SCENE_LINE:
            # Liang–Barsky, inset by half stroke width to keep the stroke inside.
            var half = command.stroke_width / 2
            var start = command.point_start
            var dx = command.point_end.x - start.x
            var dy = command.point_end.y - start.y
            var ps = List[Float32]([-dx, dx, -dy, dy])
            var qs = List[Float32]([start.x - clip.x - half, clip.x + clip.width - half - start.x, start.y - clip.y - half, clip.y + clip.height - half - start.y])
            var lo: Float32 = 0
            var hi: Float32 = 1
            var visible = clip.width > half * 2 and clip.height > half * 2
            for j in range(4):
                if abs(ps[j]) < 0.000001:
                    visible = visible and qs[j] >= 0
                elif ps[j] < 0:
                    lo = max(lo, qs[j] / ps[j])
                else:
                    hi = min(hi, qs[j] / ps[j])
            if not visible or lo > hi:
                continue
            command.point_start = Point(start.x + dx * lo, start.y + dy * lo)
            command.point_end = Point(start.x + dx * hi, start.y + dy * hi)
        elif command.kind == SCENE_RECT or command.kind == SCENE_ROUNDED_RECT:
            command.bounds = command.bounds.intersection(clip)
            if command.bounds.width <= 0 or command.bounds.height <= 0:
                continue
        elif command.kind == SCENE_TEXT:
            var bounds = command.bounds
            if bounds.x < clip.x or bounds.y < clip.y or bounds.x + bounds.width > clip.x + clip.width or bounds.y + bounds.height > clip.y + clip.height:
                continue
        result.append(command)
    return result^


def canvas_accessibility[Child: Component & Deinitable](app: App[CanvasView[Child]]) -> AccessibilitySnapshot:
    var snapshot = app.accessibility()
    # Runtime supplies semantic roles/state; publish the same ancestor clip as paint.
    for i in range(len(snapshot.nodes)):
        var bounds = snapshot.nodes[i].bounds.intersection(app.root_bounds)
        var parent = snapshot.nodes[i].parent_id
        var remaining = len(app.view.children)
        while parent >= 0 and remaining > 0:
            remaining -= 1
            var found = False
            for node in app.view.children:
                if node.id == parent:
                    if node.clip_children:
                        bounds = bounds.intersection(node.bounds)
                    parent = node.parent_id
                    found = True
                    break
            if not found:
                break
        snapshot.nodes[i].bounds = bounds
    return snapshot^


def render_canvas[Child: Component & Deinitable](mut app: App[CanvasView[Child]], mut paint: MacOSRenderer, mut graph: MacOSCanvasSceneRenderer) raises:
    var commands = app.paint()
    # The shared native ordered buffer is fixed at 1024 entries. Fail visibly.
    if commands.count() > NATIVE_ORDERED_CAPACITY:
        raise Error("Canvas native ordered-paint capacity exceeded (1024 commands)")
    paint.begin_frame()
    external_call["moxi_window_ordered_paint_begin", NoneType]()
    for i in range(commands.count()):
        var command = commands.command(i)
        if command.kind == TEXT_INPUT_VIEW_KIND and command.focused:
            external_call["moxi_window_text_editor_key", NoneType](Int32(command.id))
        paint.draw(command)
    # Publish background panels, edges, node controls, then interaction overlays.
    # Populate ordinary slots once; ordering below does not recreate editors.
    for i in range(commands.count()):
        var command = commands.command(i)
        if command.id == SEARCH_PANEL_ID or command.id == SEARCH_LABEL_ID:
            continue
        var background = command.id < CONTROL_BASE
        if not background:
            var object_index = app.component.document.object_index.get((command.id - CONTROL_BASE) // ID_STRIDE, -1)
            background = object_index >= 0 and app.component.document.objects[object_index].kind == ObjectKind.GROUP
        if background and command.kind != SLIDER_KIND and command.kind != SURFACE_KIND:
            external_call["moxi_window_ordered_paint", NoneType](Int32(command.kind), Int32(command.slot))
    var edges = clip_scene(app.component.edge_scene(), app.root_bounds)
    graph.set_clip(app.root_bounds)
    graph.begin_scene()
    for i in range(edges.count()):
        graph.draw_scene_command(edges.command(i))
    if external_call["moxi_window_ordered_custom_slice", Int32]() != 1:
        raise Error("Canvas native edge slice capacity exceeded")
    for i in range(commands.count()):
        var command = commands.command(i)
        if command.id < CONTROL_BASE:
            continue
        var object_index = app.component.document.object_index.get((command.id - CONTROL_BASE) // ID_STRIDE, -1)
        if object_index >= 0 and app.component.document.objects[object_index].kind == ObjectKind.GROUP:
            continue
        if command.kind != SLIDER_KIND and command.kind != SURFACE_KIND:
            external_call["moxi_window_ordered_paint", NoneType](Int32(command.kind), Int32(command.slot))
    var scene = app.component.overlay_scene()
    # Ordered AppKit currently accepts no slider slot. Render the genuine
    # PaintCommand through Scene; its ordinary control still owns value/input/AX.
    for i in range(commands.count()):
        var command = commands.command(i)
        if command.kind == SLIDER_KIND:
            scene.push_clip(0, command.clip_bounds if command.has_clip else app.root_bounds)
            var bounds = command.bounds
            var scale = bounds.height / 30
            var y = bounds.y + bounds.height / 2
            var x0 = bounds.x + 8 * scale
            var x1 = bounds.x + bounds.width - 8 * scale
            var at = x0 + (x1 - x0) * command.progress
            scene.append_line(command.id, Point(x0, y), Point(x1, y), command.style.fill, 5 * scale)
            scene.append_line(command.id, Point(x0, y), Point(at, y), command.style.text, 5 * scale)
            scene.append_rounded_rect(command.id, Rect(at - 6 * scale, y - 6 * scale, 12 * scale, 12 * scale), command.style.text, 6 * scale)
            if command.focused:
                scene.append_rect(command.id, Rect(bounds.x, bounds.y, bounds.width, 2 * scale), Color(1, 0.8, 0.2, 1))
            scene.pop_clip()
    var clipped = clip_scene(scene, app.root_bounds)
    var lines = 0
    var labels = 0
    for i in range(edges.count()):
        var command = edges.command(i)
        lines += 1 if command.kind == SCENE_LINE else 0
        labels += 1 if command.kind == SCENE_TEXT else 0
    for i in range(scene.count()):
        var command = scene.command(i)
        lines += 1 if command.kind == SCENE_LINE else 0
        labels += 1 if command.kind == SCENE_TEXT else 0
    if lines > NATIVE_LINE_CAPACITY or labels > NATIVE_TEXT_CAPACITY:
        raise Error("Canvas native custom scene capacity exceeded; refusing truncated output")
    for i in range(clipped.count()):
        graph.draw_scene_command(clipped.command(i))
    graph.end_scene()
    if external_call["moxi_window_ordered_custom_slice", Int32]() != 1:
        raise Error("Canvas native overlay slice capacity exceeded")
    # Search/report controls are ordinary foreground UI, above graph and ports.
    # Reuse their populated slots; do not add a parallel text or panel renderer.
    for i in range(commands.count()):
        var command = commands.command(i)
        if command.id == SEARCH_PANEL_ID or command.id == SEARCH_LABEL_ID:
            external_call["moxi_window_ordered_paint", NoneType](Int32(command.kind), Int32(command.slot))
    paint.update_accessibility(canvas_accessibility(app))
    paint.end_frame()
    app.clear_invalidation()
