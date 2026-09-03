"""Shared 0.5 nested-container scenario used by the demo and tests."""

from .component import Component
from .controls import ButtonControl, LabelControl, TextInputControl, TextInputState
from .event import (
    CLICK_KIND,
    COMPOSITION_END_KIND,
    COMPOSITION_UPDATE_KIND,
    Event,
    KEY_DOWN_KIND,
    TEXT_INPUT_KIND,
)
from .geometry import Rect
from .layout import ALIGN_CENTER
from .style import default_panel_style, default_surface_style
from .view import ColumnView


comptime CONTENT_CONTAINER_ID = 10
comptime NESTED_INPUT_ID = 12
comptime ACTIONS_CONTAINER_ID = 20
comptime FIRST_ACTION_ID = 21
comptime SECOND_ACTION_ID = 22


struct NestedState(Component):
    """An editable field and actions composed from nested containers."""

    var input: TextInputState
    var selected: Int

    def __init__(out self):
        self.input = TextInputState("Nested")
        self.selected = 0

    def build(self, bounds: Rect) -> ColumnView:
        var root = ColumnView(bounds, 16.0, 12.0)
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

        var content = root.add_column(CONTENT_CONTAINER_ID, 150.0, 8.0, 6.0)
        root.add_label_to(content, 11, "Nested containers", 28.0)
        var input = TextInputControl(
            NESTED_INPUT_ID,
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
        root.add_to(content, input.node())
        root.set_accessibility_label(NESTED_INPUT_ID, "Nested name")
        root.set_accessibility_hint(NESTED_INPUT_ID, "Type into the nested field")
        root.set_container_alignment(content, 0, ALIGN_CENTER)

        var actions = root.add_row(ACTIONS_CONTAINER_ID, 0.0, 48.0, 8.0, 8.0)
        var first_text = "One"
        if self.selected == FIRST_ACTION_ID:
            first_text = "Selected"
        var second_text = "Two"
        if self.selected == SECOND_ACTION_ID:
            second_text = "Selected"
        root.add_button_to(actions, FIRST_ACTION_ID, first_text, 32.0)
        root.add_button_to(actions, SECOND_ACTION_ID, second_text, 32.0)
        root.set_fixed_width(FIRST_ACTION_ID, 120.0)
        root.set_fixed_width(SECOND_ACTION_ID, 120.0)
        root.layout()
        return root^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        if event.target == NESTED_INPUT_ID:
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
        if event.kind == CLICK_KIND and (
            event.target == FIRST_ACTION_ID
            or event.target == SECOND_ACTION_ID
        ):
            self.selected = event.target
            return True
        return False

    def clipboard_copy(mut self, target: Int, view: ColumnView) -> String:
        if target == NESTED_INPUT_ID:
            var copied = self.input.selected_text()
            self.input.clipboard = copied
            return copied
        return ""

    def clipboard_cut(mut self, target: Int, view: ColumnView) -> String:
        if target == NESTED_INPUT_ID and self.input.has_selection():
            _ = self.input.cut_selection()
            return self.input.clipboard
        return ""

    def clipboard_paste(
        mut self,
        target: Int,
        text: String,
        view: ColumnView,
    ) -> Bool:
        if target != NESTED_INPUT_ID or text.count_codepoints() == 0:
            return False
        self.input.clipboard = text
        return self.input.insert_text(text)
