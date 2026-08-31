"""Reusable control descriptors and single-line text editing state."""

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
from .geometry import Point, Rect
from .style import (
    Style,
    default_button_style,
    default_checkbox_style,
    default_label_style,
    default_progress_style,
    default_text_input_style,
    default_slider_style,
    default_switch_style,
    default_radio_style,
    default_image_style,
    default_multiline_style,
)
from .text_boundary import (
    clamp_text_boundary,
    next_text_boundary,
    previous_text_boundary,
)
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
    ViewNode,
)


struct LabelControl(ImplicitlyCopyable):
    """A reusable declarative label descriptor."""

    var id: Int
    var text: String
    var preferred_height: Float32
    var style: Style

    def __init__(
        out self,
        id: Int,
        text: String,
        preferred_height: Float32,
    ):
        self.id = id
        self.text = text
        self.preferred_height = preferred_height
        self.style = default_label_style()

    def __init__(
        out self,
        id: Int,
        text: String,
        preferred_height: Float32,
        style: Style,
    ):
        self.id = id
        self.text = text
        self.preferred_height = preferred_height
        self.style = style

    def node(self) -> ViewNode:
        return ViewNode(
            LABEL_KIND,
            self.id,
            self.text,
            self.preferred_height,
            self.style,
        )


struct ButtonControl(ImplicitlyCopyable):
    """A reusable declarative button descriptor."""

    var id: Int
    var text: String
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
        self.preferred_height = preferred_height
        self.style = default_button_style()
        self.enabled = True

    def __init__(
        out self,
        id: Int,
        text: String,
        preferred_height: Float32,
        style: Style,
        enabled: Bool = True,
    ):
        self.id = id
        self.text = text
        self.preferred_height = preferred_height
        self.style = style
        self.enabled = enabled

    def node(self) -> ViewNode:
        var node = ViewNode(
            BUTTON_KIND,
            self.id,
            self.text,
            self.preferred_height,
            self.style,
        )
        node.enabled = self.enabled
        node.semantics.enabled = self.enabled
        return node


struct CheckboxControl(ImplicitlyCopyable):
    """A reusable, keyboard-focusable checkbox descriptor."""

    var id: Int
    var text: String
    var checked: Bool
    var preferred_height: Float32
    var style: Style
    var enabled: Bool

    def __init__(
        out self,
        id: Int,
        text: String,
        checked: Bool,
        preferred_height: Float32,
    ):
        self.id = id
        self.text = text
        self.checked = checked
        self.preferred_height = preferred_height
        self.style = default_checkbox_style()
        self.enabled = True

    def __init__(
        out self,
        id: Int,
        text: String,
        checked: Bool,
        preferred_height: Float32,
        style: Style,
        enabled: Bool = True,
    ):
        self.id = id
        self.text = text
        self.checked = checked
        self.preferred_height = preferred_height
        self.style = style
        self.enabled = enabled

    def node(self) -> ViewNode:
        var node = ViewNode(
            CHECKBOX_KIND,
            self.id,
            self.text,
            self.preferred_height,
            self.style,
        )
        node.set_checked(self.checked)
        node.enabled = self.enabled
        node.semantics.enabled = self.enabled
        return node


struct ProgressControl(ImplicitlyCopyable):
    """A non-interactive determinate progress indicator descriptor."""

    var id: Int
    var text: String
    var progress: Float32
    var preferred_height: Float32
    var style: Style

    def __init__(
        out self,
        id: Int,
        text: String,
        progress: Float32,
        preferred_height: Float32,
    ):
        self.id = id
        self.text = text
        self.progress = progress
        self.preferred_height = preferred_height
        self.style = default_progress_style()

    def __init__(
        out self,
        id: Int,
        text: String,
        progress: Float32,
        preferred_height: Float32,
        style: Style,
    ):
        self.id = id
        self.text = text
        self.progress = progress
        self.preferred_height = preferred_height
        self.style = style

    def node(self) -> ViewNode:
        var node = ViewNode(
            PROGRESS_KIND,
            self.id,
            self.text,
            self.preferred_height,
            self.style,
        )
        node.set_progress(self.progress)
        return node


