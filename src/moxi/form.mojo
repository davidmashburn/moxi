"""Shared form scenario used by the 0.5 interaction demo and tests."""

from .component import Component
from .event import (
    CLICK_KIND,
    COMPOSITION_END_KIND,
    COMPOSITION_UPDATE_KIND,
    Event,
    KEY_DOWN_KIND,
    KEY_ENTER,
    KEY_SPACE,
    TEXT_INPUT_KIND,
)
from .controls import (
    ButtonControl,
    LabelControl,
    TextInputControl,
    TextInputState,
)
from .geometry import Rect
from .style import (
    default_panel_style,
    default_surface_style,
)
from .view import ColumnView


comptime NAME_FIELD_ID = 2
comptime STATUS_LABEL_ID = 3
comptime SUBMIT_BUTTON_ID = 4


struct FormState(Component):
    """A small editable form that exercises focus and keyboard routing."""

    var input: TextInputState
    var submissions: Int

    def __init__(out self):
        self.input = TextInputState()
        self.submissions = 0

    def build(self, bounds: Rect) -> ColumnView:
        """Build the form for the current root size and input state."""
        var column = ColumnView(bounds, 32.0, 8.0)
        var panel_width = bounds.width - 40.0
        var panel_height = bounds.height - 40.0
        if panel_width < 0.0:
            panel_width = 0.0
        if panel_height < 0.0:
            panel_height = 0.0

        column.set_surface_style(default_surface_style())
        column.set_panel(
            0,
            Rect(bounds.x + 20.0, bounds.y + 20.0, panel_width, panel_height),
            default_panel_style(),
        )
        var title = LabelControl(1, "Moxi Form", 28.0)
        column.add(title.node())
        var hint = LabelControl(5, "Type a name, then submit", 24.0)
        column.add(hint.node())
        var input = TextInputControl(
            NAME_FIELD_ID,
            self.input.text,
            self.input.cursor,
            self.input.anchor,
            44.0,
        )
        input.set_composition(
            self.input.composition,
            self.input.composition_selection_start,
            self.input.composition_selection_end,
        )
        column.add(input.node())
        column.set_accessibility_label(NAME_FIELD_ID, "Name")
        column.set_accessibility_hint(NAME_FIELD_ID, "Enter your name")
        var status = LabelControl(
            STATUS_LABEL_ID,
            String("Submitted: ", self.submissions),
            28.0,
        )
        column.add(status.node())
        var submit = ButtonControl(SUBMIT_BUTTON_ID, "Submit", 40.0)
        column.add(submit.node())
        column.layout()
        return column^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        """Apply routed text, cursor, and submit actions."""
        if event.target == NAME_FIELD_ID:
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
                return self.input.handle_key(event.key, event.modifiers)
            return False

        if event.target == SUBMIT_BUTTON_ID and (
            event.kind == CLICK_KIND
            or (
                event.kind == KEY_DOWN_KIND
                and (event.key == KEY_ENTER or event.key == KEY_SPACE)
            )
        ):
            self.submissions += 1
            return True
        return False

    def clipboard_copy(mut self, target: Int, view: ColumnView) -> String:
        if target == NAME_FIELD_ID:
            var copied = self.input.selected_text()
            self.input.clipboard = copied
            return copied
        return ""

    def clipboard_cut(mut self, target: Int, view: ColumnView) -> String:
        if target == NAME_FIELD_ID and self.input.has_selection():
            _ = self.input.cut_selection()
            return self.input.clipboard
        return ""

    def clipboard_paste(
        mut self,
        target: Int,
        text: String,
        view: ColumnView,
    ) -> Bool:
        if target != NAME_FIELD_ID or text.count_codepoints() == 0:
            return False
        self.input.clipboard = text
        return self.input.insert_text(text)
