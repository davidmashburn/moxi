"""The retained `Widget` and its declarative-node diffing helpers."""


from .accessibility import Semantics, default_semantics
from .event import NO_ACTION
from .geometry import Rect
from .layout import ALIGN_STRETCH, COLUMN_AXIS, JUSTIFY_START
from .style import Color, Style, default_label_style
from .view import LABEL_KIND, ViewNode


def colors_equal(left: Color, right: Color) -> Bool:
    return (
        left.red == right.red
        and left.green == right.green
        and left.blue == right.blue
        and left.alpha == right.alpha
    )


def styles_equal(left: Style, right: Style) -> Bool:
    return (
        colors_equal(left.fill, right.fill)
        and colors_equal(left.text, right.text)
        and left.corner_radius == right.corner_radius
        and left.font_size == right.font_size
        and colors_equal(left.border, right.border)
        and left.border_width == right.border_width
        and left.opacity == right.opacity
    )


def semantics_equal(left: Semantics, right: Semantics) -> Bool:
    # Bounds, enabled, and focused are materialized by the runtime from the
    # node and focus state. Compare only the declarative semantic payload.
    return (
        left.id == right.id
        and left.parent_id == right.parent_id
        and left.role == right.role
        and left.label == right.label
        and left.value == right.value
        and left.hint == right.hint
        and left.selected == right.selected
        and left.checked == right.checked
        and left.expanded == right.expanded
        and left.has_value_range == right.has_value_range
        and left.value_min == right.value_min
        and left.value_max == right.value_max
        and left.value_now == right.value_now
        and left.actions == right.actions
    )


