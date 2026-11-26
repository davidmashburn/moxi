"""V01 / I01 / I03: one arm, two motion states, a finite inverse model family."""
from std.math import sin, cos, sqrt

comptime PI = 3.141592653589793
comptime DURATION = 2.0
comptime KNOTS = 9
comptime SEARCH_SIZE = 117
comptime FIT_TOLERANCE = 6.0  # degrees RMS at all nine authored knots
comptime HISTORY_LIMIT = 64


@fieldwise_init
struct MotionPhase(Equatable, ImplicitlyCopyable):
    var value: Int
    comptime TRACK = Self(0)
    comptime RETURN = Self(1)


@fieldwise_init
struct SketchKind(Equatable, ImplicitlyCopyable):
    var value: Int
    comptime INFORMAL = Self(0)
    comptime ARM = Self(1)


@fieldwise_init
struct SolveState(Equatable, ImplicitlyCopyable):
    var value: Int
    comptime IDLE = Self(0)
    comptime RUNNING = Self(1)
    comptime READY = Self(2)
    comptime FAILED = Self(3)
    comptime CANCELLED = Self(4)
    comptime STALE = Self(5)


@fieldwise_init
struct Parameters(Equatable, ImplicitlyCopyable):
    var peak: Int  # degrees, 20..80, step 5
    var turn: Int  # eighths of a second, 4..12

    def valid(self) -> Bool:
        return 20 <= self.peak <= 80 and self.peak % 5 == 0 and 4 <= self.turn <= 12

    def phase(self, time: Float64) -> MotionPhase:
        return MotionPhase.TRACK if time < Float64(self.turn) / 8 else MotionPhase.RETURN

    def angle(self, time: Float64) -> Float64:
        # Both endpoints are pinned. These are executable state response laws,
        # not a spline fitted through the requested target.
        if time <= 0 or time >= DURATION:
            return 0
        var turn = Float64(self.turn) / 8
        if self.phase(time) == MotionPhase.TRACK:
            return Float64(self.peak) * sin(PI * time / (2 * turn))
        return Float64(self.peak) * cos(PI * (time - turn) / (2 * (DURATION - turn)))


struct Document(ImplicitlyCopyable):
    var parameters: Parameters
    var target: List[Float64]
    var kind: SketchKind
    var length: Int
    var note: String
    var note_x: Float32
    var note_y: Float32

    def __init__(out self):
        self.parameters = Parameters(45, 8)
        self.target = List[Float64]()
        var desired = Parameters(60, 6)
        for i in range(KNOTS):
            self.target.append(desired.angle(Float64(i) / 4))
        self.kind = SketchKind.INFORMAL
        self.length = 120
        self.note = "material? / unfinished"
        self.note_x = 0.07
        self.note_y = 0.77

    def __init__(out self, *, copy: Self):
        self.parameters = copy.parameters
        self.target = copy.target.copy()
        self.kind = copy.kind
        self.length = copy.length
        self.note = copy.note
        self.note_x = copy.note_x
        self.note_y = copy.note_y


def fit_error(parameters: Parameters, target: List[Float64]) -> Float64:
    var sum: Float64 = 0
    for i in range(KNOTS):
        var difference = parameters.angle(Float64(i) / 4) - target[i]
        sum += difference * difference
    return sqrt(sum / Float64(KNOTS))


@fieldwise_init
struct Candidate(ImplicitlyCopyable):
    var parameters: Parameters
    var error: Float64


