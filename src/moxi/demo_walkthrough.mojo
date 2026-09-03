"""Capability-bus-driven automation for the live Moxi demo browser."""

from std.collections import List

from .accessibility import ACTION_PRESS
from .app_runtime import App
from .capability import (
    CALLER_AGENT,
    CALLER_SYSTEM,
    CALLER_UI,
    CAPABILITY_REQUIRES_APPROVAL,
    CAPABILITY_OK,
    CapabilityBus,
    CapabilityDescriptor,
    CapabilityHandler,
    CapabilityInvocation,
    CapabilityResult,
    SIDE_EFFECT_DESTRUCTIVE,
    SIDE_EFFECT_LOCAL,
)
from .demo_browser import (
    DEMO_COUNTER_ID,
    DEMO_COUNTER_ID_OFFSET,
    DEMO_ENTRY_VIEW_BASE,
    DEMO_INTERACTION_ID,
    DEMO_INTERACTION_ID_OFFSET,
    DEMO_METAL_SCENE_ID,
    DEMO_PLOT_GALLERY_ID,
    DEMO_RESET_BUTTON_ID,
    DEMO_SHOWCASE_ID_OFFSET,
    DEMO_TAB_DEMO_ID,
    DemoBrowserState,
)
from .event import ActionEvent, Event, ScrollEvent
from .geometry import Point
from .interaction_showcase import (
    INTERACTION_SHOWCASE_CANVAS_ID,
    INTERACTION_SHOWCASE_MOVE_ID,
    INTERACTION_SHOWCASE_SELECT_NEXT_ID,
)
from .showcase import (
    SHOWCASE_PLOT_STREAM_ID,
    SHOWCASE_PLOT_TOGGLE_MARKS_ID,
)


comptime DEMO_WALKTHROUGH_EVENT = 0
comptime DEMO_WALKTHROUGH_APPROVAL = 1

comptime DEMO_WALKTHROUGH_SELECT_HANDLER = 0
comptime DEMO_WALKTHROUGH_SHOW_HANDLER = 1
comptime DEMO_WALKTHROUGH_COUNTER_HANDLER = 2
comptime DEMO_WALKTHROUGH_SCROLL_HANDLER = 3
comptime DEMO_WALKTHROUGH_SELECT_NEXT_HANDLER = 4
comptime DEMO_WALKTHROUGH_MOVE_HANDLER = 5
comptime DEMO_WALKTHROUGH_RESET_HANDLER = 6
comptime DEMO_WALKTHROUGH_APPROVE_HANDLER = 7
comptime DEMO_WALKTHROUGH_PLOT_MARKS_HANDLER = 8
comptime DEMO_WALKTHROUGH_PLOT_STREAM_HANDLER = 9


struct DemoWalkthroughAction(ImplicitlyCopyable):
    """One typed, scheduled capability invocation in the recording script."""

    var capability_name: String
    var arguments: String
    var caller: Int
    var handler_index: Int
    var event_kind: Int
    var target: Int
    var scroll_y: Float32
    var hold_seconds: Float32

    def __init__(
        out self,
        capability_name: String = "",
        arguments: String = "{}",
        caller: Int = CALLER_UI,
        handler_index: Int = -1,
        event_kind: Int = DEMO_WALKTHROUGH_EVENT,
        target: Int = -1,
        scroll_y: Float32 = 0.0,
        hold_seconds: Float32 = 0.25,
    ):
        self.capability_name = capability_name
        self.arguments = arguments
        self.caller = caller
        self.handler_index = handler_index
        self.event_kind = event_kind
        self.target = target
        self.scroll_y = scroll_y
        self.hold_seconds = hold_seconds


struct DemoWalkthroughHandler(CapabilityHandler):
    """Typed metadata/executor pair for one recording capability."""

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