struct Widget(ImplicitlyCopyable):
    """Retained runtime state corresponding to a declarative node."""

    var kind: Int
    var id: Int
    var text: String
    var bounds: Rect
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

    def __init__(out self, id: Int, text: String, bounds: Rect):
        self.kind = LABEL_KIND
        self.id = id
        self.text = text
        self.bounds = bounds
        self.preferred_height = bounds.height
        self.preferred_width = 0.0
        self.min_width = 0.0
        self.max_width = 0.0
        self.min_height = 0.0
        self.max_height = 0.0
        self.use_intrinsic_width = False
        self.use_intrinsic_height = False
        self.wrap_text = False
        self.action_id = NO_ACTION
        self.clip_children = False
        self.checked = False
        self.progress = 0.0
        self.style = default_label_style()
        self.component_surface = False
        self.focusable = False
        self.enabled = True
        self.cursor = 0
        self.selection_anchor = -1
        self.composition = ""
        self.composition_selection_start = 0
        self.composition_selection_end = 0
        self.semantics = default_semantics(id, LABEL_KIND, text)
        self.semantics.bounds = bounds
        self.parent_id = -1
        self.container_axis = COLUMN_AXIS
        self.container_padding = 0.0
        self.container_spacing = 0.0
        self.container_main_alignment = JUSTIFY_START
        self.container_cross_alignment = ALIGN_STRETCH
        self.container_layout_kind = 0
        self.container_grid_columns = 1
        self.container_split_fraction = 0.5
        self.container_scroll_offset = 0.0
        self.resource_id = -1

    def __init__(out self, node: ViewNode):
        self.kind = node.kind
        self.id = node.id
        self.text = node.text
        self.bounds = node.bounds
        self.preferred_height = node.preferred_height
        self.preferred_width = node.preferred_width
        self.min_width = node.min_width
        self.max_width = node.max_width
        self.min_height = node.min_height
        self.max_height = node.max_height
        self.use_intrinsic_width = node.use_intrinsic_width
        self.use_intrinsic_height = node.use_intrinsic_height
        self.wrap_text = node.wrap_text
        self.action_id = node.action_id
        self.clip_children = node.clip_children
        self.checked = node.checked
        self.progress = node.progress
        self.style = node.style
        self.component_surface = node.component_surface
        self.focusable = node.focusable
        self.enabled = node.enabled
        self.cursor = node.cursor
        self.selection_anchor = node.selection_anchor
        self.composition = node.composition
        self.composition_selection_start = node.composition_selection_start
        self.composition_selection_end = node.composition_selection_end
        self.semantics = node.semantics
        self.semantics.bounds = node.bounds
        self.semantics.enabled = node.enabled
        self.parent_id = node.parent_id
        self.container_axis = node.container_axis
        self.container_padding = node.container_padding
        self.container_spacing = node.container_spacing
        self.container_main_alignment = node.container_main_alignment
        self.container_cross_alignment = node.container_cross_alignment
        self.container_layout_kind = node.container_layout_kind
        self.container_grid_columns = node.container_grid_columns
        self.container_split_fraction = node.container_split_fraction
        self.container_scroll_offset = node.container_scroll_offset
        self.resource_id = node.resource_id

    def update(mut self, node: ViewNode) -> Bool:
        """Update a retained node and report whether its declarative data changed."""
        var changed = (
            self.kind != node.kind
            or self.id != node.id
            or self.text != node.text
            or self.bounds.x != node.bounds.x
            or self.bounds.y != node.bounds.y
            or self.bounds.width != node.bounds.width
            or self.bounds.height != node.bounds.height
            or self.preferred_height != node.preferred_height
            or self.preferred_width != node.preferred_width
            or self.min_width != node.min_width
            or self.max_width != node.max_width
            or self.min_height != node.min_height
            or self.max_height != node.max_height
            or self.use_intrinsic_width != node.use_intrinsic_width
            or self.use_intrinsic_height != node.use_intrinsic_height
            or self.wrap_text != node.wrap_text
            or self.action_id != node.action_id
            or self.clip_children != node.clip_children
            or self.checked != node.checked
            or self.progress != node.progress
            or not styles_equal(self.style, node.style)
            or self.component_surface != node.component_surface
            or self.focusable != node.focusable
            or self.enabled != node.enabled
            or self.cursor != node.cursor
            or self.selection_anchor != node.selection_anchor
            or self.composition != node.composition
            or self.composition_selection_start != node.composition_selection_start
            or self.composition_selection_end != node.composition_selection_end
            or not semantics_equal(self.semantics, node.semantics)
            or self.parent_id != node.parent_id
            or self.container_axis != node.container_axis
            or self.container_padding != node.container_padding
            or self.container_spacing != node.container_spacing
            or self.container_main_alignment != node.container_main_alignment
            or self.container_cross_alignment != node.container_cross_alignment
            or self.container_layout_kind != node.container_layout_kind
            or self.container_grid_columns != node.container_grid_columns
            or self.container_split_fraction != node.container_split_fraction
            or self.container_scroll_offset != node.container_scroll_offset
            or self.resource_id != node.resource_id
        )
        self.kind = node.kind
        self.id = node.id
        self.text = node.text
        self.bounds = node.bounds
        self.preferred_height = node.preferred_height
        self.preferred_width = node.preferred_width
        self.min_width = node.min_width
        self.max_width = node.max_width
        self.min_height = node.min_height
        self.max_height = node.max_height
        self.use_intrinsic_width = node.use_intrinsic_width
        self.use_intrinsic_height = node.use_intrinsic_height
        self.wrap_text = node.wrap_text
        self.action_id = node.action_id
        self.clip_children = node.clip_children
        self.checked = node.checked
        self.progress = node.progress
        self.style = node.style
        self.component_surface = node.component_surface
        self.focusable = node.focusable
        self.enabled = node.enabled
        self.cursor = node.cursor
        self.selection_anchor = node.selection_anchor
        self.composition = node.composition
        self.composition_selection_start = node.composition_selection_start
        self.composition_selection_end = node.composition_selection_end
        self.semantics = node.semantics
        self.semantics.bounds = node.bounds
        self.semantics.enabled = node.enabled
        self.parent_id = node.parent_id
        self.container_axis = node.container_axis
        self.container_padding = node.container_padding
        self.container_spacing = node.container_spacing
        self.container_main_alignment = node.container_main_alignment
        self.container_cross_alignment = node.container_cross_alignment
        self.container_layout_kind = node.container_layout_kind
        self.container_grid_columns = node.container_grid_columns
        self.container_split_fraction = node.container_split_fraction
        self.container_scroll_offset = node.container_scroll_offset
        self.resource_id = node.resource_id
        return changed