struct Search(ImplicitlyCopyable):
    var state: SolveState
    var revision: Int
    var target: List[Float64]
    var next: Int
    var choices: List[Candidate]
    var best_error: Float64
    var selected: Int

    def __init__(out self):
        self.state = SolveState.IDLE
        self.revision = -1
        self.target = List[Float64]()
        self.next = 0
        self.choices = List[Candidate]()
        self.best_error = 1e10
        self.selected = 0

    def __init__(out self, *, copy: Self):
        self.state = copy.state
        self.revision = copy.revision
        self.target = copy.target.copy()
        self.next = copy.next
        self.choices = copy.choices.copy()
        self.best_error = copy.best_error
        self.selected = copy.selected

    def start(mut self, doc: Document, revision: Int):
        self = Search()
        self.state = SolveState.RUNNING
        self.revision = revision
        self.target = doc.target.copy()

    def tick(mut self, revision: Int):
        if self.state != SolveState.RUNNING:
            return
        if revision != self.revision:
            self.state = SolveState.STALE
            self.choices.clear()
            return
        # Three evaluations per UI tick: deterministic, bounded, cancellable.
        for _ in range(3):
            if self.next >= SEARCH_SIZE:
                break
            var parameters = Parameters(20 + (self.next // 9) * 5, 4 + self.next % 9)
            self.next += 1
            var error = fit_error(parameters, self.target)
            self.best_error = min(self.best_error, error)
            if error > FIT_TOLERANCE:
                continue
            self.choices.append(Candidate(parameters, error))
            var j = len(self.choices) - 1
            while j > 0 and self.choices[j].error < self.choices[j - 1].error:
                var previous = self.choices[j - 1]
                self.choices[j - 1] = self.choices[j]
                self.choices[j] = previous
                j -= 1
            if len(self.choices) > 3:
                _ = self.choices.pop()
        if self.next == SEARCH_SIZE:
            self.state = SolveState.READY if len(self.choices) > 0 else SolveState.FAILED


struct Studio(ImplicitlyCopyable):
    var doc: Document
    var undo_stack: List[Document]
    var redo_stack: List[Document]
    var revision: Int
    var search: Search
    var message: String
    var time: Float64
    var playing: Bool
    var knot: Int
    var draft: List[Float64]
    var dragging: Bool

    def __init__(out self):
        self.doc = Document()
        self.undo_stack = List[Document]()
        self.redo_stack = List[Document]()
        self.revision = 0
        self.search = Search()
        self.message = "An informal arm and an unfinished note. Formalize only the arm."
        self.time = 0.75
        self.playing = False
        self.knot = 3
        self.draft = List[Float64]()
        self.dragging = False

    def __init__(out self, *, copy: Self):
        self.doc = copy.doc
        self.undo_stack = copy.undo_stack.copy()
        self.redo_stack = copy.redo_stack.copy()
        self.revision = copy.revision
        self.search = copy.search
        self.message = copy.message
        self.time = copy.time
        self.playing = copy.playing
        self.knot = copy.knot
        self.draft = copy.draft.copy()
        self.dragging = copy.dragging

    def invalidate(mut self):
        self.revision += 1
        self.dragging = False
        self.draft.clear()
        if self.search.state != SolveState.IDLE and self.search.state != SolveState.STALE:
            self.search.state = SolveState.STALE
            self.search.choices.clear()

    def commit(mut self, doc: Document, message: String):
        if len(self.undo_stack) == HISTORY_LIMIT:
            _ = self.undo_stack.pop(0)
        self.undo_stack.append(self.doc)
        self.redo_stack.clear()
        self.doc = doc
        self.invalidate()
        self.message = message

    def formalize(mut self):
        if self.doc.kind == SketchKind.ARM:
            return
        var doc = self.doc
        doc.kind = SketchKind.ARM
        self.commit(doc, "Arm + pivot formalized. Neighboring note remains informal.")

    def edit_parameters(mut self, peak_delta: Int, turn_delta: Int):
        if self.doc.kind != SketchKind.ARM:
            return
        var doc = self.doc
        doc.parameters.peak = max(20, min(80, doc.parameters.peak + peak_delta))
        doc.parameters.turn = max(4, min(12, doc.parameters.turn + turn_delta))
        if doc.parameters == self.doc.parameters:
            self.message = "Parameter bound reached: peak 20..80 deg; turn 0.5..1.5 s."
            return
        self.commit(doc, "Parameters own the solid curve. Desired knots are unchanged.")

    def edit_length(mut self, delta: Int):
        if self.doc.kind != SketchKind.ARM:
            return
        var doc = self.doc
        doc.length = max(80, min(160, doc.length + delta))
        if doc.length != self.doc.length:
            self.commit(doc, "Arm length changed; angular model and unfinished note preserved.")

    def edit_target(mut self, value: Float64):
        if self.knot == 0 or self.knot == KNOTS - 1:
            self.message = "Landing and start are pinned to 0 deg. Select an interior knot."
            return
        var doc = self.doc
        doc.target[self.knot] = max(-20.0, min(120.0, value))
        if doc.target[self.knot] != self.doc.target[self.knot]:
            self.commit(doc, "Desired curve edited. Executable parameters are unchanged; request a fit.")

    def begin_drag(mut self, knot: Int):
        self.knot = knot
        if knot == 0 or knot == KNOTS - 1:
            self.message = "Landing and start are pinned to 0 deg. Select an interior knot."
            return
        self.cancel()
        self.draft = self.doc.target.copy()
        self.dragging = True
        self.playing = False
        self.message = "Desired-curve draft: drag vertically, release to commit, Escape to cancel."

    def finish_drag(mut self):
        if not self.dragging:
            return
        var value = self.draft[self.knot]
        self.dragging = False
        self.draft.clear()
        self.edit_target(value)

    def request(mut self):
        if self.doc.kind != SketchKind.ARM or self.dragging:
            return
        self.search.start(self.doc, self.revision)
        self.message = "Searching 117 pairs; pinned endpoints, peak <= 80 deg, RMS <= 6 deg."

    def tick(mut self, delta: Float64) -> Bool:
        var changed = self.playing or self.search.state == SolveState.RUNNING
        if self.playing:
            self.time += max(0.0, min(0.05, delta))
            if self.time >= DURATION:
                self.time -= DURATION
        self.search.tick(self.revision)
        if self.search.state == SolveState.READY and changed:
            self.message = "Compare up to three fits. Preview is separate; Apply commits both parameters."
        elif self.search.state == SolveState.FAILED and changed:
            self.message = "No fit in this finite family. Desired curve retained; executable model unchanged."
        return changed

    def visible_parameters(self) -> Parameters:
        if self.search.state == SolveState.READY and self.search.revision == self.revision:
            return self.search.choices[self.search.selected].parameters
        return self.doc.parameters

    def apply(mut self):
        if self.search.revision != self.revision:
            self.search.state = SolveState.STALE
            self.search.choices.clear()
            self.message = "Stale fit refused. Request again against the current document revision."
            return
        if self.search.state != SolveState.READY:
            return
        var doc = self.doc
        doc.parameters = self.visible_parameters()
        self.search = Search()
        self.commit(doc, "Applied the selected pair as one undoable edit; target retained.")

    def cancel(mut self):
        if self.dragging:
            self.dragging = False
            self.draft.clear()
            self.message = "Target draft cancelled; committed target and model preserved."
        elif self.search.state == SolveState.RUNNING or self.search.state == SolveState.READY:
            self.search.state = SolveState.CANCELLED
            self.search.choices.clear()
            self.message = "Fit cancelled; committed model and desired curve preserved."

    def undo(mut self):
        if self.dragging:
            self.cancel()
            return
        self.cancel()
        if len(self.undo_stack) == 0:
            return
        self.redo_stack.append(self.doc)
        self.doc = self.undo_stack.pop()
        self.invalidate()
        if self.doc.kind == SketchKind.INFORMAL:
            self.playing = False
            self.search = Search()
        self.message = "Undid one document edit, including sketch kind, note and location."

    def redo(mut self):
        if self.dragging:
            self.cancel()
            return
        self.cancel()
        if len(self.redo_stack) == 0:
            return
        self.undo_stack.append(self.doc)
        self.doc = self.redo_stack.pop()
        self.invalidate()
        self.message = "Redid one document edit."