struct SliderControl(ImplicitlyCopyable):
    """A keyboard-focusable scalar slider with an explicit numeric range."""

    var id: Int
    var text: String
    var value: Float32
    var minimum: Float32
    var maximum: Float32
    var step: Float32
    var preferred_height: Float32
    var style: Style
    var enabled: Bool

    def __init__(
        out self,
        id: Int,
        text: String,
        value: Float32,
        minimum: Float32,
        maximum: Float32,
        step: Float32,
        preferred_height: Float32,
    ):
        self.id = id
        self.text = text
        self.value = value
        self.minimum = minimum
        self.maximum = maximum
        self.step = step if step > 0.0 else 1.0
        self.preferred_height = preferred_height
        self.style = default_slider_style()
        self.enabled = True

    def normalized(self) -> Float32:
        if self.maximum <= self.minimum:
            return 0.0
        var result = (self.value - self.minimum) / (self.maximum - self.minimum)
        if result < 0.0:
            result = 0.0
        if result > 1.0:
            result = 1.0
        return result

    def node(self) -> ViewNode:
        var node = ViewNode(
            SLIDER_KIND,
            self.id,
            self.text,
            self.preferred_height,
            self.style,
        )
        node.set_progress(self.normalized())
        node.set_accessibility_value(String("value ", self.value))
        node.set_accessibility_value_range(self.minimum, self.maximum, self.value)
        node.enabled = self.enabled
        node.semantics.enabled = self.enabled
        return node


struct SwitchControl(ImplicitlyCopyable):
    """A keyboard-focusable on/off switch descriptor."""

    var id: Int
    var text: String
    var checked: Bool
    var preferred_height: Float32
    var style: Style
    var enabled: Bool

    def __init__(
        out self,
        id: Int,
        text: String,
        checked: Bool,
        preferred_height: Float32,
    ):
        self.id = id
        self.text = text
        self.checked = checked
        self.preferred_height = preferred_height
        self.style = default_switch_style()
        self.enabled = True

    def node(self) -> ViewNode:
        var node = ViewNode(
            SWITCH_KIND,
            self.id,
            self.text,
            self.preferred_height,
            self.style,
        )
        node.set_checked(self.checked)
        node.enabled = self.enabled
        node.semantics.enabled = self.enabled
        return node


struct RadioControl(ImplicitlyCopyable):
    """A keyboard-focusable radio option descriptor."""

    var id: Int
    var group_id: Int
    var text: String
    var selected: Bool
    var preferred_height: Float32
    var style: Style
    var enabled: Bool

    def __init__(
        out self,
        id: Int,
        group_id: Int,
        text: String,
        selected: Bool,
        preferred_height: Float32,
    ):
        self.id = id
        self.group_id = group_id
        self.text = text
        self.selected = selected
        self.preferred_height = preferred_height
        self.style = default_radio_style()
        self.enabled = True

    def node(self) -> ViewNode:
        var node = ViewNode(
            RADIO_KIND,
            self.id,
            self.text,
            self.preferred_height,
            self.style,
        )
        node.set_selected(self.selected)
        node.enabled = self.enabled
        node.semantics.enabled = self.enabled
        node.set_accessibility_value(String("group ", self.group_id))
        return node


struct ImageControl(ImplicitlyCopyable):
    """An image descriptor backed by an application-owned resource id."""

    var id: Int
    var alt_text: String
    var resource_id: Int
    var preferred_height: Float32
    var style: Style

    def __init__(
        out self,
        id: Int,
        alt_text: String,
        resource_id: Int,
        preferred_height: Float32,
    ):
        self.id = id
        self.alt_text = alt_text
        self.resource_id = resource_id
        self.preferred_height = preferred_height
        self.style = default_image_style()

    def node(self) -> ViewNode:
        var node = ViewNode(
            IMAGE_KIND,
            self.id,
            self.alt_text,
            self.preferred_height,
            self.style,
        )
        node.set_resource_id(self.resource_id)
        return node


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


