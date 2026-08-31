"""Backend-neutral paint commands."""

from std.collections import List

from .accessibility import AccessibilitySnapshot, Semantics, default_semantics
from .backend import BackendCapabilities, BACKEND_HEADLESS, backend_capabilities
from .geometry import Rect
from .style import Color, Style, default_label_style
from .scene import Scene
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
)


comptime PANEL_KIND = 3
comptime SURFACE_KIND = 4


def paint_colors_equal(left: Color, right: Color) -> Bool:
    return (
        left.red == right.red
        and left.green == right.green
        and left.blue == right.blue
        and left.alpha == right.alpha
    )


def paint_styles_equal(left: Style, right: Style) -> Bool:
    return (
        paint_colors_equal(left.fill, right.fill)
        and paint_colors_equal(left.text, right.text)
        and left.corner_radius == right.corner_radius
        and left.font_size == right.font_size
        and paint_colors_equal(left.border, right.border)
        and left.border_width == right.border_width
        and left.opacity == right.opacity
    )


def paint_rects_equal(left: Rect, right: Rect) -> Bool:
    return (
        left.x == right.x
        and left.y == right.y
        and left.width == right.width
        and left.height == right.height
    )


def paint_semantics_equal(left: Semantics, right: Semantics) -> Bool:
    return (
        left.id == right.id
        and left.parent_id == right.parent_id
        and left.role == right.role
        and left.label == right.label
        and left.value == right.value
        and left.hint == right.hint
        and paint_rects_equal(left.bounds, right.bounds)
        and left.enabled == right.enabled
        and left.focused == right.focused
        and left.selected == right.selected
        and left.checked == right.checked
        and left.expanded == right.expanded
        and left.has_value_range == right.has_value_range
        and left.value_min == right.value_min
        and left.value_max == right.value_max
        and left.value_now == right.value_now
        and left.actions == right.actions
    )


