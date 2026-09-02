"""Theme and component recipe showcase demonstrating Moxi's design tokens."""

from .component import Component
from .event import (
    ACTION_KIND,
    CLICK_KIND,
    Event,
    KEY_DOWN_KIND,
    KEY_ENTER,
    KEY_SPACE,
)
from .geometry import Rect
from .recipes import (
    badge,
    destructive_button,
    ghost_button,
    outline_button,
    primary_button,
    secondary_button,
)
from .tokens import (
    ThemeTokens,
    dark_tokens,
    emerald_tokens,
    light_tokens,
    theme_from_tokens,
    zinc_tokens,
)
from .view import ColumnView

comptime THEME_DARK = 0
comptime THEME_LIGHT = 1
comptime THEME_ZINC = 2
comptime THEME_EMERALD = 3

comptime BTN_THEME_DARK = 10
comptime BTN_THEME_LIGHT = 11
comptime BTN_THEME_ZINC = 12
comptime BTN_THEME_EMERALD = 13

comptime BTN_PRIMARY = 20
comptime BTN_SECONDARY = 21
comptime BTN_DESTRUCTIVE = 22
comptime BTN_OUTLINE = 23
comptime BTN_GHOST = 24

comptime ACTION_SET_DARK = 1
comptime ACTION_SET_LIGHT = 2
comptime ACTION_SET_ZINC = 3
comptime ACTION_SET_EMERALD = 4
comptime ACTION_DEMO_CLICK = 5


