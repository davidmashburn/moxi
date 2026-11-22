"""Theme and component recipe showcase demonstrating Moxi's design tokens."""

from .component import Component
from .controls_basic import CheckboxControl, SwitchControl
from .controls_text import TextInputControl, TextInputState
from .event import (
    ACTION_KIND,
    CLICK_KIND,
    COMPOSITION_END_KIND,
    COMPOSITION_UPDATE_KIND,
    Event,
    KEY_DOWN_KIND,
    KEY_ENTER,
    KEY_SPACE,
    TEXT_INPUT_KIND,
)
from .geometry import Rect
from .layout import ALIGN_CENTER, JUSTIFY_START
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
from .scenarios import (
    canonical_theme_modes,
    canonical_theme_mode_name,
    canonical_theme_selector_label,
    canonical_theme_status,
    canonical_theme_title,
)
from .column_view import ColumnView

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
    var input: TextInputState
    var checkbox_checked: Bool
    var switch_checked: Bool

    def __init__(out self):
        self.theme_mode = THEME_DARK
        self.click_count = 0
        self.status_message = "Ready. Click theme buttons to switch palettes."
        self.input = TextInputState()
        self.checkbox_checked = True
        self.switch_checked = True

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

        # Header Row: Title & Badges
        _ = view.add_row(1000, 0.0, 36.0, 0.0, sp.space_sm)
        view.set_container_alignment(1000, JUSTIFY_START, ALIGN_CENTER)
        view.add_label_to(1000, 1001, canonical_theme_title(), 36.0)
        var mode_name = String("Theme: ", canonical_theme_mode_name(self.theme_mode))
        var theme_badge = badge(1002, mode_name, 24.0, True, tokens)
        view.add_to(1000, theme_badge)

        # Theme Switcher Toolbar Row
        _ = view.add_row(1100, 0.0, 34.0, 0.0, sp.space_sm)
        view.add_label_to(1100, 1101, canonical_theme_selector_label(), 34.0)
        var modes = canonical_theme_modes()
        for mode in modes:
            var id = BTN_THEME_DARK + mode.mode
            var button = secondary_button(id, mode.button_label, 32.0, mode.action_id, tokens)
            if mode.mode == self.theme_mode:
                button = primary_button(id, mode.button_label, 32.0, mode.action_id, tokens)
                button.set_selected(True)
            view.add_to(1100, button)

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
        var input = TextInputControl(
            3101,
            self.input.text,
            self.input.cursor,
            self.input.anchor,
            34.0,
        )
        input.set_composition(
            self.input.composition,
            self.input.composition_selection_start,
            self.input.composition_selection_end,
        )
        view.add_to(3100, input.node())
        var checkbox = CheckboxControl(
            3102,
            "Checkbox option",
            self.checkbox_checked,
            34.0,
        )
        view.add_to(3100, checkbox.node())
        var switch_node = SwitchControl(
            3103,
            "Switch toggle",
            self.switch_checked,
            34.0,
        ).node()
        view.add_to(3100, switch_node)

        # Section 3: Status & Feedback
        view.add_separator(4000)
        view.add_label(4001, self.status_message, 24.0)

        # Local hierarchy overrides typography; palette colors stay inherited.
        view.set_font_size(1001, typography.text_xl)
        view.set_font_size(1101, typography.text_base)
        view.set_font_size(2000, typography.text_lg)
        view.set_font_size(3000, typography.text_lg)
        view.set_font_size(4001, typography.text_sm)

        view.layout()
        return view^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        var target = event.target
        var action_id = event.action_id

        if target == 3101:
            if event.kind == COMPOSITION_UPDATE_KIND:
                self.input.set_composition(
                    event.text,
                    event.selection_start,
                    event.selection_end,
                )
                return True
            if event.kind == COMPOSITION_END_KIND:
                if not self.input.has_composition():
                    return False
                self.input.clear_composition()
                return True
            if event.kind == TEXT_INPUT_KIND:
                if event.replacement_start >= 0 and event.replacement_end >= 0:
                    return self.input.replace_text_range(
                        event.text,
                        event.replacement_start,
                        event.replacement_end,
                    )
                return self.input.insert_text(event.text)
            if event.kind == KEY_DOWN_KIND:
                return self.input.handle_key(event.key, event.modifiers)
            return False

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
            self.status_message = canonical_theme_status(THEME_DARK)
            return True
        elif target == BTN_THEME_LIGHT or (target == -1 and action_id == ACTION_SET_LIGHT):
            self.theme_mode = THEME_LIGHT
            self.status_message = canonical_theme_status(THEME_LIGHT)
            return True
        elif target == BTN_THEME_ZINC or (target == -1 and action_id == ACTION_SET_ZINC):
            self.theme_mode = THEME_ZINC
            self.status_message = canonical_theme_status(THEME_ZINC)
            return True
        elif target == BTN_THEME_EMERALD or (target == -1 and action_id == ACTION_SET_EMERALD):
            self.theme_mode = THEME_EMERALD
            self.status_message = canonical_theme_status(THEME_EMERALD)
            return True
        elif target == 3102:
            self.checkbox_checked = not self.checkbox_checked
            self.status_message = (
                "Checkbox enabled."
                if self.checkbox_checked
                else "Checkbox disabled."
            )
            return True
        elif target == 3103:
            self.switch_checked = not self.switch_checked
            self.status_message = (
                "Switch on."
                if self.switch_checked
                else "Switch off."
            )
            return True
        elif action_id == ACTION_DEMO_CLICK or (target >= BTN_PRIMARY and target <= BTN_GHOST):
            self.click_count += 1
            self.status_message = "Recipe button clicked! Count: " + String(self.click_count)
            return True

        return False
