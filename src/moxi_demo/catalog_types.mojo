"""Stable demo catalog classification and search, independent of presentation."""

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

comptime DEMO_EDITORS_ID = 24
comptime DEMO_PAGE_EDITORS = 15

comptime DEMO_SHARED_ID = 25
comptime DEMO_PAGE_SHARED = 16

comptime DEMO_NOT_IMPLEMENTED_ID = 27
comptime DEMO_PAGE_NOT_IMPLEMENTED = 18

comptime DEMO_WORKSPACE_ID = 26
comptime DEMO_PAGE_WORKSPACE = 17


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
