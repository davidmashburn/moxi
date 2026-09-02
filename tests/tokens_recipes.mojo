"""Contract tests for design tokens, theme presets, and component recipes."""

from moxi import (
    BUTTON_KIND,
    Color,
    ColumnView,
    LABEL_KIND,
    Rect,
    SpacingTokens,
    RadiusTokens,
    TypographyTokens,
    ThemeTokens,
    dark_tokens,
    light_tokens,
    zinc_tokens,
    emerald_tokens,
    dark_theme,
    light_theme,
    zinc_theme,
    emerald_theme,
    primary_button,
    secondary_button,
    destructive_button,
    outline_button,
    ghost_button,
    badge,
    card_panel,
    ThemeShowcaseState,
    test_check,
)


def main():
    # 1. Scale token defaults
    var spacing = SpacingTokens()
    test_check(spacing.space_xs == 2.0)
    test_check(spacing.space_md == 8.0)
    test_check(spacing.space_2xl == 24.0)

    var radius = RadiusTokens()
    test_check(radius.radius_none == 0.0)
    test_check(radius.radius_sm == 4.0)
    test_check(radius.radius_full == 999.0)

    var typography = TypographyTokens()
    test_check(typography.text_xs == 11.0)
    test_check(typography.text_base == 15.0)
    test_check(typography.text_2xl == 28.0)

    # 2. Preset theme validation
    var dark = dark_theme()
    test_check(dark.surface.fill.red < 0.15)
    test_check(dark.button.fill.blue > 0.8)

    var light = light_theme()
    test_check(light.surface.fill.red > 0.9)
    test_check(light.text_input.border_width == 1.0)

    var zinc = zinc_theme()
    test_check(zinc.button.fill.red > 0.9)

    var emerald = emerald_theme()
    test_check(emerald.button.fill.green > 0.6)

    # 3. Recipe builder validations
    var dt = dark_tokens()
    var btn_primary = primary_button(101, "Save", 32.0, 10, dt)
    test_check(btn_primary.kind == BUTTON_KIND)
    test_check(btn_primary.id == 101)
    test_check(btn_primary.text == "Save")
    test_check(btn_primary.action_id == 10)
    test_check(btn_primary.style.fill.blue > 0.8)

    var btn_destructive = destructive_button(102, "Delete", 32.0, 11, dt)
    test_check(btn_destructive.style.fill.red > 0.8)

    var btn_outline = outline_button(103, "Cancel", 32.0, -1, dt)
    test_check(btn_outline.style.fill.alpha == 0.0)
    test_check(btn_outline.style.border_width == 1.0)

    var btn_ghost = ghost_button(104, "Options", 32.0, -1, dt)
    test_check(btn_ghost.style.fill.alpha == 0.0)
    test_check(btn_ghost.style.border_width == 0.0)

    var badge_node = badge(201, "v0.5.1", 20.0, False, dt)
    test_check(badge_node.kind == LABEL_KIND)
    test_check(badge_node.text == "v0.5.1")
    test_check(badge_node.use_intrinsic_width)

    var badge_accent = badge(202, "PRO", 20.0, True, dt)
    test_check(badge_accent.style.fill.blue > 0.8)

    var panel = card_panel(301, Rect(0.0, 0.0, 200.0, 100.0), dt)
    test_check(panel.id == 301)
    test_check(panel.style.border_width == 1.0)

    # 4. View theme application
    var view = ColumnView(Rect(0.0, 0.0, 300.0, 300.0), 8.0, 8.0)
    view.add_button(1, "Themed", 32.0)
    view.set_theme(emerald)
    test_check(view.child(0).style.fill.green > 0.6)

    # The interactive showcase applies the selected palette to its surface
    # and built-in controls while recipe variants retain their own styling.
    var showcase = ThemeShowcaseState()
    var showcase_view = showcase.build(Rect(0.0, 0.0, 780.0, 480.0))
    test_check(showcase_view.surface_style.fill.red < 0.1)
    for index in range(showcase_view.child_count()):
        var node = showcase_view.child(index)
        if node.id == 3101:
            test_check(node.style.fill.red < 0.2)
        if node.id == 4001:
            test_check(node.style.text.red > 0.8)

    showcase.theme_mode = 1
    var light_showcase_view = showcase.build(Rect(0.0, 0.0, 780.0, 480.0))
    test_check(light_showcase_view.surface_style.fill.red > 0.9)
    for index in range(light_showcase_view.child_count()):
        var node = light_showcase_view.child(index)
        if node.id == 3101:
            test_check(node.style.fill.red > 0.9)
        if node.id == 4001:
            test_check(node.style.text.red < 0.2)

    print("Moxi tokens and recipes test passed")
