"""A finite shared-screen experiment. One plot has exactly one use."""
from moxi.authoring import Screen, UI


@fieldwise_init
struct Branch(ImplicitlyCopyable):
    var index: Int

    comptime ORCHARD = Self(0)
    comptime GLADE = Self(1)
    comptime COMMONS = Self(2)

    def name(self) -> String:
        if self.index == Self.ORCHARD.index:
            return "Orchard"
        if self.index == Self.GLADE.index:
            return "Glade"
        return "Commons"

    def next(self) -> Self:
        return Self((self.index + 1) % 3)


@fieldwise_init
struct Uses(ImplicitlyCopyable):
    var gardens: Int
    var grove: Int
    var play: Int

    def counts(self) -> String:
        return String(self.gardens) + " gardens   /   " + String(self.grove) + " grove   /   " + String(self.play) + " play"


def position(value: Int, minimum: Int, owner: String) -> String:
    return owner + (" met" if value >= minimum else " short " + String(minimum - value))


@fieldwise_init
struct Decision(ImplicitlyCopyable):
    var branch: Branch
    var uses: Uses
    var minimums: Uses
    var reason: String


def alternate(current: Int, low: Int, high: Int) -> Int:
    return high if current == low else low


def positions(uses: Uses, minimums: Uses) -> String:
    return position(uses.gardens, minimums.gardens, "Fern") + "   /   " + position(uses.grove, minimums.grove, "Ash") + "   /   " + position(uses.play, minimums.play, "Pip")


struct Workbench(Screen):
    var supply: Int
    var transfer: Int
    var goals: Uses
    var selected: Branch
    var editing: Bool
    var rationale: String
    var decision: Optional[Decision]
    var previous: Optional[Decision]
    var can_undo: Bool

    def __init__(out self):
        self.supply = 12
        self.transfer = 0
        self.goals = Uses(6, 5, 4)
        self.selected = Branch.ORCHARD
        self.editing = True
        self.rationale = ""
        self.decision = None
        self.previous = None
        self.can_undo = False

    def allocation(self, branch: Branch) -> Uses:
        var grove = 3
        var play = 3
        if branch.index == Branch.GLADE.index:
            grove = 6
        elif branch.index == Branch.COMMONS.index:
            grove = 4 + self.transfer
            play = 4 - self.transfer
        return Uses(self.supply - grove - play, grove, play)

    def fern(mut self):
        self.goals.gardens = alternate(self.goals.gardens, 5, 6)

    def ash(mut self):
        self.goals.grove = alternate(self.goals.grove, 5, 6)

    def pip(mut self):
        self.goals.play = alternate(self.goals.play, 4, 5)

    def resize(mut self):
        self.supply = alternate(self.supply, 12, 13)

    def shift(mut self):
        self.transfer = 1 - self.transfer

    def switch_page(mut self):
        self.editing = not self.editing

    def select_next(mut self):
        self.selected = self.selected.next()
        self.rationale = ""

    def explain(mut self, value: String):
        self.rationale = value

    def promote(mut self):
        if not self.rationale.strip():
            return
        self.previous = self.decision
        self.decision = Decision(self.selected, self.allocation(self.selected), self.goals, self.rationale)
        self.can_undo = True

    def undo(mut self):
        if self.can_undo:
            self.decision = self.previous
            self.can_undo = False

    def render(self, mut ui: UI[Self]):
        ui.label("Orchard Commons   /   Fictional neighborhood allocation")
        ui.label("Shared supply: " + String(self.supply) + " plots. Unassigned plots become gardens.")
        ui.label("Minimums: Fern " + String(self.goals.gardens) + " gardens   /   Ash " + String(self.goals.grove) + " grove   /   Pip " + String(self.goals.play) + " play")
        for i in range(3):
            var branch = Branch(i)
            var uses = self.allocation(branch)
            ui.label(branch.name() + "    |    " + uses.counts() + "    |    " + positions(uses, self.goals))
        ui.button("Review a proposal" if self.editing else "Edit assumptions", Self.switch_page)
        if self.editing:
            ui.begin_scope("inputs")
            ui.button("Fern: set garden minimum to " + String(alternate(self.goals.gardens, 5, 6)), Self.fern)
            ui.button("Ash: set grove minimum to " + String(alternate(self.goals.grove, 5, 6)), Self.ash)
            ui.button("Pip: set play minimum to " + String(alternate(self.goals.play, 4, 5)), Self.pip)
            ui.button("All branches: set supply to " + String(alternate(self.supply, 12, 13)), Self.resize)
            ui.button("Commons: move one play plot to grove" if self.transfer == 0 else "Commons: restore the play plot", Self.shift)
            ui.end_scope()
        else:
            ui.begin_scope("proposal")
            ui.button("Review " + self.selected.next().name() + " next", Self.select_next)
            ui.label("Reason to promote " + self.selected.name())
            ui.text_input("Decision reason", self.rationale, Self.explain, show_label=False)
            ui.button("Promote " + self.selected.name(), Self.promote, Bool(self.rationale.strip()))
            ui.button("Undo promotion", Self.undo, self.can_undo)
            ui.end_scope()
        ui.label("Decision at promotion")
        if self.decision:
            var record = self.decision.value()
            ui.label(record.branch.name() + "    |    " + record.uses.counts())
            ui.label(record.reason)
            ui.label(positions(record.uses, record.minimums))
        else:
            ui.label("No allocation promoted.")
