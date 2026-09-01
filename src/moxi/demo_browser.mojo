"""WxPython-inspired browser for Moxi's runnable examples.

The browser is deliberately a component rather than a second application
runtime.  Every catalog entry mounts a real component in-process.  Scene
examples additionally expose a renderer-neutral scene for the host canvas;
the standalone command remains available as a companion entrypoint, not as a
replacement for composition.
"""

from std.collections import List

from .accessibility import ACTION_PRESS
from .alignment import AlignmentState
from .app import CounterState
from .component import Component, ComponentSlot
from .composed import ComposedState
from .controls import ButtonControl, LabelControl, TextInputControl, TextInputState
from .event import (
    ACTION_KIND,
    CLICK_KIND,
    COMPOSITION_END_KIND,
    COMPOSITION_UPDATE_KIND,
    Event,
    FRAME_TICK_KIND,
    KEY_DOWN_KIND,
    KEY_ENTER,
    KEY_ESCAPE,
    KEY_SPACE,
    SCROLL_KIND,
    TEXT_INPUT_KIND,
)
from .form import FormState
from .fractal import FRACTAL_CANVAS_ID, FractalState
from .geometry import Rect
from .interaction_showcase import (
    INTERACTION_SHOWCASE_CANVAS_ID,
    InteractionShowcaseState,
)
from .layout import ALIGN_STRETCH, JUSTIFY_START
from .live_script import LIVE_SCRIPT_CANVAS_ID, LiveScriptState
from .nested import NestedState
from .row import RowState
from .style import (
    Color,
    Style,
    default_label_style,
    default_surface_style,
    default_text_input_style,
)
from .view import ColumnView
from .wrapped import WrappedTextState
from .wxstyle import WxStyleState
from .showcase import (
    SHOWCASE_ANIMATION,
    SHOWCASE_CANVAS_ID,
    SHOWCASE_CORETEXT,
    SHOWCASE_HARFBUZZ,
    SHOWCASE_HELLO_COMPONENT,
    SHOWCASE_HELLO_WINDOW,
    SHOWCASE_METAL_SCENE,
    SHOWCASE_METAL_WINDOW,
    SHOWCASE_PLOT,
    SHOWCASE_PLOT_GALLERY,
    SHOWCASE_PLOT_SVG,
    ShowcaseState,
)
from .scene import Scene


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

comptime DEMO_TAB_OVERVIEW = 0
comptime DEMO_TAB_SOURCE = 1
comptime DEMO_TAB_DEMO = 2

# Browser-owned ids.  Child component ids are namespaced far above this range.
comptime DEMO_NAV_ID = 100
comptime DEMO_MAIN_ID = 101
comptime DEMO_SEARCH_ID = 102
comptime DEMO_CATEGORY_ROW_ONE_ID = 103
comptime DEMO_CATEGORY_ROW_TWO_ID = 104
comptime DEMO_NAV_COUNT_ID = 105
comptime DEMO_NAV_PORTAL_ID = 106
comptime DEMO_NAV_KICKER_ID = 107
comptime DEMO_NAV_SEARCH_LABEL_ID = 108
comptime DEMO_SEARCH_ROW_ID = 109
comptime DEMO_CLEAR_SEARCH_ID = 110
comptime DEMO_NAV_FILTER_LABEL_ID = 111
comptime DEMO_NAV_TIP_ID = 112
comptime DEMO_NAV_DIVIDER_ID = 113
comptime DEMO_ENTRY_VIEW_BASE = 1000
comptime DEMO_CATEGORY_BUTTON_BASE = 2000
comptime DEMO_CATEGORY_LABEL_BASE = 2100
comptime DEMO_ENTRY_SUMMARY_BASE = 4000
comptime DEMO_HEADER_ID = 3000
comptime DEMO_TITLE_ID = 3001
comptime DEMO_METADATA_ID = 3002
comptime DEMO_HEADER_TITLE_ID = 3003
comptime DEMO_HEADER_METADATA_ID = 3004
comptime DEMO_HEADER_KICKER_ID = 3005
comptime DEMO_TABS_ID = 3010
comptime DEMO_TAB_OVERVIEW_ID = 3011
comptime DEMO_TAB_SOURCE_ID = 3012
comptime DEMO_TAB_DEMO_ID = 3013
comptime DEMO_TOOLBAR_ID = 3020
comptime DEMO_RUN_BUTTON_ID = 3021
comptime DEMO_RESET_BUTTON_ID = 3022
comptime DEMO_TOOLBAR_SPACER_ID = 3023
comptime DEMO_RUN_INFO_ID = 3024
comptime DEMO_CONTENT_PORTAL_ID = 3030
comptime DEMO_STATUS_ID = 3031
comptime DEMO_PAGE_CONTAINER_ID = 3040
comptime DEMO_PAGE_TITLE_ID = 3041
comptime DEMO_PAGE_BODY_ID = 3042
comptime DEMO_PAGE_COMMAND_ID = 3043
comptime DEMO_PAGE_CANVAS_ID = 3044
comptime DEMO_PAGE_KICKER_ID = 3045
comptime DEMO_PAGE_MODE_ID = 3046
comptime DEMO_PAGE_QUICKSTART_ID = 3047
comptime DEMO_PAGE_SOURCE_ID = 3048
comptime DEMO_SOURCE_TEXT_ID = 3050
comptime DEMO_SOURCE_HINT_ID = 3051
comptime DEMO_CONTRACT_TITLE_ID = 3060
comptime DEMO_CONTRACT_BODY_ID = 3061
comptime DEMO_EMPTY_CONTAINER_ID = 3070
comptime DEMO_EMPTY_KICKER_ID = 3071
comptime DEMO_EMPTY_TITLE_ID = 3072
comptime DEMO_EMPTY_BODY_ID = 3073
comptime DEMO_EMPTY_CLEAR_ID = 3074

# Component slots use distinct slot and id-offset pairs because the flat view
# tree must remain globally unique even when the selected page changes.
comptime DEMO_COUNTER_SLOT_ID = 8001
comptime DEMO_FORM_SLOT_ID = 8002
comptime DEMO_NESTED_SLOT_ID = 8003
comptime DEMO_COMPOSED_SLOT_ID = 8004
comptime DEMO_WX_STYLE_SLOT_ID = 8005
comptime DEMO_ROW_SLOT_ID = 8006
comptime DEMO_ALIGNMENT_SLOT_ID = 8007
comptime DEMO_WRAPPED_SLOT_ID = 8008
comptime DEMO_COUNTER_ID_OFFSET = 10000
comptime DEMO_FORM_ID_OFFSET = 11000
comptime DEMO_NESTED_ID_OFFSET = 12000
comptime DEMO_COMPOSED_ID_OFFSET = 13000
comptime DEMO_WX_STYLE_ID_OFFSET = 14000
comptime DEMO_ROW_ID_OFFSET = 15000
comptime DEMO_ALIGNMENT_ID_OFFSET = 16000
comptime DEMO_WRAPPED_ID_OFFSET = 17000
comptime DEMO_SHOWCASE_SLOT_ID = 8009
comptime DEMO_FRACTAL_SLOT_ID = 8010
comptime DEMO_LIVE_SCRIPT_SLOT_ID = 8011
comptime DEMO_INTERACTION_SLOT_ID = 8012
comptime DEMO_SHOWCASE_ID_OFFSET = 18000
comptime DEMO_FRACTAL_ID_OFFSET = 19000
comptime DEMO_LIVE_SCRIPT_ID_OFFSET = 20000
comptime DEMO_INTERACTION_ID_OFFSET = 21000


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