struct ThemeShowcaseState(Component):
    """Component demonstrating design tokens, recipes, and live theme switching."""

    var theme_mode: Int
    var click_count: Int
    var status_message: String

    def __init__(out self):
        self.theme_mode = THEME_DARK
        self.click_count = 0
        self.status_message = "Ready. Click theme buttons to switch palettes."

    def current_tokens(self) -> ThemeTokens:
        if self.theme_mode == THEME_LIGHT:
            return light_tokens()
        if self.theme_mode == THEME_ZINC:
            return zinc_tokens()
        if self.theme_mode == THEME_EMERALD:
            return emerald_tokens()
        return dark_tokens()

    def build(self, bounds: Rect) -> ColumnView:
        var tokens = self.current_tokens()
        var theme = theme_from_tokens(tokens)
        var sp = tokens.spacing
        var typography = tokens.typography

        var view = ColumnView(bounds, sp.space_lg, sp.space_md)
        view.set_theme(theme)
        view.set_surface_style(theme.surface)

        # Header Row: Title & Badges
        _ = view.add_row(1000, 0.0, 36.0, 0.0, sp.space_sm)
        view.add_label_to(1000, 1001, "Moxi Design Tokens & Recipes", 36.0)
        var mode_name = "Theme: Dark"
        if self.theme_mode == THEME_LIGHT:
            mode_name = "Theme: Light"
        elif self.theme_mode == THEME_ZINC:
            mode_name = "Theme: Zinc"
        elif self.theme_mode == THEME_EMERALD:
            mode_name = "Theme: Emerald"
        var theme_badge = badge(1002, mode_name, 24.0, True, tokens)
        view.add_to(1000, theme_badge)

        # Theme Switcher Toolbar Row
        _ = view.add_row(1100, 0.0, 34.0, 0.0, sp.space_sm)
        view.add_label_to(1100, 1101, "Select Palette:", 34.0)
        var b_dark = secondary_button(BTN_THEME_DARK, "Dark Slate", 32.0, ACTION_SET_DARK, tokens)
        var b_light = secondary_button(BTN_THEME_LIGHT, "Clean Light", 32.0, ACTION_SET_LIGHT, tokens)
        var b_zinc = secondary_button(BTN_THEME_ZINC, "Neutral Zinc", 32.0, ACTION_SET_ZINC, tokens)
        var b_emerald = secondary_button(BTN_THEME_EMERALD, "Emerald Teal", 32.0, ACTION_SET_EMERALD, tokens)
        view.add_to(1100, b_dark)
        view.add_to(1100, b_light)
        view.add_to(1100, b_zinc)
        view.add_to(1100, b_emerald)

        # Section 1: Button Variants
        view.add_label(2000, "Button Recipes", 28.0)
        _ = view.add_row(2100, 0.0, 36.0, 0.0, sp.space_sm)
        var p_btn = primary_button(BTN_PRIMARY, "Primary", 34.0, ACTION_DEMO_CLICK, tokens)
        var s_btn = secondary_button(BTN_SECONDARY, "Secondary", 34.0, ACTION_DEMO_CLICK, tokens)
        var d_btn = destructive_button(BTN_DESTRUCTIVE, "Destructive", 34.0, ACTION_DEMO_CLICK, tokens)
        var o_btn = outline_button(BTN_OUTLINE, "Outline", 34.0, ACTION_DEMO_CLICK, tokens)
        var g_btn = ghost_button(BTN_GHOST, "Ghost", 34.0, ACTION_DEMO_CLICK, tokens)
        view.add_to(2100, p_btn)
        view.add_to(2100, s_btn)
        view.add_to(2100, d_btn)
        view.add_to(2100, o_btn)
        view.add_to(2100, g_btn)

        # Section 2: Form & Controls
        view.add_label(3000, "Controls & Inputs", 28.0)
        _ = view.add_row(3100, 0.0, 36.0, 0.0, sp.space_sm)
        view.add_text_input_to(3100, 3101, "Input field", 34.0)
        view.add_checkbox_to(3100, 3102, "Checkbox option", True, 34.0)
        view.add_switch_to(3100, 3103, "Switch toggle", True, 34.0)

        # Section 3: Status & Feedback
        view.add_separator(4000)
        view.add_label(4001, self.status_message, 24.0)

        # `set_theme` retains the selected theme for callers that add nodes
        # incrementally. This declarative build adds a few recipe-specific
        # nodes afterwards, so apply the semantic styles explicitly while
        # preserving the typography hierarchy and button variants above.
        var title_style = theme.label
        title_style.font_size = typography.text_xl
        view.set_style(1001, title_style)
        var toolbar_label_style = theme.label
        toolbar_label_style.font_size = typography.text_base
        view.set_style(1101, toolbar_label_style)
        var section_style = theme.label
        section_style.font_size = typography.text_lg
        view.set_style(2000, section_style)
        view.set_style(3000, section_style)
        var status_style = theme.label
        status_style.font_size = typography.text_sm
        view.set_style(4001, status_style)
        view.set_style(3101, theme.text_input)
        view.set_style(3102, theme.control)
        view.set_style(3103, theme.switch_style)
        view.set_style(4000, theme.separator_style)

        view.layout()
        return view^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        var target = event.target
        var action_id = event.action_id

        var is_trigger = False
        if event.kind == ACTION_KIND:
            is_trigger = True
        elif event.kind == CLICK_KIND:
            is_trigger = True
        elif event.kind == KEY_DOWN_KIND:
            var key = event.key
            if key == KEY_ENTER or key == KEY_SPACE:
                is_trigger = True

        if not is_trigger:
            return False

        # Prefer the concrete target when an accessibility press carries the
        # generic ACTION_PRESS id; custom theme actions use ids that may
        # overlap with that generic action.
        if target == BTN_THEME_DARK or (target == -1 and action_id == ACTION_SET_DARK):
            self.theme_mode = THEME_DARK
            self.status_message = "Switched to Dark Slate palette."
            return True
        elif target == BTN_THEME_LIGHT or (target == -1 and action_id == ACTION_SET_LIGHT):
            self.theme_mode = THEME_LIGHT
            self.status_message = "Switched to Clean Light palette."
            return True
        elif target == BTN_THEME_ZINC or (target == -1 and action_id == ACTION_SET_ZINC):
            self.theme_mode = THEME_ZINC
            self.status_message = "Switched to Neutral Zinc palette."
            return True
        elif target == BTN_THEME_EMERALD or (target == -1 and action_id == ACTION_SET_EMERALD):
            self.theme_mode = THEME_EMERALD
            self.status_message = "Switched to Emerald Teal palette."
            return True
        elif action_id == ACTION_DEMO_CLICK or (target >= BTN_PRIMARY and target <= BTN_GHOST):
            self.click_count += 1
            self.status_message = "Recipe button clicked! Count: " + String(self.click_count)
            return True

        return False