struct PaintCommand(ImplicitlyCopyable):
    """A text-and-bounds command consumed by a renderer."""

    var kind: Int
    var id: Int
    var slot: Int
    var text: String
    var bounds: Rect
    var style: Style
    var focused: Bool
    var cursor: Int
    var hovered: Bool
    var pressed: Bool
    var enabled: Bool
    var selection_start: Int
    var selection_end: Int
    var composition: String
    var composition_selection_start: Int
    var composition_selection_end: Int
    var semantics: Semantics
    var wrap_text: Bool
    var action_id: Int
    var has_clip: Bool
    var clip_bounds: Rect
    var checked: Bool
    var progress: Float32
    var resource_id: Int
    var changed: Bool

    def __init__(out self, text: String, bounds: Rect):
        self.kind = LABEL_KIND
        self.id = 0
        self.slot = 0
        self.text = text
        self.bounds = bounds
        self.style = default_label_style()
        self.focused = False
        self.cursor = 0
        self.hovered = False
        self.pressed = False
        self.enabled = True
        self.selection_start = 0
        self.selection_end = 0
        self.composition = ""
        self.composition_selection_start = 0
        self.composition_selection_end = 0
        self.semantics = default_semantics(0, LABEL_KIND, text)
        self.semantics.bounds = bounds
        self.wrap_text = False
        self.action_id = -1
        self.has_clip = False
        self.clip_bounds = Rect(0.0, 0.0, 0.0, 0.0)
        self.checked = False
        self.progress = 0.0
        self.resource_id = -1
        self.changed = True

    def __init__(
        out self,
        kind: Int,
        id: Int,
        slot: Int,
        text: String,
        bounds: Rect,
        style: Style,
    ):
        self.kind = kind
        self.id = id
        self.slot = slot
        self.text = text
        self.bounds = bounds
        self.style = style
        self.focused = False
        self.cursor = 0
        self.hovered = False
        self.pressed = False
        self.enabled = True
        self.selection_start = 0
        self.selection_end = 0
        self.composition = ""
        self.composition_selection_start = 0
        self.composition_selection_end = 0
        self.semantics = default_semantics(id, kind, text)
        self.semantics.bounds = bounds
        self.wrap_text = False
        self.action_id = -1
        self.has_clip = False
        self.clip_bounds = Rect(0.0, 0.0, 0.0, 0.0)
        self.checked = False
        self.progress = 0.0
        self.resource_id = -1
        self.changed = True

    def __init__(
        out self,
        kind: Int,
        id: Int,
        slot: Int,
        text: String,
        bounds: Rect,
        style: Style,
        focused: Bool,
        cursor: Int,
        hovered: Bool,
        pressed: Bool,
        enabled: Bool,
    ):
        self.kind = kind
        self.id = id
        self.slot = slot
        self.text = text
        self.bounds = bounds
        self.style = style
        self.focused = focused
        self.cursor = cursor
        self.hovered = hovered
        self.pressed = pressed
        self.enabled = enabled
        self.selection_start = 0
        self.selection_end = 0
        self.composition = ""
        self.composition_selection_start = 0
        self.composition_selection_end = 0
        self.semantics = default_semantics(id, kind, text)
        self.semantics.bounds = bounds
        self.wrap_text = False
        self.action_id = -1
        self.has_clip = False
        self.clip_bounds = Rect(0.0, 0.0, 0.0, 0.0)
        self.checked = False
        self.progress = 0.0
        self.resource_id = -1
        self.changed = True

    def set_selection(mut self, anchor: Int, cursor: Int):
        """Store a normalized codepoint selection for text-input renderers."""
        if anchor == -1 or anchor == cursor:
            self.selection_start = cursor
            self.selection_end = cursor
        elif anchor < cursor:
            self.selection_start = anchor
            self.selection_end = cursor
        else:
            self.selection_start = cursor
            self.selection_end = anchor

    def has_selection(self) -> Bool:
        return self.selection_start != self.selection_end

    def set_changed(mut self, changed: Bool):
        """Set whether this command differs from the previous painted frame."""
        self.changed = changed

    def is_changed(self) -> Bool:
        return self.changed

    def equivalent(self, other: PaintCommand) -> Bool:
        """Compare all frame-visible fields, excluding the transient changed bit."""
        return (
            self.kind == other.kind
            and self.id == other.id
            and self.slot == other.slot
            and self.text == other.text
            and paint_rects_equal(self.bounds, other.bounds)
            and paint_styles_equal(self.style, other.style)
            and self.focused == other.focused
            and self.cursor == other.cursor
            and self.hovered == other.hovered
            and self.pressed == other.pressed
            and self.enabled == other.enabled
            and self.selection_start == other.selection_start
            and self.selection_end == other.selection_end
            and self.composition == other.composition
            and self.composition_selection_start == other.composition_selection_start
            and self.composition_selection_end == other.composition_selection_end
            and paint_semantics_equal(self.semantics, other.semantics)
            and self.wrap_text == other.wrap_text
            and self.action_id == other.action_id
            and self.has_clip == other.has_clip
            and paint_rects_equal(self.clip_bounds, other.clip_bounds)
            and self.checked == other.checked
            and self.progress == other.progress
            and self.resource_id == other.resource_id
        )

    def set_composition(
        mut self,
        text: String,
        selection_start: Int,
        selection_end: Int,
    ):
        """Store transient IME text for a text-input renderer."""
        self.composition = text
        self.composition_selection_start = selection_start
        self.composition_selection_end = selection_end

    def set_wrap_text(mut self, enabled: Bool):
        """Set whether the renderer should wrap this command's text."""
        self.wrap_text = enabled

    def set_action(mut self, action_id: Int):
        """Attach a stable action id for backend or test inspection."""
        self.action_id = action_id

    def set_clip(mut self, bounds: Rect):
        """Set an explicit clip rectangle for this draw command."""
        self.has_clip = True
        self.clip_bounds = bounds

    def clear_clip(mut self):
        """Disable clipping for this draw command."""
        self.has_clip = False

    def set_checked(mut self, checked: Bool):
        """Store checkbox state for backend renderers."""
        self.checked = checked

    def set_progress(mut self, progress: Float32):
        """Store a normalized progress fraction for backend renderers."""
        var value = progress
        if value < 0.0:
            value = 0.0
        if value > 1.0:
            value = 1.0
        self.progress = value

    def set_resource_id(mut self, resource_id: Int):
        """Associate a paint command with an external image/resource id."""
        self.resource_id = resource_id


