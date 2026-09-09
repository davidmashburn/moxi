"""Catalog-classification constants and typography/formatting helpers for the demo browser."""


from moxi.accessibility import ACTION_PRESS
from moxi.column_view import ColumnView
from moxi.controls_basic import LabelControl
from moxi.event import ACTION_KIND, CLICK_KIND, Event, KEY_DOWN_KIND, KEY_ENTER, KEY_SPACE
from moxi.style import Color, Style, default_label_style
from .showcase import (
    SHOWCASE_ANIMATION,
    SHOWCASE_CORETEXT,
    SHOWCASE_HARFBUZZ,
    SHOWCASE_HELLO_COMPONENT,
    SHOWCASE_HELLO_WINDOW,
    SHOWCASE_METAL_SCENE,
    SHOWCASE_METAL_WINDOW,
    SHOWCASE_PLOT,
    SHOWCASE_PLOT_GALLERY,
    SHOWCASE_PLOT_SVG,
)


# Public page and category kinds make the catalog inspectable by tests and by
# future alternate browser shells (web, terminal, or documentation builds).
comptime DEMO_CATEGORY_ALL = 0
comptime DEMO_CATEGORY_START = 1
comptime DEMO_CATEGORY_COMPONENTS = 2
comptime DEMO_CATEGORY_LAYOUT = 3
comptime DEMO_CATEGORY_PLOTTING = 4
comptime DEMO_CATEGORY_RENDERING = 5
comptime DEMO_CATEGORY_TEXT = 6

comptime DEMO_PAGE_STATIC = 0
comptime DEMO_PAGE_COUNTER = 1
comptime DEMO_PAGE_FORM = 2
comptime DEMO_PAGE_NESTED = 3
comptime DEMO_PAGE_COMPOSED = 4
comptime DEMO_PAGE_WX_STYLE = 5
comptime DEMO_PAGE_ROW = 6
comptime DEMO_PAGE_ALIGNMENT = 7
comptime DEMO_PAGE_WRAPPED = 8
comptime DEMO_PAGE_SHOWCASE = 9
comptime DEMO_PAGE_FRACTAL = 10
comptime DEMO_PAGE_LIVE_SCRIPT = 11
comptime DEMO_PAGE_INTERACTION = 12
comptime DEMO_PAGE_THEME_SHOWCASE = 13
comptime DEMO_PAGE_CAPABILITY_WALKTHROUGH = 14

comptime DEMO_HELLO_WINDOW_ID = 1
comptime DEMO_HELLO_COMPONENT_ID = 2
comptime DEMO_COUNTER_ID = 3
comptime DEMO_FORM_ID = 4
comptime DEMO_NESTED_ID = 5
comptime DEMO_COMPOSED_ID = 6
comptime DEMO_WX_STYLE_ID = 7
comptime DEMO_ROW_ID = 8
comptime DEMO_ALIGNMENT_ID = 9
comptime DEMO_WRAPPED_ID = 10
comptime DEMO_ANIMATION_ID = 11
comptime DEMO_PLOT_ID = 12
comptime DEMO_PLOT_GALLERY_ID = 13
comptime DEMO_PLOT_SVG_ID = 14
comptime DEMO_FRACTAL_ID = 15
comptime DEMO_METAL_SCENE_ID = 16
comptime DEMO_METAL_WINDOW_ID = 17
comptime DEMO_CORETEXT_ID = 18
comptime DEMO_HARFBUZZ_ID = 19
comptime DEMO_LIVE_SCRIPT_ID = 20
comptime DEMO_INTERACTION_ID = 21
comptime DEMO_THEME_SHOWCASE_ID = 22
comptime DEMO_CAPABILITY_WALKTHROUGH_ID = 23


def demo_category_name(category: Int) -> String:
    """Return the long display name for a catalog category."""
    if category == DEMO_CATEGORY_START:
        return "Getting started"
    if category == DEMO_CATEGORY_COMPONENTS:
        return "Components & input"
    if category == DEMO_CATEGORY_LAYOUT:
        return "Layout & runtime"
    if category == DEMO_CATEGORY_PLOTTING:
        return "Plotting"
    if category == DEMO_CATEGORY_RENDERING:
        return "Rendering"
    if category == DEMO_CATEGORY_TEXT:
        return "Text"
    return "All demos"


def demo_category_short_name(category: Int) -> String:
    """Return a compact label suitable for the browser filter strip."""
    if category == DEMO_CATEGORY_START:
        return "Start"
    if category == DEMO_CATEGORY_COMPONENTS:
        return "UI"
    if category == DEMO_CATEGORY_LAYOUT:
        return "Layout"
    if category == DEMO_CATEGORY_PLOTTING:
        return "Plot"
    if category == DEMO_CATEGORY_RENDERING:
        return "GPU"
    if category == DEMO_CATEGORY_TEXT:
        return "Text"
    return "All"