struct DemoEntry(ImplicitlyCopyable):
    """Metadata for one runnable example in the browser catalog."""

    var id: Int
    var name: String
    var category: Int
    var summary: String
    var source: String
    var task: String
    var page_kind: Int
    var in_process: Bool
    var source_excerpt: String

    def __init__(
        out self,
        id: Int,
        name: String,
        category: Int,
        summary: String,
        source: String,
        task: String,
        page_kind: Int,
        in_process: Bool,
        source_excerpt: String,
    ):
        self.id = id
        self.name = name
        self.category = category
        self.summary = summary
        self.source = source
        self.task = task
        self.page_kind = page_kind
        self.in_process = in_process
        self.source_excerpt = source_excerpt

    def command(self) -> String:
        """Return the checked-in command that runs this entry."""
        return String("pixi run ", self.task)


struct DemoCatalog:
    """Static, inspectable inventory shared by browser and contract tests."""

    var entries: List[DemoEntry]

    def __init__(out self):
        self.entries = List[DemoEntry](capacity=24)
        self.entries.append(DemoEntry(
            DEMO_HELLO_WINDOW_ID,
            "Hello Window",
            DEMO_CATEGORY_START,
            "The smallest native window and renderer loop.",
            "examples/hello_window.mojo",
            "hello-window-demo",
            DEMO_PAGE_SHOWCASE,
            True,
            "var app = App[ShowcaseState](\n    ShowcaseState(SHOWCASE_HELLO_WINDOW), bounds\n)\napp.run(window, renderer)",
        ))
        self.entries.append(DemoEntry(
            DEMO_HELLO_COMPONENT_ID,
            "Hello Component",
            DEMO_CATEGORY_START,
            "A minimal Component and App lifecycle with a declarative label.",
            "examples/hello_component.mojo",
            "component-demo",
            DEMO_PAGE_SHOWCASE,
            True,
            "var app = App[ShowcaseState](\n    ShowcaseState(SHOWCASE_HELLO_COMPONENT), bounds\n)\napp.run(window, renderer)",
        ))
        self.entries.append(DemoEntry(
            DEMO_COUNTER_ID,
            "Counter",
            DEMO_CATEGORY_COMPONENTS,
            "A stateful button rebuild with focus, pointer, and keyboard routing.",
            "examples/counter.mojo",
            "counter-demo",
            DEMO_PAGE_COUNTER,
            True,
            "var app = App[CounterState](\n    CounterState(), bounds\n)\napp.run(window, renderer)",
        ))
        self.entries.append(DemoEntry(
            DEMO_FORM_ID,
            "Form",
            DEMO_CATEGORY_COMPONENTS,
            "Unicode-safe text input, selection, clipboard, and submit actions.",
            "examples/form.mojo",
            "form-demo",
            DEMO_PAGE_FORM,
            True,
            "var app = App[FormState](\n    FormState(), bounds\n)\napp.run_with_clipboard(window, renderer, clipboard)",
        ))
        self.entries.append(DemoEntry(
            DEMO_NESTED_ID,
            "Nested Containers",
            DEMO_CATEGORY_COMPONENTS,
            "An editable field and horizontal actions inside nested containers.",
            "examples/nested.mojo",
            "nested-demo",
            DEMO_PAGE_NESTED,
            True,
            "var content = root.add_column(CONTENT_CONTAINER_ID, ...)\nroot.add_row(ACTIONS_CONTAINER_ID, ...)",
        ))
        self.entries.append(DemoEntry(
            DEMO_COMPOSED_ID,
            "Composed Components",
            DEMO_CATEGORY_COMPONENTS,
            "Typed child ownership, namespaced ids, and local event routing.",
            "examples/composed.mojo",
            "composed-demo",
            DEMO_PAGE_COMPOSED,
            True,
            "var child = self.counter.build(child_bounds)\nroot.add_component_view_to(..., id_offset)",
        ))
        self.entries.append(DemoEntry(
            DEMO_WX_STYLE_ID,
            "wxPython-style Showcase",
            DEMO_CATEGORY_COMPONENTS,
            "A broad Frame -> Panel -> BoxSizer-style lesson covering the catalog and capability flow.",
            "examples/wx_style.mojo",
            "wx-style-demo",
            DEMO_PAGE_WX_STYLE,
            True,
            "window.open(WindowConfig(\"Moxi wxPython-style demo\", 560.0, 1100.0))\nvar app = App[WxStyleState](WxStyleState(), bounds)",
        ))
        self.entries.append(DemoEntry(
            DEMO_INTERACTION_ID,
            "Collection & Interaction Lab",
            DEMO_CATEGORY_COMPONENTS,
            "A live stable-key table, tree disclosure, scrollbar, popup stack, and reorder gesture in one component.",
            "examples/interaction_showcase.mojo",
            "interaction-showcase-demo",
            DEMO_PAGE_INTERACTION,
            True,
            "var app = App[InteractionShowcaseState](InteractionShowcaseState(), bounds)\napp.run(window, renderer)",
        ))
        self.entries.append(DemoEntry(
            DEMO_LIVE_SCRIPT_ID,
            "Editable Live Component",
            DEMO_CATEGORY_COMPONENTS,
            "Edit a real Mojo component, save it, and hot-reload its scene in this window.",
            "examples/editable_showcase.mojo",
            "live-script-demo",
            DEMO_PAGE_LIVE_SCRIPT,
            True,
            "@export\ndef moxi_live_frame(x, y, width, height) abi(\"C\") -> Int32:\n    ...",
        ))
        self.entries.append(DemoEntry(
            DEMO_ROW_ID,
            "Row Layout",
            DEMO_CATEGORY_LAYOUT,
            "Reusable controls arranged with a horizontal row and flexible spacing.",
            "examples/row.mojo",
            "row-demo",
            DEMO_PAGE_ROW,
            True,
            "var row = make_row(bounds, 24.0, 16.0)\nrow.add(previous.node())\nrow.add(next.node())",
        ))
        self.entries.append(DemoEntry(
            DEMO_ALIGNMENT_ID,
            "Alignment",
            DEMO_CATEGORY_LAYOUT,
            "Start, center, and end alignment with stable selected state.",
            "examples/alignment.mojo",
            "alignment-demo",
            DEMO_PAGE_ALIGNMENT,
            True,
            "column.set_main_alignment(JUSTIFY_CENTER)\ncolumn.set_cross_alignment(ALIGN_CENTER)",
        ))
        self.entries.append(DemoEntry(
            DEMO_WRAPPED_ID,
            "Wrapped Text",
            DEMO_CATEGORY_LAYOUT,
            "Opt-in wrapping and intrinsic-height reflow as the window changes size.",
            "examples/wrapped_text.mojo",
            "wrapped-text-demo",
            DEMO_PAGE_WRAPPED,
            True,
            "node.set_wrap_text()\nnode.set_intrinsic_height()\ncolumn.layout()",
        ))
        self.entries.append(DemoEntry(
            DEMO_ANIMATION_ID,
            "Animation & Invalidation",
            DEMO_CATEGORY_LAYOUT,
            "A deterministic frame clock, easing function, and dirty-region trace.",
            "examples/animation.mojo",
            "animation-demo",
            DEMO_PAGE_SHOWCASE,
            True,
            "var app = App[ShowcaseState](ShowcaseState(SHOWCASE_ANIMATION), bounds)\napp.tick(0.25)",
        ))
        self.entries.append(DemoEntry(
            DEMO_PLOT_ID,
            "Plot Scene",
            DEMO_CATEGORY_PLOTTING,
            "A portable line/scatter scene with hit testing and software rendering.",
            "examples/plot.mojo",
            "plot-demo",
            DEMO_PAGE_SHOWCASE,
            True,
            "var component = ShowcaseState(SHOWCASE_PLOT)\nvar scene = component.scene(bounds)\nrenderer.render_scene(scene)",
        ))
        self.entries.append(DemoEntry(
            DEMO_PLOT_GALLERY_ID,
            "Plot Gallery",
            DEMO_CATEGORY_PLOTTING,
            "Typed data, encodings, facets, statistical recipes, and interactions.",
            "examples/plot_gallery.mojo",
            "plot-gallery",
            DEMO_PAGE_SHOWCASE,
            True,
            "var component = ShowcaseState(SHOWCASE_PLOT_GALLERY)\nvar scene = component.scene(bounds)\nrenderer.render_scene(scene)",
        ))
        self.entries.append(DemoEntry(
            DEMO_PLOT_SVG_ID,
            "Plot SVG Export",
            DEMO_CATEGORY_PLOTTING,
            "Serialize the shared scene into browser-compatible SVG markup.",
            "examples/plot_svg.mojo",
            "plot-svg",
            DEMO_PAGE_SHOWCASE,
            True,
            "var component = ShowcaseState(SHOWCASE_PLOT_SVG)\nvar scene = component.scene(bounds)\nrenderer.render_scene(scene)",
        ))
        self.entries.append(DemoEntry(
            DEMO_FRACTAL_ID,
            "Interactive Line Fractal",
            DEMO_CATEGORY_PLOTTING,
            "An interactive plotting port of Xilem's draggable line-fractal generator with 27 presets and incremental rendering.",
            "examples/interactive_fractal.mojo",
            "interactive-fractal-demo",
            DEMO_PAGE_FRACTAL,
            True,
            "var app = App[FractalState](FractalState(), bounds)\napp.component.advance_render()\napp.component.paint_canvas(painter, canvas, clip)",
        ))
        self.entries.append(DemoEntry(
            DEMO_METAL_SCENE_ID,
            "Metal Scene",
            DEMO_CATEGORY_RENDERING,
            "Offscreen GPU scene rendering with deterministic checksum output.",
            "examples/metal_scene.mojo",
            "metal-demo",
            DEMO_PAGE_SHOWCASE,
            True,
            "var component = ShowcaseState(SHOWCASE_METAL_SCENE)\nvar scene = component.scene(bounds)\nrenderer.render_scene(scene)",
        ))
        self.entries.append(DemoEntry(
            DEMO_METAL_WINDOW_ID,
            "Metal Window",
            DEMO_CATEGORY_RENDERING,
            "A visible CAMetalLayer window consuming the scene contract.",
            "examples/metal_window.mojo",
            "metal-window-demo",
            DEMO_PAGE_SHOWCASE,
            True,
            "var component = ShowcaseState(SHOWCASE_METAL_WINDOW)\nvar scene = component.scene(bounds)\nrenderer.render_scene(scene)",
        ))
        self.entries.append(DemoEntry(
            DEMO_CORETEXT_ID,
            "CoreText Shaping",
            DEMO_CATEGORY_TEXT,
            "Native shaped runs for Unicode, bidi, and fallback-face metadata.",
            "examples/coretext.mojo",
            "text-demo",
            DEMO_PAGE_SHOWCASE,
            True,
            "var shaper = MacOSTextShaper()\nvar result = shaper.shape(\"Moxi • שלום • 🙂\", style, 0.0, 1)",
        ))
        self.entries.append(DemoEntry(
            DEMO_HARFBUZZ_ID,
            "HarfBuzz Shaping",
            DEMO_CATEGORY_TEXT,
            "Optional OpenType shaping through the host-linked HarfBuzz adapter.",
            "examples/harfbuzz.mojo",
            "harfbuzz-demo",
            DEMO_PAGE_SHOWCASE,
            True,
            "var shaper = HarfBuzzTextShaper()\nvar result = shaper.shape(\"office • مرحبا • नमस्ते\", style, 0.0, 0)",
        ))

    def count(self) -> Int:
        return len(self.entries)

    def entry(self, index: Int) -> DemoEntry:
        return self.entries[index]

    def index_for_id(self, id: Int) -> Int:
        for index in range(len(self.entries)):
            if self.entries[index].id == id:
                return index
        return -1

    def matches(self, index: Int, query: String, category: Int) -> Bool:
        var item = self.entries[index]
        if category != DEMO_CATEGORY_ALL and item.category != category:
            return False
        return (
            _contains_insensitive(item.name, query)
            or _contains_insensitive(item.summary, query)
            or _contains_insensitive(item.source, query)
            or _contains_insensitive(item.task, query)
        )

    def visible_count(self, query: String, category: Int) -> Int:
        var result = 0
        for index in range(len(self.entries)):
            if self.matches(index, query, category):
                result += 1
        return result