struct ComboBoxControl(ImplicitlyCopyable):
    """A focusable single-selection combo-box descriptor."""

    var id: Int
    var text: String
    var selection: String
    var preferred_height: Float32
    var expanded: Bool

    def __init__(
        out self,
        id: Int,
        text: String,
        selection: String,
        preferred_height: Float32,
        expanded: Bool = False,
    ):
        self.id = id
        self.text = text
        self.selection = selection
        self.preferred_height = preferred_height
        self.expanded = expanded

    def node(self) -> ViewNode:
        var node = ViewNode(COMBO_BOX_KIND, self.id, self.text, self.preferred_height)
        node.set_accessibility_value(self.selection)
        node.set_expanded(self.expanded)
        return node


struct ListControl(ImplicitlyCopyable):
    """A list descriptor with item-count semantics."""

    var id: Int
    var text: String
    var item_count: Int
    var preferred_height: Float32

    def __init__(out self, id: Int, text: String, item_count: Int, preferred_height: Float32):
        self.id = id
        self.text = text
        self.item_count = item_count if item_count > 0 else 0
        self.preferred_height = preferred_height

    def node(self) -> ViewNode:
        var node = ViewNode(LIST_KIND, self.id, self.text, self.preferred_height)
        node.set_accessibility_value(String("items ", self.item_count))
        return node


struct TableControl(ImplicitlyCopyable):
    """A table descriptor; cells remain application-owned child views."""

    var id: Int
    var text: String
    var columns: Int
    var preferred_height: Float32

    def __init__(out self, id: Int, text: String, columns: Int, preferred_height: Float32):
        self.id = id
        self.text = text
        self.columns = columns if columns > 0 else 1
        self.preferred_height = preferred_height

    def node(self) -> ViewNode:
        var node = ViewNode(TABLE_KIND, self.id, self.text, self.preferred_height)
        node.set_accessibility_value(String("columns ", self.columns))
        return node


struct TreeControl(ImplicitlyCopyable):
    """A tree descriptor whose expanded children are ordinary view nodes."""

    var id: Int
    var text: String
    var expanded: Bool
    var preferred_height: Float32

    def __init__(out self, id: Int, text: String, expanded: Bool, preferred_height: Float32):
        self.id = id
        self.text = text
        self.expanded = expanded
        self.preferred_height = preferred_height

    def node(self) -> ViewNode:
        var node = ViewNode(TREE_KIND, self.id, self.text, self.preferred_height)
        if self.expanded:
            node.set_accessibility_value("expanded")
        else:
            node.set_accessibility_value("collapsed")
        node.set_expanded(self.expanded)
        return node


struct MenuControl(ImplicitlyCopyable):
    """A menu descriptor with application-owned menu-item children."""

    var id: Int
    var text: String
    var preferred_height: Float32

    def __init__(out self, id: Int, text: String, preferred_height: Float32):
        self.id = id
        self.text = text
        self.preferred_height = preferred_height

    def node(self) -> ViewNode:
        return ViewNode(MENU_KIND, self.id, self.text, self.preferred_height)


struct DialogControl(ImplicitlyCopyable):
    """A dialog surface descriptor; buttons can be composed beneath it."""

    var id: Int
    var text: String
    var open: Bool
    var preferred_height: Float32

    def __init__(out self, id: Int, text: String, open: Bool, preferred_height: Float32):
        self.id = id
        self.text = text
        self.open = open
        self.preferred_height = preferred_height

    def node(self) -> ViewNode:
        var node = ViewNode(DIALOG_KIND, self.id, self.text, self.preferred_height)
        node.enabled = self.open
        node.semantics.enabled = self.open
        node.set_expanded(self.open)
        return node


struct TabsControl(ImplicitlyCopyable):
    """A tab-group descriptor with a selected-tab semantic value."""

    var id: Int
    var text: String
    var selected_index: Int
    var preferred_height: Float32

    def __init__(out self, id: Int, text: String, selected_index: Int, preferred_height: Float32):
        self.id = id
        self.text = text
        self.selected_index = selected_index if selected_index >= 0 else 0
        self.preferred_height = preferred_height

    def node(self) -> ViewNode:
        var node = ViewNode(TABS_KIND, self.id, self.text, self.preferred_height)
        node.set_accessibility_value(String("selected ", self.selected_index))
        return node