struct PaintCommands:
    """An ordered, backend-neutral command stream for one frame."""

    var commands: List[PaintCommand]
    var removed_regions: List[Rect]
    var changed_commands: Int
    var removed_commands: Int
    var dirty_bounds: Rect
    var has_dirty_bounds: Bool

    def __init__(out self):
        self.commands = List[PaintCommand]()
        self.removed_regions = List[Rect]()
        self.changed_commands = 0
        self.removed_commands = 0
        self.dirty_bounds = Rect(0.0, 0.0, 0.0, 0.0)
        self.has_dirty_bounds = False

    def append(mut self, command: PaintCommand):
        self.commands.append(command)
        if command.changed:
            self.changed_commands += 1
            self.mark_dirty(command.bounds)

    def mark_dirty(mut self, bounds: Rect):
        """Merge a rendered or removed command region into the dirty bounds."""
        if not self.has_dirty_bounds:
            self.dirty_bounds = bounds
            self.has_dirty_bounds = True
            return
        var x = self.dirty_bounds.x
        if bounds.x < x:
            x = bounds.x
        var y = self.dirty_bounds.y
        if bounds.y < y:
            y = bounds.y
        var right = self.dirty_bounds.x + self.dirty_bounds.width
        if bounds.x + bounds.width > right:
            right = bounds.x + bounds.width
        var bottom = self.dirty_bounds.y + self.dirty_bounds.height
        if bounds.y + bounds.height > bottom:
            bottom = bounds.y + bounds.height
        self.dirty_bounds = Rect(x, y, right - x, bottom - y)

    def mark_removed(mut self, bounds: Rect):
        """Record a region occupied by a command removed from the frame."""
        self.removed_regions.append(bounds)
        self.removed_commands += 1
        self.mark_dirty(bounds)

    def count(self) -> Int:
        return len(self.commands)

    def command(self, index: Int) -> PaintCommand:
        return self.commands[index]

    def changed_count(self) -> Int:
        return self.changed_commands

    def removed_count(self) -> Int:
        return self.removed_commands

    def removed_region(self, index: Int) -> Rect:
        """Return one stale region that an incremental backend must clear."""
        return self.removed_regions[index]

    def has_dirty_region(self) -> Bool:
        return self.has_dirty_bounds

    def dirty_region(self) -> Rect:
        return self.dirty_bounds


