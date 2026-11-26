"""Review a bounded worker's suggestion against a revision of one line fit."""
from moxi.authoring import Screen, UI


@fieldwise_init
struct Line(ImplicitlyCopyable):
    var gain: Int
    var offset: Int


@fieldwise_init
struct Proposal(ImplicitlyCopyable):
    var revision: Int
    var before: Line
    var after: Line


def investigate(line: Line, revision: Int) -> Proposal:
    # Fixed measurements y(0)=4 and y(1)=7 determine the intercept and slope.
    return Proposal(revision, line, Line(7 - 4, 4))


struct Workbench(Screen):
    var line: Line
    var revision: Int
    var pending: Optional[Proposal]
    var status: String

    def __init__(out self):
        self.line = Line(1, 0)
        self.revision = 0
        self.pending = None
        self.status = "Ready to investigate."

    def request(mut self):
        if not self.pending:
            self.pending = investigate(self.line, self.revision)
            self.status = "Review both changes before applying."

    def edit_gain(mut self):
        self.line.gain += 1
        self.revision += 1
        self.status = "Gain edited locally."

    def reject(mut self):
        if self.pending:
            self.pending = None
            self.status = "Rejected. Live values preserved."

    def apply(mut self):
        if not self.pending:
            return
        var candidate = self.pending.value()
        self.pending = None
        if candidate.revision != self.revision:
            self.status = "Stale proposal rejected. Request a fresh fit."
            return
        self.line = candidate.after
        self.revision += 1
        self.status = "Applied both fit parameters."

    def render(self, mut ui: UI[Self]):
        ui.label("Line fit   /   calibration sample")
        ui.label("Observations: (0, 4) and (1, 7)")
        ui.label("Live revision " + String(self.revision) + "    Gain " + String(self.line.gain) + "    Offset " + String(self.line.offset))
        ui.button("Increase live gain", Self.edit_gain)
        ui.button("Request fit proposal", Self.request, not self.pending)
        if self.pending:
            var candidate = self.pending.value()
            ui.label("Proposed fit from revision " + String(candidate.revision))
            ui.label("Gain: " + String(candidate.before.gain) + " to " + String(candidate.after.gain))
            ui.label("Offset: " + String(candidate.before.offset) + " to " + String(candidate.after.offset))
        else:
            ui.label("No proposal pending")
        ui.label(self.status)
        # Stable action scopes across preview insertion/removal.
        ui.begin_scope("review")
        ui.button("Reject", Self.reject, Bool(self.pending))
        ui.button("Apply", Self.apply, Bool(self.pending))
        ui.end_scope()
