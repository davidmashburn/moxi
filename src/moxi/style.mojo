"""Backend-neutral colors and simple view styles."""

from .geometry import Rect
from .palette import Color, ThemeTokens, dark_tokens


struct Style(ImplicitlyCopyable):
    """Backend-neutral visual properties shared by every renderer."""

    var fill: Color
    var text: Color
    var corner_radius: Float32
    var font_size: Float32
    var border: Color
    var border_width: Float32
    var opacity: Float32

    def __init__(
        out self,
        fill: Color,
        text: Color,
        corner_radius: Float32,
        font_size: Float32,
    ):
        self.fill = fill
        self.text = text
        self.corner_radius = corner_radius
        self.font_size = font_size
        self.border = Color(0.0, 0.0, 0.0, 0.0)
        self.border_width = 0.0
        self.opacity = 1.0

    def __init__(
        out self,
        fill: Color,
        text: Color,
        corner_radius: Float32,
        font_size: Float32,
        border: Color,
        border_width: Float32,
        opacity: Float32,
    ):
        self.fill = fill
        self.text = text
        self.corner_radius = corner_radius
        self.font_size = font_size
        self.border = border
        self.border_width = border_width if border_width > 0.0 else 0.0
        var value = opacity
        if value < 0.0:
            value = 0.0
        if value > 1.0:
            value = 1.0
        self.opacity = value

    def with_fill(self, color: Color) -> Style:
        var result = self
        result.fill = color
        return result

    def with_text_color(self, color: Color) -> Style:
        var result = self
        result.text = color
        return result

    def with_border(self, color: Color, width: Float32) -> Style:
        var result = self
        result.border = color
        result.border_width = width if width > 0.0 else 0.0
        return result

    def with_opacity(self, value: Float32) -> Style:
        var result = self
        var opacity_value = value
        if opacity_value < 0.0:
            opacity_value = 0.0
        if opacity_value > 1.0:
            opacity_value = 1.0
        result.opacity = opacity_value
        return result


struct Theme(ImplicitlyCopyable):
    """Composable default styles that an application can replace as a unit."""

    var surface: Style
    var panel: Style
    var label: Style
    var button: Style
    var text_input: Style
    var control: Style
    var image: Style
    var progress: Style
    var slider: Style
    var switch_style: Style
    var radio: Style
    var multiline: Style
    var combo_box: Style
    var list_style: Style
    var table_style: Style
    var tree_style: Style
    var menu_style: Style
    var dialog_style: Style
    var tabs_style: Style
    var canvas_style: Style
    var separator_style: Style

    var tokens: ThemeTokens

    def __init__(out self, tokens: ThemeTokens = dark_tokens()):
        self.tokens = tokens
        var c = tokens.colors
        var r = tokens.radius
        var t = tokens.typography

        # Surface & Panel
        self.surface = Style(
            c.background,
            c.text,
            r.radius_none,
            t.text_base,
        )
        self.panel = Style(
            c.surface,
            c.text,
            r.radius_lg,
            t.text_base,
            c.border,
            1.0,
            1.0,
        )

        # Label
        self.label = Style(
            Color(0.0, 0.0, 0.0, 0.0),
            c.text,
            r.radius_none,
            t.text_base,
        )

        # Button
        self.button = Style(
            c.secondary,
            c.text,
            r.radius_md,
            t.text_base,
            c.border,
            1.0,
            1.0,
        )

        # Text Input & Multiline
        self.text_input = Style(
            c.surface_raised,
            c.text,
            r.radius_md,
            t.text_base,
            c.border,
            1.0,
            1.0,
        )
        self.multiline = self.text_input

        # Controls: Checkbox, Switch, Radio
        self.control = Style(
            c.surface_raised,
            c.text,
            r.radius_sm,
            t.text_base,
            c.border,
            1.0,
            1.0,
        )
        self.switch_style = Style(
            c.secondary,
            c.text,
            r.radius_full,
            t.text_base,
            c.border,
            1.0,
            1.0,
        )
        self.radio = Style(
            c.surface_raised,
            c.text,
            r.radius_full,
            t.text_base,
            c.border,
            1.0,
            1.0,
        )

        # Progress & Slider
        self.progress = Style(
            c.muted,
            c.primary,
            r.radius_full,
            t.text_sm,
        )
        self.slider = self.progress

        # Image
        self.image = Style(
            c.surface_raised,
            c.text,
            r.radius_md,
            t.text_sm,
            c.border_subtle,
            1.0,
            1.0,
        )

        # Complex Catalog Controls
        self.combo_box = self.text_input
        self.list_style = Style(
            c.surface,
            c.text,
            r.radius_md,
            t.text_base,
            c.border,
            1.0,
            1.0,
        )
        self.table_style = self.list_style
        self.tree_style = self.list_style
        self.menu_style = self.text_input
        self.dialog_style = Style(
            c.surface,
            c.text,
            r.radius_xl,
            t.text_base,
            c.border,
            1.5,
            1.0,
        )
        self.tabs_style = Style(
            c.surface_raised,
            c.text,
            r.radius_md,
            t.text_base,
            c.border_subtle,
            1.0,
            1.0,
        )
        self.canvas_style = self.list_style
        self.separator_style = Style(
            c.border_subtle,
            c.text_muted,
            r.radius_none,
            t.text_xs,
        )

    def with_button(mut self, style: Style):
        self.button = style

    def with_text_input(mut self, style: Style):
        self.text_input = style

    def with_panel(mut self, style: Style):
        self.panel = style

    def with_control(mut self, style: Style):
        self.control = style

    def with_slider(mut self, style: Style):
        self.slider = style

    def with_switch(mut self, style: Style):
        self.switch_style = style

    def with_radio(mut self, style: Style):
        self.radio = style

    def with_combo_box(mut self, style: Style):
        self.combo_box = style

    def with_list(mut self, style: Style):
        self.list_style = style

    def with_table(mut self, style: Style):
        self.table_style = style

    def with_tree(mut self, style: Style):
        self.tree_style = style

    def with_menu(mut self, style: Style):
        self.menu_style = style

    def with_dialog(mut self, style: Style):
        self.dialog_style = style

    def with_tabs(mut self, style: Style):
        self.tabs_style = style

    def with_canvas(mut self, style: Style):
        self.canvas_style = style

    def with_separator(mut self, style: Style):
        self.separator_style = style


