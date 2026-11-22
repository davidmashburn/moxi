"""Reusable recipes whose identities survive theme changes."""

from .geometry import Rect
from .style import Panel, Style, Theme
from .tokens import ThemeTokens, dark_tokens
from .view_node import BUTTON_KIND, LABEL_KIND, RecipeRole, ViewNode


def primary_button(
    id: Int,
    text: String,
    preferred_height: Float32 = 32.0,
    action_id: Int = -1,
    tokens: ThemeTokens = dark_tokens(),
) -> ViewNode:
    """A prominent action using the inherited primary palette."""
    var node = ViewNode(BUTTON_KIND, id, text, preferred_height)
    node.set_recipe(RecipeRole.primary(), Theme(tokens))
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
    """A secondary action using the inherited secondary palette."""
    var node = ViewNode(BUTTON_KIND, id, text, preferred_height)
    node.set_recipe(RecipeRole.secondary(), Theme(tokens))
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
    """A destructive action retaining its role across theme changes."""
    var node = ViewNode(BUTTON_KIND, id, text, preferred_height)
    node.set_recipe(RecipeRole.destructive(), Theme(tokens))
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
    """A transparent action with an inherited visible border."""
    var node = ViewNode(BUTTON_KIND, id, text, preferred_height)
    node.set_recipe(RecipeRole.outline(), Theme(tokens))
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
    """A minimal action using the inherited muted foreground."""
    var node = ViewNode(BUTTON_KIND, id, text, preferred_height)
    node.set_recipe(RecipeRole.ghost(), Theme(tokens))
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
    """A compact tag retaining its neutral or accent role when themed."""
    var node = ViewNode(LABEL_KIND, id, text, preferred_height)
    var role = RecipeRole.badge()
    if is_accent:
        role = RecipeRole.accent_badge()
    node.set_recipe(role, Theme(tokens))
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
