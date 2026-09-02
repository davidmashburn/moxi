"""Reusable component recipes built on top of Moxi's design tokens."""

from .geometry import Rect
from .style import Color, Panel, Style
from .tokens import ThemeTokens, dark_tokens
from .view import BUTTON_KIND, LABEL_KIND, ViewNode


def primary_button(
    id: Int,
    text: String,
    preferred_height: Float32 = 32.0,
    action_id: Int = -1,
    tokens: ThemeTokens = dark_tokens(),
) -> ViewNode:
    """A prominent action button with primary accent styling."""
    var c = tokens.colors
    var r = tokens.radius
    var t = tokens.typography
    var style = Style(
        c.primary,
        Color(1.0, 1.0, 1.0, 1.0),
        r.radius_md,
        t.text_base,
        c.border_subtle,
        0.0,
        1.0,
    )
    var node = ViewNode(BUTTON_KIND, id, text, preferred_height, style)
    if action_id >= 0:
        node.set_action_id(action_id)
    return node


def secondary_button(
    id: Int,
    text: String,
    preferred_height: Float32 = 32.0,
    action_id: Int = -1,
    tokens: ThemeTokens = dark_tokens(),
) -> ViewNode:
    """A secondary action button using surface/secondary background."""
    var c = tokens.colors
    var r = tokens.radius
    var t = tokens.typography
    var style = Style(
        c.secondary,
        c.text,
        r.radius_md,
        t.text_base,
        c.border_subtle,
        1.0,
        1.0,
    )
    var node = ViewNode(BUTTON_KIND, id, text, preferred_height, style)
    if action_id >= 0:
        node.set_action_id(action_id)
    return node


def destructive_button(
    id: Int,
    text: String,
    preferred_height: Float32 = 32.0,
    action_id: Int = -1,
    tokens: ThemeTokens = dark_tokens(),
) -> ViewNode:
    """An action button indicating a destructive or dangerous operation."""
    var c = tokens.colors
    var r = tokens.radius
    var t = tokens.typography
    var style = Style(
        c.destructive,
        Color(1.0, 1.0, 1.0, 1.0),
        r.radius_md,
        t.text_base,
        c.border_subtle,
        0.0,
        1.0,
    )
    var node = ViewNode(BUTTON_KIND, id, text, preferred_height, style)
    if action_id >= 0:
        node.set_action_id(action_id)
    return node


def outline_button(
    id: Int,
    text: String,
    preferred_height: Float32 = 32.0,
    action_id: Int = -1,
    tokens: ThemeTokens = dark_tokens(),
) -> ViewNode:
    """A subtle button with a transparent background and visible border."""
    var c = tokens.colors
    var r = tokens.radius
    var t = tokens.typography
    var style = Style(
        Color(0.0, 0.0, 0.0, 0.0),
        c.text,
        r.radius_md,
        t.text_base,
        c.border,
        1.0,
        1.0,
    )
    var node = ViewNode(BUTTON_KIND, id, text, preferred_height, style)
    if action_id >= 0:
        node.set_action_id(action_id)
    return node


def ghost_button(
    id: Int,
    text: String,
    preferred_height: Float32 = 32.0,
    action_id: Int = -1,
    tokens: ThemeTokens = dark_tokens(),
) -> ViewNode:
    """A minimal button that blends into the background until hovered."""
    var c = tokens.colors
    var r = tokens.radius
    var t = tokens.typography
    var style = Style(
        Color(0.0, 0.0, 0.0, 0.0),
        c.text_muted,
        r.radius_md,
        t.text_base,
        Color(0.0, 0.0, 0.0, 0.0),
        0.0,
        1.0,
    )
    var node = ViewNode(BUTTON_KIND, id, text, preferred_height, style)
    if action_id >= 0:
        node.set_action_id(action_id)
    return node


def badge(
    id: Int,
    text: String,
    preferred_height: Float32 = 22.0,
    is_accent: Bool = False,
    tokens: ThemeTokens = dark_tokens(),
) -> ViewNode:
    """A compact badge / tag for metadata or status indicators."""
    var c = tokens.colors
    var r = tokens.radius
    var t = tokens.typography
    var fill = c.surface_raised
    var text_color = c.text_muted
    if is_accent:
        fill = c.primary
        text_color = Color(1.0, 1.0, 1.0, 1.0)
    var style = Style(
        fill,
        text_color,
        r.radius_full,
        t.text_xs,
        c.border_subtle,
        1.0,
        1.0,
    )
    var node = ViewNode(LABEL_KIND, id, text, preferred_height, style)
    node.set_intrinsic_width(True)
    return node


def card_panel(
    id: Int,
    bounds: Rect,
    tokens: ThemeTokens = dark_tokens(),
) -> Panel:
    """Create a styled panel descriptor matching card container semantics."""
    var c = tokens.colors
    var r = tokens.radius
    var t = tokens.typography
    var style = Style(
        c.surface,
        c.text,
        r.radius_lg,
        t.text_base,
        c.border,
        1.0,
        1.0,
    )
    return Panel(id, bounds, style)
