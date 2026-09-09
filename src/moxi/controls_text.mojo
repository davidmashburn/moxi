"""Multi-character text editing control descriptors and their editing state."""


from .event import (
    KEY_A,
    KEY_BACKSPACE,
    KEY_C,
    KEY_DELETE,
    KEY_END,
    KEY_ESCAPE,
    KEY_HOME,
    KEY_LEFT,
    KEY_RIGHT,
    KEY_SPACE,
    KEY_UP,
    KEY_DOWN,
    KEY_ENTER,
    KEY_V,
    KEY_X,
    MOD_COMMAND,
    MOD_CONTROL,
    MOD_SHIFT,
)
from .style import Style, default_multiline_style, default_text_input_style
from .text_boundary import (
    clamp_text_boundary,
    next_text_boundary,
    previous_text_boundary,
)
from .view_node import MULTILINE_TEXT_KIND, TEXT_INPUT_VIEW_KIND, ViewNode


struct TextInputControl(ImplicitlyCopyable):
    """A reusable declarative single-line text-input descriptor."""

    var id: Int
    var text: String
    var cursor: Int
    var selection_anchor: Int
    var composition: String
    var composition_selection_start: Int
    var composition_selection_end: Int
    var preferred_height: Float32
    var style: Style
    var enabled: Bool

    def __init__(
        out self,
        id: Int,
        text: String,
        cursor: Int,
        preferred_height: Float32,
    ):
        self.id = id
        self.text = text
        self.cursor = cursor
        self.selection_anchor = -1
        self.composition = ""
        self.composition_selection_start = 0
        self.composition_selection_end = 0
        self.preferred_height = preferred_height
        self.style = default_text_input_style()
        self.enabled = True

    def __init__(
        out self,
        id: Int,
        text: String,
        cursor: Int,
        selection_anchor: Int,
        preferred_height: Float32,
    ):
        self.id = id
        self.text = text
        self.cursor = cursor
        self.selection_anchor = selection_anchor
        self.composition = ""
        self.composition_selection_start = 0
        self.composition_selection_end = 0
        self.preferred_height = preferred_height
        self.style = default_text_input_style()
        self.enabled = True

    def __init__(
        out self,
        id: Int,
        text: String,
        cursor: Int,
        preferred_height: Float32,
        style: Style,
        enabled: Bool = True,
    ):
        self.id = id
        self.text = text
        self.cursor = cursor
        self.selection_anchor = -1
        self.composition = ""
        self.composition_selection_start = 0
        self.composition_selection_end = 0
        self.preferred_height = preferred_height
        self.style = style
        self.enabled = enabled

    def __init__(
        out self,
        id: Int,
        text: String,
        cursor: Int,
        selection_anchor: Int,
        preferred_height: Float32,
        style: Style,
        enabled: Bool = True,
    ):
        self.id = id
        self.text = text
        self.cursor = cursor
        self.selection_anchor = selection_anchor
        self.composition = ""
        self.composition_selection_start = 0
        self.composition_selection_end = 0
        self.preferred_height = preferred_height
        self.style = style
        self.enabled = enabled

    def set_composition(
        mut self,
        text: String,
        selection_start: Int,
        selection_end: Int,
    ):
        """Attach transient IME text to the descriptor before building its node."""
        self.composition = text
        self.composition_selection_start = selection_start
        self.composition_selection_end = selection_end

    def node(self) -> ViewNode:
        var node = ViewNode(
            TEXT_INPUT_VIEW_KIND,
            self.id,
            self.text,
            self.preferred_height,
            self.style,
            self.cursor,
            self.selection_anchor,
        )
        node.set_composition(
            self.composition,
            self.composition_selection_start,
            self.composition_selection_end,
        )
        node.enabled = self.enabled
        node.semantics.enabled = self.enabled
        return node


