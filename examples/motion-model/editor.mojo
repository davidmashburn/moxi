"""Ordinary Moxi Component: controls and pointer/keyboard routes share one model."""
from moxi import Component, ColumnView, Rect, Point, Event
from moxi.event import *
from moxi.style import Color, Style
from model import *

comptime CANVAS = 50


@fieldwise_init
struct Command(Equatable, ImplicitlyCopyable):
    var value: Int
    comptime FORMALIZE = Self(100)
    comptime LENGTH_DOWN = Self(101)
    comptime LENGTH_UP = Self(102)
    comptime PEAK_DOWN = Self(103)
    comptime PEAK_UP = Self(104)
    comptime TURN_DOWN = Self(105)
    comptime TURN_UP = Self(106)
    comptime REQUEST = Self(110)
    comptime FIRST = Self(111)
    comptime SECOND = Self(112)
    comptime THIRD = Self(113)
    comptime APPLY = Self(114)
    comptime CANCEL = Self(115)
    comptime TARGET_DOWN = Self(120)
    comptime TARGET_UP = Self(121)
    comptime KNOT_PREVIOUS = Self(122)
    comptime KNOT_NEXT = Self(123)
    comptime SCRUB_BACK = Self(124)
    comptime SCRUB_FORWARD = Self(125)
    comptime PLAY = Self(126)
    comptime UNDO = Self(130)
    comptime REDO = Self(131)


def button(mut view: ColumnView, row: Int, command: Command, title: String, enabled: Bool = True):
    view.add_button_to(row, command.value, title, 32)
    view.set_action(command.value, command.value)
    for i in range(len(view.children)):
        if view.children[i].id == command.value:
            view.children[i].enabled = enabled
            view.children[i].semantics.enabled = enabled


