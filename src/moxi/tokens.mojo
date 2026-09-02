"""Design tokens and coherent theme presets for Moxi."""

from .style import Color, Style, Theme


struct SpacingTokens(ImplicitlyCopyable):
    """Layout spacing scale for paddings, margins, and container gaps."""

    var space_xs: Float32
    var space_sm: Float32
    var space_md: Float32
    var space_lg: Float32
    var space_xl: Float32
    var space_2xl: Float32

    def __init__(out self):
        self.space_xs = 2.0
        self.space_sm = 4.0
        self.space_md = 8.0
        self.space_lg = 12.0
        self.space_xl = 16.0
        self.space_2xl = 24.0

    def __init__(
        out self,
        space_xs: Float32,
        space_sm: Float32,
        space_md: Float32,
        space_lg: Float32,
        space_xl: Float32,
        space_2xl: Float32,
    ):
        self.space_xs = space_xs
        self.space_sm = space_sm
        self.space_md = space_md
        self.space_lg = space_lg
        self.space_xl = space_xl
        self.space_2xl = space_2xl


struct RadiusTokens(ImplicitlyCopyable):
    """Corner radius scale for panels, controls, and badges."""

    var radius_none: Float32
    var radius_sm: Float32
    var radius_md: Float32
    var radius_lg: Float32
    var radius_xl: Float32
    var radius_full: Float32

    def __init__(out self):
        self.radius_none = 0.0
        self.radius_sm = 4.0
        self.radius_md = 6.0
        self.radius_lg = 10.0
        self.radius_xl = 16.0
        self.radius_full = 999.0

    def __init__(
        out self,
        radius_none: Float32,
        radius_sm: Float32,
        radius_md: Float32,
        radius_lg: Float32,
        radius_xl: Float32,
        radius_full: Float32,
    ):
        self.radius_none = radius_none
        self.radius_sm = radius_sm
        self.radius_md = radius_md
        self.radius_lg = radius_lg
        self.radius_xl = radius_xl
        self.radius_full = radius_full


struct TypographyTokens(ImplicitlyCopyable):
    """Font size scale for hierarchy and text styling."""

    var text_xs: Float32
    var text_sm: Float32
    var text_base: Float32
    var text_lg: Float32
    var text_xl: Float32
    var text_2xl: Float32

    def __init__(out self):
        self.text_xs = 11.0
        self.text_sm = 13.0
        self.text_base = 15.0
        self.text_lg = 18.0
        self.text_xl = 22.0
        self.text_2xl = 28.0

    def __init__(
        out self,
        text_xs: Float32,
        text_sm: Float32,
        text_base: Float32,
        text_lg: Float32,
        text_xl: Float32,
        text_2xl: Float32,
    ):
        self.text_xs = text_xs
        self.text_sm = text_sm
        self.text_base = text_base
        self.text_lg = text_lg
        self.text_xl = text_xl
        self.text_2xl = text_2xl


struct ColorTokens(ImplicitlyCopyable):
    """Semantic color palette tokens inspired by modern design systems."""

    var background: Color
    var surface: Color
    var surface_raised: Color
    var primary: Color
    var primary_hover: Color
    var secondary: Color
    var secondary_hover: Color
    var muted: Color
    var muted_text: Color
    var border: Color
    var border_subtle: Color
    var destructive: Color
    var destructive_hover: Color
    var accent: Color
    var text: Color
    var text_muted: Color

    def __init__(
        out self,
        background: Color,
        surface: Color,
        surface_raised: Color,
        primary: Color,
        primary_hover: Color,
        secondary: Color,
        secondary_hover: Color,
        muted: Color,
        muted_text: Color,
        border: Color,
        border_subtle: Color,
        destructive: Color,
        destructive_hover: Color,
        accent: Color,
        text: Color,
        text_muted: Color,
    ):
        self.background = background
        self.surface = surface
        self.surface_raised = surface_raised
        self.primary = primary
        self.primary_hover = primary_hover
        self.secondary = secondary
        self.secondary_hover = secondary_hover
        self.muted = muted
        self.muted_text = muted_text
        self.border = border
        self.border_subtle = border_subtle
        self.destructive = destructive
        self.destructive_hover = destructive_hover
        self.accent = accent
        self.text = text
        self.text_muted = text_muted


struct ThemeTokens(ImplicitlyCopyable):
    """Bundle of design tokens defining an entire visual theme."""

    var colors: ColorTokens
    var spacing: SpacingTokens
    var radius: RadiusTokens
    var typography: TypographyTokens

    def __init__(
        out self,
        colors: ColorTokens,
        spacing: SpacingTokens = SpacingTokens(),
        radius: RadiusTokens = RadiusTokens(),
        typography: TypographyTokens = TypographyTokens(),
    ):
        self.colors = colors
        self.spacing = spacing
        self.radius = radius
        self.typography = typography


