"""Shared wxPython-style teaching scenario used by the demo and tests."""

from .component import Component, ComponentSlot
from .accessibility import ACTION_INCREMENT, ACTION_DECREMENT
from .accessibility import ACTION_COLLAPSE, ACTION_EXPAND, ACTION_PRESS, ACTION_SELECT
from .control_state import (
    CanvasState,
    ComboBoxState,
    DialogState,
    ListState,
    MenuState,
    TableState,
    TabsState,
    TreeState,
)
from .app import CounterState
from .conversation import ConversationContext
from .backend import BACKEND_MACOS_APPKIT, backend_capabilities
from .capability import (
    CALLER_AGENT,
    CALLER_UI,
    CAPABILITY_INVALID,
    CAPABILITY_REQUIRES_APPROVAL,
    CapabilityBus,
    CapabilityDescriptor,
    CapabilityInvocation,
    CapabilityResult,
    SIDE_EFFECT_DESTRUCTIVE,
    SIDE_EFFECT_LOCAL,
)
from .controls import (
    ButtonControl,
    CheckboxControl,
    LabelControl,
    ProgressControl,
    SliderState,
    ToggleState,
    RadioGroupState,
    TextInputControl,
    TextInputState,
)
from .event import (
    CLICK_KIND,
    ACTION_KIND,
    COMPOSITION_END_KIND,
    COMPOSITION_UPDATE_KIND,
    Event,
    KEY_DOWN_KIND,
    KEY_ENTER,
    KEY_SPACE,
    TEXT_INPUT_KIND,
    SCROLL_KIND,
    DRAG_BEGIN_KIND,
    DRAG_UPDATE_KIND,
    DROP_KIND,
)
from .geometry import Rect
from .layout import ALIGN_STRETCH, JUSTIFY_START
from .style import default_panel_style, default_surface_style
from .style import default_label_style
from .text_layout import RichText, TextSpan, layout_rich_text
from .view import ColumnView


comptime WX_PANEL_ID = 100
comptime WX_HEADER_ID = 101
comptime WX_TITLE_ID = 102
comptime WX_SUBTITLE_ID = 103
comptime WX_BODY_ID = 104
comptime WX_NAME_LABEL_ID = 105
comptime WX_NAME_FIELD_ID = 106
comptime WX_STATUS_ID = 107
comptime WX_ACTIONS_ID = 108
comptime WX_SPACER_ID = 109
comptime WX_OK_BUTTON_ID = 110
comptime WX_CANCEL_BUTTON_ID = 111
comptime WX_HELP_ID = 112
comptime WX_CAPABILITIES_ID = 113
comptime WX_REMEMBER_ID = 114
comptime WX_PROGRESS_ID = 115
comptime WX_RESET_BUTTON_ID = 116
comptime WX_BACKEND_ID = 117
comptime WX_LAYOUT_ID = 118
comptime WX_CAPABILITY_STATUS_ID = 119
comptime WX_RICH_TEXT_ID = 120
comptime WX_CONTEXT_ID = 121
comptime WX_COMPONENT_SLOT_ID = 122
comptime WX_AGENT_RESET_BUTTON_ID = 123
comptime WX_APPROVE_RESET_ID = 124
comptime WX_APPROVAL_STATUS_ID = 125
comptime WX_ADVANCED_ID = 126
comptime WX_SLIDER_ID = 127
comptime WX_SWITCH_ID = 128
comptime WX_RADIO_ID = 129
comptime WX_IMAGE_ID = 130
comptime WX_MULTILINE_ID = 131
comptime WX_COMBO_ID = 132
comptime WX_LIST_ID = 133
comptime WX_TABLE_ID = 134
comptime WX_TREE_ID = 135
comptime WX_MENU_ID = 136
comptime WX_DIALOG_ID = 137
comptime WX_TABS_ID = 138
comptime WX_CANVAS_ID = 139
comptime WX_SEPARATOR_ID = 140
comptime WX_COUNTER_ID_OFFSET = 1000
comptime WX_SUBMIT_ACTION = 200
comptime WX_CANCEL_ACTION = 201
comptime WX_REMEMBER_ACTION = 202
comptime WX_RESET_ACTION = 203
comptime WX_AGENT_RESET_ACTION = 204
comptime WX_APPROVE_RESET_ACTION = 205


