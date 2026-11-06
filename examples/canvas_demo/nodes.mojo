"""Ordinary components: no camera math, canvas gestures or canvas imports."""
from moxi.component import Component
from moxi.column_view import ColumnView
from moxi.geometry import Rect
from moxi.controls_text import TextInputControl, TextInputState
from moxi.controls_basic import LabelControl, ButtonControl, SliderControl
from moxi.controls_state import SliderState
from moxi.event import *


struct RichNode(Component):
    var input: TextInputState
    var slider: SliderState
    var clicks: Int

    def __init__(out self, text: String = "Edit this ordinary Moxi field"):
        self.input = TextInputState(text)
        self.slider = SliderState(40, 0, 100, 1)
        self.clicks = 0

    def build(self, bounds: Rect) -> ColumnView:
        var view = ColumnView(bounds, 12, 8)
        var input = TextInputControl(1, self.input.text, self.input.cursor, self.input.anchor, 34)
        input.set_composition(self.input.composition, self.input.composition_selection_start, self.input.composition_selection_end)
        view.add(input.node())
        view.set_accessibility_label(1, "Node text")
        view.add(ButtonControl(2, String("Apply · ", self.clicks), 32).node())
        view.add(SliderControl(3, "Level", self.slider.value, 0, 100, 1, 30).node())
        view.add(LabelControl(4, String("Level ", Int(self.slider.value), "  · controls own input"), Float32(100) if self.clicks % 2 else Float32(22)).node())
        view.layout()
        return view^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        if event.target == 1:
            if event.kind == TEXT_INPUT_KIND:
                if event.replacement_start >= 0:
                    return self.input.replace_text_range(event.text, event.replacement_start, event.replacement_end)
                return self.input.insert_text(event.text)
            if event.kind == COMPOSITION_UPDATE_KIND:
                self.input.set_composition(event.text, event.selection_start, event.selection_end)
                return True
            if event.kind == COMPOSITION_END_KIND:
                var changed = self.input.has_composition()
                self.input.clear_composition()
                return changed
            if event.kind == KEY_DOWN_KIND:
                return self.input.handle_key(event.key, event.modifiers)
        if event.target == 2 and (event.kind == CLICK_KIND or (event.kind == KEY_DOWN_KIND and (event.key == KEY_ENTER or event.key == KEY_SPACE))):
            self.clicks += 1
            return True
        if event.target == 3:
            if event.kind == POINTER_DOWN_KIND or event.kind == POINTER_MOVE_KIND or event.kind == DRAG_UPDATE_KIND or event.kind == CLICK_KIND:
                return self.slider.set_from_position(event.position, view.bounds_for(3))
            if event.kind == KEY_DOWN_KIND:
                return self.slider.handle_key(event.key)
        return False

    def clipboard_copy(mut self, target: Int, view: ColumnView) -> String:
        return self.input.selected_text() if target == 1 else ""

    def clipboard_cut(mut self, target: Int, view: ColumnView) -> String:
        if target == 1:
            var selected = self.input.selected_text()
            _ = self.input.cut_selection()
            return selected
        return ""

    def clipboard_paste(mut self, target: Int, text: String, view: ColumnView) -> Bool:
        return self.input.insert_text(text) if target == 1 else False


struct GraphNode(Component):
    """Public second consumer: editable stage label and processing gain."""
    var label: TextInputState
    var gain: SliderState
    var enabled: Bool
    def __init__(out self, text: String = "New processing stage"):
        self.label = TextInputState(text)
        self.gain = SliderState(50, 0, 100, 1)
        self.enabled = True
    def build(self, bounds: Rect) -> ColumnView:
        var view = ColumnView(bounds, 12, 8)
        var input = TextInputControl(1, self.label.text, self.label.cursor, self.label.anchor, 34)
        input.set_composition(self.label.composition, self.label.composition_selection_start, self.label.composition_selection_end)
        view.add(input.node())
        view.add(ButtonControl(2, "Stage enabled" if self.enabled else "Stage bypassed", 32).node())
        view.add(SliderControl(3, "Gain", self.gain.value, 0, 100, 1, 30).node())
        view.add(LabelControl(4, String("Gain: ", Int(self.gain.value), "%"), 22).node())
        view.layout()
        return view^
    def update(mut self, event: Event, view: ColumnView) -> Bool:
        if event.target == 1:
            if event.kind == TEXT_INPUT_KIND:
                if event.replacement_start >= 0:
                    return self.label.replace_text_range(event.text, event.replacement_start, event.replacement_end)
                return self.label.insert_text(event.text)
            if event.kind == COMPOSITION_UPDATE_KIND:
                self.label.set_composition(event.text, event.selection_start, event.selection_end)
                return True
            if event.kind == COMPOSITION_END_KIND:
                var changed = self.label.has_composition()
                self.label.clear_composition()
                return changed
            if event.kind == KEY_DOWN_KIND:
                return self.label.handle_key(event.key, event.modifiers)
        if event.target == 2 and (event.kind == CLICK_KIND or (event.kind == KEY_DOWN_KIND and (event.key == KEY_ENTER or event.key == KEY_SPACE))):
            self.enabled = not self.enabled
            return True
        if event.target == 3:
            if event.kind == POINTER_DOWN_KIND or event.kind == POINTER_MOVE_KIND or event.kind == DRAG_UPDATE_KIND or event.kind == CLICK_KIND:
                return self.gain.set_from_position(event.position, view.bounds_for(3))
            if event.kind == KEY_DOWN_KIND:
                return self.gain.handle_key(event.key)
        return False
    def clipboard_copy(mut self, target: Int, view: ColumnView) -> String:
        return self.label.selected_text() if target == 1 else ""
    def clipboard_cut(mut self, target: Int, view: ColumnView) -> String:
        if target == 1:
            var selected = self.label.selected_text()
            _ = self.label.cut_selection()
            return selected
        return ""
    def clipboard_paste(mut self, target: Int, text: String, view: ColumnView) -> Bool:
        return self.label.insert_text(text) if target == 1 else False
