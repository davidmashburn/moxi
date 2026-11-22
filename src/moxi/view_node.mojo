"""`ViewNode`: the lightweight declarative leaf in a Moxi view tree.

Also defines the view-kind discriminant constants that tag every
`ViewNode.kind` and the reserved root-scroll target id.
"""


from .accessibility import Semantics, default_semantics
from .geometry import Rect, Size
from .layout import ALIGN_STRETCH, COLUMN_AXIS, JUSTIFY_START, LAYOUT_LINEAR
from .style import Color, Style, Theme
from .measure import measure_text, measure_text_wrapped


comptime LABEL_KIND = 1
comptime BADGE_HORIZONTAL_PADDING: Float32 = 12.0
comptime BADGE_VERTICAL_PADDING: Float32 = 4.0
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


comptime _RECIPE_NONE = 0
comptime _RECIPE_PRIMARY = 1
comptime _RECIPE_SECONDARY = 2
comptime _RECIPE_DESTRUCTIVE = 3
comptime _RECIPE_OUTLINE = 4
comptime _RECIPE_GHOST = 5
comptime _RECIPE_BADGE = 6
comptime _RECIPE_ACCENT_BADGE = 7


struct RecipeRole(ImplicitlyCopyable):
    """Retained recipe identity, resolved from the enclosing theme."""

    var kind: Int

    def __init__(out self, kind: Int = _RECIPE_NONE):
        self.kind = kind

    @staticmethod
    def primary() -> Self:
        return Self(_RECIPE_PRIMARY)

    @staticmethod
    def secondary() -> Self:
        return Self(_RECIPE_SECONDARY)

    @staticmethod
    def destructive() -> Self:
        return Self(_RECIPE_DESTRUCTIVE)

    @staticmethod
    def outline() -> Self:
        return Self(_RECIPE_OUTLINE)

    @staticmethod
    def ghost() -> Self:
        return Self(_RECIPE_GHOST)

    @staticmethod
    def badge() -> Self:
        return Self(_RECIPE_BADGE)

    @staticmethod
    def accent_badge() -> Self:
        return Self(_RECIPE_ACCENT_BADGE)

    def is_none(self) -> Bool:
        return self.kind == _RECIPE_NONE

    def is_badge(self) -> Bool:
        return self.kind == _RECIPE_BADGE or self.kind == _RECIPE_ACCENT_BADGE

    def resolve(self, theme: Theme) -> Style:
        if self.is_none():
            return theme.button
        var c = theme.tokens.colors
        var r = theme.tokens.radius
        var t = theme.tokens.typography
        if self.kind == _RECIPE_PRIMARY:
            return Style(c.primary, c.primary_text, r.radius_md, t.text_base,
                         c.border_subtle, 0.0, 1.0)
        if self.kind == _RECIPE_SECONDARY:
            return Style(c.secondary, c.text, r.radius_md, t.text_base,
                         c.border_subtle, 1.0, 1.0)
        if self.kind == _RECIPE_DESTRUCTIVE:
            return Style(c.destructive, Color(1.0, 1.0, 1.0, 1.0),
                         r.radius_md, t.text_base, c.border_subtle, 0.0, 1.0)
        if self.kind == _RECIPE_OUTLINE:
            return Style(Color(0.0, 0.0, 0.0, 0.0), c.text,
                         r.radius_md, t.text_base, c.border, 1.0, 1.0)
        if self.kind == _RECIPE_GHOST:
            return Style(Color(0.0, 0.0, 0.0, 0.0), c.text_muted,
                         r.radius_md, t.text_base,
                         Color(0.0, 0.0, 0.0, 0.0), 0.0, 1.0)
        var fill = c.surface_raised
        var text_color = c.text_muted
        if self.kind == _RECIPE_ACCENT_BADGE:
            fill = c.primary
            text_color = c.primary_text
        return Style(fill, text_color, r.radius_full, t.text_xs,
                     c.border_subtle, 1.0, 1.0)


def _same_color(a: Color, b: Color) -> Bool:
    return (a.red == b.red and a.green == b.green and a.blue == b.blue
            and a.alpha == b.alpha)


struct _StyleOverrides(ImplicitlyCopyable):
    """Properties changed locally after the last theme resolution."""

    var fill: Bool
    var text: Bool
    var corner_radius: Bool
    var font_size: Bool
    var border: Bool
    var border_width: Bool
    var opacity: Bool

    def __init__(out self):
        self.fill = False
        self.text = False
        self.corner_radius = False
        self.font_size = False
        self.border = False
        self.border_width = False
        self.opacity = False

    def apply(mut self, current: Style, previous: Style, base: Style) -> Style:
        # Public style fields remain editable; remember changes made directly
        # as well as changes made through the property setters below.
        self.fill = self.fill or not _same_color(current.fill, previous.fill)
        self.text = self.text or not _same_color(current.text, previous.text)
        self.corner_radius = self.corner_radius or current.corner_radius != previous.corner_radius
        self.font_size = self.font_size or current.font_size != previous.font_size
        self.border = self.border or not _same_color(current.border, previous.border)
        self.border_width = self.border_width or current.border_width != previous.border_width
        self.opacity = self.opacity or current.opacity != previous.opacity
        var result = base
        if self.fill:
            result.fill = current.fill
        if self.text:
            result.text = current.text
        if self.corner_radius:
            result.corner_radius = current.corner_radius
        if self.font_size:
            result.font_size = current.font_size
        if self.border:
            result.border = current.border
        if self.border_width:
            result.border_width = current.border_width
        if self.opacity:
            result.opacity = current.opacity
        return result