struct WxStyleState(Component):
    """A small wxPython-shaped app built from Moxi's current primitives.

    The ids intentionally make the usual wx vocabulary visible in one file:
    the window is the frame, the root panel owns box sizers, and the leaves
    are static text, a text control, and buttons with event handlers.
    """

    var input: TextInputState
    var status: String
    var submissions: Int
    var cancellations: Int
    var remember_name: Bool
    var capabilities: CapabilityBus
    var counter: ComponentSlot[CounterState]
    var request_sequence: Int
    var pending_agent_reset_request_id: String
    var slider: SliderState
    var notifications: ToggleState
    var radio: RadioGroupState
    var combo: ComboBoxState
    var list: ListState
    var table: TableState
    var tree: TreeState
    var menu: MenuState
    var dialog: DialogState
    var tabs: TabsState
    var canvas: CanvasState

    def __init__(out self):
        self.input = TextInputState()
        self.status = "Ready. Type a name."
        self.submissions = 0
        self.cancellations = 0
        self.remember_name = True
        self.capabilities = CapabilityBus()
        self.request_sequence = 0
        self.pending_agent_reset_request_id = ""
        self.slider = SliderState(0.5, 0.0, 1.0, 0.1)
        self.notifications = ToggleState(True)
        self.radio = RadioGroupState(1, WX_RADIO_ID)
        self.combo = ComboBoxState(3, 0)
        self.list = ListState(3, 0)
        self.table = TableState(4, 2)
        self.tree = TreeState(3, True)
        self.menu = MenuState(2)
        self.dialog = DialogState(True)
        self.tabs = TabsState(3, 0)
        self.canvas = CanvasState()
        _ = self.capabilities.register(
            CapabilityDescriptor(
                "wx.submit",
                "Submit the name form",
                SIDE_EFFECT_LOCAL,
                False,
                True,
            )
        )
        self.counter = ComponentSlot(
            CounterState(),
            WX_COMPONENT_SLOT_ID,
            WX_COUNTER_ID_OFFSET,
        )
        _ = self.capabilities.register(
            CapabilityDescriptor(
                "wx.cancel",
                "Clear the name form",
                SIDE_EFFECT_LOCAL,
                False,
                True,
            )
        )
        _ = self.capabilities.register(
            CapabilityDescriptor(
                "wx.reset",
                "Reset the complete demo state",
                SIDE_EFFECT_DESTRUCTIVE,
                True,
                True,
            )
        )
        _ = self.capabilities.register(
            CapabilityDescriptor(
                "wx.remember",
                "Toggle the remember-name preference",
                SIDE_EFFECT_LOCAL,
                False,
                False,
            )
        )

    def build(self, bounds: Rect) -> ColumnView:
        """Build the complete wx-style teaching surface from shared controls."""
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

        # Frame -> Panel -> vertical BoxSizer.
        # Keep the fixed-height teaching surface inside the 800 px panel.
        # The native backend renders labels with real font metrics, so the
        # headless preferred heights must leave explicit room for wrapping.
        var panel = root.add_column(WX_PANEL_ID, panel_height, 12.0, 6.0)
        root.set_accessibility_label(panel, "Panel")
        root.set_clip_children(panel)

        # A wx.StaticText-style header.
        var header = root.add_column_to(panel, WX_HEADER_ID, 60.0, 0.0, 4.0)

        var title = LabelControl(WX_TITLE_ID, "wxPython-style Moxi", 32.0)
        root.add_to(header, title.node())
        var subtitle = LabelControl(
            WX_SUBTITLE_ID,
            "Frame -> Panel -> BoxSizer -> controls",
            24.0,
        )
        root.add_to(header, subtitle.node())
        root.set_accessibility_label(header, "Header")

        # A second vertical BoxSizer containing StaticText, TextCtrl, a
        # checkbox, a determinate gauge, and status.
        var body = root.add_column_to(panel, WX_BODY_ID, 200.0, 8.0, 8.0)
        root.add_label_to(body, WX_NAME_LABEL_ID, "Your name", 24.0)
        var input = TextInputControl(
            WX_NAME_FIELD_ID,
            self.input.text,
            self.input.cursor,
            self.input.anchor,
            40.0,
        )
        input.set_composition(
            self.input.composition,
            self.input.composition_selection_start,
            self.input.composition_selection_end,
        )
        root.add_to(body, input.node())
        root.set_accessibility_label(WX_NAME_FIELD_ID, "Name")
        root.set_accessibility_hint(WX_NAME_FIELD_ID, "Type a name, then choose OK")
        root.set_accessibility_value(WX_NAME_FIELD_ID, self.input.text)
        root.add_label_to(body, WX_STATUS_ID, self.status, 28.0)
        root.set_accessibility_label(WX_STATUS_ID, "Status")
        root.set_accessibility_value(WX_STATUS_ID, self.status)
        var remember = CheckboxControl(
            WX_REMEMBER_ID,
            "Remember this name",
            self.remember_name,
            28.0,
        )
        root.add_to(body, remember.node())
        root.set_action(WX_REMEMBER_ID, WX_REMEMBER_ACTION)
        root.set_accessibility_label(WX_REMEMBER_ID, "Remember name")
        root.set_accessibility_hint(
            WX_REMEMBER_ID,
            "Toggle whether the demo keeps the entered name",
        )
        var interactions = self.submissions + self.cancellations
        var progress: Float32 = Float32(interactions) / 4.0
        var gauge = ProgressControl(
            WX_PROGRESS_ID,
            "Activity",
            progress,
            24.0,
        )
        root.add_to(body, gauge.node())
        root.set_accessibility_label(WX_PROGRESS_ID, "Activity progress")
        root.set_container_alignment(body, JUSTIFY_START, ALIGN_STRETCH)

        # Capability and backend status are visible in the same scenario so
        # the demo exercises the platform-neutral contracts, too.
        var details = root.add_column_to(panel, WX_CAPABILITIES_ID, 184.0, 8.0, 4.0)
        var detail_style = default_label_style()
        detail_style.font_size = 16.0
        var backend = backend_capabilities(BACKEND_MACOS_APPKIT)
        var backend_text = String("Backend: ")
        backend_text += backend.name
        var backend_label = LabelControl(
            WX_BACKEND_ID,
            backend_text,
            20.0,
            detail_style,
        )
        root.add_to(details, backend_label.node())
        var layout_label = LabelControl(
            WX_LAYOUT_ID,
            "Text layout: AppKit shaping + bidi",
            24.0,
            detail_style,
        )
        root.add_to(details, layout_label.node())
        var capability_text = String(
            "Capability bus: ",
            self.capabilities.descriptor_count(),
        )
        capability_text += " registered / "
        capability_text += String(self.capabilities.approved_invocations)
        capability_text += " approved / "
        capability_text += String(self.capabilities.rejected_invocations)
        capability_text += " rejected"
        var capability_label = LabelControl(
            WX_CAPABILITY_STATUS_ID,
            capability_text,
            24.0,
            detail_style,
        )
        root.add_to(details, capability_label.node())
        var rich_document = RichText()
        var rich_style = default_label_style()
        rich_document.append(TextSpan("Rich ", rich_style))
        rich_document.append(TextSpan("text spans", rich_style))
        var rich_text = String("Rich text: ")
        rich_text += rich_document.flattened()
        var rich_layout = layout_rich_text(rich_document, panel_width - 8.0)
        if rich_layout.fallback_used:
            rich_text += " (portable fallback)"
        var rich_label = LabelControl(
            WX_RICH_TEXT_ID,
            rich_text,
            24.0,
            detail_style,
        )
        root.add_to(details, rich_label.node())
        var context = ConversationContext()
        context.append_turn("assistant", "Ready for the next tool call")
        var context_payload = context.turn_payload("capabilities:4")
        var context_text = String("Agent context: ")
        context_text += String(context.count())
        context_text += " history + fresh state"
        if context_payload.count_codepoints() == 0:
            context_text = "Agent context unavailable"
        var context_label = LabelControl(
            WX_CONTEXT_ID,
            context_text,
            24.0,
            detail_style,
        )
        root.add_to(details, context_label.node())
        var approval_text = "Agent approval: idle"
        if self.pending_agent_reset_request_id.count_codepoints() > 0:
            approval_text = "Agent approval: pending"
        var approval_label = LabelControl(
            WX_APPROVAL_STATUS_ID,
            approval_text,
            28.0,
            detail_style,
        )
        var approval_node = approval_label.node()
        approval_node.set_wrap_text()
        root.add_to(details, approval_node)
        root.set_accessibility_label(WX_APPROVAL_STATUS_ID, "Agent approval status")
        root.set_accessibility_value(WX_APPROVAL_STATUS_ID, approval_text)
        root.set_accessibility_label(details, "Runtime capabilities")

        # A horizontal BoxSizer with a flexible spacer and three wx.Button-style controls.
        var actions = root.add_row_to(panel, WX_ACTIONS_ID, 0.0, 52.0, 8.0, 8.0)
        root.add_flexible_spacer_to(actions, WX_SPACER_ID)
        var ok = ButtonControl(WX_OK_BUTTON_ID, "OK", 32.0)
        root.add_to(actions, ok.node())
        var cancel = ButtonControl(WX_CANCEL_BUTTON_ID, "Cancel", 32.0)
        root.add_to(actions, cancel.node())
        var reset = ButtonControl(WX_RESET_BUTTON_ID, "Reset", 32.0)
        root.add_to(actions, reset.node())
        root.set_action(WX_OK_BUTTON_ID, WX_SUBMIT_ACTION)
        root.set_action(WX_CANCEL_BUTTON_ID, WX_CANCEL_ACTION)
        root.set_action(WX_RESET_BUTTON_ID, WX_RESET_ACTION)
        var agent_reset = ButtonControl(WX_AGENT_RESET_BUTTON_ID, "Agent reset", 32.0)
        root.add_to(actions, agent_reset.node())
        root.set_action(WX_AGENT_RESET_BUTTON_ID, WX_AGENT_RESET_ACTION)
        root.set_intrinsic_width(WX_AGENT_RESET_BUTTON_ID)
        var approve_reset = ButtonControl(WX_APPROVE_RESET_ID, "Approve reset", 32.0)
        root.add_to(actions, approve_reset.node())
        root.set_action(WX_APPROVE_RESET_ID, WX_APPROVE_RESET_ACTION)
        root.set_enabled(
            WX_APPROVE_RESET_ID,
            self.pending_agent_reset_request_id.count_codepoints() > 0,
        )
        root.set_intrinsic_width(WX_APPROVE_RESET_ID)
        root.set_intrinsic_width(WX_OK_BUTTON_ID)
        root.set_intrinsic_width(WX_CANCEL_BUTTON_ID)
        root.set_intrinsic_width(WX_RESET_BUTTON_ID)

        var help_style = default_label_style()
        help_style.font_size = 16.0
        var help = LabelControl(
            WX_HELP_ID,
            "Flow: click -> route -> action -> authorize -> update -> rebuild.\nThe same request envelope can be used by an agent adapter.",
            64.0,
            help_style,
        )
        var help_node = help.node()
        help_node.set_wrap_text()
        root.add_to(panel, help_node)
        root.set_accessibility_label(WX_HELP_ID, "Event flow explanation")

        # A real typed child component proves that the wx-shaped screen can
        # compose reusable stateful components, not only leaf descriptors.
        var child_view = self.counter.build(
            Rect(bounds.x, bounds.y, panel_width, 184.0)
        )
        root.add_component_view_to(
            panel,
            WX_COMPONENT_SLOT_ID,
            child_view,
            WX_COUNTER_ID_OFFSET,
            184.0,
        )
        root.set_accessibility_label(WX_COMPONENT_SLOT_ID, "Embedded counter component")

        # The advanced section is a small wx-style lesson for the remaining
        # framework primitives. It is intentionally a portal: the section is
        # taller than its viewport so wheel input exercises clipping,
        # persistent scroll state, and virtual-list-ready composition.
        var advanced = root.add_portal_to(
            panel,
            WX_ADVANCED_ID,
            248.0,
            8.0,
            6.0,
            0.0,
        )
        root.set_accessibility_label(advanced, "Advanced controls showcase")
        root.add_label_to(advanced, WX_LAYOUT_ID + 100, "Advanced controls", 24.0)
        root.add_slider_to(
            advanced,
            WX_SLIDER_ID,
            "Volume",
            self.slider.normalized(),
            28.0,
        )
        root.add_switch_to(
            advanced,
            WX_SWITCH_ID,
            "Notifications",
            self.notifications.checked,
            28.0,
        )
        root.add_radio_to(
            advanced,
            WX_RADIO_ID,
            "Automatic mode",
            self.radio.is_selected(WX_RADIO_ID),
            28.0,
        )
        root.add_image_to(advanced, WX_IMAGE_ID, "Moxi image resource", 1, 72.0)
        root.add_multiline_text_to(
            advanced,
            WX_MULTILINE_ID,
            "A multiline editor placeholder with native wrapping.",
            64.0,
        )
        var combo_text = String("Theme option ", self.combo.selection.selected_index)
        if self.combo.expanded:
            combo_text += " (open)"
        root.add_combo_box_to(advanced, WX_COMBO_ID, combo_text, 32.0)
        root.add_list_to(
            advanced,
            WX_LIST_ID,
            String("List selection ", self.list.selection.selected_index),
            72.0,
        )
        root.add_table_to(
            advanced,
            WX_TABLE_ID,
            String(
                "Table cell ",
                self.table.selected_row,
                ",",
                self.table.selected_column,
            ),
            72.0,
        )
        var tree_text = "Tree: collapsed outline"
        if self.tree.expanded:
            tree_text = "Tree: expanded outline"
        root.add_tree_to(advanced, WX_TREE_ID, tree_text, 72.0)
        var menu_text = "Menu: closed"
        if self.menu.open:
            menu_text = "Menu: open"
        root.add_menu_to(advanced, WX_MENU_ID, menu_text, 32.0)
        var dialog_text = "Dialog: closed"
        if self.dialog.open:
            dialog_text = "Dialog: confirmation"
        root.add_dialog_to(advanced, WX_DIALOG_ID, dialog_text, 72.0)
        root.set_enabled(WX_DIALOG_ID, self.dialog.open)
        root.add_tabs_to(
            advanced,
            WX_TABS_ID,
            String("Tabs: selected ", self.tabs.selection.selected_index),
            32.0,
        )
        root.add_canvas_to(
            advanced,
            WX_CANVAS_ID,
            String("Canvas: ", self.canvas.pointer.x, ",", self.canvas.pointer.y),
            72.0,
        )
        root.add_separator_to(advanced, WX_SEPARATOR_ID)

        root.set_container_alignment(panel, JUSTIFY_START, ALIGN_STRETCH)
        root.set_container_alignment(header, JUSTIFY_START, ALIGN_STRETCH)
        root.set_container_alignment(details, JUSTIFY_START, ALIGN_STRETCH)
        root.set_container_alignment(actions, JUSTIFY_START, ALIGN_STRETCH)
        root.layout()
        return root^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        """Handle wx-style control events through Moxi's routed event contract."""
        if self.counter.contains(event.target, view):
            return self.counter.route(event, view)

        if event.target == WX_SLIDER_ID:
            if event.kind == ACTION_KIND:
                if event.action_id == ACTION_INCREMENT:
                    return self.slider.nudge(1)
                if event.action_id == ACTION_DECREMENT:
                    return self.slider.nudge(-1)
                return False
            if event.kind == KEY_DOWN_KIND:
                return self.slider.handle_key(event.key)
            if event.kind == CLICK_KIND:
                return self.slider.set_from_position(
                    event.position,
                    view.bounds_for(WX_SLIDER_ID),
                )
            return False

        if event.target == WX_SWITCH_ID and self.is_activation(event):
            return self.notifications.toggle()

        if event.target == WX_RADIO_ID and self.is_activation(event):
            return self.radio.select(WX_RADIO_ID)

        if event.target == WX_COMBO_ID:
            if event.kind == ACTION_KIND and event.action_id == ACTION_SELECT:
                return self.combo.select(1)
            if self.is_activation(event):
                return self.combo.toggle()
            return False

        if event.target == WX_LIST_ID:
            if event.kind == ACTION_KIND and event.action_id == ACTION_SELECT:
                return self.list.next()
            if self.is_activation(event):
                return self.list.next()
            return False

        if event.target == WX_TABLE_ID:
            if event.kind == ACTION_KIND and event.action_id == ACTION_SELECT:
                return self.table.move(1, 0)
            if self.is_activation(event):
                return self.table.select(0, 0)
            return False

        if event.target == WX_TREE_ID:
            if event.kind == ACTION_KIND:
                if event.action_id == ACTION_SELECT:
                    return self.tree.select(0)
                if (
                    event.action_id == ACTION_EXPAND
                    and not self.tree.expanded
                ):
                    return self.tree.toggle_expanded()
                if (
                    event.action_id == ACTION_COLLAPSE
                    and self.tree.expanded
                ):
                    return self.tree.toggle_expanded()
            if self.is_activation(event):
                return self.tree.toggle_expanded()
            return False

        if event.target == WX_MENU_ID and self.is_activation(event):
            if self.menu.open:
                return self.menu.dismiss()
            return self.menu.show()

        if event.target == WX_DIALOG_ID and (
            self.is_activation(event)
            or (event.kind == ACTION_KIND and event.action_id == ACTION_PRESS)
        ):
            return self.dialog.resolve(1)

        if event.target == WX_TABS_ID:
            if event.kind == ACTION_KIND and event.action_id == ACTION_SELECT:
                return self.tabs.next()
            if self.is_activation(event):
                return self.tabs.next()
            return False

        if event.target == WX_CANVAS_ID:
            if event.kind == DRAG_BEGIN_KIND:
                return self.canvas.begin(event.position)
            if event.kind == DRAG_UPDATE_KIND:
                return self.canvas.update(event.position)
            if event.kind == DROP_KIND:
                return self.canvas.end(event.position)
            return False

        if event.target == WX_NAME_FIELD_ID:
            if event.kind == COMPOSITION_UPDATE_KIND:
                self.input.set_composition(
                    event.text,
                    event.selection_start,
                    event.selection_end,
                )
                return True
            if event.kind == COMPOSITION_END_KIND:
                if not self.input.has_composition():
                    return False
                self.input.clear_composition()
                return True
            if event.kind == TEXT_INPUT_KIND:
                if event.replacement_start >= 0 and event.replacement_end >= 0:
                    return self.input.replace_text_range(
                        event.text,
                        event.replacement_start,
                        event.replacement_end,
                    )
                return self.input.insert_text(event.text)
            if event.kind == KEY_DOWN_KIND:
                if event.key == KEY_ENTER:
                    return self.submit()
                return self.input.handle_key(event.key, event.modifiers)
            return False

        if (
            (event.target == WX_OK_BUTTON_ID or event.action_id == WX_SUBMIT_ACTION)
            and self.is_activation(event)
        ):
            return self.submit()

        if (
            (event.target == WX_CANCEL_BUTTON_ID or event.action_id == WX_CANCEL_ACTION)
            and self.is_activation(event)
        ):
            return self.cancel()

        if (
            (event.target == WX_REMEMBER_ID or event.action_id == WX_REMEMBER_ACTION)
            and self.is_activation(event)
        ):
            var request = CapabilityInvocation(
                self.next_request_id("ui-remember"),
                "wx.remember",
                CALLER_UI,
                "{}",
            )
            _ = self.execute_capability(request)
            return True

        if (
            (event.target == WX_RESET_BUTTON_ID or event.action_id == WX_RESET_ACTION)
            and self.is_activation(event)
        ):
            var request = CapabilityInvocation(
                self.next_request_id("ui-reset"),
                "wx.reset",
                CALLER_UI,
                "{}",
            )
            var approval = self.capabilities.issue_approval(
                request,
                "wx-style-confirmation",
            )
            request.set_approval(approval)
            _ = self.execute_capability(request)
            return True

        if (
            (event.target == WX_AGENT_RESET_BUTTON_ID
                or event.action_id == WX_AGENT_RESET_ACTION)
            and self.is_activation(event)
        ):
            _ = self.agent_reset()
            return True

        if (
            (event.target == WX_APPROVE_RESET_ID
                or event.action_id == WX_APPROVE_RESET_ACTION)
            and self.is_activation(event)
        ):
            _ = self.approve_agent_reset()
            return True
        return False

    def is_activation(self, event: Event) -> Bool:
        return event.kind == CLICK_KIND or (
            event.kind == KEY_DOWN_KIND
            and (event.key == KEY_ENTER or event.key == KEY_SPACE)
        )

    def submit(mut self) -> Bool:
        var request = CapabilityInvocation(
            self.next_request_id("ui-submit"),
            "wx.submit",
            CALLER_UI,
            String("{\"name\":", self.json_quote(self.input.text), "}"),
        )
        _ = self.execute_capability(request)
        return True

    def cancel(mut self) -> Bool:
        var request = CapabilityInvocation(
            self.next_request_id("ui-cancel"),
            "wx.cancel",
            CALLER_UI,
            "{}",
        )
        _ = self.execute_capability(request)
        return True

    def next_request_id(mut self, prefix: String) -> String:
        """Create a fresh request id so repeated UI actions are not replays."""
        self.request_sequence += 1
        return String(prefix, "-", self.request_sequence)

    def json_quote(self, value: String) -> String:
        """Quote user text before placing it in a capability argument object."""
        var result = String("\"")
        for index in range(value.count_codepoints()):
            var glyph = String(value[codepoint=index:index + 1])
            if glyph == "\"" or glyph == "\\":
                result += "\\"
                result += glyph
            elif glyph == chr(10):
                result += "\\n"
            elif glyph == chr(13):
                result += "\\r"
            elif glyph == chr(9):
                result += "\\t"
            else:
                result += glyph
        result += "\""
        return result

    def execute_capability(
        mut self,
        invocation: CapabilityInvocation,
    ) -> CapabilityResult:
        """Authorize then apply a registered demo mutation through one path."""
        var result = self.capabilities.authorize(invocation)
        if not result.ok():
            self.status = "Capability blocked: "
            self.status += result.recovery_hint
            return result

        if result.replayed:
            return result

        if invocation.capability_name == "wx.submit":
            if self.input.text.count_codepoints() == 0:
                self.status = "Please type a name."
            else:
                self.status = "Hello, "
                self.status += self.input.text
                self.submissions += 1
        elif invocation.capability_name == "wx.cancel":
            self.input.set_text("")
            self.status = "Cancelled."
            self.cancellations += 1
        elif invocation.capability_name == "wx.remember":
            self.remember_name = not self.remember_name
            if self.remember_name:
                self.status = "Remember-name enabled."
            else:
                self.status = "Remember-name disabled."
        elif invocation.capability_name == "wx.reset":
            self.input.set_text("")
            self.status = "Ready. Type a name."
            self.submissions = 0
            self.cancellations = 0
            self.remember_name = True
        result.executed = True
        self.capabilities.record_completion(invocation, result)
        return result

    def agent_submit(mut self) -> CapabilityResult:
        """Exercise the same public capability path used by an agent adapter."""
        var request = CapabilityInvocation(
            self.next_request_id("agent-submit"),
            "wx.submit",
            CALLER_AGENT,
            String("{\"name\":", self.json_quote(self.input.text), "}"),
        )
        return self.execute_capability(request)

    def agent_reset(mut self) -> CapabilityResult:
        """Show that destructive agent calls need explicit approval."""
        var request_id = self.next_request_id("agent-reset")
        self.pending_agent_reset_request_id = request_id
        var request = CapabilityInvocation(
            request_id,
            "wx.reset",
            CALLER_AGENT,
            "{}",
        )
        var result = self.execute_capability(request)
        if result.status == CAPABILITY_REQUIRES_APPROVAL:
            self.status = "Agent reset is waiting for approval."
        return result

    def approve_agent_reset(mut self) -> CapabilityResult:
        """Approve and execute the pending destructive agent request."""
        if self.pending_agent_reset_request_id.count_codepoints() == 0:
            return CapabilityResult(
                "",
                CAPABILITY_INVALID,
                "",
                "Request an agent reset before approving it.",
                error_code="NO_PENDING_APPROVAL",
            )
        var request = CapabilityInvocation(
            self.pending_agent_reset_request_id,
            "wx.reset",
            CALLER_AGENT,
            "{}",
        )
        var approval = self.capabilities.issue_approval(
            request,
            "wx-style-confirmation",
        )
        request.set_approval(approval)
        var result = self.execute_capability(request)
        if result.ok():
            self.pending_agent_reset_request_id = ""
        return result

    def clipboard_copy(mut self, target: Int, view: ColumnView) -> String:
        if target == WX_NAME_FIELD_ID:
            var copied = self.input.selected_text()
            self.input.clipboard = copied
            return copied
        return ""

    def clipboard_cut(mut self, target: Int, view: ColumnView) -> String:
        if target == WX_NAME_FIELD_ID and self.input.has_selection():
            _ = self.input.cut_selection()
            return self.input.clipboard
        return ""

    def clipboard_paste(
        mut self,
        target: Int,
        text: String,
        view: ColumnView,
    ) -> Bool:
        if target != WX_NAME_FIELD_ID or text.count_codepoints() == 0:
            return False
        self.input.clipboard = text
        return self.input.insert_text(text)