struct TextInputState(ImplicitlyCopyable):
    """Unicode/codepoint-safe editing state for a single-line text input."""

    var text: String
    var cursor: Int
    var anchor: Int
    var clipboard: String
    var composition: String
    var composition_selection_start: Int
    var composition_selection_end: Int

    def __init__(out self):
        self.text = ""
        self.cursor = 0
        self.anchor = -1
        self.clipboard = ""
        self.composition = ""
        self.composition_selection_start = 0
        self.composition_selection_end = 0

    def has_composition(self) -> Bool:
        """Return whether transient marked text is currently active."""
        return self.composition.count_codepoints() > 0

    def set_composition(
        mut self,
        text: String,
        selection_start: Int,
        selection_end: Int,
    ):
        """Replace marked text while preserving the committed text and cursor."""
        self.composition = text
        var length = text.count_codepoints()
        var start = selection_start
        var end = selection_end
        if start < 0:
            start = 0
        if start > length:
            start = length
        if end < start:
            end = start
        if end > length:
            end = length
        self.composition_selection_start = start
        self.composition_selection_end = end

    def clear_composition(mut self):
        """Discard marked text without modifying committed input."""
        self.composition = ""
        self.composition_selection_start = 0
        self.composition_selection_end = 0

    def __init__(out self, text: String):
        self.text = text
        self.cursor = text.count_codepoints()
        self.anchor = -1
        self.clipboard = ""
        self.composition = ""
        self.composition_selection_start = 0
        self.composition_selection_end = 0

    def set_text(mut self, text: String):
        self.text = text
        self.cursor = clamp_text_boundary(text, self.cursor)
        self.anchor = -1
        self.clear_composition()

    def has_selection(self) -> Bool:
        return self.anchor != -1 and self.anchor != self.cursor

    def selection_start(self) -> Int:
        if self.anchor == -1 or self.anchor >= self.cursor:
            return self.cursor if self.anchor == -1 else self.cursor
        return self.anchor

    def selection_end(self) -> Int:
        if self.anchor == -1 or self.anchor <= self.cursor:
            return self.cursor if self.anchor == -1 else self.cursor
        return self.anchor

    def clear_selection(mut self):
        self.anchor = -1

    def select_all(mut self) -> Bool:
        var length = self.text.count_codepoints()
        if length == 0:
            return False
        self.anchor = 0
        self.cursor = length
        return True

    def selected_text(self) -> String:
        """Return the selected codepoint range, or an empty string."""
        if not self.has_selection():
            return ""
        var start = self.selection_start()
        var end = self.selection_end()
        return String(self.text[codepoint=start:end])

    def copy_selection(mut self) -> Bool:
        """Copy the current selection into this input's portable clipboard."""
        if not self.has_selection():
            return False
        self.clipboard = self.selected_text()
        return True

    def cut_selection(mut self) -> Bool:
        """Copy and remove the current selection."""
        if not self.has_selection():
            return False
        self.clipboard = self.selected_text()
        return self.delete_selection()

    def paste_clipboard(mut self) -> Bool:
        """Insert the last copied or cut text at the current cursor."""
        if self.clipboard.count_codepoints() == 0:
            return False
        var clipboard = self.clipboard
        return self.insert_text(clipboard)

    def insert_text(mut self, text: String) -> Bool:
        if text.count_codepoints() == 0:
            return False
        self.clear_composition()
        _ = self.delete_selection()
        var before = self.text[codepoint=0:self.cursor]
        var after = self.text[codepoint=self.cursor:]
        var updated = String(before)
        updated += text
        updated += after
        self.text = updated
        self.cursor += text.count_codepoints()
        self.anchor = -1
        return True

    def replace_text_range(
        mut self,
        text: String,
        replacement_start: Int,
        replacement_end: Int,
    ) -> Bool:
        """Replace a native IME range using codepoint offsets."""
        var length = self.text.count_codepoints()
        var start = replacement_start
        var end = replacement_end
        if start < 0:
            start = 0
        if end < start:
            end = start
        if start > length:
            start = length
        if end > length:
            end = length
        self.clear_composition()
        var before = self.text[codepoint=0:start]
        var after = self.text[codepoint=end:]
        var updated = String(before)
        updated += text
        updated += after
        self.text = updated
        self.cursor = start + text.count_codepoints()
        self.anchor = -1
        return text.count_codepoints() > 0 or start != end

    def delete_selection(mut self) -> Bool:
        if not self.has_selection():
            return False
        var start = self.selection_start()
        var end = self.selection_end()
        var before = self.text[codepoint=0:start]
        var after = self.text[codepoint=end:]
        var updated = String(before)
        updated += after
        self.text = updated
        self.cursor = start
        self.anchor = -1
        return True

    def delete_backward(mut self) -> Bool:
        if self.delete_selection():
            return True
        if self.cursor == 0:
            return False
        var previous = previous_text_boundary(self.text, self.cursor)
        var before = self.text[codepoint=0:previous]
        var after = self.text[codepoint=self.cursor:]
        var updated = String(before)
        updated += after
        self.text = updated
        self.cursor = previous
        return True

    def delete_forward(mut self) -> Bool:
        if self.delete_selection():
            return True
        var length = self.text.count_codepoints()
        if self.cursor >= length:
            return False
        var before = self.text[codepoint=0:self.cursor]
        var after = self.text[codepoint=next_text_boundary(self.text, self.cursor):]
        var updated = String(before)
        updated += after
        self.text = updated
        return True

    def move_left(mut self, extend: Bool) -> Bool:
        if not extend and self.has_selection():
            self.cursor = self.selection_start()
            self.anchor = -1
            return True
        if self.cursor == 0:
            return False
        if extend and self.anchor == -1:
            self.anchor = self.cursor
        self.cursor = previous_text_boundary(self.text, self.cursor)
        if not extend:
            self.anchor = -1
        return True

    def move_right(mut self, extend: Bool) -> Bool:
        if not extend and self.has_selection():
            self.cursor = self.selection_end()
            self.anchor = -1
            return True
        if self.cursor >= self.text.count_codepoints():
            return False
        if extend and self.anchor == -1:
            self.anchor = self.cursor
        self.cursor = next_text_boundary(self.text, self.cursor)
        if not extend:
            self.anchor = -1
        return True

    def move_home(mut self, extend: Bool) -> Bool:
        if extend and self.anchor == -1:
            self.anchor = self.cursor
        var changed = self.cursor != 0
        self.cursor = 0
        if not extend:
            self.anchor = -1
        return changed

    def move_end(mut self, extend: Bool) -> Bool:
        if extend and self.anchor == -1:
            self.anchor = self.cursor
        var end = self.text.count_codepoints()
        var changed = self.cursor != end
        self.cursor = end
        if not extend:
            self.anchor = -1
        return changed

    def handle_key(mut self, key: Int, modifiers: Int) -> Bool:
        var extend = (modifiers & MOD_SHIFT) != 0
        var clipboard_modifier = (modifiers & (MOD_COMMAND | MOD_CONTROL)) != 0
        if key == KEY_ESCAPE and self.has_composition():
            self.clear_composition()
            return True
        if clipboard_modifier and key == KEY_C:
            return self.copy_selection()
        if clipboard_modifier and key == KEY_X:
            return self.cut_selection()
        if clipboard_modifier and key == KEY_V:
            return self.paste_clipboard()
        if key == KEY_BACKSPACE:
            return self.delete_backward()
        if key == KEY_DELETE:
            return self.delete_forward()
        if key == KEY_LEFT:
            return self.move_left(extend)
        if key == KEY_RIGHT:
            return self.move_right(extend)
        if key == KEY_HOME:
            return self.move_home(extend)
        if key == KEY_END:
            return self.move_end(extend)
        if key == KEY_SPACE and (modifiers & MOD_COMMAND) == 0:
            return self.insert_text(" ")
        if key == KEY_A and (modifiers & MOD_COMMAND) != 0:
            return self.select_all()
        return False


