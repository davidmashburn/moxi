"""Contract tests for design tokens, theme presets, and component recipes."""

from moxi import (
    BUTTON_KIND,
    ClickEvent,
    Color,
    ColumnView,
    ColumnRuntime,
    default_button_style,
    Event,
    LABEL_KIND,
    Point,
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
    TextInputEvent,
    test_check,
    measure_text,
)


def linear_channel(value: Float32) -> Float32:
    if value <= 0.04045:
        return value / 12.92
    return ((value + 0.055) / 1.055) ** 2.4


def luminance(color: Color) -> Float32:
    return (
        0.2126 * linear_channel(color.red)
        + 0.7152 * linear_channel(color.green)
        + 0.0722 * linear_channel(color.blue)
    )


def check_text_contrast(text: Color, fill: Color):
    var a = luminance(text)
    var b = luminance(fill)
    test_check((max(a, b) + 0.05) / (min(a, b) + 0.05) >= 4.5)


def check_palette(tokens: ThemeTokens):
    var colors = tokens.colors
    check_text_contrast(colors.text, colors.secondary)
    check_text_contrast(colors.primary_text, colors.primary)
    check_text_contrast(Color(1, 1, 1, 1), colors.destructive)
    check_text_contrast(colors.text_muted, colors.background)
    check_text_contrast(colors.text_muted, colors.surface_raised)


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
    check_palette(dark_tokens())
    check_palette(light_tokens())
    check_palette(zinc_tokens())
    check_palette(emerald_tokens())
    var dark = dark_theme()
    test_check(default_button_style().fill.blue == dark.button.fill.blue)
    test_check(default_button_style().font_size == dark.tokens.typography.text_base)
    test_check(dark.surface.fill.red < 0.15)
    test_check(dark.button.fill.blue == dark_tokens().colors.secondary.blue)

    var light = light_theme()
    test_check(light.surface.fill.red > 0.9)
    test_check(light.text_input.border_width == 1.0)

    var zinc = zinc_theme()
    test_check(zinc.button.fill.red == zinc_tokens().colors.secondary.red)

    var emerald = emerald_theme()
    test_check(emerald.button.fill.green == emerald_tokens().colors.secondary.green)

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

    var badge_node = badge(201, "v0.6.0", 20.0, False, dt)
    test_check(badge_node.kind == LABEL_KIND)
    test_check(badge_node.text == "v0.6.0")
    test_check(badge_node.use_intrinsic_width)
    test_check(badge_node.badge_label)
    var badge_text_size = measure_text(badge_node.text, badge_node.style)
    test_check(badge_node.intrinsic_size().width == badge_text_size.width + 24.0)
    test_check(badge_node.intrinsic_size().height == badge_text_size.height + 8.0)

    # Badge identity survives explicit restyling and reaches retained paint.
    var restyled_badge = badge(203, "Tag", 24.0, True, dt)
    restyled_badge.set_style(default_button_style())
    test_check(restyled_badge.badge_label)
    var badge_view = ColumnView(Rect(0.0, 0.0, 200.0, 40.0), 0.0, 0.0)
    badge_view.add(restyled_badge)
    badge_view.layout()
    var badge_runtime = ColumnRuntime()
    badge_runtime.reconcile(badge_view)
    var badge_commands = badge_runtime.paint()
    test_check(badge_commands.command(1).badge_label)
    badge_view.children[0].badge_label = False
    badge_runtime.reconcile(badge_view)
    var plain_commands = badge_runtime.paint()
    test_check(not plain_commands.command(1).badge_label)
    test_check(plain_commands.command(1).is_changed())

    var badge_accent = badge(202, "PRO", 20.0, True, dt)
    test_check(badge_accent.style.fill.blue > 0.8)

    var panel = card_panel(301, Rect(0.0, 0.0, 200.0, 100.0), dt)
    test_check(panel.id == 301)
    test_check(panel.style.border_width == 1.0)

    # 4. View theme application
    var view = ColumnView(Rect(0.0, 0.0, 300.0, 300.0), 8.0, 8.0)
    view.add_button(1, "Themed", 32.0)
    view.set_theme(emerald)
    test_check(view.child(0).style.fill.green == emerald.button.fill.green)

    # The interactive showcase applies the selected palette to its surface
    # and built-in controls while recipe variants retain their own styling.
    var showcase = ThemeShowcaseState()
    var showcase_view = showcase.build(Rect(0.0, 0.0, 780.0, 480.0))
    test_check(showcase_view.bounds_for(1002).height == 24.0)
    test_check(showcase_view.bounds_for(1002).y == showcase_view.bounds_for(1000).y + 6.0)
    test_check(showcase_view.bounds_for(1002).width >= 24.0)
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
        if node.id == 10 or node.id == 11:
            test_check(node.semantics.selected == (node.id == 11))
        if node.id == 3101:
            test_check(node.style.fill.red > 0.9)
        if node.id == 4001:
            test_check(node.style.text.red < 0.2)

    # The showcase controls are live state, not static recipe samples: native
    # clicks and committed text input must survive a rebuild.
    var input_event = Event(TextInputEvent("Ada"))
    input_event.set_target(3101)
    test_check(showcase.update(input_event, showcase_view))
    test_check(showcase.input.text == "Ada")
    var checkbox_event = Event(ClickEvent(Point(0.0, 0.0)))
    checkbox_event.set_target(3102)
    test_check(showcase.update(checkbox_event, showcase_view))
    test_check(not showcase.checkbox_checked)
    var switch_event = Event(ClickEvent(Point(0.0, 0.0)))
    switch_event.set_target(3103)
    test_check(showcase.update(switch_event, showcase_view))
    test_check(not showcase.switch_checked)
    var interactive_showcase_view = showcase.build(Rect(0.0, 0.0, 780.0, 480.0))
    var input_node_found = False
    var checkbox_node_found = False
    var switch_node_found = False
    for index in range(interactive_showcase_view.child_count()):
        var node = interactive_showcase_view.child(index)
        if node.id == 3101:
            input_node_found = True
            test_check(node.text == "Ada")
        if node.id == 3102:
            checkbox_node_found = True
            test_check(not node.checked)
        if node.id == 3103:
            switch_node_found = True
            test_check(not node.checked)
    test_check(input_node_found)
    test_check(checkbox_node_found)
    test_check(switch_node_found)

    print("Moxi tokens and recipes test passed")
