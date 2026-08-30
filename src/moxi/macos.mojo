"""Native macOS window and rendering backends."""

from std.ffi import external_call
from .clipboard import ClipboardBackend
from .backend import (
    BACKEND_MACOS_APPKIT,
    BackendCapabilities,
    backend_capabilities,
)
from .accessibility import AccessibilitySnapshot
from .event import (
    CLICK_KIND,
    COMPOSITION_END_KIND,
    COMPOSITION_UPDATE_KIND,
    KEY_DOWN_KIND,
    POINTER_MOVE_KIND,
    POINTER_DOWN_KIND,
    POINTER_UP_KIND,
    SCROLL_KIND,
    DRAG_BEGIN_KIND,
    DRAG_UPDATE_KIND,
    DROP_KIND,
    POINTER_CANCEL_KIND,
    ACTION_KIND,
    TEXT_INPUT_KIND,
    WINDOW_RESIZED_KIND,
    ClickEvent,
    CompositionEvent,
    Event,
    KeyEvent,
    PointerEvent,
    ResizeEvent,
    ScrollEvent,
    DragEvent,
    SemanticActionEvent,
    TextInputEvent,
)
from .geometry import Point, Size
from .paint import PANEL_KIND, SURFACE_KIND, PaintCommand, Renderer
from .resources import ImageResource
from .view import (
    BUTTON_KIND,
    CHECKBOX_KIND,
    LABEL_KIND,
    PROGRESS_KIND,
    TEXT_INPUT_VIEW_KIND,
    SLIDER_KIND,
    SWITCH_KIND,
    RADIO_KIND,
    IMAGE_KIND,
    MULTILINE_TEXT_KIND,
    COMBO_BOX_KIND,
    LIST_KIND,
    TABLE_KIND,
    TREE_KIND,
    MENU_KIND,
    DIALOG_KIND,
    TABS_KIND,
    CANVAS_KIND,
    SEPARATOR_KIND,
)
from .window import WindowBackend, WindowConfig