struct MultilineTextControl(ImplicitlyCopyable):
    """A wrapped text editor descriptor for a future native editor bridge."""

    var id: Int
    var text: String
    var cursor: Int
    var selection_anchor: Int
    var preferred_height: Float32
    var style: Style
    var enabled: Bool

    def __init__(
        out self,
        id: Int,
        text: String,
        preferred_height: Float32,
    ):
        self.id = id
        self.text = text
        self.cursor = text.count_codepoints()
        self.selection_anchor = -1
        self.preferred_height = preferred_height
        self.style = default_multiline_style()
        self.enabled = True

    def node(self) -> ViewNode:
        var node = ViewNode(
            MULTILINE_TEXT_KIND,
            self.id,
            self.text,
            self.preferred_height,
            self.style,
            self.cursor,
            self.selection_anchor,
        )
        node.set_wrap_text()
        node.enabled = self.enabled
        node.semantics.enabled = self.enabled
        return node


struct MultilineTextState(ImplicitlyCopyable):
    """Editing state that allows newline insertion in a text area."""

    var input: TextInputState

    def __init__(out self, text: String = ""):
        self.input = TextInputState(text)

    def text(self) -> String:
        return self.input.text

    def cursor(self) -> Int:
        return self.input.cursor

    def set_text(mut self, text: String):
        self.input.set_text(text)

    def handle_key(mut self, key: Int, modifiers: Int) -> Bool:
        if key == KEY_ENTER and (modifiers & MOD_COMMAND) == 0:
            return self.input.insert_text("\n")
        return self.input.handle_key(key, modifiers)

    def insert_text(mut self, text: String) -> Bool:
        return self.input.insert_text(text)
