"""Presentation styles and label composition for the demo browser."""

from moxi.column_view import ColumnView
from moxi.controls_basic import LabelControl
from moxi.style import Color, Style, default_label_style
from moxi.tokens import dark_tokens


def _label_style(font_size: Float32, color: Color) -> Style:
    var style = default_label_style()
    style.font_size = font_size
    style.text = color
    return style


def _button_style(
    fill: Color,
    text: Color,
    font_size: Float32,
    radius: Float32 = 9.0,
) -> Style:
    return Style(fill, text, radius, font_size)


def _ink() -> Color:
    return dark_tokens().colors.text


def _muted_ink() -> Color:
    return dark_tokens().colors.muted_text


def _subtle_ink() -> Color:
    return dark_tokens().colors.text_muted


def _accent_ink() -> Color:
    return dark_tokens().colors.accent


def _field_fill() -> Color:
    return dark_tokens().colors.background


def _kicker_style() -> Style:
    return _label_style(12.0, _accent_ink())


def _body_style() -> Style:
    return _label_style(dark_tokens().typography.text_base, _muted_ink())


def _small_style() -> Style:
    return _label_style(dark_tokens().typography.text_sm, _muted_ink())


def _code_style() -> Style:
    """Return the compact code-panel style used by live stories."""
    return Style(
        _field_fill(),
        dark_tokens().colors.text,
        9.0,
        12.0,
        dark_tokens().colors.border,
        1.0,
        1.0,
    )


def _subtle_style() -> Style:
    return _label_style(12.0, _subtle_ink())


def _heading_style() -> Style:
    return _label_style(dark_tokens().typography.text_xl, _ink())


def _title_style() -> Style:
    return _label_style(dark_tokens().typography.text_2xl, _ink())


def _selection_style(selected: Bool, font_size: Float32) -> Style:
    """Navigation, tabs and filters share one selected-state contrast policy."""
    var tokens = dark_tokens()
    var fill = tokens.colors.secondary
    var text = tokens.colors.muted_text
    if selected:
        fill = tokens.colors.primary
        text = tokens.colors.primary_text
    return _button_style(fill, text, font_size, tokens.radius.radius_md)


def _primary_button_style() -> Style:
    return _selection_style(True, dark_tokens().typography.text_base)


def _nav_button_style(selected: Bool) -> Style:
    var colors = dark_tokens().colors
    return _button_style(colors.secondary if selected else Color(0, 0, 0, 0),
                         colors.text if selected else colors.muted_text, 15.0, 6.0)


def _filter_button_style(selected: Bool) -> Style:
    return _selection_style(selected, dark_tokens().typography.text_xs)


def _tab_style(selected: Bool) -> Style:
    return _nav_button_style(selected)


def _add_styled_label(
    mut root: ColumnView,
    parent_id: Int,
    id: Int,
    text: String,
    preferred_height: Float32,
    style: Style,
):
    root.add_to(parent_id, LabelControl(id, text, preferred_height, style).node())


def _add_wrapped_label_styled(
    mut root: ColumnView,
    parent_id: Int,
    id: Int,
    text: String,
    width: Float32,
    style: Style,
):
    """Add a width-aware label with the browser's compact body typography."""
    root.add_to(parent_id, LabelControl(id, text, 0.0, style).wrapped_node(width))


def _add_wrapped_label(
    mut root: ColumnView,
    parent_id: Int,
    id: Int,
    text: String,
    width: Float32,
):
    _add_wrapped_label_styled(root, parent_id, id, text, width, _body_style())


