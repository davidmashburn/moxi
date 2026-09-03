"""A ten-step, interactive lesson for Moxi's capability-bus boundary."""

from .capability import (
    CALLER_AGENT,
    CALLER_UI,
    CAPABILITY_OK,
    CAPABILITY_REQUIRES_APPROVAL,
    CapabilityBus,
    CapabilityDescriptor,
    CapabilityHandler,
    CapabilityInvocation,
    CapabilityResult,
    SIDE_EFFECT_DESTRUCTIVE,
    SIDE_EFFECT_LOCAL,
)
from .accessibility import ACTION_PRESS
from .component import Component
from .controls import ButtonControl, LabelControl
from .event import ACTION_KIND, CLICK_KIND, Event, KEY_DOWN_KIND, KEY_ENTER, KEY_SPACE
from .geometry import Rect
from .style import (
    Color,
    Style,
    default_label_style,
    default_panel_style,
    default_surface_style,
)
from .view import ColumnView


comptime CAPABILITY_WALKTHROUGH_STEP_COUNT = 10
comptime CAPABILITY_WALKTHROUGH_TITLE_ID = 1
comptime CAPABILITY_WALKTHROUGH_STEP_ID = 2
comptime CAPABILITY_WALKTHROUGH_BODY_ID = 3
comptime CAPABILITY_WALKTHROUGH_PROGRESS_ID = 4
comptime CAPABILITY_WALKTHROUGH_PREVIOUS_ID = 5
comptime CAPABILITY_WALKTHROUGH_NEXT_ID = 6
comptime CAPABILITY_WALKTHROUGH_RESTART_ID = 7
comptime CAPABILITY_WALKTHROUGH_AGENT_RESET_ID = 8
comptime CAPABILITY_WALKTHROUGH_APPROVE_ID = 9
comptime CAPABILITY_WALKTHROUGH_STATUS_ID = 10
comptime CAPABILITY_WALKTHROUGH_BUS_ID = 11
comptime CAPABILITY_WALKTHROUGH_HINT_ID = 12


def _is_activation(event: Event) -> Bool:
    return event.kind == CLICK_KIND or (
        event.kind == KEY_DOWN_KIND
        and (event.key == KEY_ENTER or event.key == KEY_SPACE)
    ) or (event.kind == ACTION_KIND and event.action_id == ACTION_PRESS)


def _label_style(font_size: Float32, color: Color) -> Style:
    var style = default_label_style()
    style.font_size = font_size
    style.text = color
    return style


struct CapabilityWalkthroughHandler(CapabilityHandler):
    """A typed executor whose descriptor is registered with the walkthrough bus."""

    var name: String
    var description: String
    var side_effect: Int
    var requires_approval: Bool
    var exclusive: Bool

    def __init__(
        out self,
        name: String,
        description: String,
        side_effect: Int = SIDE_EFFECT_LOCAL,
        requires_approval: Bool = False,
        exclusive: Bool = False,
    ):
        self.name = name
        self.description = description
        self.side_effect = side_effect
        self.requires_approval = requires_approval
        self.exclusive = exclusive

    def capability_descriptor(self) -> CapabilityDescriptor:
        return CapabilityDescriptor(
            self.name,
            self.description,
            self.side_effect,
            self.requires_approval,
            self.exclusive,
        )

    def execute_capability(
        mut self,
        invocation: CapabilityInvocation,
    ) -> CapabilityResult:
        return CapabilityResult(
            invocation.request_id,
            CAPABILITY_OK,
            String("Executed ", invocation.capability_name),
        )


