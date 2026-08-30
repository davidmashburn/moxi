"""Backend-neutral colors and simple view styles."""

from .geometry import Rect


struct Color(ImplicitlyCopyable):
    """An RGBA color represented in normalized float components."""

    var red: Float32
    var green: Float32
    var blue: Float32
    var alpha: Float32

    def __init__(
        out self,
        red: Float32,
        green: Float32,
        blue: Float32,
        alpha: Float32,
    ):
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha


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

    def __init__(out self):
        self.surface = default_surface_style()
        self.panel = default_panel_style()
        self.label = default_label_style()
        self.button = default_button_style()
        self.text_input = default_text_input_style()
        self.control = default_checkbox_style()
        self.image = default_image_style()
        self.progress = default_progress_style()
        self.slider = default_slider_style()
        self.switch_style = default_switch_style()
        self.radio = default_radio_style()
        self.multiline = default_multiline_style()
        self.combo_box = default_text_input_style()
        self.list_style = default_text_input_style()
        self.table_style = default_text_input_style()
        self.tree_style = default_text_input_style()
        self.menu_style = default_text_input_style()
        self.dialog_style = default_panel_style()
        self.tabs_style = default_text_input_style()
        self.canvas_style = default_panel_style()
        self.separator_style = default_progress_style()

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
    return Style(
        Color(0.08, 0.10, 0.16, 1.0),
        Color(1.0, 1.0, 1.0, 1.0),
        0.0,
        0.0,
    )


def default_panel_style() -> Style:
    return Style(
        Color(0.16, 0.20, 0.30, 1.0),
        Color(1.0, 1.0, 1.0, 1.0),
        14.0,
        0.0,
    )


def default_label_style() -> Style:
    return Style(
        Color(0.0, 0.0, 0.0, 0.0),
        Color(1.0, 1.0, 1.0, 1.0),
        0.0,
        24.0,
    )


def default_button_style() -> Style:
    return Style(
        Color(0.18, 0.48, 0.92, 1.0),
        Color(1.0, 1.0, 1.0, 1.0),
        10.0,
        16.0,
    )


def default_text_input_style() -> Style:
    return Style(
        Color(0.07, 0.09, 0.14, 1.0),
        Color(1.0, 1.0, 1.0, 1.0),
        8.0,
        18.0,
    )


def default_checkbox_style() -> Style:
    """Return a compact style shared by checkbox renderers."""
    return Style(
        Color(0.07, 0.09, 0.14, 1.0),
        Color(1.0, 1.0, 1.0, 1.0),
        5.0,
        16.0,
    )


def default_progress_style() -> Style:
    """Return the track/fill style for a progress indicator."""
    return Style(
        Color(0.10, 0.14, 0.22, 1.0),
        Color(1.0, 1.0, 1.0, 1.0),
        8.0,
        14.0,
    )


def default_slider_style() -> Style:
    """Return the track style for a scalar slider control."""
    return Style(
        Color(0.10, 0.14, 0.22, 1.0),
        Color(0.35, 0.72, 1.0, 1.0),
        8.0,
        14.0,
    )


def default_switch_style() -> Style:
    """Return the visual style for a boolean switch control."""
    return Style(
        Color(0.14, 0.18, 0.28, 1.0),
        Color(1.0, 1.0, 1.0, 1.0),
        12.0,
        16.0,
    )


def default_radio_style() -> Style:
    """Return the visual style for a radio control."""
    return Style(
        Color(0.10, 0.14, 0.22, 1.0),
        Color(1.0, 1.0, 1.0, 1.0),
        10.0,
        16.0,
    )


def default_image_style() -> Style:
    """Return a neutral style for an image resource placeholder."""
    return Style(
        Color(0.12, 0.15, 0.22, 1.0),
        Color(1.0, 1.0, 1.0, 1.0),
        4.0,
        14.0,
    )


def default_multiline_style() -> Style:
    """Return the editor style for multiline text controls."""
    return Style(
        Color(0.07, 0.09, 0.14, 1.0),
        Color(1.0, 1.0, 1.0, 1.0),
        8.0,
        18.0,
    )