struct MacOSRenderer(Renderer):
    """Submits Moxi paint commands to the active AppKit canvas."""

    def __init__(out self):
        pass

    def backend_capabilities(self) -> BackendCapabilities:
        return backend_capabilities(BACKEND_MACOS_APPKIT)

    def register_image(mut self, resource: ImageResource) raises:
        """Resolve an application image before it appears in a frame."""
        var source = resource.source
        var c_source = source.as_c_string_slice()
        external_call["moxi_window_register_image", NoneType](
            Int32(resource.id),
            c_source.ptr(),
        )

    def begin_frame(mut self) raises:
        external_call["moxi_window_begin_frame", NoneType]()

    def update_accessibility(
        mut self,
        snapshot: AccessibilitySnapshot,
    ) raises:
        external_call["moxi_window_begin_accessibility", NoneType]()
        for index in range(snapshot.count()):
            var node = snapshot.node(index)
            var label = node.label
            var value = node.value
            var hint = node.hint
            var c_label = label.as_c_string_slice()
            var c_value = value.as_c_string_slice()
            var c_hint = hint.as_c_string_slice()
            var enabled = 0
            var focused = 0
            var selected = 0
            if node.enabled:
                enabled = 1
            if node.focused:
                focused = 1
            if node.selected:
                selected = 1
            external_call["moxi_window_set_accessibility_at", NoneType](
                Int32(index),
                Int32(node.id),
                Int32(node.parent_id),
                Int32(node.role),
                c_label.ptr(),
                c_value.ptr(),
                c_hint.ptr(),
                node.bounds.x,
                node.bounds.y,
                node.bounds.width,
                node.bounds.height,
                enabled,
                focused,
                selected,
                node.actions,
            )
        external_call["moxi_window_end_accessibility", NoneType]()

    def set_clip(self, command: PaintCommand) raises:
        """Pass a per-command clip to the native slot retained for drawRect."""
        var enabled = 0
        if command.has_clip:
            enabled = 1
        external_call["moxi_window_set_clip", NoneType](
            enabled,
            command.clip_bounds.x,
            command.clip_bounds.y,
            command.clip_bounds.width,
            command.clip_bounds.height,
        )

    def draw(mut self, command: PaintCommand) raises:
        self.set_clip(command)
        if command.kind == SURFACE_KIND:
            self.draw_surface(command)
        elif command.kind == PANEL_KIND:
            self.draw_panel(command)
        elif command.kind == LABEL_KIND:
            self.draw_label(command)
        elif command.kind == BUTTON_KIND:
            self.draw_button(command)
        elif command.kind == TEXT_INPUT_VIEW_KIND:
            self.draw_text_input(command)
        elif command.kind == CHECKBOX_KIND:
            self.draw_checkbox(command)
        elif command.kind == PROGRESS_KIND:
            self.draw_progress(command)
        elif command.kind == SLIDER_KIND:
            self.draw_slider(command)
        elif command.kind == SWITCH_KIND:
            self.draw_switch(command)
        elif command.kind == RADIO_KIND:
            self.draw_radio(command)
        elif command.kind == IMAGE_KIND:
            self.draw_image(command)
        elif command.kind == MULTILINE_TEXT_KIND:
            self.draw_multiline_text(command)
        elif command.kind == COMBO_BOX_KIND:
            self.draw_combo_box(command)
        elif command.kind == LIST_KIND:
            self.draw_list(command)
        elif command.kind == TABLE_KIND:
            self.draw_table(command)
        elif command.kind == TREE_KIND:
            self.draw_tree(command)
        elif command.kind == MENU_KIND:
            self.draw_menu(command)
        elif command.kind == DIALOG_KIND:
            self.draw_dialog(command)
        elif command.kind == TABS_KIND:
            self.draw_tabs(command)
        elif command.kind == CANVAS_KIND:
            self.draw_canvas(command)
        elif command.kind == SEPARATOR_KIND:
            self.draw_separator(command)

    def draw_surface(mut self, command: PaintCommand) raises:
        external_call["moxi_window_set_surface", NoneType](
            command.style.fill.red,
            command.style.fill.green,
            command.style.fill.blue,
            command.style.fill.alpha,
        )

    def draw_panel(mut self, command: PaintCommand) raises:
        var clip_enabled = 0
        if command.has_clip:
            clip_enabled = 1
        external_call["moxi_window_set_panel_at", NoneType](
            Int32(command.slot),
            command.bounds.x,
            command.bounds.y,
            command.bounds.width,
            command.bounds.height,
            command.style.fill.red,
            command.style.fill.green,
            command.style.fill.blue,
            command.style.fill.alpha,
            command.style.corner_radius,
            clip_enabled,
            command.clip_bounds.x,
            command.clip_bounds.y,
            command.clip_bounds.width,
            command.clip_bounds.height,
        )

    def draw_label(mut self, command: PaintCommand) raises:
        var text = command.text
        var c_text = text.as_c_string_slice()
        var wrap_text = 0
        if command.wrap_text:
            wrap_text = 1
        external_call["moxi_window_set_label_at", NoneType](
            Int32(command.slot),
            c_text.ptr(),
            command.bounds.x,
            command.bounds.y,
            command.bounds.width,
            command.bounds.height,
            command.style.text.red,
            command.style.text.green,
            command.style.text.blue,
            command.style.text.alpha,
            command.style.font_size,
            wrap_text,
        )

    def draw_button(mut self, command: PaintCommand) raises:
        var text = command.text
        var c_text = text.as_c_string_slice()
        var focused = 0
        var hovered = 0
        var pressed = 0
        var enabled = 0
        if command.focused:
            focused = 1
        if command.hovered:
            hovered = 1
        if command.pressed:
            pressed = 1
        if command.enabled:
            enabled = 1
        var wrap_text = 0
        if command.wrap_text:
            wrap_text = 1
        external_call["moxi_window_set_button_at", NoneType](
            Int32(command.slot),
            c_text.ptr(),
            command.bounds.x,
            command.bounds.y,
            command.bounds.width,
            command.bounds.height,
            command.style.fill.red,
            command.style.fill.green,
            command.style.fill.blue,
            command.style.fill.alpha,
            command.style.text.red,
            command.style.text.green,
            command.style.text.blue,
            command.style.text.alpha,
            command.style.corner_radius,
            command.style.font_size,
            wrap_text,
            focused,
            hovered,
            pressed,
            enabled,
        )

    def draw_text_input(mut self, command: PaintCommand) raises:
        var text = command.text
        var c_text = text.as_c_string_slice()
        var composition = command.composition
        var c_composition = composition.as_c_string_slice()
        var focused = 0
        if command.focused:
            focused = 1
        var wrap_text = 0
        if command.wrap_text:
            wrap_text = 1
        external_call["moxi_window_set_text_input_at", NoneType](
            Int32(command.slot),
            c_text.ptr(),
            command.bounds.x,
            command.bounds.y,
            command.bounds.width,
            command.bounds.height,
            command.style.fill.red,
            command.style.fill.green,
            command.style.fill.blue,
            command.style.fill.alpha,
            command.style.text.red,
            command.style.text.green,
            command.style.text.blue,
            command.style.text.alpha,
            command.style.corner_radius,
            command.style.font_size,
            wrap_text,
            focused,
            Int32(command.cursor),
            Int32(command.selection_start),
            Int32(command.selection_end),
            c_composition.ptr(),
            Int32(command.composition_selection_start),
            Int32(command.composition_selection_end),
        )

    def draw_checkbox(mut self, command: PaintCommand) raises:
        var text = command.text
        var c_text = text.as_c_string_slice()
        var focused = 0
        var hovered = 0
        var pressed = 0
        var enabled = 0
        var checked = 0
        if command.focused:
            focused = 1
        if command.hovered:
            hovered = 1
        if command.pressed:
            pressed = 1
        if command.enabled:
            enabled = 1
        if command.checked:
            checked = 1
        external_call["moxi_window_set_checkbox_at", NoneType](
            Int32(command.slot),
            c_text.ptr(),
            command.bounds.x,
            command.bounds.y,
            command.bounds.width,
            command.bounds.height,
            command.style.fill.red,
            command.style.fill.green,
            command.style.fill.blue,
            command.style.fill.alpha,
            command.style.text.red,
            command.style.text.green,
            command.style.text.blue,
            command.style.text.alpha,
            command.style.corner_radius,
            command.style.font_size,
            focused,
            hovered,
            pressed,
            enabled,
            checked,
        )

    def draw_progress(mut self, command: PaintCommand) raises:
        var text = command.text
        var c_text = text.as_c_string_slice()
        external_call["moxi_window_set_progress_at", NoneType](
            Int32(command.slot),
            c_text.ptr(),
            command.bounds.x,
            command.bounds.y,
            command.bounds.width,
            command.bounds.height,
            command.style.fill.red,
            command.style.fill.green,
            command.style.fill.blue,
            command.style.fill.alpha,
            command.style.text.red,
            command.style.text.green,
            command.style.text.blue,
            command.style.text.alpha,
            command.style.corner_radius,
            command.style.font_size,
            command.progress,
        )

    def draw_slider(mut self, command: PaintCommand) raises:
        """Render a labelled track and thumb through the AppKit shim."""
        var text = command.text
        var c_text = text.as_c_string_slice()
        var focused = 0
        var hovered = 0
        var pressed = 0
        var enabled = 0
        if command.focused:
            focused = 1
        if command.hovered:
            hovered = 1
        if command.pressed:
            pressed = 1
        if command.enabled:
            enabled = 1
        external_call["moxi_window_set_slider_at", NoneType](
            Int32(command.slot),
            c_text.ptr(),
            command.bounds.x,
            command.bounds.y,
            command.bounds.width,
            command.bounds.height,
            command.style.fill.red,
            command.style.fill.green,
            command.style.fill.blue,
            command.style.fill.alpha,
            command.style.text.red,
            command.style.text.green,
            command.style.text.blue,
            command.style.text.alpha,
            command.style.corner_radius,
            command.style.font_size,
            command.progress,
            focused,
            hovered,
            pressed,
            enabled,
        )

    def draw_switch(mut self, command: PaintCommand) raises:
        """Render a native-style pill switch."""
        self.draw_toggle(command, False)

    def draw_radio(mut self, command: PaintCommand) raises:
        """Render a native-style radio option."""
        self.draw_toggle(command, True)

    def draw_toggle(mut self, command: PaintCommand, radio: Bool) raises:
        var text = command.text
        var c_text = text.as_c_string_slice()
        var focused = 0
        var hovered = 0
        var pressed = 0
        var enabled = 0
        var checked = 0
        var is_radio = 0
        if command.focused:
            focused = 1
        if command.hovered:
            hovered = 1
        if command.pressed:
            pressed = 1
        if command.enabled:
            enabled = 1
        if command.checked:
            checked = 1
        if radio:
            is_radio = 1
        external_call["moxi_window_set_toggle_at", NoneType](
            Int32(command.slot),
            c_text.ptr(),
            command.bounds.x,
            command.bounds.y,
            command.bounds.width,
            command.bounds.height,
            command.style.fill.red,
            command.style.fill.green,
            command.style.fill.blue,
            command.style.fill.alpha,
            command.style.text.red,
            command.style.text.green,
            command.style.text.blue,
            command.style.text.alpha,
            command.style.corner_radius,
            command.style.font_size,
            focused,
            hovered,
            pressed,
            enabled,
            checked,
            is_radio,
        )

    def draw_image(mut self, command: PaintCommand) raises:
        """Render a resolved image with an accessible fallback label."""
        var text = command.text
        var c_text = text.as_c_string_slice()
        external_call["moxi_window_set_image_at", NoneType](
            Int32(command.slot),
            Int32(command.resource_id),
            c_text.ptr(),
            command.bounds.x,
            command.bounds.y,
            command.bounds.width,
            command.bounds.height,
            command.style.fill.red,
            command.style.fill.green,
            command.style.fill.blue,
            command.style.fill.alpha,
            command.style.text.red,
            command.style.text.green,
            command.style.text.blue,
            command.style.text.alpha,
            command.style.corner_radius,
        )

    def draw_multiline_text(mut self, command: PaintCommand) raises:
        """Reuse the AppKit text-input surface with wrapping enabled."""
        self.draw_text_input(command)

    def draw_combo_box(mut self, command: PaintCommand) raises:
        """Use the label bridge while preserving combo-box semantics."""
        self.draw_label(command)

    def draw_list(mut self, command: PaintCommand) raises:
        """Use the label bridge for list content in the current AppKit path."""
        self.draw_label(command)

    def draw_table(mut self, command: PaintCommand) raises:
        """Use the label bridge for table content in the current AppKit path."""
        self.draw_label(command)

    def draw_tree(mut self, command: PaintCommand) raises:
        """Use the label bridge for tree content in the current AppKit path."""
        self.draw_label(command)

    def draw_menu(mut self, command: PaintCommand) raises:
        """Use the label bridge for menu content in the current AppKit path."""
        self.draw_label(command)

    def draw_dialog(mut self, command: PaintCommand) raises:
        """Present a dialog descriptor as a styled native panel."""
        self.draw_panel(command)

    def draw_tabs(mut self, command: PaintCommand) raises:
        """Use the label bridge for tab-group content."""
        self.draw_label(command)

    def draw_canvas(mut self, command: PaintCommand) raises:
        """Present a custom canvas descriptor as a styled native panel."""
        self.draw_panel(command)

    def draw_separator(mut self, command: PaintCommand) raises:
        """Keep separators visible through the neutral panel bridge."""
        self.draw_panel(command)


