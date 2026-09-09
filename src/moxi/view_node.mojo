"""`ViewNode`: the lightweight declarative leaf in a Moxi view tree.

Also defines the view-kind discriminant constants that tag every
`ViewNode.kind` and the reserved root-scroll target id.
"""


from .accessibility import Semantics, default_semantics
from .geometry import Rect, Size
from .layout import ALIGN_STRETCH, COLUMN_AXIS, JUSTIFY_START, LAYOUT_LINEAR
from .style import (
    Style,
    default_button_style,
    default_label_style,
    default_panel_style,
    default_text_input_style,
    default_checkbox_style,
    default_progress_style,
    default_slider_style,
    default_switch_style,
    default_radio_style,
    default_image_style,
    default_multiline_style,
)
from .measure import measure_text, measure_text_wrapped


comptime LABEL_KIND = 1
comptime BUTTON_KIND = 2
comptime TEXT_INPUT_VIEW_KIND = 5
comptime SPACER_KIND = 6
comptime CONTAINER_KIND = 7
comptime CHECKBOX_KIND = 8
comptime PROGRESS_KIND = 9
comptime SLIDER_KIND = 10
comptime SWITCH_KIND = 11
comptime RADIO_KIND = 12
comptime IMAGE_KIND = 13
comptime MULTILINE_TEXT_KIND = 14
comptime COMBO_BOX_KIND = 15
comptime LIST_KIND = 16
comptime TABLE_KIND = 17
comptime TREE_KIND = 18
comptime MENU_KIND = 19
comptime DIALOG_KIND = 20
comptime TABS_KIND = 21
comptime CANVAS_KIND = 22
comptime SEPARATOR_KIND = 23
# Paint-only affordance emitted for overflowing scroll containers.
comptime SCROLLBAR_KIND = 24
# Reserved target for the implicit viewport owned by a ColumnView root.
comptime ROOT_SCROLL_ID = -2


