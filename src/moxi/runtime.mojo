"""Retained widgets and the minimal reconciliation runtime."""

from std.collections import List

from .accessibility import (
    AccessibilitySnapshot,
    ROLE_BUTTON,
    ROLE_CHECKBOX,
    ROLE_RADIO,
    ROLE_COMBO_BOX,
    ROLE_LIST,
    ROLE_TABLE,
    ROLE_TREE,
    ROLE_MENU,
    ROLE_TAB_GROUP,
    ROLE_SLIDER,
    ROLE_TEXT_INPUT,
    ROLE_TEXT_AREA,
    ROLE_SWITCH,
    ROLE_DIALOG,
    ROLE_CANVAS,
    Semantics,
    default_semantics,
)
from .geometry import Point, Rect
from .event import KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_UP, NO_ACTION
from .layout import (
    ALIGN_STRETCH,
    COLUMN_AXIS,
    JUSTIFY_START,
    LAYOUT_LINEAR,
    LAYOUT_PORTAL,
    ROW_AXIS,
)
from .paint import PANEL_KIND, SURFACE_KIND, PaintCommand, PaintCommands
from .scrollbar import (
    SCROLLBAR_HORIZONTAL,
    SCROLLBAR_VERTICAL,
    ScrollbarState,
)
from .style import (
    Color,
    Panel,
    Style,
    default_button_style,
    default_label_style,
    default_panel_style,
    default_surface_style,
)
from .view import (
    BUTTON_KIND,
    CHECKBOX_KIND,
    CONTAINER_KIND,
    PROGRESS_KIND,
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
    TABS_KIND,
    SPACER_KIND,
    SCROLLBAR_KIND,
    TEXT_INPUT_VIEW_KIND,
    CounterView,
    LABEL_KIND,
    ColumnView,
    Label,
    ROOT_SCROLL_ID,
    ViewNode,
)


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


struct Runtime:
    """Reconciles one declarative Label into one retained Widget."""

    var widget: Widget

    def __init__(out self):
        self.widget = Widget(0, "", Rect(0.0, 0.0, 0.0, 0.0))

    def reconcile(mut self, view: Label):
        self.widget.id = view.id
        self.widget.text = view.text
        self.widget.bounds = view.bounds
        self.widget.semantics.label = view.text
        self.widget.semantics.bounds = view.bounds

    def paint(self) -> PaintCommand:
        return PaintCommand(self.widget.text, self.widget.bounds)