def showcase_mode_for_demo(id: Int) -> Int:
    """Map a catalog id to the shared embeddable showcase mode."""
    if id == DEMO_HELLO_COMPONENT_ID:
        return SHOWCASE_HELLO_COMPONENT
    if id == DEMO_ANIMATION_ID:
        return SHOWCASE_ANIMATION
    if id == DEMO_PLOT_ID:
        return SHOWCASE_PLOT
    if id == DEMO_PLOT_GALLERY_ID:
        return SHOWCASE_PLOT_GALLERY
    if id == DEMO_PLOT_SVG_ID:
        return SHOWCASE_PLOT_SVG
    if id == DEMO_METAL_SCENE_ID:
        return SHOWCASE_METAL_SCENE
    if id == DEMO_METAL_WINDOW_ID:
        return SHOWCASE_METAL_WINDOW
    if id == DEMO_CORETEXT_ID:
        return SHOWCASE_CORETEXT
    if id == DEMO_HARFBUZZ_ID:
        return SHOWCASE_HARFBUZZ
    return SHOWCASE_HELLO_WINDOW


def _ascii_lower(value: String) -> String:
    """Lower ASCII letters while retaining non-ASCII source text."""
    var result = String("")
    for index in range(value.count_codepoints()):
        var glyph = String(value[codepoint=index:index + 1])
        var code = ord(glyph)
        if code >= ord("A") and code <= ord("Z"):
            glyph = chr(code + 32)
        result += glyph
    return result


def _contains_insensitive(value: String, query: String) -> Bool:
    if query.count_codepoints() == 0:
        return True
    return _ascii_lower(query) in _ascii_lower(value)


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
    return Color(0.93, 0.96, 1.0, 1.0)


def _muted_ink() -> Color:
    return Color(0.68, 0.75, 0.86, 1.0)


def _subtle_ink() -> Color:
    return Color(0.48, 0.57, 0.70, 1.0)


def _accent_ink() -> Color:
    return Color(0.48, 0.79, 1.0, 1.0)


def _accent_fill() -> Color:
    return Color(0.12, 0.38, 0.70, 1.0)


def _quiet_fill() -> Color:
    return Color(0.13, 0.17, 0.26, 1.0)


def _field_fill() -> Color:
    return Color(0.055, 0.075, 0.125, 1.0)


def _kicker_style() -> Style:
    return _label_style(12.0, _accent_ink())


def _body_style() -> Style:
    return _label_style(15.0, _muted_ink())


def _small_style() -> Style:
    return _label_style(13.0, _muted_ink())


def _code_style() -> Style:
    """Return the compact code-panel style used by live stories."""
    return Style(
        _field_fill(),
        Color(0.78, 0.90, 1.0, 1.0),
        9.0,
        12.0,
        Color(0.22, 0.34, 0.52, 1.0),
        1.0,
        1.0,
    )


def _subtle_style() -> Style:
    return _label_style(12.0, _subtle_ink())


def _heading_style() -> Style:
    return _label_style(22.0, _ink())


def _title_style() -> Style:
    return _label_style(29.0, _ink())


def _nav_button_style(selected: Bool) -> Style:
    var style = _button_style(_quiet_fill(), _ink(), 14.0, 8.0)
    if selected:
        style.fill = _accent_fill()
        style.text = _ink()
    return style


def _filter_button_style(selected: Bool) -> Style:
    var style = _button_style(
        Color(0.10, 0.14, 0.22, 1.0),
        _muted_ink(),
        12.0,
        7.0,
    )
    if selected:
        style.fill = _accent_fill()
        style.text = _ink()
    return style


def _tab_style(selected: Bool) -> Style:
    var style = _button_style(
        Color(0.10, 0.14, 0.22, 1.0),
        _muted_ink(),
        13.0,
        7.0,
    )
    if selected:
        style.fill = _accent_fill()
        style.text = _ink()
    return style


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
    var node = LabelControl(id, text, 0.0, style).node()
    node.set_wrap_text()
    root.add_to(parent_id, node)
    root.set_preferred_width(id, width)
    root.set_intrinsic_height(id)


def _is_activation(event: Event) -> Bool:
    return (
        event.kind == CLICK_KIND
        or (
            event.kind == KEY_DOWN_KIND
            and (event.key == KEY_ENTER or event.key == KEY_SPACE)
        )
        or (event.kind == ACTION_KIND and event.action_id == ACTION_PRESS)
    )


def _add_wrapped_label(
    mut root: ColumnView,
    parent_id: Int,
    id: Int,
    text: String,
    width: Float32,
):
    _add_wrapped_label_styled(root, parent_id, id, text, width, _body_style())


