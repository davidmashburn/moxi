"""Linked sketch, executable state graph and owned curve roles via Moxi Scene."""
from std.math import sin, cos
from moxi import Rect, Point, Scene, Color
from moxi.scene_text import SceneTextStyle
from editor import plot_bounds, knot_point, number
from model import *

comptime INK = Color(0.87, 0.92, 1, 1)
comptime MUTED = Color(0.52, 0.61, 0.73, 1)
comptime BLUE = Color(0.24, 0.74, 1, 1)
comptime ORANGE = Color(1, 0.66, 0.26, 1)
comptime GREEN = Color(0.39, 0.9, 0.68, 1)
comptime RED = Color(1, 0.38, 0.43, 1)


def text(mut scene: Scene, label: String, x: Float32, y: Float32, width: Float32, color: Color = INK, size: Float32 = 13):
    scene.append_text_styled(0, label, Rect(x, y, width, 22), color, SceneTextStyle("system-ui", size))


def line(mut scene: Scene, a: Point, b: Point, color: Color = MUTED, width: Float32 = 1):
    scene.append_line(0, a, b, color, width)


def dot(mut scene: Scene, point: Point, color: Color, size: Float32 = 7):
    scene.append_rounded_rect(0, Rect(point.x - size / 2, point.y - size / 2, size, size), color, size / 2)


def arm_point(pivot: Point, length: Float32, angle: Float64) -> Point:
    var radians = angle * PI / 180
    return Point(pivot.x + length * Float32(cos(radians)), pivot.y - length * Float32(sin(radians)))


def response(mut scene: Scene, canvas: Rect, p: Parameters, color: Color, width: Float32):
    var previous = knot_point(canvas, 0, 0)
    var plot = plot_bounds(canvas)
    for i in range(1, 161):
        var t = Float64(i) / 80
        var point = Point(plot.x + plot.width * Float32(t / 2), plot.y + plot.height * Float32(120 - p.angle(t)) / 140)
        line(scene, previous, point, color, width)
        previous = point


