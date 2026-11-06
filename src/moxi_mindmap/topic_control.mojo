"""Ordinary editable topic controls mounted through the public canvas package."""
from moxi import Component, ColumnView, Rect, Event
from moxi.controls_text import TextInputState
from moxi import TextInputControl, ButtonControl, LabelControl
from moxi.event import *
from moxi.style import Color
from .model import TopicStyle, MAX_TEXT

@fieldwise_init
struct EditorField(Equatable, ImplicitlyCopyable):
    var value: Int
    comptime LABEL = Self(0)
    comptime NOTE = Self(1)
    comptime LINK = Self(2)
    comptime TAGS = Self(3)
    comptime ICONS = Self(4)
    comptime LINK_LABEL = Self(5)

struct TopicControl(Component):
    var input: TextInputState
    var subtitle: String
    var style: TopicStyle
    var field: EditorField
    var fold_requested: Bool

    def __init__(out self, text: String = "", subtitle: String = "", style: TopicStyle = TopicStyle.DEFAULT):
        self.input = TextInputState(text)
        self.subtitle = subtitle
        self.style = style
        self.field = EditorField.LABEL
        self.fold_requested = False

    def build(self, bounds: Rect) -> ColumnView:
        var view = ColumnView(bounds, 8, 5)
        var input = TextInputControl(1, self.input.text, self.input.cursor, self.input.anchor, max(Float32(32), bounds.height - 55))
        input.set_composition(self.input.composition, self.input.composition_selection_start, self.input.composition_selection_end)
        var node = input.node()
        node.wrap_text = True
        node.semantics.label = "Topic label" if self.field == EditorField.LABEL else "Topic metadata"
        node.style.font_size = 15
        if self.style == TopicStyle.IDEA:
            node.style.fill = Color(0.12, 0.26, 0.26, 1)
        elif self.style == TopicStyle.QUESTION:
            node.style.fill = Color(0.3, 0.19, 0.35, 1)
        elif self.style == TopicStyle.EMPHASIS:
            node.style.fill = Color(0.34, 0.22, 0.09, 1)
        view.add(node)
        view.add(ButtonControl(2, self.subtitle, 26).node())
        view.layout()
        return view^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        if event.target == 2 and event.kind == CLICK_KIND:
            self.fold_requested = True
            return True
        if event.target != 1:
            return False
        if event.kind == TEXT_INPUT_KIND:
            if self.input.text.byte_length() + event.text.byte_length() > MAX_TEXT:
                return False
            if event.replacement_start >= 0:
                return self.input.replace_text_range(event.text, event.replacement_start, event.replacement_end)
            return self.input.insert_text(event.text)
        if event.kind == COMPOSITION_UPDATE_KIND:
            if event.text.byte_length() <= MAX_TEXT:
                self.input.set_composition(event.text, event.selection_start, event.selection_end)
            return True
        if event.kind == COMPOSITION_END_KIND:
            self.input.clear_composition()
            return True
        if event.kind == KEY_DOWN_KIND:
            return self.input.handle_key(event.key, event.modifiers)
        return False

    def clipboard_copy(mut self, target: Int, view: ColumnView) -> String:
        return self.input.selected_text() if target == 1 else ""
    def clipboard_cut(mut self, target: Int, view: ColumnView) -> String:
        var text = self.input.selected_text() if target == 1 else ""
        if target == 1:
            _ = self.input.cut_selection()
        return text
    def clipboard_paste(mut self, target: Int, text: String, view: ColumnView) -> Bool:
        return self.input.insert_text(text) if target == 1 and self.input.text.byte_length() + text.byte_length() <= MAX_TEXT else False