struct ThemeOverride(ImplicitlyCopyable):
    """Optional semantic colors to apply over the current enclosing theme."""

    var primary: Optional[Color]
    var primary_text: Optional[Color]
    var primary_hover: Optional[Color]
    var accent: Optional[Color]

    def __init__(
        out self, *, primary: Optional[Color] = None,
        primary_text: Optional[Color] = None, primary_hover: Optional[Color] = None,
        accent: Optional[Color] = None,
    ):
        self.primary = primary
        self.primary_text = primary_text
        self.primary_hover = primary_hover
        self.accent = accent

    def is_empty(self) -> Bool:
        return not (self.primary or self.primary_text or self.primary_hover or self.accent)

    def apply(self, var inherited: Theme) -> Theme:
        if self.primary:
            var color = self.primary.value()
            inherited.tokens.colors.primary = color
            # These two control defaults draw their value with the primary ink.
            inherited.progress.text = color
            inherited.slider.text = color
        if self.primary_text:
            inherited.tokens.colors.primary_text = self.primary_text.value()
        if self.primary_hover:
            inherited.tokens.colors.primary_hover = self.primary_hover.value()
        if self.accent:
            inherited.tokens.colors.accent = self.accent.value()
        return inherited


struct Panel(ImplicitlyCopyable):
    """A backend-neutral panel background command description."""

    var id: Int
    var bounds: Rect
    var style: Style

    def __init__(out self, id: Int, bounds: Rect, style: Style):
        self.id = id
        self.bounds = bounds
        self.style = style


def default_surface_style() -> Style:
    return Theme().surface


def default_panel_style() -> Style:
    return Theme().panel


def default_label_style() -> Style:
    return Theme().label


def default_button_style() -> Style:
    return Theme().button


def default_text_input_style() -> Style:
    return Theme().text_input


def default_checkbox_style() -> Style:
    return Theme().control


def default_progress_style() -> Style:
    return Theme().progress


def default_slider_style() -> Style:
    return Theme().slider


def default_switch_style() -> Style:
    return Theme().switch_style


def default_radio_style() -> Style:
    return Theme().radio


def default_image_style() -> Style:
    return Theme().image


def default_multiline_style() -> Style:
    return Theme().multiline
