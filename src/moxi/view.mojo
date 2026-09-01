"""Declarative view values and the first composable container."""

from std.collections import List

from .accessibility import Semantics, default_semantics
from .geometry import Point, Rect, Size
from .layout import (
    ALIGN_CENTER,
    ALIGN_END,
    ALIGN_START,
    ALIGN_STRETCH,
    COLUMN_AXIS,
    ColumnLayout,
    LAYOUT_GRID,
    LAYOUT_LINEAR,
    LAYOUT_PORTAL,
    LAYOUT_SPLIT,
    LAYOUT_STACK,
    JUSTIFY_CENTER,
    JUSTIFY_END,
    JUSTIFY_SPACE_BETWEEN,
    JUSTIFY_START,
    ROW_AXIS,
    RowLayout,
)
from .style import (
    Panel,
    Style,
    Theme,
    default_button_style,
    default_label_style,
    default_panel_style,
    default_surface_style,
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


struct Label(ImplicitlyCopyable):
    """A declarative text view with stable identity and bounds."""

    var id: Int
    var text: String
    var bounds: Rect

    def __init__(out self, id: Int, text: String, bounds: Rect):
        self.id = id
        self.text = text
        self.bounds = bounds


struct Button(ImplicitlyCopyable):
    """A declarative clickable text view with stable identity and bounds."""

    var id: Int
    var text: String
    var bounds: Rect

    def __init__(out self, id: Int, text: String, bounds: Rect):
        self.id = id
        self.text = text
        self.bounds = bounds


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


def make_counter_column(count: Int, bounds: Rect) -> ColumnView:
    """Build the counter's composed view tree from its current state."""
    var count_text = String("Count: ", count)
    var column = ColumnView(
        bounds,
        32.0,
        8.0,
    )
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
    column.add_label(1, "Moxi Counter", 28.0)
    column.add_label(2, count_text, 40.0)
    column.add_button(3, "Increment", 36.0)
    column.layout()
    return column^


struct ColumnView:
    """A lightweight vertical container of composable leaf views."""

    var layout_spec: ColumnLayout
    var children: List[ViewNode]
    var surface_style: Style
    var panel: Panel
    var has_panel: Bool
    var axis: Int
    var row_layout: RowLayout
    var main_alignment: Int
    var cross_alignment: Int
    var clip_to_bounds: Bool
    var root_scroll_offset: Float32
    var theme: Theme

    def __init__(
        out self,
        bounds: Rect,
        padding: Float32,
        spacing: Float32,
    ):
        self.layout_spec = ColumnLayout(bounds, padding, spacing)
        self.children = List[ViewNode]()
        self.surface_style = default_surface_style()
        self.panel = Panel(
            0,
            Rect(0.0, 0.0, 0.0, 0.0),
            default_panel_style(),
        )
        self.has_panel = False
        self.axis = COLUMN_AXIS
        self.row_layout = RowLayout(bounds, padding, spacing)
        self.main_alignment = JUSTIFY_START
        self.cross_alignment = ALIGN_STRETCH
        self.clip_to_bounds = False
        self.root_scroll_offset = 0.0
        self.theme = Theme()

    def add(mut self, child: ViewNode):
        """Append a declarative child before running layout."""
        self.children.append(child)

    def add_to(mut self, parent_id: Int, child: ViewNode):
        """Append a child to a previously declared container node."""
        var nested = child
        nested.parent_id = parent_id
        nested.semantics.parent_id = parent_id
        self.children.append(nested)

    def add_component_view_to(
        mut self,
        parent_id: Int,
        slot_id: Int,
        child: ColumnView,
        id_offset: Int,
        preferred_height: Float32 = 0.0,
    ):
        """Embed a child component view under a namespaced container.

        The child view's root decoration is owned by the parent. Its view
        nodes are copied into the parent's flat tree, with `id_offset` applied
        to ids and parent links so multiple component instances can coexist.
        A zero preferred height uses the child's intrinsic height.
        """
        var height = preferred_height
        if height <= 0.0:
            height = child.intrinsic_size().height
        var slot = ViewNode(CONTAINER_KIND, slot_id, "", height)
        slot.container_axis = child.axis
        slot.container_padding = child.layout_spec.padding
        slot.container_spacing = child.layout_spec.spacing
        slot.container_main_alignment = child.main_alignment
        slot.container_cross_alignment = child.cross_alignment
        slot.clip_children = child.clip_to_bounds
        slot.parent_id = parent_id
        slot.semantics.parent_id = parent_id
        slot.semantics.label = "Component"
        self.add(slot)

        for index in range(child.child_count()):
            var nested = child.child(index)
            nested.id += id_offset
            if nested.parent_id == -1:
                nested.parent_id = slot_id
            else:
                nested.parent_id += id_offset
            nested.semantics.id = nested.id
            nested.semantics.parent_id = nested.parent_id
            self.add(nested)

    def add_column(
        mut self,
        id: Int,
        preferred_height: Float32,
        padding: Float32,
        spacing: Float32,
    ) -> Int:
        """Append a nested vertical container and return its stable id."""
        return self.add_column_to(-1, id, preferred_height, padding, spacing)

    def add_column_to(
        mut self,
        parent_id: Int,
        id: Int,
        preferred_height: Float32,
        padding: Float32,
        spacing: Float32,
    ) -> Int:
        """Append a vertical container under another container."""
        var container = ViewNode(CONTAINER_KIND, id, "", preferred_height)
        container.container_axis = COLUMN_AXIS
        container.container_padding = padding
        container.container_spacing = spacing
        container.parent_id = parent_id
        container.semantics.parent_id = parent_id
        container.semantics.label = "Container"
        self.add(container)
        return id

    def add_row(
        mut self,
        id: Int,
        preferred_width: Float32,
        preferred_height: Float32,
        padding: Float32,
        spacing: Float32,
    ) -> Int:
        """Append a nested horizontal container and return its stable id."""
        return self.add_row_to(
            -1,
            id,
            preferred_width,
            preferred_height,
            padding,
            spacing,
        )

    def add_row_to(
        mut self,
        parent_id: Int,
        id: Int,
        preferred_width: Float32,
        preferred_height: Float32,
        padding: Float32,
        spacing: Float32,
    ) -> Int:
        """Append a horizontal container under another container."""
        var container = ViewNode(CONTAINER_KIND, id, "", preferred_height)
        container.preferred_width = preferred_width
        container.container_axis = ROW_AXIS
        container.container_padding = padding
        container.container_spacing = spacing
        container.parent_id = parent_id
        container.semantics.parent_id = parent_id
        container.semantics.label = "Container"
        self.add(container)
        return id

    def add_stack(
        mut self,
        id: Int,
        preferred_height: Float32,
        padding: Float32 = 0.0,
        spacing: Float32 = 0.0,
    ) -> Int:
        """Append a z-stack container whose children share one region."""
        return self.add_stack_to(
            -1,
            id,
            preferred_height,
            padding,
            spacing,
        )

    def add_stack_to(
        mut self,
        parent_id: Int,
        id: Int,
        preferred_height: Float32,
        padding: Float32 = 0.0,
        spacing: Float32 = 0.0,
    ) -> Int:
        """Append a z-stack under another container."""
        return self.add_special_container_to(
            parent_id,
            id,
            0.0,
            preferred_height,
            padding,
            spacing,
            LAYOUT_STACK,
        )

    def add_grid(
        mut self,
        id: Int,
        preferred_height: Float32,
        columns: Int,
        padding: Float32 = 0.0,
        spacing: Float32 = 0.0,
    ) -> Int:
        """Append an equal-cell grid container."""
        return self.add_grid_to(
            -1,
            id,
            preferred_height,
            columns,
            padding,
            spacing,
        )

    def add_grid_to(
        mut self,
        parent_id: Int,
        id: Int,
        preferred_height: Float32,
        columns: Int,
        padding: Float32 = 0.0,
        spacing: Float32 = 0.0,
    ) -> Int:
        """Append an equal-cell grid under another container."""
        var result = self.add_special_container_to(
            parent_id,
            id,
            0.0,
            preferred_height,
            padding,
            spacing,
            LAYOUT_GRID,
        )
        self.set_grid_columns(id, columns)
        return result

    def add_split(
        mut self,
        id: Int,
        preferred_width: Float32,
        preferred_height: Float32,
        axis: Int,
        fraction: Float32,
        padding: Float32 = 0.0,
        spacing: Float32 = 0.0,
    ) -> Int:
        """Append a two-pane split container."""
        return self.add_split_to(
            -1,
            id,
            preferred_width,
            preferred_height,
            axis,
            fraction,
            padding,
            spacing,
        )

    def add_split_to(
        mut self,
        parent_id: Int,
        id: Int,
        preferred_width: Float32,
        preferred_height: Float32,
        axis: Int,
        fraction: Float32,
        padding: Float32 = 0.0,
        spacing: Float32 = 0.0,
    ) -> Int:
        """Append a two-pane split under another container."""
        var result = self.add_special_container_to(
            parent_id,
            id,
            preferred_width,
            preferred_height,
            padding,
            spacing,
            LAYOUT_SPLIT,
        )
        for index in range(len(self.children)):
            if self.children[index].id == id:
                self.children[index].container_axis = axis
                self.children[index].set_split_fraction(fraction)
        return result

    def add_portal(
        mut self,
        id: Int,
        preferred_height: Float32,
        padding: Float32 = 0.0,
        spacing: Float32 = 0.0,
        scroll_offset: Float32 = 0.0,
    ) -> Int:
        """Append a clipped, scrollable vertical viewport."""
        return self.add_portal_to(
            -1,
            id,
            preferred_height,
            padding,
            spacing,
            scroll_offset,
        )

    def add_portal_to(
        mut self,
        parent_id: Int,
        id: Int,
        preferred_height: Float32,
        padding: Float32 = 0.0,
        spacing: Float32 = 0.0,
        scroll_offset: Float32 = 0.0,
    ) -> Int:
        """Append a clipped, scrollable vertical viewport under a parent."""
        var result = self.add_special_container_to(
            parent_id,
            id,
            0.0,
            preferred_height,
            padding,
            spacing,
            LAYOUT_PORTAL,
        )
        for index in range(len(self.children)):
            if self.children[index].id == id:
                self.children[index].set_clip_children()
                self.children[index].set_scroll_offset(scroll_offset)
        return result

    def add_special_container_to(
        mut self,
        parent_id: Int,
        id: Int,
        preferred_width: Float32,
        preferred_height: Float32,
        padding: Float32,
        spacing: Float32,
        layout_kind: Int,
    ) -> Int:
        """Create a non-linear container while keeping one tree format."""
        var container = ViewNode(CONTAINER_KIND, id, "", preferred_height)
        container.preferred_width = preferred_width
        container.container_axis = COLUMN_AXIS
        container.container_padding = padding
        container.container_spacing = spacing
        container.container_layout_kind = layout_kind
        container.parent_id = parent_id
        container.semantics.parent_id = parent_id
        container.semantics.label = "Container"
        self.add(container)
        return id

    def set_container_alignment(mut self, id: Int, main: Int, cross: Int):
        """Set the alignment policy used by a nested container."""
        for index in range(len(self.children)):
            if self.children[index].id == id and self.children[index].kind == CONTAINER_KIND:
                self.children[index].container_main_alignment = main
                self.children[index].container_cross_alignment = cross

    def set_container_layout(mut self, id: Int, layout_kind: Int):
        """Change a nested container's layout policy by stable id."""
        for index in range(len(self.children)):
            if self.children[index].id == id:
                self.children[index].set_container_layout(layout_kind)

    def set_grid_columns(mut self, id: Int, columns: Int):
        """Set the column count for a grid container."""
        for index in range(len(self.children)):
            if self.children[index].id == id:
                self.children[index].set_grid_columns(columns)

    def set_split_fraction(mut self, id: Int, fraction: Float32):
        """Set the first-pane fraction for a split container."""
        for index in range(len(self.children)):
            if self.children[index].id == id:
                self.children[index].set_split_fraction(fraction)

    def set_scroll_offset(mut self, id: Int, offset: Float32):
        """Set a scroll container's main-axis scroll offset."""
        if id == ROOT_SCROLL_ID:
            self.root_scroll_offset = offset if offset > 0.0 else 0.0
            return
        for index in range(len(self.children)):
            if self.children[index].id == id:
                self.children[index].set_scroll_offset(offset)

    def scroll_offset_for(self, id: Int) -> Float32:
        """Return one scroll container's current main-axis scroll offset."""
        if id == ROOT_SCROLL_ID:
            return self.root_scroll_offset
        for index in range(len(self.children)):
            if self.children[index].id == id:
                return self.children[index].container_scroll_offset
        return 0.0

    def scroll_axis_for(self, id: Int) -> Int:
        """Return the main axis used by one scroll container."""
        if id == ROOT_SCROLL_ID:
            return self.axis
        for index in range(len(self.children)):
            if (
                self.children[index].id == id
                and self.children[index].kind == CONTAINER_KIND
            ):
                return self.children[index].container_axis
        return COLUMN_AXIS

    def _linear_content_extent(
        self,
        parent_id: Int,
        axis: Int,
        padding: Float32,
        spacing: Float32,
    ) -> Float32:
        """Measure the main-axis extent produced by a linear layout pass."""
        var extent = padding * 2.0
        var count = 0
        for index in range(len(self.children)):
            if self.children[index].parent_id != parent_id:
                continue
            if axis == ROW_AXIS:
                extent += self.layout_width(index)
            else:
                extent += self.layout_height(index)
            count += 1
        if count > 1:
            extent += spacing * Float32(count - 1)
        return extent

    def scroll_max_offset(self, id: Int) -> Float32:
        """Return the clamped scroll extent for a scroll container."""
        if id == ROOT_SCROLL_ID:
            var content = self._linear_content_extent(
                -1,
                self.axis,
                self.layout_spec.padding,
                self.layout_spec.spacing,
            )
            var viewport = self.layout_spec.bounds.height
            if self.axis == ROW_AXIS:
                viewport = self.layout_spec.bounds.width
            var maximum = content - viewport
            return maximum if maximum > 0.0 else 0.0
        for index in range(len(self.children)):
            if (
                self.children[index].id == id
                and self.children[index].kind == CONTAINER_KIND
                and (
                    self.children[index].container_layout_kind == LAYOUT_LINEAR
                    or self.children[index].container_layout_kind == LAYOUT_PORTAL
                )
            ):
                var node = self.children[index]
                var content = self._linear_content_extent(
                    id,
                    node.container_axis,
                    node.container_padding,
                    node.container_spacing,
                )
                var viewport = node.bounds.height
                if node.container_axis == ROW_AXIS:
                    viewport = node.bounds.width
                    var horizontal = content - viewport
                    return horizontal if horizontal > 0.0 else 0.0
                var vertical = content - viewport
                return vertical if vertical > 0.0 else 0.0
        return 0.0

    def add_label_to(
        mut self,
        parent_id: Int,
        id: Int,
        text: String,
        preferred_height: Float32,
    ):
        """Append a label to a nested container."""
        self.add_to(parent_id, ViewNode(LABEL_KIND, id, text, preferred_height))

    def add_button_to(
        mut self,
        parent_id: Int,
        id: Int,
        text: String,
        preferred_height: Float32,
    ):
        """Append a button to a nested container."""
        self.add_to(parent_id, ViewNode(BUTTON_KIND, id, text, preferred_height))

    def add_text_input_to(
        mut self,
        parent_id: Int,
        id: Int,
        text: String,
        preferred_height: Float32,
    ):
        """Append a text input to a nested container."""
        self.add_to(
            parent_id,
            ViewNode(
                TEXT_INPUT_VIEW_KIND,
                id,
                text,
                preferred_height,
                default_text_input_style(),
                text.count_codepoints(),
            ),
        )

    def add_checkbox_to(
        mut self,
        parent_id: Int,
        id: Int,
        text: String,
        checked: Bool,
        preferred_height: Float32,
    ):
        """Append a focusable checkbox to a nested container."""
        var child = ViewNode(CHECKBOX_KIND, id, text, preferred_height)
        child.set_checked(checked)
        self.add_to(parent_id, child)

    def add_progress_to(
        mut self,
        parent_id: Int,
        id: Int,
        text: String,
        progress: Float32,
        preferred_height: Float32,
    ):
        """Append a determinate progress indicator to a nested container."""
        var child = ViewNode(PROGRESS_KIND, id, text, preferred_height)
        child.set_progress(progress)
        self.add_to(parent_id, child)

    def add_slider_to(
        mut self,
        parent_id: Int,
        id: Int,
        text: String,
        progress: Float32,
        preferred_height: Float32,
    ):
        """Append a keyboard-focusable scalar slider to a container."""
        var child = ViewNode(SLIDER_KIND, id, text, preferred_height)
        child.set_progress(progress)
        self.add_to(parent_id, child)

    def add_switch_to(
        mut self,
        parent_id: Int,
        id: Int,
        text: String,
        checked: Bool,
        preferred_height: Float32,
    ):
        """Append a keyboard-focusable boolean switch to a container."""
        var child = ViewNode(SWITCH_KIND, id, text, preferred_height)
        child.set_checked(checked)
        self.add_to(parent_id, child)

    def add_radio_to(
        mut self,
        parent_id: Int,
        id: Int,
        text: String,
        selected: Bool,
        preferred_height: Float32,
    ):
        """Append a keyboard-focusable radio option to a container."""
        var child = ViewNode(RADIO_KIND, id, text, preferred_height)
        child.set_selected(selected)
        self.add_to(parent_id, child)

    def add_image_to(
        mut self,
        parent_id: Int,
        id: Int,
        alt_text: String,
        resource_id: Int,
        preferred_height: Float32,
    ):
        """Append an image resource placeholder with accessible alt text."""
        var child = ViewNode(IMAGE_KIND, id, alt_text, preferred_height)
        child.set_resource_id(resource_id)
        self.add_to(parent_id, child)

    def add_multiline_text_to(
        mut self,
        parent_id: Int,
        id: Int,
        text: String,
        preferred_height: Float32,
    ):
        """Append a wrapped, focusable multiline text editor descriptor."""
        var child = ViewNode(
            MULTILINE_TEXT_KIND,
            id,
            text,
            preferred_height,
            default_multiline_style(),
            text.count_codepoints(),
        )
        child.set_wrap_text()
        self.add_to(parent_id, child)

    def add_catalog_to(
        mut self,
        parent_id: Int,
        id: Int,
        kind: Int,
        text: String,
        preferred_height: Float32,
    ):
        """Append one of the catalog controls under a container."""
        self.add_to(parent_id, ViewNode(kind, id, text, preferred_height))

    def add_combo_box_to(mut self, parent_id: Int, id: Int, text: String, preferred_height: Float32):
        self.add_catalog_to(parent_id, id, COMBO_BOX_KIND, text, preferred_height)

    def add_list_to(mut self, parent_id: Int, id: Int, text: String, preferred_height: Float32):
        self.add_catalog_to(parent_id, id, LIST_KIND, text, preferred_height)

    def add_table_to(mut self, parent_id: Int, id: Int, text: String, preferred_height: Float32):
        self.add_catalog_to(parent_id, id, TABLE_KIND, text, preferred_height)

    def add_tree_to(mut self, parent_id: Int, id: Int, text: String, preferred_height: Float32):
        self.add_catalog_to(parent_id, id, TREE_KIND, text, preferred_height)

    def add_menu_to(mut self, parent_id: Int, id: Int, text: String, preferred_height: Float32):
        self.add_catalog_to(parent_id, id, MENU_KIND, text, preferred_height)

    def add_dialog_to(mut self, parent_id: Int, id: Int, text: String, preferred_height: Float32):
        self.add_catalog_to(parent_id, id, DIALOG_KIND, text, preferred_height)

    def add_tabs_to(mut self, parent_id: Int, id: Int, text: String, preferred_height: Float32):
        self.add_catalog_to(parent_id, id, TABS_KIND, text, preferred_height)

    def add_canvas_to(mut self, parent_id: Int, id: Int, text: String, preferred_height: Float32):
        self.add_catalog_to(parent_id, id, CANVAS_KIND, text, preferred_height)

    def add_separator_to(mut self, parent_id: Int, id: Int, preferred_height: Float32 = 1.0):
        self.add_catalog_to(parent_id, id, SEPARATOR_KIND, "", preferred_height)

    def add_label(
        mut self,
        id: Int,
        text: String,
        preferred_height: Float32,
    ):
        self.add(ViewNode(LABEL_KIND, id, text, preferred_height))

    def add_button(
        mut self,
        id: Int,
        text: String,
        preferred_height: Float32,
    ):
        self.add(ViewNode(BUTTON_KIND, id, text, preferred_height))

    def add_checkbox(
        mut self,
        id: Int,
        text: String,
        checked: Bool,
        preferred_height: Float32,
    ):
        """Append a focusable checkbox to the root container."""
        var child = ViewNode(CHECKBOX_KIND, id, text, preferred_height)
        child.set_checked(checked)
        self.add(child)

    def add_progress(
        mut self,
        id: Int,
        text: String,
        progress: Float32,
        preferred_height: Float32,
    ):
        """Append a determinate progress indicator to the root container."""
        var child = ViewNode(PROGRESS_KIND, id, text, preferred_height)
        child.set_progress(progress)
        self.add(child)

    def add_slider(
        mut self,
        id: Int,
        text: String,
        progress: Float32,
        preferred_height: Float32,
    ):
        """Append a keyboard-focusable scalar slider to the root."""
        var child = ViewNode(SLIDER_KIND, id, text, preferred_height)
        child.set_progress(progress)
        self.add(child)

    def add_switch(
        mut self,
        id: Int,
        text: String,
        checked: Bool,
        preferred_height: Float32,
    ):
        """Append a keyboard-focusable boolean switch to the root."""
        var child = ViewNode(SWITCH_KIND, id, text, preferred_height)
        child.set_checked(checked)
        self.add(child)

    def add_radio(
        mut self,
        id: Int,
        text: String,
        selected: Bool,
        preferred_height: Float32,
    ):
        """Append a keyboard-focusable radio option to the root."""
        var child = ViewNode(RADIO_KIND, id, text, preferred_height)
        child.set_selected(selected)
        self.add(child)

    def add_image(
        mut self,
        id: Int,
        alt_text: String,
        resource_id: Int,
        preferred_height: Float32,
    ):
        """Append an image resource placeholder to the root."""
        var child = ViewNode(IMAGE_KIND, id, alt_text, preferred_height)
        child.set_resource_id(resource_id)
        self.add(child)

    def add_multiline_text(
        mut self,
        id: Int,
        text: String,
        preferred_height: Float32,
    ):
        """Append a wrapped, focusable multiline text editor descriptor."""
        var child = ViewNode(
            MULTILINE_TEXT_KIND,
            id,
            text,
            preferred_height,
            default_multiline_style(),
            text.count_codepoints(),
        )
        child.set_wrap_text()
        self.add(child)

    def add_catalog(
        mut self,
        id: Int,
        kind: Int,
        text: String,
        preferred_height: Float32,
    ):
        """Append one of the catalog controls to the root container."""
        self.add(ViewNode(kind, id, text, preferred_height))

    def add_combo_box(mut self, id: Int, text: String, preferred_height: Float32):
        self.add_catalog(id, COMBO_BOX_KIND, text, preferred_height)

    def add_list(mut self, id: Int, text: String, preferred_height: Float32):
        self.add_catalog(id, LIST_KIND, text, preferred_height)

    def add_table(mut self, id: Int, text: String, preferred_height: Float32):
        self.add_catalog(id, TABLE_KIND, text, preferred_height)

    def add_tree(mut self, id: Int, text: String, preferred_height: Float32):
        self.add_catalog(id, TREE_KIND, text, preferred_height)

    def add_menu(mut self, id: Int, text: String, preferred_height: Float32):
        self.add_catalog(id, MENU_KIND, text, preferred_height)

    def add_dialog(mut self, id: Int, text: String, preferred_height: Float32):
        self.add_catalog(id, DIALOG_KIND, text, preferred_height)

    def add_tabs(mut self, id: Int, text: String, preferred_height: Float32):
        self.add_catalog(id, TABS_KIND, text, preferred_height)

    def add_canvas(mut self, id: Int, text: String, preferred_height: Float32):
        self.add_catalog(id, CANVAS_KIND, text, preferred_height)

    def add_separator(mut self, id: Int, preferred_height: Float32 = 1.0):
        self.add_catalog(id, SEPARATOR_KIND, "", preferred_height)

    def add_label_styled(
        mut self,
        id: Int,
        text: String,
        preferred_height: Float32,
        style: Style,
    ):
        self.add(ViewNode(LABEL_KIND, id, text, preferred_height, style))

    def add_button_styled(
        mut self,
        id: Int,
        text: String,
        preferred_height: Float32,
        style: Style,
    ):
        self.add(ViewNode(BUTTON_KIND, id, text, preferred_height, style))

    def add_text_input(
        mut self,
        id: Int,
        text: String,
        preferred_height: Float32,
    ):
        self.add(
            ViewNode(
                TEXT_INPUT_VIEW_KIND,
                id,
                text,
                preferred_height,
                default_text_input_style(),
                text.count_codepoints(),
            )
        )

    def add_text_input_styled(
        mut self,
        id: Int,
        text: String,
        preferred_height: Float32,
        style: Style,
        cursor: Int,
    ):
        self.add(
            ViewNode(
                TEXT_INPUT_VIEW_KIND,
                id,
                text,
                preferred_height,
                style,
                cursor,
            )
        )

    def add_text_input_selection(
        mut self,
        id: Int,
        text: String,
        preferred_height: Float32,
        style: Style,
        cursor: Int,
        selection_anchor: Int,
    ):
        """Append a text input with an explicit cursor and selection anchor."""
        self.add(
            ViewNode(
                TEXT_INPUT_VIEW_KIND,
                id,
                text,
                preferred_height,
                style,
                cursor,
                selection_anchor,
            )
        )

    def add_spacer(mut self, id: Int, preferred_size: Float32):
        """Append a fixed-size non-rendering layout slot."""
        var spacer = ViewNode(SPACER_KIND, id, "", preferred_size)
        spacer.preferred_width = preferred_size
        self.add(spacer)

    def add_flexible_spacer(mut self, id: Int):
        """Append a non-rendering row slot that absorbs remaining width."""
        var spacer = ViewNode(SPACER_KIND, id, "", 0.0)
        spacer.preferred_width = 0.0
        self.add(spacer)

    def add_flexible_spacer_to(mut self, parent_id: Int, id: Int):
        """Append a flexible spacer to a specific row or column."""
        var spacer = ViewNode(SPACER_KIND, id, "", 0.0)
        spacer.preferred_width = 0.0
        self.add_to(parent_id, spacer)

    def add_spacer_to(
        mut self,
        parent_id: Int,
        id: Int,
        preferred_size: Float32,
    ):
        """Append a fixed spacer to a specific row or column."""
        var spacer = ViewNode(SPACER_KIND, id, "", preferred_size)
        spacer.preferred_width = preferred_size
        self.add_to(parent_id, spacer)

    def set_preferred_width(mut self, id: Int, width: Float32):
        """Set a row child's fixed width; zero keeps it flexible."""
        var fixed_width = width
        if fixed_width < 0.0:
            fixed_width = 0.0
        for index in range(len(self.children)):
            if self.children[index].id == id:
                self.children[index].preferred_width = fixed_width

    def set_fixed_width(mut self, id: Int, width: Float32):
        """Clearer spelling for setting a fixed width in a horizontal row."""
        self.set_preferred_width(id, width)

    def set_min_width(mut self, id: Int, width: Float32):
        """Set a child's minimum layout width."""
        for index in range(len(self.children)):
            if self.children[index].id == id:
                self.children[index].set_min_width(width)

    def set_max_width(mut self, id: Int, width: Float32):
        """Set a child's maximum layout width; zero means unlimited."""
        for index in range(len(self.children)):
            if self.children[index].id == id:
                self.children[index].set_max_width(width)

    def set_min_height(mut self, id: Int, height: Float32):
        """Set a child's minimum layout height."""
        for index in range(len(self.children)):
            if self.children[index].id == id:
                self.children[index].set_min_height(height)

    def set_max_height(mut self, id: Int, height: Float32):
        """Set a child's maximum layout height; zero means unlimited."""
        for index in range(len(self.children)):
            if self.children[index].id == id:
                self.children[index].set_max_height(height)

    def set_intrinsic_width(mut self, id: Int, enabled: Bool = True):
        """Use measured content width when the node has no fixed width."""
        for index in range(len(self.children)):
            if self.children[index].id == id:
                self.children[index].set_intrinsic_width(enabled)

    def set_intrinsic_height(mut self, id: Int, enabled: Bool = True):
        """Use measured content height when the node has no fixed height."""
        for index in range(len(self.children)):
            if self.children[index].id == id:
                self.children[index].set_intrinsic_height(enabled)

    def set_wrap_text(mut self, id: Int, enabled: Bool = True):
        """Enable or disable deterministic wrapping for a child."""
        for index in range(len(self.children)):
            if self.children[index].id == id:
                self.children[index].set_wrap_text(enabled)

    def set_wrap(mut self, id: Int, enabled: Bool = True):
        """Compatibility spelling for `set_wrap_text(id, enabled)`."""
        self.set_wrap_text(id, enabled)

    def set_action(mut self, id: Int, action_id: Int):
        """Attach a stable action id to a child view."""
        for index in range(len(self.children)):
            if self.children[index].id == id:
                self.children[index].set_action(action_id)

    def set_action_id(mut self, id: Int, action_id: Int):
        """Explicit spelling for `set_action(id, action_id)`."""
        self.set_action(id, action_id)

    def set_clip_to_bounds(mut self, enabled: Bool = True):
        """Clip root content to the current view bounds."""
        self.clip_to_bounds = enabled

    def set_clip_children(mut self, id: Int, enabled: Bool = True):
        """Clip a nested container's descendants to its bounds."""
        for index in range(len(self.children)):
            if self.children[index].id == id:
                self.children[index].set_clip_children(enabled)

    def set_enabled(mut self, id: Int, enabled: Bool):
        """Enable or disable an interactive child by stable id."""
        for index in range(len(self.children)):
            if self.children[index].id == id:
                self.children[index].enabled = enabled
                self.children[index].semantics.enabled = enabled

    def set_accessibility_label(mut self, id: Int, label: String):
        """Override a child's accessible label without changing its visuals."""
        for index in range(len(self.children)):
            if self.children[index].id == id:
                self.children[index].set_accessibility_label(label)

    def set_accessibility_value(mut self, id: Int, value: String):
        """Set the current accessible value for a child."""
        for index in range(len(self.children)):
            if self.children[index].id == id:
                self.children[index].set_accessibility_value(value)

    def set_accessibility_hint(mut self, id: Int, hint: String):
        """Set a short accessible usage hint for a child."""
        for index in range(len(self.children)):
            if self.children[index].id == id:
                self.children[index].set_accessibility_hint(hint)

    def set_accessibility_value_range(
        mut self,
        id: Int,
        minimum: Float32,
        maximum: Float32,
        current: Float32,
    ):
        """Publish machine-readable scalar range metadata for a child."""
        for index in range(len(self.children)):
            if self.children[index].id == id:
                self.children[index].set_accessibility_value_range(
                    minimum, maximum, current
                )

    def set_expanded(mut self, id: Int, expanded: Bool):
        """Update a disclosure/open state by stable id."""
        for index in range(len(self.children)):
            if self.children[index].id == id:
                self.children[index].set_expanded(expanded)

    def set_selected(mut self, id: Int, selected: Bool):
        """Expose selection state for semantic consumers."""
        for index in range(len(self.children)):
            if self.children[index].id == id:
                self.children[index].set_selected(selected)

    def set_style(mut self, id: Int, style: Style):
        """Replace one child style without changing its identity."""
        for index in range(len(self.children)):
            if self.children[index].id == id:
                self.children[index].set_style(style)

    def set_checked(mut self, id: Int, checked: Bool):
        """Update checkbox state and its semantic value by stable id."""
        for index in range(len(self.children)):
            if self.children[index].id == id:
                self.children[index].set_checked(checked)

    def set_progress(mut self, id: Int, progress: Float32):
        """Update a determinate progress indicator by stable id."""
        for index in range(len(self.children)):
            if self.children[index].id == id:
                self.children[index].set_progress(progress)

    def add_button_enabled(
        mut self,
        id: Int,
        text: String,
        preferred_height: Float32,
        enabled: Bool,
    ):
        """Append a button with an explicit enabled state."""
        var child = ViewNode(BUTTON_KIND, id, text, preferred_height)
        child.enabled = enabled
        child.semantics.enabled = enabled
        self.add(child)

    def set_surface_style(mut self, style: Style):
        self.surface_style = style

    def set_theme(mut self, theme: Theme):
        """Apply a complete visual theme to the current view tree."""
        self.theme = theme
        self.apply_theme()

    def apply_theme(mut self):
        """Apply the stored theme while retaining view identity and state."""
        for index in range(len(self.children)):
            var kind = self.children[index].kind
            if kind == LABEL_KIND:
                self.children[index].set_style(self.theme.label)
            elif kind == BUTTON_KIND:
                self.children[index].set_style(self.theme.button)
            elif kind == TEXT_INPUT_VIEW_KIND:
                self.children[index].set_style(self.theme.text_input)
            elif kind == CHECKBOX_KIND:
                self.children[index].set_style(self.theme.control)
            elif kind == PROGRESS_KIND:
                self.children[index].set_style(self.theme.progress)
            elif kind == SLIDER_KIND:
                self.children[index].set_style(self.theme.slider)
            elif kind == SWITCH_KIND:
                self.children[index].set_style(self.theme.switch_style)
            elif kind == RADIO_KIND:
                self.children[index].set_style(self.theme.radio)
            elif kind == IMAGE_KIND:
                self.children[index].set_style(self.theme.image)
            elif kind == MULTILINE_TEXT_KIND:
                self.children[index].set_style(self.theme.multiline)
            elif kind == COMBO_BOX_KIND:
                self.children[index].set_style(self.theme.combo_box)
            elif kind == LIST_KIND:
                self.children[index].set_style(self.theme.list_style)
            elif kind == TABLE_KIND:
                self.children[index].set_style(self.theme.table_style)
            elif kind == TREE_KIND:
                self.children[index].set_style(self.theme.tree_style)
            elif kind == MENU_KIND:
                self.children[index].set_style(self.theme.menu_style)
            elif kind == DIALOG_KIND:
                self.children[index].set_style(self.theme.dialog_style)
            elif kind == TABS_KIND:
                self.children[index].set_style(self.theme.tabs_style)
            elif kind == CANVAS_KIND:
                self.children[index].set_style(self.theme.canvas_style)
            elif kind == SEPARATOR_KIND:
                self.children[index].set_style(self.theme.separator_style)

    def set_panel(mut self, id: Int, bounds: Rect, style: Style):
        self.panel = Panel(id, bounds, style)
        self.has_panel = True

    def set_row_layout(mut self):
        """Switch this container to a horizontal layout."""
        self.axis = ROW_AXIS
        self.row_layout = RowLayout(
            self.layout_spec.bounds,
            self.layout_spec.padding,
            self.layout_spec.spacing,
        )

    def set_horizontal_layout(mut self):
        """Preferred spelling for `set_row_layout()`."""
        self.set_row_layout()

    def set_main_alignment(mut self, alignment: Int):
        """Set main-axis distribution to start, center, end, or space-between."""
        self.main_alignment = alignment

    def set_cross_alignment(mut self, alignment: Int):
        """Set cross-axis alignment to start, center, end, or stretch."""
        self.cross_alignment = alignment

    def set_justify_content(mut self, alignment: Int):
        """CSS-like alias for main-axis distribution."""
        self.set_main_alignment(alignment)

    def set_align_items(mut self, alignment: Int):
        """CSS-like alias for cross-axis alignment."""
        self.set_cross_alignment(alignment)

    def child_intrinsic_size(self, index: Int) -> Size:
        """Measure a leaf or recursively measure a nested container."""
        if self.children[index].kind == CONTAINER_KIND:
            return self.intrinsic_group_size(
                self.children[index].id,
                self.children[index].container_axis,
                self.children[index].container_padding,
                self.children[index].container_spacing,
                self.children[index].container_layout_kind,
                self.children[index].container_grid_columns,
            )
        return self.children[index].intrinsic_size()

    def layout_width(self, index: Int) -> Float32:
        """Return the explicit or opt-in intrinsic width for one child."""
        var width = self.children[index].preferred_width
        if width <= 0.0 and self.children[index].use_intrinsic_width:
            width = self.child_intrinsic_size(index).width
        return self.children[index].constrained_width(width)

    def layout_height(self, index: Int) -> Float32:
        """Return the explicit or opt-in intrinsic height for one child."""
        var height = self.children[index].preferred_height
        if height <= 0.0 and self.children[index].use_intrinsic_height:
            height = self.child_intrinsic_size(index).height
        return self.children[index].constrained_height(height)

    def intrinsic_group_size(
        self,
        parent_id: Int,
        axis: Int,
        padding: Float32,
        spacing: Float32,
        layout_kind: Int = LAYOUT_LINEAR,
        grid_columns: Int = 1,
    ) -> Size:
        """Measure direct children using their content sizes and container axis."""
        var count = 0
        var width: Float32 = 0.0
        var height: Float32 = 0.0

        if layout_kind == LAYOUT_STACK:
            for index in range(len(self.children)):
                if self.children[index].parent_id != parent_id:
                    continue
                var child_size = self.child_intrinsic_size(index)
                if child_size.width > width:
                    width = child_size.width
                if child_size.height > height:
                    height = child_size.height
            return Size(width + padding * 2.0, height + padding * 2.0)

        if layout_kind == LAYOUT_GRID:
            var columns = grid_columns if grid_columns > 0 else 1
            var max_cell_width: Float32 = 0.0
            var max_cell_height: Float32 = 0.0
            for index in range(len(self.children)):
                if self.children[index].parent_id != parent_id:
                    continue
                var child_size = self.child_intrinsic_size(index)
                if child_size.width > max_cell_width:
                    max_cell_width = child_size.width
                if child_size.height > max_cell_height:
                    max_cell_height = child_size.height
                count += 1
            var rows = (count + columns - 1) // columns
            width = max_cell_width * Float32(columns)
            height = max_cell_height * Float32(rows)
            if columns > 1:
                width += spacing * Float32(columns - 1)
            if rows > 1:
                height += spacing * Float32(rows - 1)
            return Size(width + padding * 2.0, height + padding * 2.0)

        if layout_kind == LAYOUT_SPLIT:
            var pane_count = 0
            for index in range(len(self.children)):
                if self.children[index].parent_id != parent_id:
                    continue
                var child_size = self.child_intrinsic_size(index)
                if axis == ROW_AXIS:
                    width += child_size.width
                    if child_size.height > height:
                        height = child_size.height
                else:
                    height += child_size.height
                    if child_size.width > width:
                        width = child_size.width
                pane_count += 1
                if pane_count == 2:
                    break
            if pane_count > 1:
                if axis == ROW_AXIS:
                    width += spacing
                else:
                    height += spacing
            return Size(width + padding * 2.0, height + padding * 2.0)

        for index in range(len(self.children)):
            if self.children[index].parent_id != parent_id:
                continue
            var child_size = self.child_intrinsic_size(index)
            if axis == ROW_AXIS:
                width += child_size.width
                if child_size.height > height:
                    height = child_size.height
            else:
                height += child_size.height
                if child_size.width > width:
                    width = child_size.width
            count += 1
        if count > 1:
            if axis == ROW_AXIS:
                width += spacing * Float32(count - 1)
            else:
                height += spacing * Float32(count - 1)
        return Size(width + padding * 2.0, height + padding * 2.0)

    def intrinsic_size(self) -> Size:
        """Return the natural content extent of this view tree."""
        return self.intrinsic_group_size(
            -1,
            self.axis,
            self.layout_spec.padding,
            self.layout_spec.spacing,
        )

    def layout(mut self):
        """Assign bounds to the root and any nested container children."""
        var bounds = self.layout_spec.bounds
        var axis = self.axis
        var padding = self.layout_spec.padding
        var spacing = self.layout_spec.spacing
        var main_alignment = self.main_alignment
        var cross_alignment = self.cross_alignment
        var root_scroll = self.root_scroll_offset
        var root_content = self._linear_content_extent(
            -1,
            axis,
            padding,
            spacing,
        )
        var root_viewport = bounds.height
        if axis == ROW_AXIS:
            root_viewport = bounds.width
        var root_max = root_content - root_viewport
        if root_max < 0.0:
            root_max = 0.0
        if root_scroll > root_max:
            root_scroll = root_max
        if root_scroll < 0.0:
            root_scroll = 0.0
        self.root_scroll_offset = root_scroll
        self.layout_group(
            -1,
            bounds,
            axis,
            padding,
            spacing,
            main_alignment,
            cross_alignment,
            LAYOUT_LINEAR,
            1,
            0.5,
            root_scroll,
        )

    def is_valid(self) -> Bool:
        """Validate ids and parent links before layout or reconciliation."""
        var count = self.child_count()
        for index in range(count):
            var node = self.children[index]
            if node.id < 0:
                return False
            for previous_index in range(index):
                if self.children[previous_index].id == node.id:
                    return False
            if node.parent_id == node.id:
                return False
            if node.parent_id == -1:
                continue

            var parent_id = node.parent_id
            var hops = 0
            while parent_id != -1:
                if parent_id == node.id:
                    return False
                var found_parent = False
                var next_parent = -1
                for parent_index in range(count):
                    var parent = self.children[parent_index]
                    if parent.id == parent_id:
                        if parent.kind != CONTAINER_KIND:
                            return False
                        found_parent = True
                        next_parent = parent.parent_id
                        break
                if not found_parent:
                    return False
                parent_id = next_parent
                hops += 1
                if hops > count:
                    return False
        return True

    def validate(self) -> Bool:
        """Compatibility spelling for `is_valid()`."""
        return self.is_valid()

    def layout_child_if_container(mut self, index: Int):
        """Recursively lay out a child container with its own policy."""
        if self.children[index].kind != CONTAINER_KIND:
            return
        var child_id = self.children[index].id
        var child_bounds = self.children[index].bounds
        var child_axis = self.children[index].container_axis
        var child_padding = self.children[index].container_padding
        var child_spacing = self.children[index].container_spacing
        var child_main = self.children[index].container_main_alignment
        var child_cross = self.children[index].container_cross_alignment
        var child_layout = self.children[index].container_layout_kind
        var child_columns = self.children[index].container_grid_columns
        var child_split = self.children[index].container_split_fraction
        var child_scroll = self.children[index].container_scroll_offset
        if child_layout == LAYOUT_LINEAR or child_layout == LAYOUT_PORTAL:
            var child_content = self._linear_content_extent(
                child_id,
                child_axis,
                child_padding,
                child_spacing,
            )
            var child_viewport = child_bounds.height
            if child_axis == ROW_AXIS:
                child_viewport = child_bounds.width
            var child_max = child_content - child_viewport
            if child_max < 0.0:
                child_max = 0.0
            if child_scroll > child_max:
                child_scroll = child_max
            if child_scroll < 0.0:
                child_scroll = 0.0
            self.children[index].container_scroll_offset = child_scroll
        self.layout_group(
            child_id,
            child_bounds,
            child_axis,
            child_padding,
            child_spacing,
            child_main,
            child_cross,
            child_layout,
            child_columns,
            child_split,
            child_scroll,
        )

    def layout_group(
        mut self,
        parent_id: Int,
        bounds: Rect,
        axis: Int,
        padding: Float32,
        spacing: Float32,
        main_alignment: Int,
        cross_alignment: Int,
        layout_kind: Int = LAYOUT_LINEAR,
        grid_columns: Int = 1,
        split_fraction: Float32 = 0.5,
        scroll_offset: Float32 = 0.0,
    ):
        """Lay out direct children and recursively visit nested containers."""
        var count = 0
        for index in range(len(self.children)):
            if self.children[index].parent_id == parent_id:
                count += 1
        if count == 0:
            return

        var content_width = bounds.width - padding * 2.0
        if content_width < 0.0:
            content_width = 0.0
        var content_height = bounds.height - padding * 2.0
        if content_height < 0.0:
            content_height = 0.0

        if layout_kind == LAYOUT_STACK:
            for index in range(len(self.children)):
                if self.children[index].parent_id != parent_id:
                    continue
                var child_width = self.layout_width(index)
                if child_width <= 0.0 or cross_alignment == ALIGN_STRETCH:
                    child_width = self.children[index].constrained_width(
                        content_width
                    )
                elif child_width > content_width:
                    child_width = content_width
                var child_height = self.layout_height(index)
                if child_height <= 0.0:
                    child_height = self.children[index].constrained_height(
                        content_height
                    )
                elif child_height > content_height:
                    child_height = content_height
                var left = bounds.x + padding
                var top = bounds.y + padding
                if cross_alignment == ALIGN_CENTER:
                    left += (content_width - child_width) * 0.5
                elif cross_alignment == ALIGN_END:
                    left += content_width - child_width
                if main_alignment == JUSTIFY_CENTER:
                    top += (content_height - child_height) * 0.5
                elif main_alignment == JUSTIFY_END:
                    top += content_height - child_height
                self.children[index].bounds = Rect(
                    left,
                    top,
                    child_width,
                    child_height,
                )
                self.layout_child_if_container(index)
            return

        if layout_kind == LAYOUT_GRID:
            var columns = grid_columns
            if columns < 1:
                columns = 1
            var rows = (count + columns - 1) // columns
            var cell_width = content_width - spacing * Float32(columns - 1)
            if cell_width < 0.0:
                cell_width = 0.0
            cell_width = cell_width / Float32(columns)
            var cell_height = content_height
            if rows > 1:
                cell_height -= spacing * Float32(rows - 1)
            if cell_height < 0.0:
                cell_height = 0.0
            if rows > 0:
                cell_height = cell_height / Float32(rows)
            var child_number = 0
            for index in range(len(self.children)):
                if self.children[index].parent_id != parent_id:
                    continue
                var row = child_number // columns
                var column = child_number % columns
                var left = bounds.x + padding + Float32(column) * (cell_width + spacing)
                var top = bounds.y + padding + Float32(row) * (cell_height + spacing)
                self.children[index].bounds = Rect(
                    left,
                    top,
                    self.children[index].constrained_width(cell_width),
                    self.children[index].constrained_height(cell_height),
                )
                self.layout_child_if_container(index)
                child_number += 1
            return

        if layout_kind == LAYOUT_SPLIT:
            var first_extent: Float32
            var total_extent: Float32
            if axis == ROW_AXIS:
                total_extent = content_width
            else:
                total_extent = content_height
            var available = total_extent - spacing
            if available < 0.0:
                available = 0.0
            var fraction = split_fraction
            if fraction < 0.0:
                fraction = 0.0
            if fraction > 1.0:
                fraction = 1.0
            first_extent = available * fraction
            var child_number = 0
            for index in range(len(self.children)):
                if self.children[index].parent_id != parent_id:
                    continue
                if child_number > 1:
                    break
                var main_start: Float32
                var main_extent: Float32
                if child_number == 0:
                    main_start = 0.0
                    main_extent = first_extent
                else:
                    main_start = first_extent + spacing
                    main_extent = available - first_extent
                if axis == ROW_AXIS:
                    self.children[index].bounds = Rect(
                        bounds.x + padding + main_start,
                        bounds.y + padding,
                        self.children[index].constrained_width(main_extent),
                        self.children[index].constrained_height(content_height),
                    )
                else:
                    self.children[index].bounds = Rect(
                        bounds.x + padding,
                        bounds.y + padding + main_start,
                        self.children[index].constrained_width(content_width),
                        self.children[index].constrained_height(main_extent),
                    )
                self.layout_child_if_container(index)
                child_number += 1
            return

        if axis == ROW_AXIS:
            var available = content_width
            if count > 1:
                available -= spacing * Float32(count - 1)
            if available < 0.0:
                available = 0.0
            var fixed_width: Float32 = 0.0
            var flexible_count = 0
            for index in range(len(self.children)):
                if self.children[index].parent_id != parent_id:
                    continue
                var child_width = self.layout_width(index)
                if child_width > 0.0:
                    fixed_width += child_width
                else:
                    flexible_count += 1
            var flexible_width: Float32 = 0.0
            if flexible_count > 0:
                var remaining = available - fixed_width
                if remaining < 0.0:
                    remaining = 0.0
                flexible_width = remaining / Float32(flexible_count)

            var used_width: Float32 = 0.0
            for index in range(len(self.children)):
                if self.children[index].parent_id != parent_id:
                    continue
                var child_width = self.layout_width(index)
                if child_width <= 0.0:
                    child_width = self.children[index].constrained_width(
                        flexible_width
                    )
                used_width += child_width
            var unused_width = content_width - used_width
            if count > 1:
                unused_width -= spacing * Float32(count - 1)
            if unused_width < 0.0:
                unused_width = 0.0
            var actual_spacing: Float32 = spacing
            var leading: Float32 = 0.0
            if main_alignment == JUSTIFY_SPACE_BETWEEN and count > 1:
                actual_spacing += unused_width / Float32(count - 1)
            elif main_alignment == JUSTIFY_CENTER:
                leading = unused_width * 0.5
            elif main_alignment == JUSTIFY_END:
                leading = unused_width

            var left = bounds.x + padding + leading
            if layout_kind == LAYOUT_LINEAR or layout_kind == LAYOUT_PORTAL:
                left -= scroll_offset
            for index in range(len(self.children)):
                if self.children[index].parent_id != parent_id:
                    continue
                var child_width = self.layout_width(index)
                if child_width <= 0.0:
                    child_width = self.children[index].constrained_width(
                        flexible_width
                    )
                var child_height = self.children[index].constrained_height(
                    content_height
                )
                var top = bounds.y + padding
                if cross_alignment != ALIGN_STRETCH:
                    child_height = self.layout_height(index)
                    if child_height > content_height:
                        child_height = content_height
                    if cross_alignment == ALIGN_CENTER:
                        top += (content_height - child_height) * 0.5
                    elif cross_alignment == ALIGN_END:
                        top += content_height - child_height
                self.children[index].bounds = Rect(left, top, child_width, child_height)
                self.layout_child_if_container(index)
                left += child_width + actual_spacing
            return

        var total_height: Float32 = 0.0
        for index in range(len(self.children)):
            if self.children[index].parent_id == parent_id:
                total_height += self.layout_height(index)
        if count > 1:
            total_height += spacing * Float32(count - 1)
        var unused_height = content_height - total_height
        if unused_height < 0.0:
            unused_height = 0.0
        var actual_spacing: Float32 = spacing
        var leading: Float32 = 0.0
        if main_alignment == JUSTIFY_SPACE_BETWEEN and count > 1:
            actual_spacing += unused_height / Float32(count - 1)
        elif main_alignment == JUSTIFY_CENTER:
            leading = unused_height * 0.5
        elif main_alignment == JUSTIFY_END:
            leading = unused_height

        var cursor = bounds.y + padding + leading
        if layout_kind == LAYOUT_LINEAR or layout_kind == LAYOUT_PORTAL:
            cursor -= scroll_offset
        for index in range(len(self.children)):
            if self.children[index].parent_id != parent_id:
                continue
            var height = self.layout_height(index)
            var width = content_width
            var left = bounds.x + padding
            var requested_width = self.layout_width(index)
            if cross_alignment == ALIGN_STRETCH:
                # Stretch fills the cross axis, but explicit constraints still
                # cap or expand the result. Without this, max-width is ignored
                # for ordinary column children.
                width = self.children[index].constrained_width(content_width)
            elif requested_width > 0.0:
                width = requested_width
                if width > content_width:
                    width = content_width
                if cross_alignment == ALIGN_CENTER:
                    left += (content_width - width) * 0.5
                elif cross_alignment == ALIGN_END:
                    left += content_width - width
            self.children[index].bounds = Rect(left, cursor, width, height)
            self.layout_child_if_container(index)
            cursor += height + actual_spacing

    def layout_children(mut self):
        """Compatibility spelling for the layout pass."""
        self.layout()

    def child_count(self) -> Int:
        return len(self.children)

    def child(self, index: Int) -> ViewNode:
        return self.children[index]

    def bounds_for(self, id: Int) -> Rect:
        for index in range(len(self.children)):
            if self.children[index].id == id:
                return self.children[index].bounds
        return Rect(0.0, 0.0, 0.0, 0.0)

    def is_focusable(self, id: Int) -> Bool:
        for index in range(len(self.children)):
            if self.children[index].id == id:
                return self.children[index].focusable and self.children[index].enabled
        return False

    def first_focusable_id(self) -> Int:
        for index in range(len(self.children)):
            if self.children[index].focusable and self.children[index].enabled:
                return self.children[index].id
        return -1

    def hit_test(self, position: Point) -> Int:
        """Return the interactive view id under a point, or -1 when there is no target."""
        var index = len(self.children) - 1
        while index >= 0:
            var child = self.children[index]
            if (
                child.focusable
                and child.enabled
                and self.point_is_visible(child, position)
                and child.bounds.contains(position)
            ):
                return child.id
            index -= 1
        return -1

    def point_is_visible(self, child: ViewNode, position: Point) -> Bool:
        """Respect root and ancestor clipping while routing pointer input."""
        if (
            (
                self.clip_to_bounds
                or self.scroll_max_offset(ROOT_SCROLL_ID) > 0.0
            )
            and not self.layout_spec.bounds.contains(position)
        ):
            return False
        var parent_id = child.parent_id
        var hops = 0
        while parent_id != -1:
            var found_parent = False
            var next_parent = -1
            for index in range(len(self.children)):
                var parent = self.children[index]
                if parent.id == parent_id:
                    found_parent = True
                    next_parent = parent.parent_id
                    if (
                        (
                            parent.clip_children
                            or self._is_scrollable_node(parent)
                        )
                        and not parent.bounds.contains(position)
                    ):
                        return False
                    break
            if not found_parent:
                return False
            parent_id = next_parent
            hops += 1
            if hops > len(self.children):
                return False
        return True

    def _is_scrollable_node(self, node: ViewNode) -> Bool:
        """Return whether a linear container node currently has overflow."""
        if (
            node.kind != CONTAINER_KIND
            or (
                node.container_layout_kind != LAYOUT_LINEAR
                and node.container_layout_kind != LAYOUT_PORTAL
            )
        ):
            return False
        var content = self._linear_content_extent(
            node.id,
            node.container_axis,
            node.container_padding,
            node.container_spacing,
        )
        var viewport = node.bounds.height
        if node.container_axis == ROW_AXIS:
            viewport = node.bounds.width
        return content > viewport


def make_row(bounds: Rect, padding: Float32, spacing: Float32) -> ColumnView:
    """Build a horizontal container with flexible children by default."""
    var row = ColumnView(bounds, padding, spacing)
    row.set_row_layout()
    return row^


struct CounterView:
    """The counter screen expressed as a small composed view tree."""

    var column: ColumnView
    var label: Label
    var button: Button

    def __init__(out self, count: Int):
        var count_text = String("Count: ", count)
        self.column = make_counter_column(
            count,
            Rect(0.0, 0.0, 384.0, 184.0),
        )

        self.label = Label(2, count_text, self.column.bounds_for(2))
        self.button = Button(
            3,
            "Increment",
            self.column.bounds_for(3),
        )

    def hit_test(self, position: Point) -> Int:
        """Route a point through the laid-out composed view tree."""
        return self.column.hit_test(position)