def dark_tokens() -> ThemeTokens:
    """Dark slate/indigo theme tokens."""
    var colors = ColorTokens(
        background=Color(0.06, 0.08, 0.12, 1.0),
        surface=Color(0.10, 0.13, 0.20, 1.0),
        surface_raised=Color(0.14, 0.18, 0.28, 1.0),
        primary=Color(0.24, 0.52, 0.96, 1.0),
        primary_hover=Color(0.32, 0.60, 1.0, 1.0),
        secondary=Color(0.18, 0.23, 0.35, 1.0),
        secondary_hover=Color(0.24, 0.30, 0.44, 1.0),
        muted=Color(0.12, 0.16, 0.24, 1.0),
        muted_text=Color(0.60, 0.66, 0.76, 1.0),
        border=Color(0.22, 0.28, 0.40, 1.0),
        border_subtle=Color(0.15, 0.20, 0.30, 1.0),
        destructive=Color(0.88, 0.26, 0.26, 1.0),
        destructive_hover=Color(0.96, 0.34, 0.34, 1.0),
        accent=Color(0.35, 0.72, 1.0, 1.0),
        text=Color(0.96, 0.98, 1.0, 1.0),
        text_muted=Color(0.55, 0.62, 0.74, 1.0),
    )
    return ThemeTokens(colors)


def light_tokens() -> ThemeTokens:
    """Crisp light theme tokens."""
    var colors = ColorTokens(
        background=Color(0.98, 0.98, 0.99, 1.0),
        surface=Color(1.0, 1.0, 1.0, 1.0),
        surface_raised=Color(0.94, 0.95, 0.97, 1.0),
        primary=Color(0.12, 0.42, 0.90, 1.0),
        primary_hover=Color(0.08, 0.34, 0.78, 1.0),
        secondary=Color(0.92, 0.94, 0.96, 1.0),
        secondary_hover=Color(0.86, 0.88, 0.92, 1.0),
        muted=Color(0.95, 0.96, 0.97, 1.0),
        muted_text=Color(0.42, 0.46, 0.54, 1.0),
        border=Color(0.82, 0.85, 0.90, 1.0),
        border_subtle=Color(0.90, 0.92, 0.95, 1.0),
        destructive=Color(0.84, 0.20, 0.20, 1.0),
        destructive_hover=Color(0.72, 0.14, 0.14, 1.0),
        accent=Color(0.12, 0.50, 0.92, 1.0),
        text=Color(0.08, 0.10, 0.15, 1.0),
        text_muted=Color(0.45, 0.50, 0.58, 1.0),
    )
    return ThemeTokens(colors)


def zinc_tokens() -> ThemeTokens:
    """Minimalist neutral zinc theme tokens."""
    var colors = ColorTokens(
        background=Color(0.09, 0.09, 0.11, 1.0),
        surface=Color(0.14, 0.14, 0.17, 1.0),
        surface_raised=Color(0.20, 0.20, 0.24, 1.0),
        primary=Color(0.95, 0.95, 0.97, 1.0),
        primary_hover=Color(1.0, 1.0, 1.0, 1.0),
        secondary=Color(0.22, 0.22, 0.26, 1.0),
        secondary_hover=Color(0.28, 0.28, 0.33, 1.0),
        muted=Color(0.16, 0.16, 0.19, 1.0),
        muted_text=Color(0.62, 0.62, 0.68, 1.0),
        border=Color(0.26, 0.26, 0.31, 1.0),
        border_subtle=Color(0.18, 0.18, 0.22, 1.0),
        destructive=Color(0.85, 0.25, 0.25, 1.0),
        destructive_hover=Color(0.95, 0.32, 0.32, 1.0),
        accent=Color(0.80, 0.80, 0.85, 1.0),
        text=Color(0.96, 0.96, 0.98, 1.0),
        text_muted=Color(0.58, 0.58, 0.64, 1.0),
    )
    return ThemeTokens(colors)


def emerald_tokens() -> ThemeTokens:
    """Emerald/Teal accent theme tokens."""
    var colors = ColorTokens(
        background=Color(0.04, 0.09, 0.08, 1.0),
        surface=Color(0.08, 0.15, 0.13, 1.0),
        surface_raised=Color(0.12, 0.22, 0.19, 1.0),
        primary=Color(0.10, 0.68, 0.50, 1.0),
        primary_hover=Color(0.16, 0.78, 0.58, 1.0),
        secondary=Color(0.13, 0.24, 0.21, 1.0),
        secondary_hover=Color(0.18, 0.32, 0.28, 1.0),
        muted=Color(0.09, 0.17, 0.15, 1.0),
        muted_text=Color(0.58, 0.72, 0.68, 1.0),
        border=Color(0.18, 0.32, 0.28, 1.0),
        border_subtle=Color(0.11, 0.20, 0.18, 1.0),
        destructive=Color(0.88, 0.25, 0.28, 1.0),
        destructive_hover=Color(0.96, 0.33, 0.36, 1.0),
        accent=Color(0.20, 0.82, 0.62, 1.0),
        text=Color(0.95, 0.98, 0.97, 1.0),
        text_muted=Color(0.52, 0.68, 0.63, 1.0),
    )
    return ThemeTokens(colors)