def draw(studio: Studio, canvas: Rect) -> Scene:
    var scene = Scene()
    var x = canvas.x
    var y = canvas.y
    var w = canvas.width
    var h = canvas.height
    var plot = plot_bounds(canvas)
    var arm = studio.doc.kind == SketchKind.ARM
    var parameters = studio.visible_parameters()
    var preview = studio.search.state == SolveState.READY and studio.search.revision == studio.revision
    scene.append_rounded_rect(0, canvas, Color(0.075, 0.10, 0.15, 1), 10)

    # The graph describes the very same two branches evaluated by angle().
    var phase = parameters.phase(studio.time)
    var track_color = BLUE if arm and phase == MotionPhase.TRACK else MUTED
    var return_color = BLUE if arm and phase == MotionPhase.RETURN else MUTED
    scene.append_rounded_rect(0, Rect(x + 22, y + 17, 150, 44), Color(0.12, 0.20, 0.29, 1), 8)
    scene.append_rounded_rect(0, Rect(x + 302, y + 17, 150, 44), Color(0.12, 0.20, 0.29, 1), 8)
    text(scene, "TRACK" + (" / active" if arm and phase == MotionPhase.TRACK else ""), x + 36, y + 28, 142, track_color, 15)
    text(scene, "RETURN" + (" / active" if arm and phase == MotionPhase.RETURN else ""), x + 316, y + 28, 142, return_color, 15)
    line(scene, Point(x + 178, y + 39), Point(x + 290, y + 39), BLUE, 2)
    text(scene, "t >= turn  >", x + 184, y + 17, 120, MUTED, 12)
    text(scene, "t = 2 s: reset to TRACK", x + 188, y + 55, 250, MUTED, 12)
    text(scene, "A sin(pi*t / (2*turn))", x + 24, y + 76, 240, INK, 12)
    text(scene, "A cos(pi*(t-turn) / (2*(2-turn)))", x + 280, y + 76, 250, INK, 12)
    text(scene, String("t = ", number(studio.time), " s  |  ", "PREVIEW" if preview else ("EXECUTABLE" if arm else "INFORMAL")), x + w * 0.56, y + 24, w * 0.42, GREEN if preview else BLUE, 16)
    text(scene, String("Committed ", studio.doc.parameters.peak, " deg / ", number(Float64(studio.doc.parameters.turn) / 8), " s"), x + w * 0.56, y + 52, w * 0.42, INK)

    if studio.search.state == SolveState.READY:
        for i in range(len(studio.search.choices)):
            var candidate = studio.search.choices[i]
            var cx = x + 24 + Float32(i) * (w - 48) / 3
            text(scene, String(i + 1, ": ", candidate.parameters.peak, " deg / ", number(Float64(candidate.parameters.turn) / 8), " s / RMS ", number(candidate.error)), cx, y + 109, (w - 48) / 3, GREEN if i == studio.search.selected else MUTED)
    elif studio.search.state == SolveState.RUNNING:
        text(scene, String("SEARCHING ", studio.search.next, " / ", SEARCH_SIZE, " pairs. Cancel stays available."), x + 24, y + 109, w - 48, ORANGE)
    elif studio.search.state == SolveState.FAILED:
        text(scene, String("UNSATISFIED in this grid: best RMS ", number(studio.search.best_error), " deg > 6 deg. Target retained."), x + 24, y + 109, w - 48, RED)
    elif studio.search.state == SolveState.STALE:
        text(scene, "STALE proposal discarded: document revision changed. Request a new fit.", x + 24, y + 109, w - 48, RED)
    else:
        text(scene, "Fixed model family. Landing is pinned; desired curves never silently become code.", x + 24, y + 109, w - 48, MUTED)

    # I01: partial formalization has a local boundary. This note is never a
    # dependency and keeps its document coordinates through every undo/redo.
    var left_width = w * 0.40
    var pivot = Point(x + 62, y + h * 0.70)
    var scale = min(Float32(1.4), max(Float32(60), h * 0.70 - 205) / 160)
    var length = Float32(studio.doc.length) * scale
    var angle = parameters.angle(studio.time) if arm else Float64(28)
    var tip = arm_point(pivot, length, angle)
    text(scene, "PIVOT + ARM" if arm else "SKETCH / not executable", x + 25, y + 148, left_width - 30, BLUE if arm else MUTED, 14)
    text(scene, "forbidden sector: angle > 80 deg", x + 25, y + 174, left_width - 30, RED, 12)
    line(scene, pivot, arm_point(pivot, length + 8, 80), RED, 1)
    var previous = arm_point(pivot, length, 0)
    for i in range(1, 101):
        var point = arm_point(pivot, length, Float64(i))
        line(scene, previous, point, RED if i > 80 else MUTED, 1)
        previous = point
    if arm:
        var prior = arm_point(pivot, length, parameters.angle(0))
        for i in range(1, 81):
            var point = arm_point(pivot, length, parameters.angle(Float64(i) / 40))
            line(scene, prior, point, GREEN if preview else BLUE, 2)
            prior = point
    line(scene, pivot, tip, GREEN if preview else (BLUE if arm else MUTED), Float32(5 if arm else 2))
    dot(scene, pivot, INK, 13)
    dot(scene, tip, GREEN if preview else (BLUE if arm else MUTED), 12)
    text(scene, String(studio.doc.length, " px   /   ", number(angle), " deg"), x + 25, y + h - 29, left_width - 30, INK)
    var note_x = x + studio.doc.note_x * w
    var note_y = y + studio.doc.note_y * h
    scene.append_rounded_rect(0, Rect(note_x, note_y, left_width - 42, 46), Color(0.20, 0.18, 0.13, 1), 5)
    text(scene, studio.doc.note, note_x + 10, note_y + 4, left_width - 60, ORANGE)
    text(scene, "Informal note / no dependency", note_x + 10, note_y + 24, left_width - 60, MUTED, 11)

    # Plot roles remain distinct even while a proposal is previewed.
    for value in range(0, 121, 40):
        var py = plot.y + plot.height * Float32(120 - value) / 140
        line(scene, Point(plot.x, py), Point(plot.x + plot.width, py), Color(0.18, 0.24, 0.32, 1))
        text(scene, String(value), plot.x - 31, py - 11, 30, MUTED, 11)
    var cap_y = plot.y + plot.height * 40 / 140
    line(scene, Point(plot.x, cap_y), Point(plot.x + plot.width, cap_y), RED)
    for i in range(5):
        text(scene, String(Float32(i) / 2, " s"), plot.x + plot.width * Float32(i) / 4 - 12, plot.y + plot.height + 1, 55, MUTED, 11)
    if arm:
        response(scene, canvas, studio.doc.parameters, BLUE, 2)
        if preview:
            response(scene, canvas, parameters, GREEN, 3)
    var values = studio.draft.copy() if studio.dragging else studio.doc.target.copy()
    for i in range(KNOTS):
        var point = knot_point(canvas, i, values[i])
        if i > 0:
            line(scene, knot_point(canvas, i - 1, values[i - 1]), point, ORANGE, 2)
        if i == studio.knot:
            dot(scene, point, INK, 15)
        dot(scene, point, MUTED if i == 0 or i == 8 else ORANGE, 8)
    var cursor_x = plot.x + plot.width * Float32(studio.time) / 2
    line(scene, Point(cursor_x, plot.y), Point(cursor_x, plot.y + plot.height), MUTED)
    text(scene, "deg: angle vs time", plot.x, plot.y - 23, plot.width, MUTED, 11)
    text(scene, "Blue: committed   Orange: desired   Green: candidate", plot.x - 20, y + h - 26, plot.width + 45, INK, 12)
    return scene^