def number(value: Float64) -> String:
    var scaled = Int(abs(value) * 1000 + 0.5)
    var fraction = scaled % 1000
    return String("-" if value < 0 else "", scaled // 1000, ".", fraction // 100, (fraction // 10) % 10, fraction % 10)


def plot_bounds(canvas: Rect) -> Rect:
    return Rect(canvas.x + canvas.width * 0.44, canvas.y + 146, canvas.width * 0.52, canvas.height - 198)


def knot_point(canvas: Rect, knot: Int, value: Float64) -> Point:
    var plot = plot_bounds(canvas)
    return Point(plot.x + plot.width * Float32(knot) / 8, plot.y + plot.height * Float32(120 - value) / 140)


struct MotionEditor(Component):
    var studio: Studio
    var pointer_drag: Bool

    def __init__(out self):
        self.studio = Studio()
        self.pointer_drag = False

    def build(self, bounds: Rect) -> ColumnView:
        var s = self.studio
        var arm = s.doc.kind == SketchKind.ARM
        var ready = s.search.state == SolveState.READY and s.search.revision == s.revision
        var view = ColumnView(bounds, 16, 7)
        view.set_surface_style(Style(Color(0.055, 0.075, 0.11, 1), Color(0.92, 0.95, 1, 1), 0, 14))
        view.add_label(1, "MOTION / from sketch to executable behavior", 28)
        view.set_font_size(1, 23)
        view.add_label(2, "V01  /  I01 sketch  /  I03 inverse design     |     Synthetic 2D arm, two-state response, 2 seconds", 22)
        view.add_canvas(CANVAS, "Arm sketch, state graph and editable desired-angle knots. Drag a knot; Tab to equivalent knot controls. Escape cancels.", max(Float32(340), bounds.height - 382))
        _ = view.add_row(60, 0, 32, 0, 6)
        button(view, 60, Command.FORMALIZE, "Formalize arm", not arm)
        button(view, 60, Command.LENGTH_DOWN, "Length -10", arm)
        button(view, 60, Command.LENGTH_UP, "Length +10", arm)
        button(view, 60, Command.PEAK_DOWN, "Peak -5 deg", arm)
        button(view, 60, Command.PEAK_UP, "Peak +5 deg", arm)
        button(view, 60, Command.TURN_DOWN, "Turn -0.125 s", arm)
        button(view, 60, Command.TURN_UP, "Turn +0.125 s", arm)
        view.add_label(3, String("PARAMETERS own execution   |   length ", s.doc.length, " px   peak ", s.doc.parameters.peak, " deg   turn ", number(Float64(s.doc.parameters.turn) / 8), " s   |   revision ", s.revision), 22)
        _ = view.add_row(61, 0, 32, 0, 6)
        button(view, 61, Command.REQUEST, "Find alternatives", arm and not s.dragging and s.search.state != SolveState.RUNNING)
        button(view, 61, Command.FIRST, "Preview 1", ready and len(s.search.choices) > 0)
        button(view, 61, Command.SECOND, "Preview 2", ready and len(s.search.choices) > 1)
        button(view, 61, Command.THIRD, "Preview 3", ready and len(s.search.choices) > 2)
        button(view, 61, Command.APPLY, "Commit target" if s.dragging else "Apply preview", ready or s.dragging)
        button(view, 61, Command.CANCEL, "Cancel / Escape", s.dragging or ready or s.search.state == SolveState.RUNNING)
        view.add_label(4, String("DESIRED ", "DRAFT" if s.dragging else "knots request a fit", "   |   selected t = ", number(Float64(s.knot) / 4), " s : ", number(s.draft[s.knot] if s.dragging else s.doc.target[s.knot]), " deg   |   endpoints pinned at 0 deg"), 22)
        _ = view.add_row(62, 0, 32, 0, 6)
        button(view, 62, Command.TARGET_DOWN, "Target -5 deg")
        button(view, 62, Command.TARGET_UP, "Target +5 deg")
        button(view, 62, Command.KNOT_PREVIOUS, "Previous knot", not s.dragging)
        button(view, 62, Command.KNOT_NEXT, "Next knot", not s.dragging)
        button(view, 62, Command.SCRUB_BACK, "Scrub -0.25 s", arm)
        button(view, 62, Command.SCRUB_FORWARD, "Scrub +0.25 s", arm)
        button(view, 62, Command.PLAY, "Pause" if s.playing else "Play", arm)
        _ = view.add_row(63, 0, 32, 0, 6)
        button(view, 63, Command.UNDO, "Undo / Cmd+Z", len(s.undo_stack) > 0 or s.dragging)
        button(view, 63, Command.REDO, "Redo / Cmd+Shift+Z", len(s.redo_stack) > 0)
        view.add_label_to(63, 5, "Drag knots. Tab selects controls; Space activates. Escape cancels. Cmd+Z undoes.", 32)
        view.set_preferred_width(Command.UNDO.value, 145)
        view.set_preferred_width(Command.REDO.value, 190)
        view.add_label(6, s.message, 24)
        view.set_font_size(6, 13)
        view.add_label(7, "Family: peak 20..80 deg by 5; turn 0.5..1.5 s by 0.125. Max 117 tests, best 3 within 6 deg RMS. No general inverse solver.", 20)
        view.set_font_size(7, 12)
        view.layout()
        return view^

    def command(mut self, command: Command) -> Bool:
        if command == Command.FORMALIZE:
            self.studio.formalize()
        elif command == Command.LENGTH_DOWN or command == Command.LENGTH_UP:
            self.studio.edit_length(-10 if command == Command.LENGTH_DOWN else 10)
        elif command == Command.PEAK_DOWN or command == Command.PEAK_UP:
            self.studio.edit_parameters(-5 if command == Command.PEAK_DOWN else 5, 0)
        elif command == Command.TURN_DOWN or command == Command.TURN_UP:
            self.studio.edit_parameters(0, -1 if command == Command.TURN_DOWN else 1)
        elif command == Command.REQUEST:
            self.studio.request()
        elif command == Command.FIRST or command == Command.SECOND or command == Command.THIRD:
            var index = command.value - Command.FIRST.value
            if self.studio.search.state == SolveState.READY and index < len(self.studio.search.choices):
                self.studio.search.selected = index
        elif command == Command.APPLY:
            if self.studio.dragging:
                self.studio.finish_drag()
                self.pointer_drag = False
            else:
                self.studio.apply()
        elif command == Command.CANCEL:
            self.studio.cancel()
            self.pointer_drag = False
        elif command == Command.TARGET_DOWN or command == Command.TARGET_UP:
            if not self.studio.dragging:
                self.studio.begin_drag(self.studio.knot)
                self.pointer_drag = False
            if self.studio.dragging:
                var value = self.studio.draft[self.studio.knot] + Float64(-5 if command == Command.TARGET_DOWN else 5)
                self.studio.draft[self.studio.knot] = max(-20.0, min(120.0, value))
                self.studio.message = "Desired-curve draft: Commit target to accept; Escape or Undo cancels."
        elif command == Command.KNOT_PREVIOUS or command == Command.KNOT_NEXT:
            self.studio.knot = max(0, min(8, self.studio.knot + (-1 if command == Command.KNOT_PREVIOUS else 1)))
        elif command == Command.SCRUB_BACK or command == Command.SCRUB_FORWARD:
            self.studio.playing = False
            self.studio.time = max(0.0, min(2.0, self.studio.time + (-0.25 if command == Command.SCRUB_BACK else 0.25)))
        elif command == Command.PLAY:
            if self.studio.doc.kind == SketchKind.ARM:
                self.studio.playing = not self.studio.playing
        elif command == Command.UNDO:
            self.studio.undo()
        elif command == Command.REDO:
            self.studio.redo()
        else:
            return False
        return True

    def intercepts_pointer(self, event: Event) -> Bool:
        return self.studio.dragging and self.pointer_drag

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        if event.kind == FRAME_TICK_KIND:
            return self.studio.tick(Float64(event.delta_seconds))
        if event.kind == KEY_DOWN_KIND:
            if event.key == KEY_ESCAPE:
                return self.command(Command.CANCEL)
            if event.key == 122 and (event.modifiers & MOD_COMMAND) != 0:
                return self.command(Command.REDO if (event.modifiers & MOD_SHIFT) != 0 else Command.UNDO)
            if event.target == CANVAS:
                if event.key == KEY_SPACE:
                    return self.command(Command.PLAY)
        if event.kind == POINTER_DOWN_KIND and event.target == CANVAS:
            var plot = plot_bounds(view.bounds_for(CANVAS))
            if plot.contains(event.position):
                var knot = Int((event.position.x - plot.x) * 8 / plot.width + 0.5)
                self.studio.begin_drag(max(0, min(8, knot)))
                self.pointer_drag = self.studio.dragging
                return True
        if self.studio.dragging and self.pointer_drag:
            if event.kind == POINTER_MOVE_KIND or event.kind == DRAG_UPDATE_KIND or event.kind == DRAG_BEGIN_KIND:
                var plot = plot_bounds(view.bounds_for(CANVAS))
                self.studio.draft[self.studio.knot] = max(-20.0, min(120.0, 120 - Float64((event.position.y - plot.y) * 140 / plot.height)))
                return True
            if event.kind == POINTER_UP_KIND or event.kind == DROP_KIND:
                self.studio.finish_drag()
                self.pointer_drag = False
                return True
            if event.kind == POINTER_CANCEL_KIND:
                self.studio.cancel()
                return True
        if event.kind == ACTION_KIND or event.kind == CLICK_KIND:
            # Unknown control ids retain the component's unhandled behavior.
            return self.command(Command(event.target))
        if event.kind == KEY_DOWN_KIND and (event.key == KEY_SPACE or event.key == KEY_ENTER):
            return self.command(Command(event.target))
        return False