struct CapabilityWalkthroughState(Component):
    """A real Moxi Component that makes the capability bus visible."""

    var bus: CapabilityBus
    var next_handler: CapabilityWalkthroughHandler
    var previous_handler: CapabilityWalkthroughHandler
    var restart_handler: CapabilityWalkthroughHandler
    var reset_handler: CapabilityWalkthroughHandler
    var step: Int
    var request_sequence: Int
    var pending_agent_reset_request_id: String
    var status: String

    def __init__(out self):
        self.bus = CapabilityBus()
        self.next_handler = CapabilityWalkthroughHandler(
            "walkthrough.next",
            "Advance the visible walkthrough step",
        )
        self.previous_handler = CapabilityWalkthroughHandler(
            "walkthrough.previous",
            "Move to the previous walkthrough step",
        )
        self.restart_handler = CapabilityWalkthroughHandler(
            "walkthrough.restart",
            "Restart the local walkthrough state",
        )
        self.reset_handler = CapabilityWalkthroughHandler(
            "walkthrough.reset",
            "Reset walkthrough state from an agent request",
            SIDE_EFFECT_DESTRUCTIVE,
            True,
            True,
        )
        self.step = 0
        self.request_sequence = 0
        self.pending_agent_reset_request_id = ""
        self.status = "Ready. Use Next to authorize the first step."
        _ = self.bus.register_handler(self.next_handler)
        _ = self.bus.register_handler(self.previous_handler)
        _ = self.bus.register_handler(self.restart_handler)
        _ = self.bus.register_handler(self.reset_handler)

    def step_title(self) -> String:
        if self.step == 0:
            return "1 · Define the Component boundary"
        if self.step == 1:
            return "2 · Build the view tree"
        if self.step == 2:
            return "3 · Route events through update"
        if self.step == 3:
            return "4 · Register a capability descriptor"
        if self.step == 4:
            return "5 · Authorize the UI mutation"
        if self.step == 5:
            return "6 · Reuse the envelope for agents"
        if self.step == 6:
            return "7 · Require trusted approval"
        if self.step == 7:
            return "8 · Execute through a typed handler"
        if self.step == 8:
            return "9 · Keep replay and queue behavior bounded"
        return "10 · Verify the contract and ship"

    def step_body(self) -> String:
        if self.step == 0:
            return "A Moxi component owns value state and returns a lightweight view. The native window and renderer remain host concerns."
        if self.step == 1:
            return "Implement build(bounds) -> ColumnView. Add labels, controls, or a canvas, configure layout, and return the completed tree."
        if self.step == 2:
            return "App routes a click or key event to update. The component changes its own state, then App rebuilds and reconciles the view."
        if self.step == 3:
            return "CapabilityDescriptor makes the action inspectable: stable name, side-effect class, approval policy, concurrency, and input schema."
        if self.step == 4:
            return "The UI creates a CapabilityInvocation and sends it through authorize. Only after policy accepts it does application code apply the mutation."
        if self.step == 5:
            return "An agent uses the same request envelope with caller, idempotency, and reasoning metadata. It does not receive a mutable reference to component state."
        if self.step == 6:
            return "Destructive or network work cannot use a caller-supplied Boolean as approval. The bus issues a token bound to this exact request."
        if self.step == 7:
            return "Register a CapabilityHandler and call invoke_handler when the application wants a typed executor. Executor-less invoke calls are rejected."
        if self.step == 8:
            return "The bus preserves a bounded FIFO and recent idempotent completions. Queue pressure, replay, and exclusive leases stay observable."
        return "Tests cover descriptors, schemas, approval, leases, handlers, replay, and queue limits. Run pixi run check before recording the final walkthrough."

    def next_request_id(mut self, prefix: String) -> String:
        self.request_sequence += 1
        return String(prefix, "-", self.request_sequence)

    def request(
        mut self,
        capability_name: String,
        caller: Int,
        prefix: String,
    ) -> CapabilityInvocation:
        var invocation = CapabilityInvocation(
            self.next_request_id(prefix),
            capability_name,
            caller,
            "{}",
        )
        invocation.set_ui_context(
            "capability-walkthrough",
            "demo/capability-bus",
        )
        if caller == CALLER_AGENT:
            var request_key = invocation.request_id
            invocation.set_agent_context(
                request_key,
                "advance the recorded Moxi walkthrough",
            )
        return invocation

    def set_result_status(mut self, result: CapabilityResult):
        if result.completed():
            self.status = result.output
        elif result.recovery_hint.count_codepoints() > 0:
            self.status = String("Capability blocked · ", result.recovery_hint)
        else:
            self.status = "Capability did not execute."

    def run_next(mut self) -> Bool:
        var invocation = self.request(
            "walkthrough.next",
            CALLER_UI,
            "next",
        )
        var handler = self.next_handler
        var result = self.bus.invoke_handler(handler, invocation)
        self.set_result_status(result)
        if result.completed() and not result.replayed:
            if self.step < CAPABILITY_WALKTHROUGH_STEP_COUNT - 1:
                self.step += 1
            else:
                self.status = "Walkthrough complete. The bus authorized the final step."
        return True

    def run_previous(mut self) -> Bool:
        var invocation = self.request(
            "walkthrough.previous",
            CALLER_UI,
            "previous",
        )
        var handler = self.previous_handler
        var result = self.bus.invoke_handler(handler, invocation)
        self.set_result_status(result)
        if result.completed() and not result.replayed:
            if self.step > 0:
                self.step -= 1
            else:
                self.status = "Already at the first walkthrough step."
        return True

    def run_restart(mut self) -> Bool:
        var invocation = self.request(
            "walkthrough.restart",
            CALLER_UI,
            "restart",
        )
        var handler = self.restart_handler
        var result = self.bus.invoke_handler(handler, invocation)
        self.set_result_status(result)
        if result.completed() and not result.replayed:
            self.step = 0
            self.pending_agent_reset_request_id = ""
            self.status = "Local restart authorized by the capability bus."
        return True

    def request_agent_reset(mut self) -> Bool:
        var invocation = self.request(
            "walkthrough.reset",
            CALLER_AGENT,
            "agent-reset",
        )
        self.pending_agent_reset_request_id = invocation.request_id
        var handler = self.reset_handler
        var result = self.bus.invoke_handler(handler, invocation)
        if result.status == CAPABILITY_REQUIRES_APPROVAL:
            self.status = "Agent reset is waiting for trusted approval."
        else:
            self.set_result_status(result)
        return True

    def approve_agent_reset(mut self) -> Bool:
        if self.pending_agent_reset_request_id.count_codepoints() == 0:
            self.status = "Request an agent reset before approving it."
            return True
        var invocation = CapabilityInvocation(
            self.pending_agent_reset_request_id,
            "walkthrough.reset",
            CALLER_AGENT,
            "{}",
        )
        invocation.set_ui_context(
            "capability-walkthrough",
            "demo/capability-bus",
        )
        var request_key = invocation.request_id
        invocation.set_agent_context(
            request_key,
            "advance the recorded Moxi walkthrough",
        )
        var approval = self.bus.issue_approval(
            invocation,
            "capability-walkthrough-confirmation",
        )
        invocation.set_approval(approval)
        var handler = self.reset_handler
        var result = self.bus.invoke_handler(handler, invocation)
        self.set_result_status(result)
        if result.completed() and not result.replayed:
            self.step = 0
            self.pending_agent_reset_request_id = ""
            self.status = "Approved agent reset executed through the bus."
        return True

    def build(self, bounds: Rect) -> ColumnView:
        var root = ColumnView(bounds, 20.0, 12.0)
        var panel_width = bounds.width - 40.0
        var panel_height = bounds.height - 40.0
        if panel_width < 0.0:
            panel_width = 0.0
        if panel_height < 0.0:
            panel_height = 0.0
        root.set_surface_style(default_surface_style())
        root.set_panel(
            0,
            Rect(bounds.x + 20.0, bounds.y + 20.0, panel_width, panel_height),
            default_panel_style(),
        )
        root.set_clip_to_bounds()

        root.add_to(
            -1,
            LabelControl(
                CAPABILITY_WALKTHROUGH_TITLE_ID,
                "Moxi · Capability Bus Walkthrough",
                38.0,
                _label_style(30.0, Color(0.93, 0.96, 1.0, 1.0)),
            ).node(),
        )
        root.add_to(
            -1,
            LabelControl(
                CAPABILITY_WALKTHROUGH_STEP_ID,
                self.step_title(),
                34.0,
                _label_style(21.0, Color(0.48, 0.79, 1.0, 1.0)),
            ).node(),
        )
        var body = LabelControl(
            CAPABILITY_WALKTHROUGH_BODY_ID,
            self.step_body(),
            0.0,
            _label_style(16.0, Color(0.68, 0.75, 0.86, 1.0)),
        ).node()
        body.set_wrap_text()
        root.add(body)
        root.set_preferred_width(
            CAPABILITY_WALKTHROUGH_BODY_ID,
            bounds.width - 72.0,
        )
        root.set_intrinsic_height(CAPABILITY_WALKTHROUGH_BODY_ID)
        root.add_progress(
            CAPABILITY_WALKTHROUGH_PROGRESS_ID,
            "Walkthrough progress",
            Float32(self.step + 1) / Float32(CAPABILITY_WALKTHROUGH_STEP_COUNT),
            32.0,
        )

        var actions = root.add_row(
            20,
            0.0,
            44.0,
            8.0,
            8.0,
        )
        root.add_to(
            actions,
            ButtonControl(
                CAPABILITY_WALKTHROUGH_PREVIOUS_ID,
                "Previous",
                40.0,
            ).node(),
        )
        root.add_flexible_spacer_to(actions, 21)
        root.add_to(
            actions,
            ButtonControl(
                CAPABILITY_WALKTHROUGH_RESTART_ID,
                "Restart",
                40.0,
            ).node(),
        )
        root.add_to(
            actions,
            ButtonControl(
                CAPABILITY_WALKTHROUGH_NEXT_ID,
                "Next",
                40.0,
            ).node(),
        )
        root.set_intrinsic_width(CAPABILITY_WALKTHROUGH_PREVIOUS_ID)
        root.set_intrinsic_width(CAPABILITY_WALKTHROUGH_RESTART_ID)
        root.set_intrinsic_width(CAPABILITY_WALKTHROUGH_NEXT_ID)

        var approval_actions = root.add_row(
            30,
            0.0,
            44.0,
            8.0,
            8.0,
        )
        root.add_to(
            approval_actions,
            ButtonControl(
                CAPABILITY_WALKTHROUGH_AGENT_RESET_ID,
                "Request agent reset",
                40.0,
            ).node(),
        )
        root.add_to(
            approval_actions,
            ButtonControl(
                CAPABILITY_WALKTHROUGH_APPROVE_ID,
                "Approve reset",
                40.0,
            ).node(),
        )
        root.set_enabled(
            CAPABILITY_WALKTHROUGH_APPROVE_ID,
            self.pending_agent_reset_request_id.count_codepoints() > 0,
        )
        root.set_intrinsic_width(CAPABILITY_WALKTHROUGH_AGENT_RESET_ID)
        root.set_intrinsic_width(CAPABILITY_WALKTHROUGH_APPROVE_ID)

        root.add_to(
            -1,
            LabelControl(
                CAPABILITY_WALKTHROUGH_STATUS_ID,
                String("Status · ", self.status),
                44.0,
                _label_style(15.0, Color(0.82, 0.92, 1.0, 1.0)),
            ).node(),
        )
        root.add_to(
            -1,
            LabelControl(
                CAPABILITY_WALKTHROUGH_BUS_ID,
                String(
                    "Bus · ",
                    self.bus.descriptor_count(),
                    " registered · ",
                    self.bus.approved_invocations,
                    " approved · ",
                    self.bus.rejected_invocations,
                    " rejected · ",
                    self.bus.pending_count(),
                    "/",
                    self.bus.queue_capacity(),
                    " queued",
                ),
                30.0,
                _label_style(13.0, Color(0.48, 0.57, 0.70, 1.0)),
            ).node(),
        )
        var hint = LabelControl(
            CAPABILITY_WALKTHROUGH_HINT_ID,
            "The buttons below are normal Component events. Their mutations cross the same CapabilityBus boundary used by an agent adapter.",
            0.0,
            _label_style(14.0, Color(0.48, 0.57, 0.70, 1.0)),
        ).node()
        hint.set_wrap_text()
        root.add(hint)
        root.set_preferred_width(
            CAPABILITY_WALKTHROUGH_HINT_ID,
            bounds.width - 72.0,
        )
        root.set_intrinsic_height(CAPABILITY_WALKTHROUGH_HINT_ID)
        root.layout()
        return root^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        if not _is_activation(event):
            return False
        if event.target == CAPABILITY_WALKTHROUGH_PREVIOUS_ID:
            return self.run_previous()
        if event.target == CAPABILITY_WALKTHROUGH_NEXT_ID:
            return self.run_next()
        if event.target == CAPABILITY_WALKTHROUGH_RESTART_ID:
            return self.run_restart()
        if event.target == CAPABILITY_WALKTHROUGH_AGENT_RESET_ID:
            return self.request_agent_reset()
        if event.target == CAPABILITY_WALKTHROUGH_APPROVE_ID:
            return self.approve_agent_reset()
        return False


def capability_walkthrough_step_count() -> Int:
    """Return the number of scripted scenes used by the walkthrough."""
    return CAPABILITY_WALKTHROUGH_STEP_COUNT
