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
    """The small set of visual properties supported by the preview renderer."""

    var fill: Color
    var text: Color
    var corner_radius: Float32
    var font_size: Float32

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