trait Renderer:
    """A platform backend consumes commands without owning view state."""

    def backend_capabilities(self) -> BackendCapabilities:
        """Describe the backend without requiring a platform import."""
        return backend_capabilities(BACKEND_HEADLESS)

    def begin_frame(mut self) raises:
        pass

    def update_accessibility(
        mut self,
        snapshot: AccessibilitySnapshot,
    ) raises:
        """Publish backend-neutral semantics to an optional platform bridge."""
        pass

    def supports_incremental(self) -> Bool:
        """Return whether the backend retains surfaces between frames."""
        return False

    def clear_region(mut self, bounds: Rect) raises:
        """Clear one stale region before drawing an incremental frame."""
        pass

    def draw(mut self, command: PaintCommand) raises:
        if command.kind == SURFACE_KIND:
            self.draw_surface(command)
        elif command.kind == PANEL_KIND:
            self.draw_panel(command)
        elif command.kind == LABEL_KIND:
            self.draw_label(command)
        elif command.kind == BUTTON_KIND:
            self.draw_button(command)
        elif command.kind == TEXT_INPUT_VIEW_KIND:
            self.draw_text_input(command)
        elif command.kind == CHECKBOX_KIND:
            self.draw_checkbox(command)
        elif command.kind == PROGRESS_KIND:
            self.draw_progress(command)
        elif command.kind == SLIDER_KIND:
            self.draw_slider(command)
        elif command.kind == SWITCH_KIND:
            self.draw_switch(command)
        elif command.kind == RADIO_KIND:
            self.draw_radio(command)
        elif command.kind == IMAGE_KIND:
            self.draw_image(command)
        elif command.kind == MULTILINE_TEXT_KIND:
            self.draw_multiline_text(command)
        elif command.kind == COMBO_BOX_KIND:
            self.draw_combo_box(command)
        elif command.kind == LIST_KIND:
            self.draw_list(command)
        elif command.kind == TABLE_KIND:
            self.draw_table(command)
        elif command.kind == TREE_KIND:
            self.draw_tree(command)
        elif command.kind == MENU_KIND:
            self.draw_menu(command)
        elif command.kind == DIALOG_KIND:
            self.draw_dialog(command)
        elif command.kind == TABS_KIND:
            self.draw_tabs(command)
        elif command.kind == CANVAS_KIND:
            self.draw_canvas(command)
        elif command.kind == SEPARATOR_KIND:
            self.draw_separator(command)

    def draw_surface(mut self, command: PaintCommand) raises:
        pass

    def draw_panel(mut self, command: PaintCommand) raises:
        pass

    def draw_label(mut self, command: PaintCommand) raises:
        pass

    def draw_button(mut self, command: PaintCommand) raises:
        pass

    def draw_text_input(mut self, command: PaintCommand) raises:
        pass

    def draw_checkbox(mut self, command: PaintCommand) raises:
        pass

    def draw_progress(mut self, command: PaintCommand) raises:
        pass

    def draw_slider(mut self, command: PaintCommand) raises:
        pass

    def draw_switch(mut self, command: PaintCommand) raises:
        pass

    def draw_radio(mut self, command: PaintCommand) raises:
        pass

    def draw_image(mut self, command: PaintCommand) raises:
        pass

    def draw_multiline_text(mut self, command: PaintCommand) raises:
        pass

    def draw_combo_box(mut self, command: PaintCommand) raises:
        pass

    def draw_list(mut self, command: PaintCommand) raises:
        pass

    def draw_table(mut self, command: PaintCommand) raises:
        pass

    def draw_tree(mut self, command: PaintCommand) raises:
        pass

    def draw_menu(mut self, command: PaintCommand) raises:
        pass

    def draw_dialog(mut self, command: PaintCommand) raises:
        pass

    def draw_tabs(mut self, command: PaintCommand) raises:
        pass

    def draw_canvas(mut self, command: PaintCommand) raises:
        pass

    def draw_separator(mut self, command: PaintCommand) raises:
        pass


def scene_from_paint(commands: PaintCommands) -> Scene:
    """Translate the retained paint stream into the backend-neutral scene IR."""
    var scene = Scene()
    for index in range(commands.count()):
        var command = commands.command(index)
        if command.kind == SURFACE_KIND or command.kind == PANEL_KIND:
            if command.style.corner_radius > 0.0:
                scene.append_rounded_rect(
                    command.id,
                    command.bounds,
                    command.style.fill,
                    command.style.corner_radius,
                )
            else:
                scene.append_rect(command.id, command.bounds, command.style.fill)
        elif command.kind == IMAGE_KIND:
            scene.append_image(command.id, command.resource_id, command.bounds)
        elif command.kind == SEPARATOR_KIND:
            scene.append_rect(command.id, command.bounds, command.style.fill)
        else:
            scene.append_text(command.id, command.text, command.bounds, command.style.text)
    return scene^