struct DemoWalkthroughDriver:
    """Replay real browser/component events through a CapabilityBus."""

    var bus: CapabilityBus
    var select_handler: DemoWalkthroughHandler
    var show_handler: DemoWalkthroughHandler
    var counter_handler: DemoWalkthroughHandler
    var scroll_handler: DemoWalkthroughHandler
    var select_next_handler: DemoWalkthroughHandler
    var move_handler: DemoWalkthroughHandler
    var reset_handler: DemoWalkthroughHandler
    var approve_handler: DemoWalkthroughHandler
    var plot_marks_handler: DemoWalkthroughHandler
    var plot_stream_handler: DemoWalkthroughHandler
    var actions: List[DemoWalkthroughAction]
    var action_index: Int
    var wait_remaining: Float32
    var request_sequence: Int
    var pending_action: DemoWalkthroughAction
    var pending_invocation: CapabilityInvocation
    var has_pending_approval: Bool
    var running: Bool
    var finished: Bool
    var failed: Bool
    var counter_peak: Int
    var max_scroll_offset: Float32
    var observed_selection: Bool
    var observed_reorder: Bool
    var observed_plot: Bool
    var observed_metal: Bool

    def __init__(out self):
        self.bus = CapabilityBus()
        self.select_handler = DemoWalkthroughHandler("", "")
        self.show_handler = DemoWalkthroughHandler("", "")
        self.counter_handler = DemoWalkthroughHandler("", "")
        self.scroll_handler = DemoWalkthroughHandler("", "")
        self.select_next_handler = DemoWalkthroughHandler("", "")
        self.move_handler = DemoWalkthroughHandler("", "")
        self.reset_handler = DemoWalkthroughHandler("", "")
        self.approve_handler = DemoWalkthroughHandler("", "")
        self.plot_marks_handler = DemoWalkthroughHandler("", "")
        self.plot_stream_handler = DemoWalkthroughHandler("", "")
        self.actions = List[DemoWalkthroughAction]()
        self.action_index = 0
        self.wait_remaining = 0.0
        self.request_sequence = 0
        self.pending_action = DemoWalkthroughAction()
        self.pending_invocation = CapabilityInvocation("", "", CALLER_SYSTEM)
        self.has_pending_approval = False
        self.running = False
        self.finished = False
        self.failed = False
        self.counter_peak = 0
        self.max_scroll_offset = 0.0
        self.observed_selection = False
        self.observed_reorder = False
        self.observed_plot = False
        self.observed_metal = False

    def _register_handlers(mut self):
        self.bus = CapabilityBus()
        self.select_handler = DemoWalkthroughHandler(
            "demo.select",
            "Select a live catalog component",
        )
        self.show_handler = DemoWalkthroughHandler(
            "demo.show",
            "Show the selected component's live Demo tab",
        )
        self.counter_handler = DemoWalkthroughHandler(
            "counter.increment",
            "Dispatch the mounted counter increment action",
        )
        self.scroll_handler = DemoWalkthroughHandler(
            "interaction.scroll",
            "Scroll the mounted interaction canvas",
        )
        self.select_next_handler = DemoWalkthroughHandler(
            "interaction.select_next",
            "Select the next stable-key collection row",
        )
        self.move_handler = DemoWalkthroughHandler(
            "interaction.move_selected",
            "Move the selected stable-key collection row",
        )
        self.reset_handler = DemoWalkthroughHandler(
            "demo.reset",
            "Reset the mounted live component",
            SIDE_EFFECT_DESTRUCTIVE,
            True,
            True,
        )
        self.approve_handler = DemoWalkthroughHandler(
            "approve",
            "Issue trusted approval for one pending demo request",
        )
        self.plot_marks_handler = DemoWalkthroughHandler(
            "plot.toggle_marks",
            "Toggle the live plot marks through its component action",
        )
        self.plot_stream_handler = DemoWalkthroughHandler(
            "plot.stream",
            "Toggle live plot data streaming through its component action",
        )
        _ = self.bus.register_handler(self.select_handler)
        _ = self.bus.register_handler(self.show_handler)
        _ = self.bus.register_handler(self.counter_handler)
        _ = self.bus.register_handler(self.scroll_handler)
        _ = self.bus.register_handler(self.select_next_handler)
        _ = self.bus.register_handler(self.move_handler)
        _ = self.bus.register_handler(self.reset_handler)
        _ = self.bus.register_handler(self.approve_handler)
        _ = self.bus.register_handler(self.plot_marks_handler)
        _ = self.bus.register_handler(self.plot_stream_handler)

    def _append_action(
        mut self,
        capability_name: String,
        arguments: String,
        caller: Int,
        handler_index: Int,
        target: Int,
        hold_seconds: Float32,
    ):
        self.actions.append(
            DemoWalkthroughAction(
                capability_name,
                arguments,
                caller,
                handler_index,
                DEMO_WALKTHROUGH_EVENT,
                target,
                0.0,
                hold_seconds,
            )
        )

    def _append_scroll(mut self, delta_y: Float32, hold_seconds: Float32):
        self.actions.append(
            DemoWalkthroughAction(
                "interaction.scroll",
                String("{\"dy\":", delta_y, "}"),
                CALLER_UI,
                DEMO_WALKTHROUGH_SCROLL_HANDLER,
                DEMO_WALKTHROUGH_EVENT,
                -1,
                delta_y,
                hold_seconds,
            )
        )

    def _append_approval(mut self, hold_seconds: Float32):
        self.actions.append(
            DemoWalkthroughAction(
                "approve",
                "{\"source\":\"trusted-ui\"}",
                CALLER_UI,
                DEMO_WALKTHROUGH_APPROVE_HANDLER,
                DEMO_WALKTHROUGH_APPROVAL,
                -1,
                0.0,
                hold_seconds,
            )
        )

    def _build_actions(mut self):
        self.actions = List[DemoWalkthroughAction]()

        # Hold the normal workbench long enough to establish the one-window
        # browser before the first bus traversal begins.
        self._append_action(
            "demo.select",
            "{\"demo\":\"counter\"}",
            CALLER_UI,
            DEMO_WALKTHROUGH_SELECT_HANDLER,
            DEMO_ENTRY_VIEW_BASE + DEMO_COUNTER_ID,
            0.80,
        )
        self._append_action(
            "demo.show",
            "{\"tab\":\"demo\"}",
            CALLER_UI,
            DEMO_WALKTHROUGH_SHOW_HANDLER,
            DEMO_TAB_DEMO_ID,
            1.10,
        )
        self._append_action(
            "counter.increment",
            "{\"step\":1}",
            CALLER_UI,
            DEMO_WALKTHROUGH_COUNTER_HANDLER,
            DEMO_COUNTER_ID_OFFSET + 3,
            0.90,
        )
        self._append_action(
            "counter.increment",
            "{\"step\":2}",
            CALLER_UI,
            DEMO_WALKTHROUGH_COUNTER_HANDLER,
            DEMO_COUNTER_ID_OFFSET + 3,
            0.90,
        )
        self._append_action(
            "counter.increment",
            "{\"step\":3}",
            CALLER_UI,
            DEMO_WALKTHROUGH_COUNTER_HANDLER,
            DEMO_COUNTER_ID_OFFSET + 3,
            2.30,
        )

        # Keep the plot and GPU examples embedded in the same browser host.
        self._append_action(
            "demo.select",
            "{\"demo\":\"plot-gallery\"}",
            CALLER_UI,
            DEMO_WALKTHROUGH_SELECT_HANDLER,
            DEMO_ENTRY_VIEW_BASE + DEMO_PLOT_GALLERY_ID,
            0.90,
        )
        self._append_action(
            "demo.show",
            "{\"tab\":\"demo\"}",
            CALLER_UI,
            DEMO_WALKTHROUGH_SHOW_HANDLER,
            DEMO_TAB_DEMO_ID,
            1.20,
        )
        self._append_action(
            "plot.toggle_marks",
            "{\"marks\":\"toggle\"}",
            CALLER_UI,
            DEMO_WALKTHROUGH_PLOT_MARKS_HANDLER,
            DEMO_SHOWCASE_ID_OFFSET + SHOWCASE_PLOT_TOGGLE_MARKS_ID,
            1.20,
        )
        self._append_action(
            "plot.stream",
            "{\"streaming\":true}",
            CALLER_UI,
            DEMO_WALKTHROUGH_PLOT_STREAM_HANDLER,
            DEMO_SHOWCASE_ID_OFFSET + SHOWCASE_PLOT_STREAM_ID,
            2.50,
        )
        self._append_action(
            "demo.select",
            "{\"demo\":\"metal-scene\"}",
            CALLER_UI,
            DEMO_WALKTHROUGH_SELECT_HANDLER,
            DEMO_ENTRY_VIEW_BASE + DEMO_METAL_SCENE_ID,
            0.90,
        )
        self._append_action(
            "demo.show",
            "{\"tab\":\"demo\"}",
            CALLER_UI,
            DEMO_WALKTHROUGH_SHOW_HANDLER,
            DEMO_TAB_DEMO_ID,
            2.50,
        )

        self._append_action(
            "demo.select",
            "{\"demo\":\"interaction\"}",
            CALLER_UI,
            DEMO_WALKTHROUGH_SELECT_HANDLER,
            DEMO_ENTRY_VIEW_BASE + DEMO_INTERACTION_ID,
            0.90,
        )
        self._append_action(
            "demo.show",
            "{\"tab\":\"demo\"}",
            CALLER_UI,
            DEMO_WALKTHROUGH_SHOW_HANDLER,
            DEMO_TAB_DEMO_ID,
            1.10,
        )
        # Two bounded increments make both scroll transitions visible without
        # asking the viewport to move past its clamped maximum.
        self._append_scroll(64.0, 1.30)
        self._append_action(
            "interaction.select_next",
            "{\"selection\":\"next\"}",
            CALLER_UI,
            DEMO_WALKTHROUGH_SELECT_NEXT_HANDLER,
            DEMO_INTERACTION_ID_OFFSET + INTERACTION_SHOWCASE_SELECT_NEXT_ID,
            1.10,
        )
        self._append_action(
            "interaction.move_selected",
            "{\"destination\":\"computed\"}",
            CALLER_UI,
            DEMO_WALKTHROUGH_MOVE_HANDLER,
            DEMO_INTERACTION_ID_OFFSET + INTERACTION_SHOWCASE_MOVE_ID,
            1.30,
        )
        self._append_scroll(64.0, 1.30)

        self._append_action(
            "demo.reset",
            "{\"demo\":\"interaction\",\"caller\":\"agent\"}",
            CALLER_AGENT,
            DEMO_WALKTHROUGH_RESET_HANDLER,
            DEMO_RESET_BUTTON_ID,
            1.00,
        )
        self._append_approval(1.30)

    def start(mut self):
        """Reset and start the deterministic live-component replay."""
        self._register_handlers()
        self._build_actions()
        self.action_index = 0
        self.wait_remaining = 3.50
        self.request_sequence = 0
        self.pending_action = DemoWalkthroughAction()
        self.pending_invocation = CapabilityInvocation("", "", CALLER_SYSTEM)
        self.has_pending_approval = False
        self.running = True
        self.finished = False
        self.failed = False
        self.counter_peak = 0
        self.max_scroll_offset = 0.0
        self.observed_selection = False
        self.observed_reorder = False
        self.observed_plot = False
        self.observed_metal = False

    def _next_request(mut self) -> String:
        self.request_sequence += 1
        return String("demo-walkthrough-", self.request_sequence)

    def _invocation(
        mut self,
        action: DemoWalkthroughAction,
    ) -> CapabilityInvocation:
        var invocation = CapabilityInvocation(
            self._next_request(),
            action.capability_name,
            action.caller,
            action.arguments,
        )
        invocation.set_ui_context("demo-walkthrough-driver", "demo/live")
        if action.caller == CALLER_AGENT:
            var request_key = invocation.request_id
            invocation.set_agent_context(
                request_key,
                String("show live component action ", action.capability_name),
            )
        return invocation

    def _invoke(
        mut self,
        handler_index: Int,
        invocation: CapabilityInvocation,
    ) -> CapabilityResult:
        if handler_index == DEMO_WALKTHROUGH_SELECT_HANDLER:
            var handler = self.select_handler
            return self.bus.invoke_handler(handler, invocation)
        if handler_index == DEMO_WALKTHROUGH_SHOW_HANDLER:
            var handler = self.show_handler
            return self.bus.invoke_handler(handler, invocation)
        if handler_index == DEMO_WALKTHROUGH_COUNTER_HANDLER:
            var handler = self.counter_handler
            return self.bus.invoke_handler(handler, invocation)
        if handler_index == DEMO_WALKTHROUGH_SCROLL_HANDLER:
            var handler = self.scroll_handler
            return self.bus.invoke_handler(handler, invocation)
        if handler_index == DEMO_WALKTHROUGH_SELECT_NEXT_HANDLER:
            var handler = self.select_next_handler
            return self.bus.invoke_handler(handler, invocation)
        if handler_index == DEMO_WALKTHROUGH_MOVE_HANDLER:
            var handler = self.move_handler
            return self.bus.invoke_handler(handler, invocation)
        if handler_index == DEMO_WALKTHROUGH_RESET_HANDLER:
            var handler = self.reset_handler
            return self.bus.invoke_handler(handler, invocation)
        if handler_index == DEMO_WALKTHROUGH_PLOT_MARKS_HANDLER:
            var handler = self.plot_marks_handler
            return self.bus.invoke_handler(handler, invocation)
        if handler_index == DEMO_WALKTHROUGH_PLOT_STREAM_HANDLER:
            var handler = self.plot_stream_handler
            return self.bus.invoke_handler(handler, invocation)
        var handler = self.approve_handler
        return self.bus.invoke_handler(handler, invocation)

    def _publish(
        mut self,
        mut app: App[DemoBrowserState],
        message: String,
    ) -> Bool:
        app.component.status = message
        app.rebuild()
        return True

    def _publish_result(
        mut self,
        mut app: App[DemoBrowserState],
        action: DemoWalkthroughAction,
        result: CapabilityResult,
        suffix: String = "",
    ) -> Bool:
        var state = "blocked"
        if result.completed():
            state = "executed"
        elif result.status == CAPABILITY_REQUIRES_APPROVAL:
            state = "approval required"
        var message = String(
            "CapabilityBus · ",
            action.capability_name,
            " · ",
            state,
            " · ",
            self.bus.approved_invocations,
            " approved · ",
            self.bus.rejected_invocations,
            " rejected",
        )
        if suffix.count_codepoints() > 0:
            message += String(" · ", suffix)
        return self._publish(app, message)

    def _dispatch_action(
        mut self,
        mut app: App[DemoBrowserState],
        action: DemoWalkthroughAction,
    ) -> Bool:
        var event = Event(ActionEvent(ACTION_PRESS))
        event.set_target(action.target)
        return app.dispatch(event)

    def _dispatch_scroll(
        mut self,
        mut app: App[DemoBrowserState],
        action: DemoWalkthroughAction,
    ) -> Bool:
        var canvas = app.view.bounds_for(
            DEMO_INTERACTION_ID_OFFSET + INTERACTION_SHOWCASE_CANVAS_ID
        )
        var position = Point(
            canvas.x + canvas.width * 0.5,
            canvas.y + canvas.height * 0.5,
        )
        return app.dispatch(
            Event(ScrollEvent(position, Point(0.0, action.scroll_y)))
        )

    def _record_observations(
        mut self,
        app: App[DemoBrowserState],
        action: DemoWalkthroughAction,
    ):
        if action.capability_name == "demo.select":
            if app.component.selected_id == DEMO_PLOT_GALLERY_ID:
                self.observed_plot = True
            elif app.component.selected_id == DEMO_METAL_SCENE_ID:
                self.observed_metal = True
        elif action.capability_name == "counter.increment":
            if app.component.counter.component.count > self.counter_peak:
                self.counter_peak = app.component.counter.component.count
        elif action.capability_name == "plot.toggle_marks":
            self.observed_plot = (
                self.observed_plot
                and not app.component.showcase.component.plot_points_visible
            )
        elif action.capability_name == "plot.stream":
            self.observed_plot = (
                self.observed_plot
                and app.component.showcase.component.plot_streaming
            )
        elif action.capability_name == "interaction.scroll":
            var offset = app.component.interaction.component.scrollbar.offset
            if offset > self.max_scroll_offset:
                self.max_scroll_offset = offset
        elif action.capability_name == "interaction.select_next":
            self.observed_selection = (
                app.component.interaction.component.collection.focus_index() == 2
            )
        elif action.capability_name == "interaction.move_selected":
            self.observed_reorder = (
                app.component.interaction.component.collection.key_at(4) == 114
            )

    def _run_approval(
        mut self,
        mut app: App[DemoBrowserState],
        action: DemoWalkthroughAction,
    ) -> Bool:
        if not self.has_pending_approval:
            self.failed = True
            self.running = False
            return self._publish(app, "CapabilityBus · approval requested without a pending request")

        var approval_request = self._invocation(action)
        var approval_result = self._invoke(
            DEMO_WALKTHROUGH_APPROVE_HANDLER,
            approval_request,
        )
        if not approval_result.completed():
            self.failed = True
            self.running = False
            return self._publish_result(app, action, approval_result)

        var approval = self.bus.issue_approval(
            self.pending_invocation,
            "demo-walkthrough-trusted-ui",
        )
        var retry_invocation = self.pending_invocation
        retry_invocation.set_approval(approval)
        self.pending_invocation = retry_invocation
        var reset_result = self._invoke(
            DEMO_WALKTHROUGH_RESET_HANDLER,
            retry_invocation,
        )
        if not reset_result.completed():
            self.failed = True
            self.running = False
            return self._publish_result(app, action, reset_result)

        var reset_action = self.pending_action
        var changed = self._dispatch_action(app, reset_action)
        self.has_pending_approval = False
        if not changed:
            self.failed = True
            self.running = False
            return self._publish(
                app,
                "CapabilityBus · approved reset did not update the live component",
            )
        return self._publish(
            app,
            String(
                "CapabilityBus · demo.reset · approved and executed · ",
                self.bus.approved_invocations,
                " approved · ",
                self.bus.rejected_invocations,
                " rejected",
            ),
        )

    def _run_action(
        mut self,
        mut app: App[DemoBrowserState],
        action: DemoWalkthroughAction,
    ) -> Bool:
        if action.event_kind == DEMO_WALKTHROUGH_APPROVAL:
            return self._run_approval(app, action)

        var invocation = self._invocation(action)
        var result = self._invoke(action.handler_index, invocation)
        if result.status == CAPABILITY_REQUIRES_APPROVAL:
            self.pending_action = action
            self.pending_invocation = invocation
            self.has_pending_approval = True
            return self._publish_result(app, action, result, "waiting for trusted approval")
        if not result.completed():
            self.failed = True
            self.running = False
            return self._publish_result(app, action, result)

        var changed = (
            self._dispatch_scroll(app, action)
            if action.capability_name == "interaction.scroll"
            else self._dispatch_action(app, action)
        )
        if not changed:
            self.failed = True
            self.running = False
            return self._publish(
                app,
                String(
                    "CapabilityBus · ",
                    action.capability_name,
                    " authorized but produced no visible update",
                ),
            )
        self._record_observations(app, action)
        return self._publish_result(app, action, result, "live Component updated")

    def tick(
        mut self,
        mut app: App[DemoBrowserState],
        delta_seconds: Float32,
    ) -> Bool:
        """Advance at most one scripted capability action per frame."""
        if not self.running:
            return False
        self.wait_remaining -= delta_seconds
        if self.wait_remaining > 0.0:
            return False
        if self.action_index >= len(self.actions):
            self.running = False
            self.finished = not self.failed
            return False

        var action = self.actions[self.action_index]
        var changed = self._run_action(app, action)
        self.action_index += 1
        self.wait_remaining = action.hold_seconds
        if self.action_index >= len(self.actions) and not self.failed:
            self.running = False
            self.finished = True
        return changed

    def is_running(self) -> Bool:
        return self.running

    def is_finished(self) -> Bool:
        return self.finished

    def action_count(self) -> Int:
        return len(self.actions)

    def current_action_index(self) -> Int:
        return self.action_index