struct CanvasControl(ImplicitlyCopyable):
    """A custom drawing surface descriptor for app-owned scene content."""

    var id: Int
    var text: String
    var preferred_height: Float32

    def __init__(out self, id: Int, text: String, preferred_height: Float32):
        self.id = id
        self.text = text
        self.preferred_height = preferred_height

    def node(self) -> ViewNode:
        return ViewNode(CANVAS_KIND, self.id, self.text, self.preferred_height)


struct SeparatorControl(ImplicitlyCopyable):
    """A non-focusable visual separator."""

    var id: Int
    var preferred_height: Float32

    def __init__(out self, id: Int, preferred_height: Float32 = 1.0):
        self.id = id
        self.preferred_height = preferred_height

    def node(self) -> ViewNode:
        return ViewNode(SEPARATOR_KIND, self.id, "", self.preferred_height)


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


struct SliderState(ImplicitlyCopyable):
    """State and keyboard/pointer behavior for a scalar slider."""

    var value: Float32
    var minimum: Float32
    var maximum: Float32
    var step: Float32

    def __init__(
        out self,
        value: Float32 = 0.0,
        minimum: Float32 = 0.0,
        maximum: Float32 = 1.0,
        step: Float32 = 0.1,
    ):
        self.minimum = minimum
        self.maximum = maximum if maximum >= minimum else minimum
        self.step = step if step > 0.0 else 0.1
        self.value = value
        _ = self.set_value(value)

    def set_value(mut self, value: Float32) -> Bool:
        var next = value
        if next < self.minimum:
            next = self.minimum
        if next > self.maximum:
            next = self.maximum
        if next == self.value:
            return False
        self.value = next
        return True

    def normalized(self) -> Float32:
        if self.maximum <= self.minimum:
            return 0.0
        return (self.value - self.minimum) / (self.maximum - self.minimum)

    def nudge(mut self, direction: Int) -> Bool:
        return self.set_value(self.value + self.step * Float32(direction))

    def set_from_position(mut self, position: Point, bounds: Rect) -> Bool:
        if bounds.width <= 0.0:
            return False
        var fraction = (position.x - bounds.x) / bounds.width
        if fraction < 0.0:
            fraction = 0.0
        if fraction > 1.0:
            fraction = 1.0
        var raw = self.minimum + fraction * (self.maximum - self.minimum)
        var steps = Int((raw - self.minimum) / self.step + 0.5)
        return self.set_value(self.minimum + Float32(steps) * self.step)

    def handle_key(mut self, key: Int) -> Bool:
        if key == KEY_LEFT or key == KEY_DOWN:
            return self.nudge(-1)
        if key == KEY_RIGHT or key == KEY_UP:
            return self.nudge(1)
        if key == KEY_HOME:
            return self.set_value(self.minimum)
        if key == KEY_END:
            return self.set_value(self.maximum)
        return False


struct ToggleState(ImplicitlyCopyable):
    """Shared state behavior for switches and checkboxes."""

    var checked: Bool

    def __init__(out self, checked: Bool = False):
        self.checked = checked

    def toggle(mut self) -> Bool:
        self.checked = not self.checked
        return True

    def set_checked(mut self, checked: Bool) -> Bool:
        if self.checked == checked:
            return False
        self.checked = checked
        return True


struct RadioGroupState(ImplicitlyCopyable):
    """Single-selection state shared by a group of radio descriptors."""

    var selected_id: Int
    var group_id: Int

    def __init__(out self, group_id: Int, selected_id: Int = -1):
        self.group_id = group_id
        self.selected_id = selected_id

    def select(mut self, id: Int) -> Bool:
        if self.selected_id == id:
            return False
        self.selected_id = id
        return True

    def is_selected(self, id: Int) -> Bool:
        return self.selected_id == id


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
