"""An application-owned, zero-argument operation over stable observation IDs."""
from moxi.capability_bus import CapabilityBus, CapabilityHandler
from moxi.capability_types import (
    CALLER_SYSTEM, CALLER_UI, CAPABILITY_DISABLED, CAPABILITY_INVALID,
    CAPABILITY_OK, SIDE_EFFECT_LOCAL, CapabilityDescriptor, CapabilityInvocation,
    CapabilityResult,
)
from moxi import ColumnView, Component, Event, Rect
from moxi.event import KEY_DOWN_KIND, KEY_F2

comptime OPERATION = "observations.collect_high.v1"
comptime THRESHOLD = 70


@fieldwise_init
struct Observation(ImplicitlyCopyable):
    var id: Int
    var reading: Int


struct Notebook(CapabilityHandler):
    var rows: List[Observation]
    var members: List[Int]
    var writes: Int

    def __init__(out self):
        self.rows = [Observation(104, 82), Observation(207, 51), Observation(318, 70)]
        self.members = []
        self.writes = 0

    def __init__(out self, *, copy: Self):
        self.rows = copy.rows.copy()
        self.members = copy.members.copy()
        self.writes = copy.writes

    def capability_descriptor(self) -> CapabilityDescriptor:
        return CapabilityDescriptor(OPERATION, "Collect observations with readings of 70 or higher", SIDE_EFFECT_LOCAL)

    def execute_capability(mut self, invocation: CapabilityInvocation) -> CapabilityResult:
        if invocation.caller != CALLER_UI and invocation.caller != CALLER_SYSTEM:
            return CapabilityResult(invocation.request_id, CAPABILITY_DISABLED, "", "Caller has read-only access")
        if invocation.arguments != "{}":
            return CapabilityResult(invocation.request_id, CAPABILITY_INVALID, "", "Expected the empty argument object")
        self.members.clear()
        for row in self.rows:
            if row.reading >= THRESHOLD:
                self.members.append(row.id)
        self.writes += 1
        return CapabilityResult(invocation.request_id, CAPABILITY_OK, self.member_ids())

    def member_ids(self) -> String:
        var ids = String("[")
        for i in range(len(self.members)):
            if i:
                ids += ","
            ids += String(self.members[i])
        return ids + "]"


struct CohortScreen(Component):
    var notebook: Notebook
    var bus: CapabilityBus
    var status: String
    var requests: Int

    def __init__(out self):
        self.notebook = Notebook()
        self.bus = CapabilityBus()
        _ = self.bus.register_handler(self.notebook)
        self.status = "Ready"
        self.requests = 0

    def collect(mut self, caller: Int, route: String) -> CapabilityResult:
        self.requests += 1
        var result = self.bus.invoke_handler(self.notebook, CapabilityInvocation(
            String(self.requests), OPERATION, caller, "{}",
        ))
        self.status = route + " / "
        if result.completed():
            self.status += "Saved cohort"
        else:
            self.status += result.recovery_hint
        return result

    def button_id(self) -> Int:
        # Alternate mounted IDs on successful builds to exercise view replacement.
        return 20 + self.notebook.writes % 2

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        if event.kind == KEY_DOWN_KIND and event.key == KEY_F2:
            _ = self.collect(CALLER_UI, "Keyboard")
            return True
        if event.is_activation() and event.target == self.button_id():
            _ = self.collect(CALLER_UI, "Button")
            return True
        return False

    def build(self, bounds: Rect) -> ColumnView:
        var view = ColumnView(bounds, 24, 6)
        view.set_panel(0, Rect(12, 12, bounds.width - 24, bounds.height - 24))
        view.add_label(1, "Field notebook", 32)
        view.add_label(2, "Observation ID   /   Sensor reading", 26)
        for i in range(len(self.notebook.rows)):
            var row = self.notebook.rows[i]
            view.add_label(10 + i, String(row.id, "     /     ", row.reading), 24)
        view.add_button(self.button_id(), "Collect readings >= 70   (F2)", 38)
        view.add_label(3, "High-reading cohort   " + self.notebook.member_ids(), 30)
        view.add_label(4, self.status, 28)
        view.layout()
        return view^