struct ColumnRuntime:
    """Retained children reconciled from a declarative ColumnView.

    `widgets` is a stable pool. `active_indices` describes the current
    declaration order, so reordering or removing a view does not require
    rebuilding the retained storage.
    """

    var widgets: List[Widget]
    var active_indices: List[Int]
    var previous_commands: List[PaintCommand]
    var root_bounds: Rect
    var root_axis: Int
    var root_padding: Float32
    var root_spacing: Float32
    var root_scroll_offset: Float32
    var clip_to_bounds: Bool
    var surface_style: Style
    var panel: Panel
    var has_panel: Bool
    var focused_id: Int
    var hovered_id: Int
    var pressed_id: Int
    var last_created_count: Int
    var last_reused_count: Int
    var last_updated_count: Int
    var last_removed_count: Int
    var last_moved_count: Int
    var last_validation_failed: Bool
    var identity_keys: List[Int]
    var identity_kinds: List[Int]
    var identity_values: List[Int]

    def __init__(out self):
        self.widgets = List[Widget]()
        self.active_indices = List[Int]()
        self.previous_commands = List[PaintCommand]()
        self.root_bounds = Rect(0.0, 0.0, 0.0, 0.0)
        self.root_axis = COLUMN_AXIS
        self.root_padding = 0.0
        self.root_spacing = 0.0
        self.root_scroll_offset = 0.0
        self.clip_to_bounds = False
        self.surface_style = default_surface_style()
        self.panel = Panel(0, Rect(0.0, 0.0, 0.0, 0.0), default_panel_style())
        self.has_panel = False
        self.focused_id = -1
        self.hovered_id = -1
        self.pressed_id = -1
        self.last_created_count = 0
        self.last_reused_count = 0
        self.last_updated_count = 0
        self.last_removed_count = 0
        self.last_moved_count = 0
        self.last_validation_failed = False
        self.identity_keys = List[Int]()
        self.identity_kinds = List[Int]()
        self.identity_values = List[Int]()

    def _identity_hash(self, id: Int, kind: Int, capacity: Int) -> Int:
        var value = id * 31 + kind
        if value < 0:
            value = -value
        return value % capacity

    def _prepare_identity_index(mut self):
        """Build a linear-probed index for the previous active frame."""
        var capacity = 8
        while capacity < len(self.active_indices) * 2:
            capacity *= 2
        self.identity_keys = List[Int](capacity=capacity)
        self.identity_kinds = List[Int](capacity=capacity)
        self.identity_values = List[Int](capacity=capacity)
        for _ in range(capacity):
            self.identity_keys.append(-1)
            self.identity_kinds.append(-1)
            self.identity_values.append(-1)
        for old_order in range(len(self.active_indices)):
            var retained_index = self.active_indices[old_order]
            var widget = self.widgets[retained_index]
            var slot = self._identity_hash(widget.id, widget.kind, capacity)
            while self.identity_values[slot] != -1:
                if (
                    self.identity_keys[slot] == widget.id
                    and self.identity_kinds[slot] == widget.kind
                ):
                    break
                slot = (slot + 1) % capacity
            if self.identity_values[slot] == -1:
                self.identity_keys[slot] = widget.id
                self.identity_kinds[slot] = widget.kind
                self.identity_values[slot] = retained_index

    def _take_identity(mut self, id: Int, kind: Int) -> Int:
        """Claim one previous identity, returning its retained slot once."""
        if len(self.identity_values) == 0:
            return -1
        var capacity = len(self.identity_values)
        var slot = self._identity_hash(id, kind, capacity)
        for _ in range(capacity):
            var value = self.identity_values[slot]
            if value == -1:
                return -1
            if self.identity_keys[slot] == id and self.identity_kinds[slot] == kind:
                if value < 0:
                    return -1
                self.identity_values[slot] = -2
                return value
            slot = (slot + 1) % capacity
        return -1

    def reconcile(mut self, view: ColumnView):
        """Reconcile by stable `(id, kind)` identity and preserve node storage."""
        self.last_validation_failed = False
        if not view.is_valid():
            self.last_validation_failed = True
            return
        var previous_focus = self.focused_id
        var previous_hover = self.hovered_id
        var previous_pressed = self.pressed_id
        self.root_bounds = view.layout_spec.bounds
        self.root_axis = view.axis
        self.root_padding = view.layout_spec.padding
        self.root_spacing = view.layout_spec.spacing
        self.root_scroll_offset = view.root_scroll_offset
        self.clip_to_bounds = view.clip_to_bounds
        self.surface_style = view.surface_style
        self.panel = view.panel
        self.has_panel = view.has_panel
        self.last_created_count = 0
        self.last_reused_count = 0
        self.last_updated_count = 0
        self.last_removed_count = 0
        self.last_moved_count = 0

        self._prepare_identity_index()
        var active_flags = List[Bool](capacity=len(self.widgets))
        var old_positions = List[Int](capacity=len(self.widgets))
        for _ in range(len(self.widgets)):
            active_flags.append(False)
            old_positions.append(-1)
        var free_indices = List[Int]()
        for old_order in range(len(self.active_indices)):
            var active_index = self.active_indices[old_order]
            active_flags[active_index] = True
            old_positions[active_index] = old_order
        for index in range(len(self.widgets)):
            if not active_flags[index]:
                free_indices.append(index)
        var free_head = 0
        var retained_flags = List[Bool](capacity=len(self.widgets))
        for _ in range(len(self.widgets)):
            retained_flags.append(False)

        var next_indices = List[Int](capacity=view.child_count())
        for index in range(view.child_count()):
            var node = view.child(index)
            var retained_index = self._take_identity(node.id, node.kind)
            var matched_active = retained_index != -1

            if retained_index == -1 and free_head < len(free_indices):
                retained_index = free_indices[free_head]
                free_head += 1

            if retained_index == -1:
                self.widgets.append(Widget(node))
                retained_index = len(self.widgets) - 1
                retained_flags.append(False)
                self.last_created_count += 1
            elif not matched_active:
                # The storage slot is reused, but the logical identity is
                # new and should still appear as a creation in the diff.
                _ = self.widgets[retained_index].update(node)
                self.last_created_count += 1
            else:
                var changed = self.widgets[retained_index].update(node)
                self.last_reused_count += 1
                if changed:
                    self.last_updated_count += 1

            var old_order = old_positions[retained_index] if retained_index < len(old_positions) else -1
            if matched_active and old_order != index:
                self.last_moved_count += 1
            if retained_index >= len(retained_flags):
                retained_flags.append(True)
            else:
                retained_flags[retained_index] = True
            next_indices.append(retained_index)

        for old_order in range(len(self.active_indices)):
            if not retained_flags[self.active_indices[old_order]]:
                self.last_removed_count += 1

        self.active_indices = next_indices^
        if previous_focus != -1 and view.is_focusable(previous_focus):
            self.focused_id = previous_focus
        else:
            self.focused_id = view.first_focusable_id()
        if previous_hover != -1 and view.is_focusable(previous_hover):
            self.hovered_id = previous_hover
        else:
            self.hovered_id = -1
        if previous_pressed != -1 and view.is_focusable(previous_pressed):
            self.pressed_id = previous_pressed
        else:
            self.pressed_id = -1

    def widget_count(self) -> Int:
        return len(self.active_indices)

    def widget(self, index: Int) -> Widget:
        return self.widgets[self.active_indices[index]]

    def retained_count(self) -> Int:
        """Return the number of allocated retained slots, including free ones."""
        return len(self.widgets)

    def retained_index(self, id: Int) -> Int:
        """Return the retained slot for an active stable id, or `-1`."""
        for index in range(len(self.active_indices)):
            var retained_index = self.active_indices[index]
            if self.widgets[retained_index].id == id:
                return retained_index
        return -1

    def last_created(self) -> Int:
        return self.last_created_count

    def last_reused(self) -> Int:
        return self.last_reused_count

    def last_updated(self) -> Int:
        return self.last_updated_count

    def last_removed(self) -> Int:
        return self.last_removed_count

    def last_moved(self) -> Int:
        return self.last_moved_count

    def validation_failed(self) -> Bool:
        """Return whether the most recent reconcile rejected the view tree."""
        return self.last_validation_failed

    def focus_id(self) -> Int:
        return self.focused_id

    def set_focus(mut self, id: Int) -> Bool:
        if id == self.focused_id:
            return False
        if id == -1:
            self.focused_id = -1
            return True
        for index in range(self.widget_count()):
            var widget = self.widget(index)
            if (
                widget.id == id
                and widget.focusable
                and widget.enabled
            ):
                self.focused_id = id
                return True
        return False

    def hover_id(self) -> Int:
        return self.hovered_id

    def set_hover(mut self, id: Int) -> Bool:
        if id == self.hovered_id:
            return False
        if id == -1:
            self.hovered_id = -1
            return True
        for index in range(self.widget_count()):
            var widget = self.widget(index)
            if (
                widget.id == id
                and widget.focusable
                and widget.enabled
            ):
                self.hovered_id = id
                return True
        return False

    def press(mut self, id: Int) -> Bool:
        if id == -1:
            var changed = self.pressed_id != -1
            self.pressed_id = -1
            return changed
        for index in range(self.widget_count()):
            var widget = self.widget(index)
            if (
                widget.id == id
                and widget.focusable
                and widget.enabled
            ):
                var changed = self.pressed_id != id
                self.pressed_id = id
                return changed
        return False

    def release(mut self, id: Int) -> Bool:
        var activated = self.pressed_id != -1 and self.pressed_id == id
        self.pressed_id = -1
        return activated

    def cancel_press(mut self) -> Bool:
        """Cancel pointer capture without synthesizing a click."""
        var changed = self.pressed_id != -1
        self.pressed_id = -1
        return changed

    def pressed_view_id(self) -> Int:
        return self.pressed_id

    def move_focus(mut self, reverse: Bool) -> Bool:
        var focusable_ids = List[Int]()
        for index in range(self.widget_count()):
            var widget = self.widget(index)
            if widget.focusable and widget.enabled:
                focusable_ids.append(widget.id)

        if len(focusable_ids) == 0:
            return False

        var current_index = -1
        for index in range(len(focusable_ids)):
            if focusable_ids[index] == self.focused_id:
                current_index = index
                break

        var target_index = 0
        if current_index == -1:
            if reverse:
                target_index = len(focusable_ids) - 1
        elif reverse:
            if current_index == 0:
                target_index = len(focusable_ids) - 1
            else:
                target_index = current_index - 1
        else:
            target_index = (current_index + 1) % len(focusable_ids)
        return self.set_focus(focusable_ids[target_index])

    def focused_kind(self) -> Int:
        """Return the kind of the focused node, or -1 when focus is empty."""
        for index in range(self.widget_count()):
            var widget = self.widget(index)
            if widget.id == self.focused_id:
                return widget.kind
        return -1

    def action_for(self, id: Int) -> Int:
        """Return a child's stable action id, or `NO_ACTION`."""
        for index in range(self.widget_count()):
            var widget = self.widget(index)
            if widget.id == id:
                return widget.action_id
        return NO_ACTION

    def _is_linear_layout(self, layout_kind: Int) -> Bool:
        """Return whether a container has a one-dimensional scroll axis."""
        return layout_kind == LAYOUT_LINEAR or layout_kind == LAYOUT_PORTAL

    def _root_content_extent(self) -> Float32:
        """Measure the laid-out direct children of the implicit root viewport."""
        var extent = self.root_padding * 2.0
        var child_count = 0
        for index in range(self.widget_count()):
            var child = self.widget(index)
            if child.parent_id != -1:
                continue
            if self.root_axis == ROW_AXIS:
                extent += child.bounds.width
            else:
                extent += child.bounds.height
            child_count += 1
        if child_count > 1:
            extent += self.root_spacing * Float32(child_count - 1)
        return extent

    def _container_content_extent(self, container: Widget) -> Float32:
        """Measure the laid-out direct children inside one linear container."""
        var extent = container.container_padding * 2.0
        var child_count = 0
        for index in range(self.widget_count()):
            var child = self.widget(index)
            if child.parent_id != container.id:
                continue
            if container.container_axis == ROW_AXIS:
                extent += child.bounds.width
            else:
                extent += child.bounds.height
            child_count += 1
        if child_count > 1:
            extent += container.container_spacing * Float32(child_count - 1)
        return extent

    def _container_viewport_extent(self, container: Widget) -> Float32:
        """Return the viewport length along a container's scroll axis."""
        if container.container_axis == ROW_AXIS:
            return container.bounds.width
        return container.bounds.height

    def _container_is_scrollable(self, container: Widget) -> Bool:
        """Return whether a linear container currently has overflow."""
        if (
            container.kind != CONTAINER_KIND
            or not self._is_linear_layout(container.container_layout_kind)
        ):
            return False
        return (
            self._container_content_extent(container)
            > self._container_viewport_extent(container)
        )

    def _root_is_scrollable(self) -> Bool:
        """Return whether the implicit root viewport currently has overflow."""
        var viewport = self.root_bounds.height
        if self.root_axis == ROW_AXIS:
            viewport = self.root_bounds.width
        return self._root_content_extent() > viewport

    def scroll_target(self, position: Point) -> Int:
        """Return the deepest overflowing container containing a scroll position."""
        var index = self.widget_count() - 1
        while index >= 0:
            var widget = self.widget(index)
            if (
                self._container_is_scrollable(widget)
                and self.point_is_visible(widget, position)
                and widget.bounds.contains(position)
            ):
                return widget.id
            index -= 1
        if self._root_is_scrollable() and self.root_bounds.contains(position):
            return ROOT_SCROLL_ID
        return -1

    def move_focus_direction(mut self, key: Int) -> Bool:
        """Move to the nearest semantic control in an arrow-key direction."""
        if (
            key != KEY_LEFT
            and key != KEY_RIGHT
            and key != KEY_UP
            and key != KEY_DOWN
        ):
            return False

        var source_x: Float32 = 0.0
        var source_y: Float32 = 0.0
        var found_source = False
        for index in range(self.widget_count()):
            var widget = self.widget(index)
            if widget.id == self.focused_id:
                source_x = widget.bounds.x + widget.bounds.width * 0.5
                source_y = widget.bounds.y + widget.bounds.height * 0.5
                found_source = True
                break
        if not found_source:
            return False

        var best_id = -1
        var best_score: Float32 = 1000000000.0
        for index in range(self.widget_count()):
            var candidate = self.widget(index)
            if (
                candidate.id == self.focused_id
                or not candidate.focusable
                or not candidate.enabled
                or (
                    candidate.semantics.role != ROLE_BUTTON
                    and candidate.semantics.role != ROLE_TEXT_INPUT
                    and candidate.semantics.role != ROLE_TEXT_AREA
                    and candidate.semantics.role != ROLE_CHECKBOX
                    and candidate.semantics.role != ROLE_SLIDER
                    and candidate.semantics.role != ROLE_SWITCH
                    and candidate.semantics.role != ROLE_RADIO
                    and candidate.semantics.role != ROLE_COMBO_BOX
                    and candidate.semantics.role != ROLE_LIST
                    and candidate.semantics.role != ROLE_TABLE
                    and candidate.semantics.role != ROLE_TREE
                    and candidate.semantics.role != ROLE_MENU
                    and candidate.semantics.role != ROLE_TAB_GROUP
                    and candidate.semantics.role != ROLE_DIALOG
                    and candidate.semantics.role != ROLE_CANVAS
                )
            ):
                continue

            var candidate_x = candidate.bounds.x + candidate.bounds.width * 0.5
            var candidate_y = candidate.bounds.y + candidate.bounds.height * 0.5
            var primary: Float32
            var secondary: Float32
            if key == KEY_LEFT:
                primary = source_x - candidate_x
                secondary = source_y - candidate_y
            elif key == KEY_RIGHT:
                primary = candidate_x - source_x
                secondary = source_y - candidate_y
            elif key == KEY_UP:
                primary = source_y - candidate_y
                secondary = source_x - candidate_x
            else:
                primary = candidate_y - source_y
                secondary = source_x - candidate_x

            if primary <= 0.0:
                continue
            if secondary < 0.0:
                secondary = -secondary
            var score = primary + secondary * 0.25
            if score < best_score:
                best_score = score
                best_id = candidate.id

        if best_id == -1:
            return False
        return self.set_focus(best_id)

    def command_changed(self, command: PaintCommand) -> Bool:
        """Return whether a command differs from the last painted frame."""
        for index in range(len(self.previous_commands)):
            var previous = self.previous_commands[index]
            if previous.kind == command.kind and previous.id == command.id:
                return not previous.equivalent(command)
        return True

    def previous_command_index(self, command: PaintCommand) -> Int:
        """Return the prior frame index for an identified command, or `-1`."""
        for index in range(len(self.previous_commands)):
            var previous = self.previous_commands[index]
            if previous.kind == command.kind and previous.id == command.id:
                return index
        return -1

    def paint(mut self) -> PaintCommands:
        var commands = PaintCommands()
        var surface = PaintCommand(
            SURFACE_KIND,
            0,
            0,
            "",
            self.root_bounds,
            self.surface_style,
        )
        surface.set_changed(self.command_changed(surface))
        commands.append(surface)
        if self.has_panel:
            var panel = PaintCommand(
                PANEL_KIND,
                self.panel.id,
                0,
                "",
                self.panel.bounds,
                self.panel.style,
            )
            panel.set_changed(self.command_changed(panel))
            commands.append(panel)
        var label_slot = 0
        var button_slot = 0
        var text_input_slot = 0
        var checkbox_slot = 0
        var progress_slot = 0
        var slider_slot = 0
        var scrollbar_slot = 0
        for index in range(self.widget_count()):
            var widget = self.widget(index)
            if widget.kind == SPACER_KIND or widget.kind == CONTAINER_KIND:
                continue
            var slot = label_slot
            if widget.kind == BUTTON_KIND:
                slot = button_slot
                button_slot += 1
            elif widget.kind == TEXT_INPUT_VIEW_KIND:
                slot = text_input_slot
                text_input_slot += 1
            elif widget.kind == CHECKBOX_KIND:
                slot = checkbox_slot
                checkbox_slot += 1
            elif widget.kind == PROGRESS_KIND:
                slot = progress_slot
                progress_slot += 1
            elif widget.kind == SLIDER_KIND:
                slot = slider_slot
                slider_slot += 1
            elif widget.kind == SWITCH_KIND:
                slot = checkbox_slot
                checkbox_slot += 1
            elif widget.kind == RADIO_KIND:
                slot = checkbox_slot
                checkbox_slot += 1
            elif widget.kind == IMAGE_KIND:
                slot = label_slot
                label_slot += 1
            elif widget.kind == MULTILINE_TEXT_KIND:
                slot = text_input_slot
                text_input_slot += 1
            elif (
                widget.kind == COMBO_BOX_KIND
                or widget.kind == LIST_KIND
                or widget.kind == TABLE_KIND
                or widget.kind == TREE_KIND
                or widget.kind == MENU_KIND
                or widget.kind == TABS_KIND
            ):
                slot = label_slot
                label_slot += 1
            else:
                label_slot += 1
            var command = PaintCommand(
                widget.kind,
                widget.id,
                slot,
                widget.text,
                widget.bounds,
                widget.style,
                widget.id == self.focused_id,
                widget.cursor,
                widget.id == self.hovered_id,
                widget.id == self.pressed_id,
                widget.enabled,
            )
            command.set_selection(widget.selection_anchor, widget.cursor)
            command.set_action(widget.action_id)
            command.set_composition(
                widget.composition,
                widget.composition_selection_start,
                widget.composition_selection_end,
            )
            command.set_wrap_text(widget.wrap_text)
            command.set_checked(widget.checked)
            command.set_progress(widget.progress)
            command.set_resource_id(widget.resource_id)
            var clip = self.root_bounds
            var clip_enabled = self.clip_to_bounds or self._root_is_scrollable()
            var parent_id = widget.parent_id
            var clip_hops = 0
            while parent_id != -1:
                var parent_found = False
                var next_parent = -1
                for parent_index in range(self.widget_count()):
                    var parent = self.widget(parent_index)
                    if parent.id == parent_id:
                        parent_found = True
                        next_parent = parent.parent_id
                        if parent.clip_children or self._container_is_scrollable(parent):
                            if clip_enabled:
                                clip = clip.intersection(parent.bounds)
                            else:
                                clip = parent.bounds
                                clip_enabled = True
                        break
                if not parent_found:
                    break
                parent_id = next_parent
                clip_hops += 1
                if clip_hops > self.widget_count():
                    break
            if clip_enabled:
                command.set_clip(clip)
            var semantics = widget.semantics
            semantics.bounds = widget.bounds
            semantics.enabled = widget.enabled
            semantics.focused = widget.id == self.focused_id
            command.semantics = semantics
            var previous_index = self.previous_command_index(command)
            var changed = self.command_changed(command)
            # A retained command can move without changing its own fields.
            # Incremental renderers still need to redraw it at the new stream
            # position, and the old bounds must be invalidated as well.
            if previous_index != -1 and previous_index != commands.count():
                changed = True
            if previous_index != -1 and changed:
                commands.mark_dirty(self.previous_commands[previous_index].bounds)
            command.set_changed(changed)
            commands.append(command)

        # Overflowing linear containers are clipped and wheel-scrollable, so keep a visible static
        # affordance in the same retained command stream. The renderer owns
        # only the final track/thumb pixels; offset and geometry stay portable.
        for index in range(self.widget_count()):
            var portal = self.widget(index)
            if not self._container_is_scrollable(portal):
                continue

            var orientation = SCROLLBAR_VERTICAL
            var viewport_extent = portal.bounds.height
            var track = Rect(
                portal.bounds.x + portal.bounds.width - 12.0,
                portal.bounds.y + 4.0,
                8.0,
                portal.bounds.height - 8.0,
            )
            if portal.container_axis == ROW_AXIS:
                orientation = SCROLLBAR_HORIZONTAL
                viewport_extent = portal.bounds.width
                track = Rect(
                    portal.bounds.x + 4.0,
                    portal.bounds.y + portal.bounds.height - 12.0,
                    portal.bounds.width - 8.0,
                    8.0,
                )
            if viewport_extent <= 0.0:
                continue

            var scrollbar = ScrollbarState(orientation, 18.0)
            scrollbar.set_metrics(
                self._container_content_extent(portal),
                viewport_extent,
            )
            _ = scrollbar.set_offset(portal.container_scroll_offset)
            var geometry = scrollbar.geometry(track)
            if not geometry.visible:
                continue

            var scrollbar_command = PaintCommand(
                SCROLLBAR_KIND,
                portal.id,
                scrollbar_slot,
                "",
                geometry.track,
                Style(
                    Color(0.055, 0.075, 0.125, 0.72),
                    Color(0.48, 0.79, 1.0, 0.94),
                    4.0,
                    0.0,
                ),
            )
            scrollbar_command.set_scrollbar(
                orientation,
                geometry.thumb,
                geometry.visible,
            )
            if self.clip_to_bounds or self._root_is_scrollable():
                scrollbar_command.set_clip(
                    self.root_bounds.intersection(portal.bounds)
                )
            elif portal.clip_children or self._container_is_scrollable(portal):
                scrollbar_command.set_clip(portal.bounds)

            var previous_index = self.previous_command_index(scrollbar_command)
            var changed = self.command_changed(scrollbar_command)
            if previous_index != -1 and previous_index != commands.count():
                changed = True
            if previous_index != -1 and changed:
                commands.mark_dirty(self.previous_commands[previous_index].bounds)
            scrollbar_command.set_changed(changed)
            commands.append(scrollbar_command)
            scrollbar_slot += 1

        # A ColumnView root is itself a viewport. Keep its bar in the same
        # command stream so standalone components get the same affordance as
        # content mounted inside an explicit portal.
        if self._root_is_scrollable():
            var root_orientation = SCROLLBAR_VERTICAL
            var root_viewport_extent = self.root_bounds.height
            var root_track = Rect(
                self.root_bounds.x + self.root_bounds.width - 12.0,
                self.root_bounds.y + 4.0,
                8.0,
                self.root_bounds.height - 8.0,
            )
            if self.root_axis == ROW_AXIS:
                root_orientation = SCROLLBAR_HORIZONTAL
                root_viewport_extent = self.root_bounds.width
                root_track = Rect(
                    self.root_bounds.x + 4.0,
                    self.root_bounds.y + self.root_bounds.height - 12.0,
                    self.root_bounds.width - 8.0,
                    8.0,
                )
            if root_viewport_extent > 0.0:
                var root_scrollbar = ScrollbarState(root_orientation, 18.0)
                root_scrollbar.set_metrics(
                    self._root_content_extent(),
                    root_viewport_extent,
                )
                _ = root_scrollbar.set_offset(self.root_scroll_offset)
                var root_geometry = root_scrollbar.geometry(root_track)
                if root_geometry.visible:
                    var root_command = PaintCommand(
                        SCROLLBAR_KIND,
                        ROOT_SCROLL_ID,
                        scrollbar_slot,
                        "",
                        root_geometry.track,
                        Style(
                            Color(0.055, 0.075, 0.125, 0.72),
                            Color(0.48, 0.79, 1.0, 0.94),
                            4.0,
                            0.0,
                        ),
                    )
                    root_command.set_scrollbar(
                        root_orientation,
                        root_geometry.thumb,
                        root_geometry.visible,
                    )
                    root_command.set_clip(self.root_bounds)
                    var previous_index = self.previous_command_index(root_command)
                    var changed = self.command_changed(root_command)
                    if previous_index != -1 and previous_index != commands.count():
                        changed = True
                    if previous_index != -1 and changed:
                        commands.mark_dirty(self.previous_commands[previous_index].bounds)
                    root_command.set_changed(changed)
                    commands.append(root_command)

        # A removed command leaves a stale region that an incremental backend
        # must clear, even though there is no current draw command for it.
        for previous_index in range(len(self.previous_commands)):
            var previous = self.previous_commands[previous_index]
            var found = False
            for current_index in range(commands.count()):
                var current = commands.command(current_index)
                if (
                    current.kind == previous.kind
                    and current.id == previous.id
                ):
                    found = True
                    break
            if not found:
                commands.mark_removed(previous.bounds)

        self.previous_commands = List[PaintCommand](capacity=commands.count())
        for index in range(commands.count()):
            self.previous_commands.append(commands.command(index))
        return commands^

    def accessibility(self) -> AccessibilitySnapshot:
        """Return the current ordered, backend-neutral accessibility snapshot."""
        var snapshot = AccessibilitySnapshot()
        for index in range(self.widget_count()):
            var widget = self.widget(index)
            if widget.kind == SPACER_KIND:
                continue
            var semantics = widget.semantics
            semantics.bounds = widget.bounds
            semantics.enabled = widget.enabled
            semantics.focused = widget.id == self.focused_id
            snapshot.append(semantics)
        return snapshot^

    def hit_test(self, position: Point) -> Int:
        var index = self.widget_count() - 1
        while index >= 0:
            var widget = self.widget(index)
            if (
                widget.focusable
                and widget.enabled
                and self.point_is_visible(widget, position)
                and widget.bounds.contains(position)
            ):
                return widget.id
            index -= 1
        return -1

    def point_is_visible(self, widget: Widget, position: Point) -> Bool:
        """Respect root and ancestor clipping while routing pointer input."""
        if (
            (self.clip_to_bounds or self._root_is_scrollable())
            and not self.root_bounds.contains(position)
        ):
            return False
        var parent_id = widget.parent_id
        var hops = 0
        while parent_id != -1:
            var found_parent = False
            var next_parent = -1
            for index in range(self.widget_count()):
                var parent = self.widget(index)
                if parent.id == parent_id:
                    found_parent = True
                    next_parent = parent.parent_id
                    if (
                        (parent.clip_children or self._container_is_scrollable(parent))
                        and not parent.bounds.contains(position)
                    ):
                        return False
                    break
            if not found_parent:
                return False
            parent_id = next_parent
            hops += 1
            if hops > self.widget_count():
                return False
        return True


struct CounterRuntime:
    """Retained state for the composed counter screen."""

    var column: ColumnRuntime
    var label: Widget
    var button: Widget

    def __init__(out self):
        self.column = ColumnRuntime()
        self.label = Widget(0, "", Rect(0.0, 0.0, 0.0, 0.0))
        self.button = Widget(0, "", Rect(0.0, 0.0, 0.0, 0.0))

    def reconcile(mut self, view: CounterView):
        """Reconcile the complete declarative column."""
        self.column.reconcile(view.column)
        self.label = Widget(
            view.label.id,
            view.label.text,
            view.label.bounds,
        )
        self.button = Widget(
            view.button.id,
            view.button.text,
            view.button.bounds,
        )
        self.button.kind = BUTTON_KIND
        self.button.style = default_button_style()

    def paint(mut self) -> PaintCommands:
        return self.column.paint()

    def hit_test(self, position: Point) -> Int:
        return self.column.hit_test(position)

    def paint_label(self) -> PaintCommand:
        return PaintCommand(self.label.text, self.label.bounds)

    def paint_button(self) -> PaintCommand:
        return PaintCommand(
            BUTTON_KIND,
            self.button.id,
            0,
            self.button.text,
            self.button.bounds,
            self.button.style,
        )