struct MacOSClipboard(ClipboardBackend):
    """Bridge portable clipboard commands to the active macOS pasteboard."""

    def __init__(out self):
        pass

    def copy(mut self, text: String) raises:
        var text_copy = text
        var c_text = text_copy.as_c_string_slice()
        external_call["moxi_clipboard_set", NoneType](c_text.ptr())

    def paste(mut self) raises -> String:
        var text = String("")
        var index = 0
        while True:
            var codepoint = Int(
                external_call["moxi_clipboard_codepoint_at", Int32](Int32(index))
            )
            if codepoint < 0:
                break
            text += chr(codepoint)
            index += 1
        return text


struct MacOSWindow(WindowBackend):
    """Owns the AppKit window lifecycle without owning view state."""

    def __init__(out self):
        pass

    def open(mut self, config: WindowConfig) raises:
        var title = config.title
        var c_title = title.as_c_string_slice()
        external_call["moxi_window_open", NoneType](
            c_title.ptr(),
            config.width,
            config.height,
            config.min_width,
            config.min_height,
            config.max_width,
            config.max_height,
            1 if config.resizable else 0,
            1 if config.fullscreen else 0,
        )

    def run(mut self) raises:
        while self.is_open():
            self.pump()

    def pump(mut self) raises:
        external_call["moxi_window_pump", NoneType]()

    def is_open(self) raises -> Bool:
        return external_call["moxi_window_is_open", Int32]() != 0

    def event_queue_depth(self) raises -> Int:
        """Return queued native events waiting for the application loop."""
        return Int(external_call["moxi_window_event_queue_depth", Int32]())

    def dropped_event_count(self) raises -> Int:
        """Return native events dropped after the bounded queue filled."""
        return Int(external_call["moxi_window_event_dropped_count", Int32]())

    def command_overflow_count(self) raises -> Int:
        """Return native draw slots rejected in the current frame."""
        return Int(external_call["moxi_window_command_overflow_count", Int32]())

    def poll_click(mut self) raises -> Bool:
        return external_call["moxi_window_poll_click", Int32]() != 0

    def poll_event(mut self) raises -> Event:
        var kind = Int(external_call["moxi_window_poll_event", Int32]())
        if kind == CLICK_KIND:
            return Event(
                ClickEvent(
                    Point(
                        external_call["moxi_window_event_x", Float32](),
                        external_call["moxi_window_event_y", Float32](),
                    )
                )
            )
        elif (
            kind == POINTER_DOWN_KIND
            or kind == POINTER_UP_KIND
            or kind == POINTER_MOVE_KIND
            or kind == POINTER_CANCEL_KIND
        ):
            return Event(
                PointerEvent(
                    kind,
                    Point(
                        external_call["moxi_window_event_x", Float32](),
                        external_call["moxi_window_event_y", Float32](),
                    ),
                )
            )
        elif kind == DRAG_BEGIN_KIND or kind == DRAG_UPDATE_KIND or kind == DROP_KIND:
            return Event(
                DragEvent(
                    kind,
                    Point(
                        external_call["moxi_window_event_x", Float32](),
                        external_call["moxi_window_event_y", Float32](),
                    ),
                )
            )
        elif kind == KEY_DOWN_KIND:
            return Event(
                KeyEvent(
                    Int(external_call["moxi_window_event_key", Int32]()),
                    Int(external_call["moxi_window_event_modifiers", Int32]()),
                )
            )
        elif kind == TEXT_INPUT_KIND:
            return Event(
                TextInputEvent(
                    self.event_text(),
                    Int(external_call["moxi_window_event_selection_start", Int32]()),
                    Int(external_call["moxi_window_event_selection_end", Int32]()),
                )
            )
        elif kind == COMPOSITION_UPDATE_KIND:
            return Event(
                CompositionEvent(
                    self.event_text(),
                    Int(external_call["moxi_window_event_selection_start", Int32]()),
                    Int(external_call["moxi_window_event_selection_end", Int32]()),
                )
            )
        elif kind == COMPOSITION_END_KIND:
            return Event(CompositionEvent())
        elif kind == SCROLL_KIND:
            return Event(
                ScrollEvent(
                    Point(
                        external_call["moxi_window_event_x", Float32](),
                        external_call["moxi_window_event_y", Float32](),
                    ),
                    Point(
                        external_call["moxi_window_event_scroll_x", Float32](),
                        external_call["moxi_window_event_scroll_y", Float32](),
                    ),
                )
            )
        elif kind == WINDOW_RESIZED_KIND:
            return Event(ResizeEvent(self.size()))
        elif kind == ACTION_KIND:
            return Event(
                SemanticActionEvent(
                    Int(external_call["moxi_window_event_target", Int32]()),
                    Int(external_call["moxi_window_event_action", Int32]()),
                    self.event_text(),
                )
            )
        return Event()

    def event_text(self) -> String:
        """Read the current native event text through the codepoint ABI."""
        var text = String("")
        var index = 0
        while True:
            var codepoint = Int(
                external_call["moxi_window_event_codepoint_at", Int32](Int32(index))
            )
            if codepoint < 0:
                break
            text += chr(codepoint)
            index += 1
        return text

    def click_position(self) raises -> Point:
        return Point(
            external_call["moxi_window_click_x", Float32](),
            external_call["moxi_window_click_y", Float32](),
        )

    def size(self) raises -> Size:
        return Size(
            external_call["moxi_window_width", Float32](),
            external_call["moxi_window_height", Float32](),
        )