def theme_from_tokens(tokens: ThemeTokens) -> Theme:
    """Build a complete Moxi Theme struct from design tokens."""
    var theme = Theme()
    var c = tokens.colors
    var r = tokens.radius
    var t = tokens.typography

    # Surface & Panel
    theme.surface = Style(
        c.background,
        c.text,
        r.radius_none,
        t.text_base,
    )
    theme.panel = Style(
        c.surface,
        c.text,
        r.radius_lg,
        t.text_base,
        c.border,
        1.0,
        1.0,
    )

    # Label
    theme.label = Style(
        Color(0.0, 0.0, 0.0, 0.0),
        c.text,
        r.radius_none,
        t.text_base,
    )

    # Button
    theme.button = Style(
        c.primary,
        Color(1.0, 1.0, 1.0, 1.0),
        r.radius_md,
        t.text_base,
        c.border_subtle,
        0.0,
        1.0,
    )

    # Text Input & Multiline
    theme.text_input = Style(
        c.surface_raised,
        c.text,
        r.radius_md,
        t.text_base,
        c.border,
        1.0,
        1.0,
    )
    theme.multiline = Style(
        c.surface_raised,
        c.text,
        r.radius_md,
        t.text_base,
        c.border,
        1.0,
        1.0,
    )

    # Controls: Checkbox, Switch, Radio
    theme.control = Style(
        c.surface_raised,
        c.text,
        r.radius_sm,
        t.text_base,
        c.border,
        1.0,
        1.0,
    )
    theme.switch_style = Style(
        c.secondary,
        c.text,
        r.radius_full,
        t.text_base,
        c.border,
        1.0,
        1.0,
    )
    theme.radio = Style(
        c.surface_raised,
        c.text,
        r.radius_full,
        t.text_base,
        c.border,
        1.0,
        1.0,
    )

    # Progress & Slider
    theme.progress = Style(
        c.muted,
        c.primary,
        r.radius_full,
        t.text_sm,
    )
    theme.slider = Style(
        c.muted,
        c.primary,
        r.radius_full,
        t.text_sm,
    )

    # Image
    theme.image = Style(
        c.surface_raised,
        c.text,
        r.radius_md,
        t.text_sm,
        c.border_subtle,
        1.0,
        1.0,
    )

    # Complex Catalog Controls
    theme.combo_box = Style(
        c.surface_raised,
        c.text,
        r.radius_md,
        t.text_base,
        c.border,
        1.0,
        1.0,
    )
    theme.list_style = Style(
        c.surface,
        c.text,
        r.radius_md,
        t.text_base,
        c.border,
        1.0,
        1.0,
    )
    theme.table_style = Style(
        c.surface,
        c.text,
        r.radius_md,
        t.text_base,
        c.border,
        1.0,
        1.0,
    )
    theme.tree_style = Style(
        c.surface,
        c.text,
        r.radius_md,
        t.text_base,
        c.border,
        1.0,
        1.0,
    )
    theme.menu_style = Style(
        c.surface_raised,
        c.text,
        r.radius_md,
        t.text_base,
        c.border,
        1.0,
        1.0,
    )
    theme.dialog_style = Style(
        c.surface,
        c.text,
        r.radius_xl,
        t.text_base,
        c.border,
        1.5,
        1.0,
    )
    theme.tabs_style = Style(
        c.surface_raised,
        c.text,
        r.radius_md,
        t.text_base,
        c.border_subtle,
        1.0,
        1.0,
    )
    theme.canvas_style = Style(
        c.surface,
        c.text,
        r.radius_md,
        t.text_base,
        c.border,
        1.0,
        1.0,
    )
    theme.separator_style = Style(
        c.border_subtle,
        c.text_muted,
        r.radius_none,
        t.text_xs,
    )

    return theme


def dark_theme() -> Theme:
    """Return the default sleek dark theme."""
    return theme_from_tokens(dark_tokens())


def light_theme() -> Theme:
    """Return the default clean light theme."""
    return theme_from_tokens(light_tokens())


def zinc_theme() -> Theme:
    """Return the minimalist monochromatic zinc theme."""
    return theme_from_tokens(zinc_tokens())


def emerald_theme() -> Theme:
    """Return the emerald/teal accent theme."""
    return theme_from_tokens(emerald_tokens())
