"""Design tokens and coherent theme presets for Moxi."""

from .palette import (
    Color, ColorTokens, RadiusTokens, SpacingTokens, ThemeTokens,
    TypographyTokens, dark_tokens, light_tokens, zinc_tokens, emerald_tokens,
)
from .style import Style, Theme


def theme_from_tokens(tokens: ThemeTokens) -> Theme:
    """Build the standard control styles from a semantic palette."""
    return Theme(tokens)


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