def _style_for_kind(theme: Theme, kind: Int) -> Style:
    if kind == CONTAINER_KIND:
        return Style(Color(0.0, 0.0, 0.0, 0.0), theme.surface.text, 0.0, theme.surface.font_size)
    if kind == BUTTON_KIND:
        return theme.button
    if kind == TEXT_INPUT_VIEW_KIND:
        return theme.text_input
    if kind == CHECKBOX_KIND:
        return theme.control
    if kind == PROGRESS_KIND:
        return theme.progress
    if kind == SLIDER_KIND:
        return theme.slider
    if kind == SWITCH_KIND:
        return theme.switch_style
    if kind == RADIO_KIND:
        return theme.radio
    if kind == IMAGE_KIND:
        return theme.image
    if kind == MULTILINE_TEXT_KIND:
        return theme.multiline
    if kind == COMBO_BOX_KIND:
        return theme.combo_box
    if kind == LIST_KIND:
        return theme.list_style
    if kind == TABLE_KIND:
        return theme.table_style
    if kind == TREE_KIND:
        return theme.tree_style
    if kind == MENU_KIND:
        return theme.menu_style
    if kind == DIALOG_KIND:
        return theme.dialog_style
    if kind == TABS_KIND:
        return theme.tabs_style
    if kind == CANVAS_KIND:
        return theme.canvas_style
    if kind == SEPARATOR_KIND:
        return theme.separator_style
    return theme.label


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
    var badge_label: Bool
    var action_id: Int
    var clip_children: Bool
    var checked: Bool
    var progress: Float32
    var bounds: Rect
    var style: Style
    var has_explicit_style: Bool
    var recipe: RecipeRole
    var _resolved_style: Style
    var _recipe_style: Style
    var _style_overrides: _StyleOverrides
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
        var style = _style_for_kind(Theme(), kind)
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
        self.badge_label = False
        self.action_id = -1
        self.clip_children = False
        self.checked = False
        self.progress = 0.0
        self.bounds = Rect(0.0, 0.0, 0.0, 0.0)
        self.style = style
        self.has_explicit_style = False
        self.recipe = RecipeRole()
        self._resolved_style = style
        self._recipe_style = style
        self._style_overrides = _StyleOverrides()
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
        self.badge_label = False
        self.action_id = -1
        self.clip_children = False
        self.checked = False
        self.progress = 0.0
        self.bounds = Rect(0.0, 0.0, 0.0, 0.0)
        self.style = style
        self.has_explicit_style = True
        self.recipe = RecipeRole()
        self._resolved_style = style
        self._recipe_style = style
        self._style_overrides = _StyleOverrides()
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
        self.badge_label = False
        self.action_id = -1
        self.clip_children = False
        self.checked = False
        self.progress = 0.0
        self.bounds = Rect(0.0, 0.0, 0.0, 0.0)
        self.style = style
        self.has_explicit_style = True
        self.recipe = RecipeRole()
        self._resolved_style = style
        self._recipe_style = style
        self._style_overrides = _StyleOverrides()
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
        self.badge_label = False
        self.action_id = -1
        self.clip_children = False
        self.checked = False
        self.progress = 0.0
        self.bounds = Rect(0.0, 0.0, 0.0, 0.0)
        self.style = style
        self.has_explicit_style = True
        self.recipe = RecipeRole()
        self._resolved_style = style
        self._recipe_style = style
        self._style_overrides = _StyleOverrides()
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
        self.has_explicit_style = True
        self._resolved_style = style
        self._recipe_style = style
        self._style_overrides = _StyleOverrides()

    def set_font_size(mut self, size: Float32):
        """Override only typography size, retaining inherited colors."""
        self.style.font_size = size
        self._style_overrides.font_size = True

    def set_text_color(mut self, color: Color):
        """Override only the foreground color."""
        self.style.text = color
        self._style_overrides.text = True

    def set_corner_radius(mut self, radius: Float32):
        """Override only corner rounding."""
        self.style.corner_radius = radius
        self._style_overrides.corner_radius = True

    def inherit_style(mut self):
        """Restore theme defaults and clear local style overrides."""
        self.has_explicit_style = False
        self.recipe = RecipeRole()
        self.badge_label = False
        self.style = _style_for_kind(Theme(), self.kind)
        self._resolved_style = self.style
        self._style_overrides = _StyleOverrides()

    def _inherit_control_style(mut self):
        # Control descriptors expose an editable style field. Compare that
        # field with the ordinary default to retain any local property edits.
        self.has_explicit_style = False
        self._resolved_style = _style_for_kind(Theme(), self.kind)

    def set_recipe(mut self, role: RecipeRole, theme: Theme = Theme()):
        """Retain a variant rather than a snapshot of its initial palette."""
        self.recipe = role
        self.badge_label = self.kind == LABEL_KIND and role.is_badge()
        self.has_explicit_style = False
        self.style = role.resolve(theme)
        self._resolved_style = self.style
        self._recipe_style = self.style
        self._style_overrides = _StyleOverrides()

    def resolve_theme(
        mut self,
        theme: Theme,
        has_explicit_theme: Bool = True,
        owns_theme_surface: Bool = False,
    ):
        """Resolve inherited defaults, then retain local property overrides."""
        if self.has_explicit_style:
            return
        var base = _style_for_kind(theme, self.kind)
        if self.component_surface or owns_theme_surface:
            base = theme.surface
        elif not self.recipe.is_none():
            base = self._recipe_style
            if has_explicit_theme:
                base = self.recipe.resolve(theme)
        self.style = self._style_overrides.apply(self.style, self._resolved_style, base)
        self._resolved_style = self.style

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
        if self.kind == LABEL_KIND and self.badge_label:
            measured.width += BADGE_HORIZONTAL_PADDING * 2.0
            measured.height += BADGE_VERTICAL_PADDING * 2.0
        elif self.kind == BUTTON_KIND:
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