struct ViewNode(ImplicitlyCopyable):
    """A lightweight leaf in a declarative Moxi view tree."""

    var kind: Int
    var id: Int
    var text: String
    var preferred_height: Float32
    var preferred_width: Float32
    var min_width: Float32
    var max_width: Float32
    var min_height: Float32
    var max_height: Float32
    var use_intrinsic_width: Bool
    var use_intrinsic_height: Bool
    var wrap_text: Bool
    var action_id: Int
    var clip_children: Bool
    var checked: Bool
    var progress: Float32
    var bounds: Rect
    var style: Style
    var component_surface: Bool
    var focusable: Bool
    var enabled: Bool
    var cursor: Int
    var selection_anchor: Int
    var composition: String
    var composition_selection_start: Int
    var composition_selection_end: Int
    var semantics: Semantics
    var parent_id: Int
    var container_axis: Int
    var container_padding: Float32
    var container_spacing: Float32
    var container_main_alignment: Int
    var container_cross_alignment: Int
    var container_layout_kind: Int
    var container_grid_columns: Int
    var container_split_fraction: Float32
    var container_scroll_offset: Float32
    var resource_id: Int

    def __init__(
        out self,
        kind: Int,
        id: Int,
        text: String,
        preferred_height: Float32,
    ):
        var style = default_label_style()
        if kind == BUTTON_KIND:
            style = default_button_style()
        elif kind == TEXT_INPUT_VIEW_KIND:
            style = default_text_input_style()
        elif kind == CHECKBOX_KIND:
            style = default_checkbox_style()
        elif kind == PROGRESS_KIND:
            style = default_progress_style()
        elif kind == SLIDER_KIND:
            style = default_slider_style()
        elif kind == SWITCH_KIND:
            style = default_switch_style()
        elif kind == RADIO_KIND:
            style = default_radio_style()
        elif kind == IMAGE_KIND:
            style = default_image_style()
        elif kind == MULTILINE_TEXT_KIND:
            style = default_multiline_style()
        elif (
            kind == COMBO_BOX_KIND
            or kind == LIST_KIND
            or kind == TABLE_KIND
            or kind == TREE_KIND
            or kind == MENU_KIND
            or kind == TABS_KIND
        ):
            style = default_text_input_style()
        elif kind == DIALOG_KIND or kind == CANVAS_KIND:
            style = default_panel_style()
        elif kind == SEPARATOR_KIND:
            style = default_progress_style()
        self.kind = kind
        self.id = id
        self.text = text
        self.preferred_height = preferred_height
        self.preferred_width = 0.0
        self.min_width = 0.0
        self.max_width = 0.0
        self.min_height = 0.0
        self.max_height = 0.0
        self.use_intrinsic_width = False
        self.use_intrinsic_height = False
        self.wrap_text = False
        self.action_id = -1
        self.clip_children = False
        self.checked = False
        self.progress = 0.0
        self.bounds = Rect(0.0, 0.0, 0.0, 0.0)
        self.style = style
        self.component_surface = False
        self.focusable = (
            kind == BUTTON_KIND
            or kind == TEXT_INPUT_VIEW_KIND
            or kind == CHECKBOX_KIND
            or kind == SLIDER_KIND
            or kind == SWITCH_KIND
            or kind == RADIO_KIND
            or kind == MULTILINE_TEXT_KIND
            or kind == DIALOG_KIND
            or kind == CANVAS_KIND
            or kind == COMBO_BOX_KIND
            or kind == LIST_KIND
            or kind == TABLE_KIND
            or kind == TREE_KIND
            or kind == TABS_KIND
            or kind == MENU_KIND
        )
        self.enabled = True
        self.cursor = 0
        self.selection_anchor = -1
        self.composition = ""
        self.composition_selection_start = 0
        self.composition_selection_end = 0
        self.semantics = default_semantics(id, kind, text)
        self.parent_id = -1
        self.container_axis = COLUMN_AXIS
        self.container_padding = 0.0
        self.container_spacing = 0.0
        self.container_main_alignment = JUSTIFY_START
        self.container_cross_alignment = ALIGN_STRETCH
        self.container_layout_kind = LAYOUT_LINEAR
        self.container_grid_columns = 1
        self.container_split_fraction = 0.5
        self.container_scroll_offset = 0.0
        self.resource_id = -1

    def __init__(
        out self,
        kind: Int,
        id: Int,
        text: String,
        preferred_height: Float32,
        style: Style,
    ):
        self.kind = kind
        self.id = id
        self.text = text
        self.preferred_height = preferred_height
        self.preferred_width = 0.0
        self.min_width = 0.0
        self.max_width = 0.0
        self.min_height = 0.0
        self.max_height = 0.0
        self.use_intrinsic_width = False
        self.use_intrinsic_height = False
        self.wrap_text = False
        self.action_id = -1
        self.clip_children = False
        self.checked = False
        self.progress = 0.0
        self.bounds = Rect(0.0, 0.0, 0.0, 0.0)
        self.style = style
        self.component_surface = False
        self.focusable = (
            kind == BUTTON_KIND
            or kind == TEXT_INPUT_VIEW_KIND
            or kind == CHECKBOX_KIND
            or kind == SLIDER_KIND
            or kind == SWITCH_KIND
            or kind == RADIO_KIND
            or kind == MULTILINE_TEXT_KIND
            or kind == DIALOG_KIND
            or kind == CANVAS_KIND
            or kind == COMBO_BOX_KIND
            or kind == LIST_KIND
            or kind == TABLE_KIND
            or kind == TREE_KIND
            or kind == TABS_KIND
            or kind == MENU_KIND
        )
        self.enabled = True
        self.cursor = 0
        self.selection_anchor = -1
        self.composition = ""
        self.composition_selection_start = 0
        self.composition_selection_end = 0
        self.semantics = default_semantics(id, kind, text)
        self.parent_id = -1
        self.container_axis = COLUMN_AXIS
        self.container_padding = 0.0
        self.container_spacing = 0.0
        self.container_main_alignment = JUSTIFY_START
        self.container_cross_alignment = ALIGN_STRETCH
        self.container_layout_kind = LAYOUT_LINEAR
        self.container_grid_columns = 1
        self.container_split_fraction = 0.5
        self.container_scroll_offset = 0.0
        self.resource_id = -1

    def __init__(
        out self,
        kind: Int,
        id: Int,
        text: String,
        preferred_height: Float32,
        style: Style,
        cursor: Int,
    ):
        self.kind = kind
        self.id = id
        self.text = text
        self.preferred_height = preferred_height
        self.preferred_width = 0.0
        self.min_width = 0.0
        self.max_width = 0.0
        self.min_height = 0.0
        self.max_height = 0.0
        self.use_intrinsic_width = False
        self.use_intrinsic_height = False
        self.wrap_text = False
        self.action_id = -1
        self.clip_children = False
        self.checked = False
        self.progress = 0.0
        self.bounds = Rect(0.0, 0.0, 0.0, 0.0)
        self.style = style
        self.component_surface = False
        self.focusable = (
            kind == BUTTON_KIND
            or kind == TEXT_INPUT_VIEW_KIND
            or kind == CHECKBOX_KIND
            or kind == SLIDER_KIND
            or kind == SWITCH_KIND
            or kind == RADIO_KIND
            or kind == MULTILINE_TEXT_KIND
            or kind == DIALOG_KIND
            or kind == CANVAS_KIND
            or kind == COMBO_BOX_KIND
            or kind == LIST_KIND
            or kind == TABLE_KIND
            or kind == TREE_KIND
            or kind == TABS_KIND
            or kind == MENU_KIND
        )
        self.enabled = True
        self.cursor = cursor
        self.selection_anchor = -1
        self.composition = ""
        self.composition_selection_start = 0
        self.composition_selection_end = 0
        self.semantics = default_semantics(id, kind, text)
        self.parent_id = -1
        self.container_axis = COLUMN_AXIS
        self.container_padding = 0.0
        self.container_spacing = 0.0
        self.container_main_alignment = JUSTIFY_START
        self.container_cross_alignment = ALIGN_STRETCH
        self.container_layout_kind = LAYOUT_LINEAR
        self.container_grid_columns = 1
        self.container_split_fraction = 0.5
        self.container_scroll_offset = 0.0
        self.resource_id = -1

    def __init__(
        out self,
        kind: Int,
        id: Int,
        text: String,
        preferred_height: Float32,
        style: Style,
        cursor: Int,
        selection_anchor: Int,
    ):
        self.kind = kind
        self.id = id
        self.text = text
        self.preferred_height = preferred_height
        self.preferred_width = 0.0
        self.min_width = 0.0
        self.max_width = 0.0
        self.min_height = 0.0
        self.max_height = 0.0
        self.use_intrinsic_width = False
        self.use_intrinsic_height = False
        self.wrap_text = False
        self.action_id = -1
        self.clip_children = False
        self.checked = False
        self.progress = 0.0
        self.bounds = Rect(0.0, 0.0, 0.0, 0.0)
        self.style = style
        self.component_surface = False
        self.focusable = (
            kind == BUTTON_KIND
            or kind == TEXT_INPUT_VIEW_KIND
            or kind == CHECKBOX_KIND
            or kind == SLIDER_KIND
            or kind == SWITCH_KIND
            or kind == RADIO_KIND
            or kind == MULTILINE_TEXT_KIND
            or kind == DIALOG_KIND
            or kind == CANVAS_KIND
            or kind == COMBO_BOX_KIND
            or kind == LIST_KIND
            or kind == TABLE_KIND
            or kind == TREE_KIND
            or kind == TABS_KIND
            or kind == MENU_KIND
        )
        self.enabled = True
        self.cursor = cursor
        self.selection_anchor = selection_anchor
        self.composition = ""
        self.composition_selection_start = 0
        self.composition_selection_end = 0
        self.semantics = default_semantics(id, kind, text)
        self.parent_id = -1
        self.container_axis = COLUMN_AXIS
        self.container_padding = 0.0
        self.container_spacing = 0.0
        self.container_main_alignment = JUSTIFY_START
        self.container_cross_alignment = ALIGN_STRETCH
        self.container_layout_kind = LAYOUT_LINEAR
        self.container_grid_columns = 1
        self.container_split_fraction = 0.5
        self.container_scroll_offset = 0.0
        self.resource_id = -1

    def set_accessibility_label(mut self, label: String):
        self.semantics.label = label

    def set_style(mut self, style: Style):
        """Replace the backend-neutral style of this node."""
        self.style = style

    def set_accessibility_value(mut self, value: String):
        self.semantics.value = value

    def set_accessibility_hint(mut self, hint: String):
        self.semantics.hint = hint

    def set_accessibility_value_range(
        mut self,
        minimum: Float32,
        maximum: Float32,
        current: Float32,
    ):
        """Publish machine-readable scalar range metadata."""
        self.semantics.set_value_range(minimum, maximum, current)

    def set_expanded(mut self, expanded: Bool):
        """Publish disclosure/open state without encoding it in a label."""
        self.semantics.set_expanded(expanded)

    def set_selected(mut self, selected: Bool):
        self.semantics.selected = selected
        if self.kind == CHECKBOX_KIND or self.kind == SWITCH_KIND or self.kind == RADIO_KIND:
            self.checked = selected
            self.semantics.checked = selected
            if selected:
                self.semantics.value = "checked"
            else:
                self.semantics.value = "unchecked"

    def set_checked(mut self, checked: Bool):
        """Set checkbox state and its accessible value together."""
        self.checked = checked
        self.semantics.selected = checked
        self.semantics.checked = checked
        if checked:
            self.semantics.value = "checked"
        else:
            self.semantics.value = "unchecked"

    def set_progress(mut self, progress: Float32):
        """Set a progress fraction, clamped to the public `[0, 1]` range."""
        var value = progress
        if value < 0.0:
            value = 0.0
        if value > 1.0:
            value = 1.0
        self.progress = value
        self.semantics.set_value_range(0.0, 1.0, value)
        var percent = Int(value * 100.0)
        self.semantics.value = String(percent)
        self.semantics.value += "%"

    def set_composition(
        mut self,
        text: String,
        selection_start: Int,
        selection_end: Int,
    ):
        """Store transient IME text without changing committed input text."""
        self.composition = text
        self.composition_selection_start = selection_start
        self.composition_selection_end = selection_end

    def set_intrinsic_width(mut self, enabled: Bool = True):
        """Opt this node into measured width when no fixed width is set."""
        self.use_intrinsic_width = enabled

    def set_intrinsic_height(mut self, enabled: Bool = True):
        """Opt this node into measured height when no fixed height is set."""
        self.use_intrinsic_height = enabled

    def set_wrap_text(mut self, enabled: Bool = True):
        """Opt this node into deterministic wrapping inside its width."""
        self.wrap_text = enabled

    def set_wrap(mut self, enabled: Bool = True):
        """Compatibility spelling for `set_wrap_text()`."""
        self.set_wrap_text(enabled)

    def set_action(mut self, action_id: Int):
        """Attach a stable action id that survives view-id changes."""
        self.action_id = action_id

    def set_action_id(mut self, action_id: Int):
        """Explicit spelling for `set_action()`."""
        self.set_action(action_id)

    def set_clip_children(mut self, enabled: Bool = True):
        """Clip descendants to this container's laid-out bounds."""
        self.clip_children = enabled

    def set_container_layout(mut self, layout_kind: Int):
        """Set the layout policy for a nested container node."""
        self.container_layout_kind = layout_kind

    def set_grid_columns(mut self, columns: Int):
        """Set the number of equal columns used by a grid container."""
        self.container_grid_columns = columns if columns > 0 else 1

    def set_split_fraction(mut self, fraction: Float32):
        """Set the first-pane fraction for a split container."""
        var value = fraction
        if value < 0.0:
            value = 0.0
        if value > 1.0:
            value = 1.0
        self.container_split_fraction = value

    def set_scroll_offset(mut self, offset: Float32):
        """Set the main-axis scroll offset for a scroll container."""
        self.container_scroll_offset = offset if offset > 0.0 else 0.0

    def set_resource_id(mut self, resource_id: Int):
        """Associate an image or external resource with this node."""
        self.resource_id = resource_id

    def set_min_width(mut self, width: Float32):
        """Set the smallest width this node may receive during layout."""
        self.min_width = width if width > 0.0 else 0.0
        if self.max_width > 0.0 and self.max_width < self.min_width:
            self.max_width = self.min_width

    def set_max_width(mut self, width: Float32):
        """Set a maximum width; zero means no maximum."""
        self.max_width = width if width > 0.0 else 0.0
        if self.max_width > 0.0 and self.min_width > self.max_width:
            self.min_width = self.max_width

    def set_min_height(mut self, height: Float32):
        """Set the smallest height this node may receive during layout."""
        self.min_height = height if height > 0.0 else 0.0
        if self.max_height > 0.0 and self.max_height < self.min_height:
            self.max_height = self.min_height

    def set_max_height(mut self, height: Float32):
        """Set a maximum height; zero means no maximum."""
        self.max_height = height if height > 0.0 else 0.0
        if self.max_height > 0.0 and self.min_height > self.max_height:
            self.min_height = self.max_height

    def constrained_width(self, width: Float32) -> Float32:
        var result = width
        if result < self.min_width:
            result = self.min_width
        if self.max_width > 0.0 and result > self.max_width:
            result = self.max_width
        return result

    def constrained_height(self, height: Float32) -> Float32:
        var result = height
        if result < self.min_height:
            result = self.min_height
        if self.max_height > 0.0 and result > self.max_height:
            result = self.max_height
        return result

    def intrinsic_size(self) -> Size:
        """Return a stable content size for this node."""
        var measured: Size
        if self.wrap_text:
            var wrapping_width = self.preferred_width
            if wrapping_width <= 0.0:
                wrapping_width = self.max_width
            if self.kind == BUTTON_KIND:
                wrapping_width -= 32.0
            elif self.kind == TEXT_INPUT_VIEW_KIND:
                wrapping_width -= 24.0
            elif self.kind == CHECKBOX_KIND:
                wrapping_width -= 28.0
            elif self.kind == SWITCH_KIND or self.kind == RADIO_KIND:
                wrapping_width -= 32.0
            elif self.kind == MULTILINE_TEXT_KIND:
                wrapping_width -= 16.0
            if wrapping_width < 0.0:
                wrapping_width = 0.0
            if wrapping_width > 0.0:
                measured = measure_text_wrapped(
                    self.text,
                    self.style,
                    wrapping_width,
                ).size
            else:
                measured = measure_text(self.text, self.style)
        else:
            measured = measure_text(self.text, self.style)
        if self.kind == BUTTON_KIND:
            measured.width += 32.0
            measured.height += 12.0
        elif self.kind == TEXT_INPUT_VIEW_KIND:
            measured.width += 24.0
            if measured.width < 160.0:
                measured.width = 160.0
            measured.height += 12.0
        elif self.kind == CHECKBOX_KIND:
            measured.width += 28.0
            if measured.height < 24.0:
                measured.height = 24.0
        elif self.kind == PROGRESS_KIND:
            if measured.width < 160.0:
                measured.width = 160.0
            if measured.height < 18.0:
                measured.height = 18.0
        elif self.kind == SLIDER_KIND:
            if measured.width < 160.0:
                measured.width = 160.0
            if measured.height < 24.0:
                measured.height = 24.0
        elif self.kind == SWITCH_KIND:
            measured.width += 52.0
            if measured.height < 28.0:
                measured.height = 28.0
        elif self.kind == RADIO_KIND:
            measured.width += 32.0
            if measured.height < 24.0:
                measured.height = 24.0
        elif self.kind == IMAGE_KIND:
            if measured.width < 64.0:
                measured.width = 64.0
            if measured.height < 64.0:
                measured.height = 64.0
        elif self.kind == MULTILINE_TEXT_KIND:
            measured.width += 16.0
            measured.height += 16.0
        elif self.kind == COMBO_BOX_KIND:
            measured.width += 28.0
            if measured.height < 28.0:
                measured.height = 28.0
        elif self.kind == LIST_KIND or self.kind == TABLE_KIND or self.kind == TREE_KIND:
            measured.width += 16.0
            if measured.height < 80.0:
                measured.height = 80.0
        elif self.kind == MENU_KIND or self.kind == TABS_KIND:
            measured.width += 16.0
            if measured.height < 32.0:
                measured.height = 32.0
        elif self.kind == DIALOG_KIND:
            measured.width += 32.0
            measured.height += 32.0
        elif self.kind == CANVAS_KIND:
            if measured.width < 160.0:
                measured.width = 160.0
            if measured.height < 100.0:
                measured.height = 100.0
        elif self.kind == SEPARATOR_KIND:
            measured.width = 1.0
            measured.height = 1.0
        return measured