struct DemoBrowserState(Component):
    """A searchable, categorized browser for all checked-in Moxi examples."""

    var search: TextInputState
    var category: Int
    var selected_id: Int
    var tab: Int
    var status: String
    var pending_task: String
    var task_running: Bool
    var active_task: String

    var counter: ComponentSlot[CounterState]
    var form: ComponentSlot[FormState]
    var nested: ComponentSlot[NestedState]
    var composed: ComponentSlot[ComposedState]
    var wx_style: ComponentSlot[WxStyleState]
    var interaction: ComponentSlot[InteractionShowcaseState]
    var row: ComponentSlot[RowState]
    var alignment: ComponentSlot[AlignmentState]
    var wrapped: ComponentSlot[WrappedTextState]
    var showcase: ComponentSlot[ShowcaseState]
    var fractal: ComponentSlot[FractalState]
    var live_script: ComponentSlot[LiveScriptState]

    def __init__(out self):
        self.search = TextInputState()
        self.category = DEMO_CATEGORY_ALL
        self.selected_id = DEMO_HELLO_WINDOW_ID
        self.tab = DEMO_TAB_OVERVIEW
        self.status = "Ready · choose an example to explore."
        self.pending_task = ""
        self.task_running = False
        self.active_task = ""
        self.counter = ComponentSlot[CounterState](
            CounterState(), DEMO_COUNTER_SLOT_ID, DEMO_COUNTER_ID_OFFSET
        )
        self.form = ComponentSlot[FormState](
            FormState(), DEMO_FORM_SLOT_ID, DEMO_FORM_ID_OFFSET
        )
        self.nested = ComponentSlot[NestedState](
            NestedState(), DEMO_NESTED_SLOT_ID, DEMO_NESTED_ID_OFFSET
        )
        self.composed = ComponentSlot[ComposedState](
            ComposedState(), DEMO_COMPOSED_SLOT_ID, DEMO_COMPOSED_ID_OFFSET
        )
        self.wx_style = ComponentSlot[WxStyleState](
            WxStyleState(), DEMO_WX_STYLE_SLOT_ID, DEMO_WX_STYLE_ID_OFFSET
        )
        self.interaction = ComponentSlot[InteractionShowcaseState](
            InteractionShowcaseState(),
            DEMO_INTERACTION_SLOT_ID,
            DEMO_INTERACTION_ID_OFFSET,
        )
        self.row = ComponentSlot[RowState](
            RowState(), DEMO_ROW_SLOT_ID, DEMO_ROW_ID_OFFSET
        )
        self.alignment = ComponentSlot[AlignmentState](
            AlignmentState(), DEMO_ALIGNMENT_SLOT_ID, DEMO_ALIGNMENT_ID_OFFSET
        )
        self.wrapped = ComponentSlot[WrappedTextState](
            WrappedTextState(), DEMO_WRAPPED_SLOT_ID, DEMO_WRAPPED_ID_OFFSET
        )
        self.showcase = ComponentSlot[ShowcaseState](
            ShowcaseState(SHOWCASE_HELLO_WINDOW),
            DEMO_SHOWCASE_SLOT_ID,
            DEMO_SHOWCASE_ID_OFFSET,
        )
        self.fractal = ComponentSlot[FractalState](
            FractalState(), DEMO_FRACTAL_SLOT_ID, DEMO_FRACTAL_ID_OFFSET
        )
        self.live_script = ComponentSlot[LiveScriptState](
            LiveScriptState(),
            DEMO_LIVE_SCRIPT_SLOT_ID,
            DEMO_LIVE_SCRIPT_ID_OFFSET,
        )

    def selected_entry(self) -> DemoEntry:
        var catalog = DemoCatalog()
        var index = catalog.index_for_id(self.selected_id)
        if index < 0:
            index = 0
        return catalog.entry(index)

    def visible_count(self) -> Int:
        var catalog = DemoCatalog()
        return catalog.visible_count(self.search.text, self.category)

    def selected_source_path(self) -> String:
        """Return the checked-in source path for the selected catalog entry."""
        return self.selected_entry().source

    def has_live_script(self) -> Bool:
        """Return whether the selected page participates in the reload ABI."""
        return self.selected_entry().page_kind == DEMO_PAGE_LIVE_SCRIPT

    def set_live_reload_status(mut self, status: String):
        """Publish host reload state through the embedded component view."""
        var live = self.live_script.component
        live.set_status(status)
        self.live_script.component = live
        self.status = status

    def _activate_entry(mut self, id: Int):
        """Select the concrete component implementation for a catalog entry."""
        var catalog = DemoCatalog()
        var index = catalog.index_for_id(id)
        if index < 0:
            return
        var entry = catalog.entry(index)
        if entry.page_kind == DEMO_PAGE_SHOWCASE:
            var showcase = self.showcase.component
            showcase.set_mode(showcase_mode_for_demo(id))
            self.showcase.component = showcase

    def take_pending_task(mut self) -> String:
        """Take one standalone task request produced by the Run action."""
        var task = self.pending_task
        self.pending_task = ""
        return task

    def set_task_result(mut self, task: String, launched: Bool):
        """Record the host result after attempting a catalog task launch."""
        if launched:
            self.task_running = True
            self.active_task = task
            self.status = String("Launched pixi run ", task, ".")
        else:
            self.task_running = False
            self.active_task = ""
            self.status = String(
                "Could not launch pixi run ", task,
                "; it may already be running or unavailable.",
            )

    def set_task_completion(mut self, task: String, status_code: Int):
        """Record the terminal status of a standalone task."""
        self.task_running = False
        self.active_task = ""
        if status_code == 0:
            self.status = String("Completed pixi run ", task, ".")
        else:
            self.status = String(
                "pixi run ", task,
                " exited with status ", status_code, ".",
            )

    def _select_first_visible(mut self):
        var catalog = DemoCatalog()
        for index in range(catalog.count()):
            if catalog.matches(index, self.search.text, self.category):
                self.selected_id = catalog.entry(index).id
                self._activate_entry(self.selected_id)
                self.tab = DEMO_TAB_OVERVIEW
                return
        self.selected_id = -1
        self.tab = DEMO_TAB_OVERVIEW

    def clear_search(mut self) -> Bool:
        """Clear the catalog query and restore its first visible example."""
        if self.search.text.count_codepoints() == 0 and not self.search.has_composition():
            return False
        self.search = TextInputState()
        self._select_first_visible()
        if self.category == DEMO_CATEGORY_ALL:
            self.status = "Showing all examples."
        else:
            self.status = String(
                "Showing ", demo_category_name(self.category), " examples."
            )
        return True

    def _reset_active(mut self):
        if self.selected_id == DEMO_COUNTER_ID:
            self.counter.component = CounterState()
        elif self.selected_id == DEMO_FORM_ID:
            self.form.component = FormState()
        elif self.selected_id == DEMO_NESTED_ID:
            self.nested.component = NestedState()
        elif self.selected_id == DEMO_COMPOSED_ID:
            self.composed.component = ComposedState()
        elif self.selected_id == DEMO_WX_STYLE_ID:
            self.wx_style.component = WxStyleState()
        elif self.selected_id == DEMO_INTERACTION_ID:
            self.interaction.component = InteractionShowcaseState()
        elif self.selected_id == DEMO_ROW_ID:
            self.row.component = RowState()
        elif self.selected_id == DEMO_ALIGNMENT_ID:
            self.alignment.component = AlignmentState()
        elif self.selected_id == DEMO_WRAPPED_ID:
            self.wrapped.component = WrappedTextState()
        elif self.selected_entry().page_kind == DEMO_PAGE_SHOWCASE:
            self.showcase.component = ShowcaseState(
                showcase_mode_for_demo(self.selected_id)
            )
        elif self.selected_id == DEMO_FRACTAL_ID:
            self.fractal.component = FractalState()
        elif self.selected_entry().page_kind == DEMO_PAGE_LIVE_SCRIPT:
            self.live_script.component = LiveScriptState()

    def selected_scene(self, view: ColumnView) -> Scene:
        """Return the selected component's scene for the host canvas.

        The returned scene uses the laid-out, namespaced canvas bounds.  This
        keeps scene rendering in the same coordinate space as the surrounding
        Moxi widgets while leaving the component itself backend-neutral.
        """
        var empty = Scene()
        if self.tab != DEMO_TAB_DEMO:
            return empty^
        var entry = self.selected_entry()
        if entry.page_kind == DEMO_PAGE_INTERACTION:
            var canvas = view.bounds_for(
                DEMO_INTERACTION_ID_OFFSET + INTERACTION_SHOWCASE_CANVAS_ID
            )
            return self.interaction.component.scene(canvas)
        if entry.page_kind == DEMO_PAGE_SHOWCASE:
            var canvas = view.bounds_for(
                DEMO_SHOWCASE_ID_OFFSET + SHOWCASE_CANVAS_ID
            )
            return self.showcase.component.scene(canvas)
        if entry.page_kind == DEMO_PAGE_FRACTAL:
            var canvas = view.bounds_for(
                DEMO_FRACTAL_ID_OFFSET + FRACTAL_CANVAS_ID
            )
            return self.fractal.component.build_scene(canvas)
        return empty^

    def selected_surface_bounds(self, view: ColumnView) -> Rect:
        """Return the active component canvas bounds for a scene host."""
        if self.tab != DEMO_TAB_DEMO:
            return Rect(0.0, 0.0, 0.0, 0.0)
        var entry = self.selected_entry()
        if entry.page_kind == DEMO_PAGE_INTERACTION:
            return view.bounds_for(
                DEMO_INTERACTION_ID_OFFSET + INTERACTION_SHOWCASE_CANVAS_ID
            )
        if entry.page_kind == DEMO_PAGE_SHOWCASE and self.showcase.component.has_scene():
            return view.bounds_for(
                DEMO_SHOWCASE_ID_OFFSET + SHOWCASE_CANVAS_ID
            )
        if entry.page_kind == DEMO_PAGE_FRACTAL:
            return view.bounds_for(
                DEMO_FRACTAL_ID_OFFSET + FRACTAL_CANVAS_ID
            )
        if entry.page_kind == DEMO_PAGE_LIVE_SCRIPT:
            return view.bounds_for(
                DEMO_LIVE_SCRIPT_ID_OFFSET + LIVE_SCRIPT_CANVAS_ID
            )
        return Rect(0.0, 0.0, 0.0, 0.0)

    def build(self, bounds: Rect) -> ColumnView:
        """Build the browser shell and the selected page."""
        var root = ColumnView(bounds, 14.0, 12.0)
        root.set_surface_style(default_surface_style())
        var shell_width = bounds.width - 16.0
        var shell_height = bounds.height - 16.0
        if shell_width < 0.0:
            shell_width = 0.0
        if shell_height < 0.0:
            shell_height = 0.0
        root.set_panel(
            0,
            Rect(bounds.x + 8.0, bounds.y + 8.0, shell_width, shell_height),
            Style(
                Color(0.105, 0.135, 0.21, 1.0),
                _ink(),
                18.0,
                0.0,
            ),
        )
        root.set_clip_to_bounds()
        root.set_row_layout()

        var nav = root.add_column(DEMO_NAV_ID, 0.0, 14.0, 6.0)
        var main = root.add_column(DEMO_MAIN_ID, 0.0, 18.0, 8.0)
        root.set_fixed_width(nav, 308.0)
        root.set_container_alignment(nav, JUSTIFY_START, ALIGN_STRETCH)
        root.set_container_alignment(main, JUSTIFY_START, ALIGN_STRETCH)

        _add_styled_label(
            root,
            nav,
            DEMO_NAV_KICKER_ID,
            "MOXI / PLAYGROUND",
            18.0,
            _kicker_style(),
        )
        _add_styled_label(
            root,
            nav,
            DEMO_TITLE_ID,
            "Moxi Playground",
            34.0,
            _title_style(),
        )
        _add_styled_label(
            root,
            nav,
            DEMO_METADATA_ID,
            "Run, read, and inspect real examples from one native workbench.",
            38.0,
            _body_style(),
        )
        root.add_separator_to(nav, DEMO_NAV_DIVIDER_ID, 1.0)
        var divider_style = Style(
            Color(0.0, 0.0, 0.0, 0.0),
            Color(0.28, 0.37, 0.52, 1.0),
            0.0,
            1.0,
        )
        root.set_style(DEMO_NAV_DIVIDER_ID, divider_style)
        _add_styled_label(
            root,
            nav,
            DEMO_NAV_SEARCH_LABEL_ID,
            "FIND AN EXAMPLE",
            18.0,
            _kicker_style(),
        )

        var search_row = root.add_row_to(
            nav,
            DEMO_SEARCH_ROW_ID,
            0.0,
            38.0,
            0.0,
            6.0,
        )
        var search_style = default_text_input_style()
        search_style.fill = _field_fill()
        search_style.text = _ink()
        search_style.font_size = 15.0
        var search = TextInputControl(
            DEMO_SEARCH_ID,
            self.search.text,
            self.search.cursor,
            38.0,
            search_style,
        )
        search.selection_anchor = self.search.anchor
        search.set_composition(
            self.search.composition,
            self.search.composition_selection_start,
            self.search.composition_selection_end,
        )
        root.add_to(search_row, search.node())
        root.set_accessibility_label(DEMO_SEARCH_ID, "Search demos")
        root.set_accessibility_hint(
            DEMO_SEARCH_ID,
            "Search names, descriptions, source paths, or tasks",
        )
        var clear_search = ButtonControl(
            DEMO_CLEAR_SEARCH_ID,
            "Clear",
            34.0,
            _filter_button_style(False),
            self.search.text.count_codepoints() > 0,
        )
        root.add_to(search_row, clear_search.node())
        root.set_fixed_width(DEMO_CLEAR_SEARCH_ID, 58.0)
        root.set_accessibility_label(DEMO_CLEAR_SEARCH_ID, "Clear search")
        root.set_accessibility_hint(
            DEMO_CLEAR_SEARCH_ID,
            "Clear the query and show every example",
        )

        _add_styled_label(
            root,
            nav,
            DEMO_NAV_FILTER_LABEL_ID,
            "FILTER BY AREA",
            18.0,
            _kicker_style(),
        )
        var categories_one = root.add_row_to(
            nav, DEMO_CATEGORY_ROW_ONE_ID, 0.0, 30.0, 0.0, 4.0
        )
        var categories_two = root.add_row_to(
            nav, DEMO_CATEGORY_ROW_TWO_ID, 0.0, 30.0, 0.0, 4.0
        )
        self.add_category_button(root, categories_one, DEMO_CATEGORY_ALL)
        self.add_category_button(root, categories_one, DEMO_CATEGORY_START)
        self.add_category_button(root, categories_one, DEMO_CATEGORY_COMPONENTS)
        self.add_category_button(root, categories_two, DEMO_CATEGORY_LAYOUT)
        self.add_category_button(root, categories_two, DEMO_CATEGORY_PLOTTING)
        self.add_category_button(root, categories_two, DEMO_CATEGORY_RENDERING)
        self.add_category_button(root, categories_two, DEMO_CATEGORY_TEXT)

        var catalog = DemoCatalog()
        _add_styled_label(
            root,
            nav,
            DEMO_NAV_COUNT_ID,
            String(self.visible_count(), " of ", catalog.count(), " examples"),
            22.0,
            _small_style(),
        )
        _add_styled_label(
            root,
            nav,
            DEMO_NAV_TIP_ID,
            "Tip: type to filter · Esc clears",
            22.0,
            _subtle_style(),
        )

        var nav_height = bounds.height - 393.0
        if nav_height < 160.0:
            nav_height = 160.0
        var nav_portal = root.add_portal_to(
            nav,
            DEMO_NAV_PORTAL_ID,
            nav_height,
            4.0,
            6.0,
            0.0,
        )
        root.set_accessibility_label(nav_portal, "Demo catalog")
        var last_category = -1
        var added = 0
        for index in range(catalog.count()):
            if not catalog.matches(index, self.search.text, self.category):
                continue
            var item = catalog.entry(index)
            if item.category != last_category:
                root.add_label_to(
                    nav_portal,
                    DEMO_CATEGORY_LABEL_BASE + item.category,
                    demo_category_name(item.category),
                    20.0,
                )
                root.set_style(
                    DEMO_CATEGORY_LABEL_BASE + item.category,
                    _kicker_style(),
                )
                last_category = item.category
            var item_id = DEMO_ENTRY_VIEW_BASE + item.id
            var item_text = String("   ", item.name)
            if item.id == self.selected_id:
                item_text = String("●  ", item.name)
            var item_button = ButtonControl(
                item_id,
                item_text,
                34.0,
                _nav_button_style(item.id == self.selected_id),
            )
            root.add_to(nav_portal, item_button.node())
            root.set_accessibility_label(item_id, item.name)
            root.set_accessibility_value(item_id, item.summary)
            root.set_selected(item_id, item.id == self.selected_id)
            _add_wrapped_label_styled(
                root,
                nav_portal,
                DEMO_ENTRY_SUMMARY_BASE + item.id,
                item.summary,
                280.0,
                _subtle_style(),
            )
            added += 1
        if added == 0:
            _add_wrapped_label(
                root,
                nav_portal,
                DEMO_CATEGORY_BUTTON_BASE + 100,
                "No examples match. Clear the query or choose another area.",
                280.0,
            )

        var main_width = bounds.width - 384.0
        if main_width < 240.0:
            main_width = 240.0

        if self.visible_count() == 0:
            var empty_height = bounds.height - 104.0
            if empty_height < 180.0:
                empty_height = 180.0
            self.build_empty(root, main, main_width, empty_height)
            _add_styled_label(
                root,
                main,
                DEMO_STATUS_ID,
                self.status,
                32.0,
                _small_style(),
            )
            root.set_accessibility_label(DEMO_STATUS_ID, "Demo browser status")
            root.set_accessibility_value(DEMO_STATUS_ID, self.status)
            root.layout()
            return root^

        var entry = self.selected_entry()
        var header = root.add_column_to(main, DEMO_HEADER_ID, 70.0, 0.0, 2.0)
        _add_styled_label(
            root,
            header,
            DEMO_HEADER_KICKER_ID,
            "SELECTED EXAMPLE",
            16.0,
            _kicker_style(),
        )
        _add_styled_label(
            root,
            header,
            DEMO_HEADER_TITLE_ID,
            entry.name,
            32.0,
            _title_style(),
        )
        var metadata = String(demo_category_name(entry.category), " · ", entry.source)
        if entry.in_process:
            metadata += " · LIVE"
        else:
            metadata += " · SCRIPT"
        _add_styled_label(
            root,
            header,
            DEMO_HEADER_METADATA_ID,
            metadata,
            18.0,
            _small_style(),
        )

        var tabs = root.add_row_to(main, DEMO_TABS_ID, 0.0, 40.0, 0.0, 6.0)
        self.add_tab_button(root, tabs, DEMO_TAB_OVERVIEW, "Overview", DEMO_TAB_OVERVIEW_ID)
        self.add_tab_button(root, tabs, DEMO_TAB_SOURCE, "Source", DEMO_TAB_SOURCE_ID)
        self.add_tab_button(root, tabs, DEMO_TAB_DEMO, "Demo", DEMO_TAB_DEMO_ID)

        var toolbar = root.add_row_to(main, DEMO_TOOLBAR_ID, 0.0, 46.0, 0.0, 8.0)
        var run_text = "Run script"
        if entry.in_process:
            run_text = "Run live page"
        var run_enabled = not self.task_running or entry.in_process
        var run_button = ButtonControl(
            DEMO_RUN_BUTTON_ID,
            run_text,
            36.0,
            _button_style(_accent_fill(), _ink(), 14.0, 8.0),
            run_enabled,
        )
        root.add_to(toolbar, run_button.node())
        root.set_intrinsic_width(DEMO_RUN_BUTTON_ID)
        root.set_accessibility_label(DEMO_RUN_BUTTON_ID, run_text)
        root.set_accessibility_value(
            DEMO_RUN_BUTTON_ID,
            "live component"
                if entry.in_process
                else (
                    "standalone task ready"
                    if run_enabled
                    else "Disabled while the standalone task is running"
                ),
        )
        var reset_button = ButtonControl(
            DEMO_RESET_BUTTON_ID,
            "Reset",
            36.0,
            _filter_button_style(False),
            entry.in_process,
        )
        root.add_to(toolbar, reset_button.node())
        root.set_intrinsic_width(DEMO_RESET_BUTTON_ID)
        root.set_accessibility_label(DEMO_RESET_BUTTON_ID, "Reset live example")
        root.set_accessibility_hint(
            DEMO_RESET_BUTTON_ID,
            "Reset the selected in-browser component",
        )
        root.add_flexible_spacer_to(toolbar, DEMO_TOOLBAR_SPACER_ID)
        var run_info = "COMPANION SCRIPT · run separately from the browser"
        if entry.in_process:
            run_info = "LIVE COMPONENT · stays in this window"
        if self.task_running:
            run_info = String("● RUNNING · ", self.active_task)
        _add_styled_label(
            root,
            toolbar,
            DEMO_RUN_INFO_ID,
            run_info,
            26.0,
            _small_style(),
        )
        root.set_accessibility_label(DEMO_RUN_INFO_ID, "Execution mode")
        root.set_accessibility_value(DEMO_RUN_INFO_ID, run_info)

        var content_height = bounds.height - 284.0
        if content_height < 180.0:
            content_height = 180.0
        var content = root.add_portal_to(
            main,
            DEMO_CONTENT_PORTAL_ID,
            content_height,
            12.0,
            10.0,
            0.0,
        )
        root.set_accessibility_label(content, "Selected demo content")
        if self.tab == DEMO_TAB_OVERVIEW:
            self.build_overview(root, content, entry, main_width - 24.0)
        elif self.tab == DEMO_TAB_SOURCE:
            self.build_source(root, content, entry, main_width - 24.0)
        else:
            self.build_demo(root, content, entry, main_width - 24.0, content_height)
        var status_style = _small_style()
        if self.task_running:
            status_style.text = _accent_ink()
        _add_styled_label(root, main, DEMO_STATUS_ID, self.status, 32.0, status_style)
        root.set_accessibility_label(DEMO_STATUS_ID, "Demo browser status")
        root.set_accessibility_value(DEMO_STATUS_ID, self.status)

        root.layout()
        return root^

    def build_empty(
        self,
        mut root: ColumnView,
        parent_id: Int,
        width: Float32,
        height: Float32,
    ):
        """Build a useful empty state instead of leaving stale content visible."""
        var empty = root.add_column_to(
            parent_id,
            DEMO_EMPTY_CONTAINER_ID,
            height,
            0.0,
            10.0,
        )
        root.set_container_alignment(empty, JUSTIFY_START, ALIGN_STRETCH)
        _add_styled_label(
            root,
            empty,
            DEMO_EMPTY_KICKER_ID,
            "NO MATCHES",
            18.0,
            _kicker_style(),
        )
        _add_styled_label(
            root,
            empty,
            DEMO_EMPTY_TITLE_ID,
            "Nothing found",
            34.0,
            _title_style(),
        )
        _add_wrapped_label_styled(
            root,
            empty,
            DEMO_EMPTY_BODY_ID,
            "Try a different word, search a source path, or clear the filter to return to the full catalog.",
            width,
            _body_style(),
        )
        var clear = ButtonControl(
            DEMO_EMPTY_CLEAR_ID,
            "Clear search",
            36.0,
            _button_style(_accent_fill(), _ink(), 14.0, 8.0),
        )
        root.add_to(empty, clear.node())
        root.set_intrinsic_width(DEMO_EMPTY_CLEAR_ID)
        root.set_accessibility_label(DEMO_EMPTY_CLEAR_ID, "Clear search")
        root.set_accessibility_hint(
            DEMO_EMPTY_CLEAR_ID,
            "Show every example again",
        )

    def add_category_button(
        self,
        mut root: ColumnView,
        parent_id: Int,
        category: Int,
    ):
        var label = demo_category_short_name(category)
        var button = ButtonControl(
            DEMO_CATEGORY_BUTTON_BASE + category,
            label,
            28.0,
            _filter_button_style(self.category == category),
        )
        root.add_to(parent_id, button.node())
        root.set_fixed_width(DEMO_CATEGORY_BUTTON_BASE + category, 62.0)
        root.set_selected(
            DEMO_CATEGORY_BUTTON_BASE + category,
            self.category == category,
        )
        root.set_accessibility_label(
            DEMO_CATEGORY_BUTTON_BASE + category,
            demo_category_name(category),
        )
        root.set_accessibility_value(
            DEMO_CATEGORY_BUTTON_BASE + category,
            "selected" if self.category == category else "not selected",
        )

    def add_tab_button(
        self,
        mut root: ColumnView,
        parent_id: Int,
        tab: Int,
        label: String,
        id: Int,
    ):
        var button = ButtonControl(id, label, 36.0, _tab_style(self.tab == tab))
        root.add_to(parent_id, button.node())
        root.set_fixed_width(id, 112.0)
        root.set_selected(id, self.tab == tab)
        root.set_accessibility_label(id, String(label, " tab"))
        root.set_accessibility_value(
            id,
            "selected" if self.tab == tab else "not selected",
        )

    def build_overview(
        self,
        mut root: ColumnView,
        parent_id: Int,
        entry: DemoEntry,
        width: Float32,
    ):
        var mode = "COMPANION SCRIPT"
        var usage = "The checked-in task remains available as a standalone companion command."
        if entry.in_process:
            mode = "LIVE COMPONENT"
            usage = "Run live page mounts the typed component in this browser."
        _add_styled_label(
            root,
            parent_id,
            DEMO_PAGE_KICKER_ID,
            mode,
            18.0,
            _kicker_style(),
        )
        _add_styled_label(
            root,
            parent_id,
            DEMO_PAGE_TITLE_ID,
            "About this example",
            30.0,
            _heading_style(),
        )
        _add_wrapped_label_styled(
            root,
            parent_id,
            DEMO_PAGE_BODY_ID,
            entry.summary,
            width,
            _body_style(),
        )
        _add_styled_label(
            root,
            parent_id,
            DEMO_PAGE_QUICKSTART_ID,
            "1  Read   ·   2  Run   ·   3  Inspect",
            28.0,
            _label_style(14.0, _accent_ink()),
        )
        _add_styled_label(
            root,
            parent_id,
            DEMO_PAGE_COMMAND_ID,
            String("Command  ·  ", entry.command()),
            28.0,
            _small_style(),
        )
        _add_styled_label(
            root,
            parent_id,
            DEMO_PAGE_SOURCE_ID,
            String("Source  ·  ", entry.source),
            26.0,
            _subtle_style(),
        )
        _add_wrapped_label_styled(
            root,
            parent_id,
            DEMO_SOURCE_HINT_ID,
            usage,
            width,
            _body_style(),
        )
        _add_styled_label(
            root,
            parent_id,
            DEMO_CONTRACT_TITLE_ID,
            "What to look for",
            26.0,
            _heading_style(),
        )
        _add_wrapped_label_styled(
            root,
            parent_id,
            DEMO_CONTRACT_BODY_ID,
            "Every item is backed by a real examples/ file. Pages exercise Moxi's value-based App, focus, event, component-slot, and canvas contracts in this window; the standalone task remains available when you want the exact command-line entrypoint.",
            width,
            _body_style(),
        )

    def build_source(
        self,
        mut root: ColumnView,
        parent_id: Int,
        entry: DemoEntry,
        width: Float32,
    ):
        _add_styled_label(
            root,
            parent_id,
            DEMO_PAGE_KICKER_ID,
            "READ-ONLY EXCERPT",
            18.0,
            _kicker_style(),
        )
        _add_styled_label(
            root,
            parent_id,
            DEMO_PAGE_TITLE_ID,
            "Source",
            30.0,
            _heading_style(),
        )
        _add_styled_label(
            root,
            parent_id,
            DEMO_PAGE_COMMAND_ID,
            String("File  ·  ", entry.source, "\nTask  ·  ", entry.command()),
            38.0,
            _small_style(),
        )
        root.add_multiline_text_to(
            parent_id,
            DEMO_SOURCE_TEXT_ID,
            entry.source_excerpt,
            210.0,
        )
        root.set_enabled(DEMO_SOURCE_TEXT_ID, False)
        root.set_accessibility_label(DEMO_SOURCE_TEXT_ID, "Source excerpt")
        _add_wrapped_label_styled(
            root,
            parent_id,
            DEMO_SOURCE_HINT_ID,
            "The checked-in file is the executable reference. This compact excerpt keeps the browser lightweight and deterministic; use the command above to run the complete example.",
            width,
            _body_style(),
        )

    def build_demo(
        self,
        mut root: ColumnView,
        parent_id: Int,
        entry: DemoEntry,
        width: Float32,
        height: Float32,
    ):
        var page_width = width - 24.0
        if page_width < 240.0:
            page_width = 240.0
        var page_height = height - 24.0
        if page_height < 140.0:
            page_height = 140.0

        if entry.page_kind == DEMO_PAGE_COUNTER:
            var child = self.counter.build(Rect(0.0, 0.0, page_width, page_height))
            root.add_component_view_to(
                parent_id,
                DEMO_COUNTER_SLOT_ID,
                child,
                DEMO_COUNTER_ID_OFFSET,
                page_height,
            )
            return
        if entry.page_kind == DEMO_PAGE_FORM:
            var child = self.form.build(Rect(0.0, 0.0, page_width, page_height))
            root.add_component_view_to(
                parent_id,
                DEMO_FORM_SLOT_ID,
                child,
                DEMO_FORM_ID_OFFSET,
                page_height,
            )
            return
        if entry.page_kind == DEMO_PAGE_NESTED:
            var child = self.nested.build(Rect(0.0, 0.0, page_width, page_height))
            root.add_component_view_to(
                parent_id,
                DEMO_NESTED_SLOT_ID,
                child,
                DEMO_NESTED_ID_OFFSET,
                page_height,
            )
            return
        if entry.page_kind == DEMO_PAGE_COMPOSED:
            var child = self.composed.build(Rect(0.0, 0.0, page_width, page_height))
            root.add_component_view_to(
                parent_id,
                DEMO_COMPOSED_SLOT_ID,
                child,
                DEMO_COMPOSED_ID_OFFSET,
                page_height,
            )
            return
        if entry.page_kind == DEMO_PAGE_WX_STYLE:
            var child_height: Float32 = 1080.0
            var child = self.wx_style.build(Rect(0.0, 0.0, page_width, child_height))
            root.add_component_view_to(
                parent_id,
                DEMO_WX_STYLE_SLOT_ID,
                child,
                DEMO_WX_STYLE_ID_OFFSET,
                child_height,
            )
            return
        if entry.page_kind == DEMO_PAGE_INTERACTION:
            var child = self.interaction.build(
                Rect(0.0, 0.0, page_width, page_height)
            )
            root.add_component_view_to(
                parent_id,
                DEMO_INTERACTION_SLOT_ID,
                child,
                DEMO_INTERACTION_ID_OFFSET,
                page_height,
            )
            return
        if entry.page_kind == DEMO_PAGE_ROW:
            var child = self.row.build(Rect(0.0, 0.0, page_width, page_height))
            root.add_component_view_to(
                parent_id,
                DEMO_ROW_SLOT_ID,
                child,
                DEMO_ROW_ID_OFFSET,
                page_height,
            )
            return
        if entry.page_kind == DEMO_PAGE_ALIGNMENT:
            var child = self.alignment.build(Rect(0.0, 0.0, page_width, page_height))
            root.add_component_view_to(
                parent_id,
                DEMO_ALIGNMENT_SLOT_ID,
                child,
                DEMO_ALIGNMENT_ID_OFFSET,
                page_height,
            )
            return
        if entry.page_kind == DEMO_PAGE_WRAPPED:
            var child = self.wrapped.build(Rect(0.0, 0.0, page_width, page_height))
            root.add_component_view_to(
                parent_id,
                DEMO_WRAPPED_SLOT_ID,
                child,
                DEMO_WRAPPED_ID_OFFSET,
                page_height,
            )
            return
        if entry.page_kind == DEMO_PAGE_SHOWCASE:
            var child = self.showcase.build(
                Rect(0.0, 0.0, page_width, page_height)
            )
            root.add_component_view_to(
                parent_id,
                DEMO_SHOWCASE_SLOT_ID,
                child,
                DEMO_SHOWCASE_ID_OFFSET,
                page_height,
            )
            return
        if entry.page_kind == DEMO_PAGE_FRACTAL:
            var child_height: Float32 = 1080.0
            var child = self.fractal.build(
                Rect(0.0, 0.0, page_width, child_height)
            )
            root.add_component_view_to(
                parent_id,
                DEMO_FRACTAL_SLOT_ID,
                child,
                DEMO_FRACTAL_ID_OFFSET,
                child_height,
            )
            return
        if entry.page_kind == DEMO_PAGE_LIVE_SCRIPT:
            var child = self.live_script.build(
                Rect(0.0, 0.0, page_width, page_height)
            )
            root.add_component_view_to(
                parent_id,
                DEMO_LIVE_SCRIPT_SLOT_ID,
                child,
                DEMO_LIVE_SCRIPT_ID_OFFSET,
                page_height,
            )
            return

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        """Handle browser controls before routing to the active page."""
        if self.tab == DEMO_TAB_DEMO:
            if event.kind == FRAME_TICK_KIND:
                var frame = event
                frame.set_target(-1)
                if self.selected_entry().page_kind == DEMO_PAGE_SHOWCASE:
                    return self.showcase.route(frame, view)
                if self.selected_id == DEMO_FRACTAL_ID:
                    return self.fractal.route(frame, view)
            if self.selected_id == DEMO_COUNTER_ID and self.counter.contains(event.target, view):
                return self.counter.route(event, view)
            if self.selected_id == DEMO_FORM_ID and self.form.contains(event.target, view):
                return self.form.route(event, view)
            if self.selected_id == DEMO_NESTED_ID and self.nested.contains(event.target, view):
                return self.nested.route(event, view)
            if self.selected_id == DEMO_COMPOSED_ID and self.composed.contains(event.target, view):
                return self.composed.route(event, view)
            if self.selected_id == DEMO_WX_STYLE_ID and self.wx_style.contains(event.target, view):
                return self.wx_style.route(event, view)
            if (
                self.selected_id == DEMO_INTERACTION_ID
                and event.kind == KEY_DOWN_KIND
                and self.interaction.component.popups.is_open()
            ):
                # Popup focus scopes are owned by the child scene rather than
                # the declarative parent tree. Route their keyboard stream as
                # an unscoped child event so synthetic focus ids do not get
                # rejected by ComponentSlot.contains().
                var popup_event = event
                popup_event.set_target(-1)
                return self.interaction.route(popup_event, view)
            if self.selected_id == DEMO_INTERACTION_ID and (
                self.interaction.contains(event.target, view)
                or event.kind == SCROLL_KIND
            ):
                return self.interaction.route(event, view)
            if self.selected_id == DEMO_ROW_ID and self.row.contains(event.target, view):
                return self.row.route(event, view)
            if self.selected_id == DEMO_ALIGNMENT_ID and self.alignment.contains(event.target, view):
                return self.alignment.route(event, view)
            if self.selected_id == DEMO_WRAPPED_ID and self.wrapped.contains(event.target, view):
                return self.wrapped.route(event, view)
            if self.selected_entry().page_kind == DEMO_PAGE_SHOWCASE and self.showcase.contains(event.target, view):
                return self.showcase.route(event, view)
            if self.selected_id == DEMO_FRACTAL_ID and self.fractal.contains(event.target, view):
                return self.fractal.route(event, view)
            if self.selected_entry().page_kind == DEMO_PAGE_LIVE_SCRIPT and self.live_script.contains(event.target, view):
                return self.live_script.route(event, view)

        if event.target == DEMO_SEARCH_ID:
            if event.kind == COMPOSITION_UPDATE_KIND:
                self.search.set_composition(
                    event.text,
                    event.selection_start,
                    event.selection_end,
                )
                return True
            if event.kind == COMPOSITION_END_KIND:
                if not self.search.has_composition():
                    return False
                self.search.clear_composition()
                return True
            if event.kind == TEXT_INPUT_KIND:
                if event.replacement_start >= 0 and event.replacement_end >= 0:
                    var changed = self.search.replace_text_range(
                        event.text,
                        event.replacement_start,
                        event.replacement_end,
                    )
                    if changed:
                        self._select_first_visible()
                    return changed
                else:
                    var changed = self.search.insert_text(event.text)
                    if changed:
                        self._select_first_visible()
                    return changed
            if event.kind == KEY_DOWN_KIND:
                if event.key == KEY_ESCAPE and not self.search.has_composition():
                    return self.clear_search()
                return self.search.handle_key(event.key, event.modifiers)

        if _is_activation(event):
            if event.target == DEMO_CLEAR_SEARCH_ID:
                return self.clear_search()

            if event.target == DEMO_EMPTY_CLEAR_ID:
                return self.clear_search()

            if event.target >= DEMO_ENTRY_VIEW_BASE and event.target < DEMO_ENTRY_VIEW_BASE + 100:
                var id = event.target - DEMO_ENTRY_VIEW_BASE
                var catalog = DemoCatalog()
                if catalog.index_for_id(id) >= 0 and self.selected_id != id:
                    self.selected_id = id
                    self._activate_entry(id)
                    self.tab = DEMO_TAB_OVERVIEW
                    self.status = String("Selected ", catalog.entry(catalog.index_for_id(id)).name, ".")
                    return True
                return False

            if event.target >= DEMO_CATEGORY_BUTTON_BASE and event.target < DEMO_CATEGORY_BUTTON_BASE + 100:
                var next_category = event.target - DEMO_CATEGORY_BUTTON_BASE
                if next_category >= DEMO_CATEGORY_ALL and next_category <= DEMO_CATEGORY_TEXT:
                    if self.category != next_category:
                        self.category = next_category
                        self._select_first_visible()
                        self.status = String("Showing ", demo_category_name(next_category), ".")
                        return True
                return False

            if event.target == DEMO_TAB_OVERVIEW_ID:
                if self.tab != DEMO_TAB_OVERVIEW:
                    self.tab = DEMO_TAB_OVERVIEW
                    return True
                return False
            if event.target == DEMO_TAB_SOURCE_ID:
                if self.tab != DEMO_TAB_SOURCE:
                    self.tab = DEMO_TAB_SOURCE
                    return True
                return False
            if event.target == DEMO_TAB_DEMO_ID:
                if self.tab != DEMO_TAB_DEMO:
                    self.tab = DEMO_TAB_DEMO
                    self.status = String("Inspecting ", self.selected_entry().name, " in the browser.")
                    return True
                return False

            if event.target == DEMO_RUN_BUTTON_ID:
                var entry = self.selected_entry()
                if self.task_running and not entry.in_process:
                    self.status = "A standalone task is already running."
                    return True
                if entry.in_process:
                    self.tab = DEMO_TAB_DEMO
                    self.status = String("Running ", entry.name, " as a typed in-process component.")
                else:
                    self.tab = DEMO_TAB_DEMO
                    self.pending_task = entry.task
                    self.status = String("Launching ", entry.command(), " …")
                return True

            if event.target == DEMO_RESET_BUTTON_ID:
                self._reset_active()
                self.status = String("Reset ", self.selected_entry().name, ".")
                return True

        return False

    def clipboard_copy(mut self, target: Int, view: ColumnView) -> String:
        if target == DEMO_SEARCH_ID:
            var copied = self.search.selected_text()
            self.search.clipboard = copied
            return copied
        if self.tab == DEMO_TAB_DEMO:
            if self.selected_id == DEMO_FORM_ID and self.form.contains(target, view):
                return self.form.clipboard_copy(target, view)
            if self.selected_id == DEMO_NESTED_ID and self.nested.contains(target, view):
                return self.nested.clipboard_copy(target, view)
            if self.selected_id == DEMO_WX_STYLE_ID and self.wx_style.contains(target, view):
                return self.wx_style.clipboard_copy(target, view)
        return ""

    def clipboard_cut(mut self, target: Int, view: ColumnView) -> String:
        if target == DEMO_SEARCH_ID:
            var changed = self.search.cut_selection()
            if changed:
                self._select_first_visible()
            return self.search.clipboard
        if self.tab == DEMO_TAB_DEMO:
            if self.selected_id == DEMO_FORM_ID and self.form.contains(target, view):
                return self.form.clipboard_cut(target, view)
            if self.selected_id == DEMO_NESTED_ID and self.nested.contains(target, view):
                return self.nested.clipboard_cut(target, view)
            if self.selected_id == DEMO_WX_STYLE_ID and self.wx_style.contains(target, view):
                return self.wx_style.clipboard_cut(target, view)
        return ""

    def clipboard_paste(
        mut self,
        target: Int,
        text: String,
        view: ColumnView,
    ) -> Bool:
        if target == DEMO_SEARCH_ID:
            var changed = self.search.insert_text(text)
            if changed:
                self._select_first_visible()
            return changed
        if self.tab == DEMO_TAB_DEMO:
            if self.selected_id == DEMO_FORM_ID and self.form.contains(target, view):
                return self.form.clipboard_paste(target, text, view)
            if self.selected_id == DEMO_NESTED_ID and self.nested.contains(target, view):
                return self.nested.clipboard_paste(target, text, view)
            if self.selected_id == DEMO_WX_STYLE_ID and self.wx_style.contains(target, view):
                return self.wx_style.clipboard_paste(target, text, view)
        return False
