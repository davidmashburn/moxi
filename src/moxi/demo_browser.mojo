"""WxPython-inspired browser for Moxi's runnable examples.

The browser is deliberately a component rather than a second application
runtime.  It keeps the demo inventory as data, mounts the stateful component
examples in-process, and makes the standalone command the source of truth for
headless, GPU, text, and plot examples that do not have a widget tree.
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
    KEY_DOWN_KIND,
    KEY_ENTER,
    KEY_SPACE,
    TEXT_INPUT_KIND,
)
from .form import FormState
from .geometry import Rect
from .layout import ALIGN_STRETCH, JUSTIFY_START
from .nested import NestedState
from .row import RowState
from .style import Color, default_button_style, default_surface_style
from .view import ColumnView
from .wrapped import WrappedTextState
from .wxstyle import WxStyleState


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
comptime DEMO_METAL_SCENE_ID = 15
comptime DEMO_METAL_WINDOW_ID = 16
comptime DEMO_CORETEXT_ID = 17
comptime DEMO_HARFBUZZ_ID = 18

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
comptime DEMO_ENTRY_VIEW_BASE = 1000
comptime DEMO_CATEGORY_BUTTON_BASE = 2000
comptime DEMO_CATEGORY_LABEL_BASE = 2100
comptime DEMO_HEADER_ID = 3000
comptime DEMO_TITLE_ID = 3001
comptime DEMO_METADATA_ID = 3002
comptime DEMO_HEADER_TITLE_ID = 3003
comptime DEMO_HEADER_METADATA_ID = 3004
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
comptime DEMO_SOURCE_TEXT_ID = 3050
comptime DEMO_SOURCE_HINT_ID = 3051
comptime DEMO_CONTRACT_TITLE_ID = 3060
comptime DEMO_CONTRACT_BODY_ID = 3061

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


def _active_text(label: String, selected: Bool) -> String:
    if selected:
        return String("[", label, "]")
    return label


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
    """Add a width-aware label to an overview/source page."""
    var node = LabelControl(id, text, 0.0).node()
    node.set_wrap_text()
    root.add_to(parent_id, node)
    root.set_preferred_width(id, width)
    root.set_intrinsic_height(id)


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
        self.entries = List[DemoEntry](capacity=18)
        self.entries.append(DemoEntry(
            DEMO_HELLO_WINDOW_ID,
            "Hello Window",
            DEMO_CATEGORY_START,
            "The smallest native window and renderer loop.",
            "examples/hello_window.mojo",
            "hello-window-demo",
            DEMO_PAGE_STATIC,
            False,
            "from moxi import Label, Rect, Runtime\n\nvar runtime = Runtime()",
        ))
        self.entries.append(DemoEntry(
            DEMO_HELLO_COMPONENT_ID,
            "Hello Component",
            DEMO_CATEGORY_START,
            "A minimal Component and App lifecycle with a declarative label.",
            "examples/hello_component.mojo",
            "component-demo",
            DEMO_PAGE_STATIC,
            False,
            "struct GreetingComponent(Component):\n    def build(self, bounds: Rect) -> ColumnView:",
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
            DEMO_PAGE_STATIC,
            False,
            "var slide = Animation(0.0, 240.0, 1.0, EASE_IN_OUT)\nslide.advance(0.25)\ninvalidation.invalidate(...)",
        ))
        self.entries.append(DemoEntry(
            DEMO_PLOT_ID,
            "Plot Scene",
            DEMO_CATEGORY_PLOTTING,
            "A portable line/scatter scene with hit testing and software rendering.",
            "examples/plot.mojo",
            "plot-demo",
            DEMO_PAGE_STATIC,
            False,
            "var plot = make_plot_scenario(bounds)\nvar scene = plot.build_scene()\nrenderer.render_scene(scene)",
        ))
        self.entries.append(DemoEntry(
            DEMO_PLOT_GALLERY_ID,
            "Plot Gallery",
            DEMO_CATEGORY_PLOTTING,
            "Typed data, encodings, facets, statistical recipes, and interactions.",
            "examples/plot_gallery.mojo",
            "plot-gallery",
            DEMO_PAGE_STATIC,
            False,
            "var spec = PlotSpec(\"Telemetry gallery\")\n_ = spec.add_hover(True, True)\n_ = spec.add_brush()",
        ))
        self.entries.append(DemoEntry(
            DEMO_PLOT_SVG_ID,
            "Plot SVG Export",
            DEMO_CATEGORY_PLOTTING,
            "Serialize the shared scene into browser-compatible SVG markup.",
            "examples/plot_svg.mojo",
            "plot-svg",
            DEMO_PAGE_STATIC,
            False,
            "var renderer = SvgSceneRenderer(640, 420)\nrenderer.render_scene(scene)\nprint(renderer.markup())",
        ))
        self.entries.append(DemoEntry(
            DEMO_METAL_SCENE_ID,
            "Metal Scene",
            DEMO_CATEGORY_RENDERING,
            "Offscreen GPU scene rendering with deterministic checksum output.",
            "examples/metal_scene.mojo",
            "metal-demo",
            DEMO_PAGE_STATIC,
            False,
            "var renderer = MacOSMetalRenderer(320, 220)\nrenderer.render_scene(scene)\nprint(renderer.checksum())",
        ))
        self.entries.append(DemoEntry(
            DEMO_METAL_WINDOW_ID,
            "Metal Window",
            DEMO_CATEGORY_RENDERING,
            "A visible CAMetalLayer window consuming the scene contract.",
            "examples/metal_window.mojo",
            "metal-window-demo",
            DEMO_PAGE_STATIC,
            False,
            "var window = MacOSMetalWindow()\nwindow.open(WindowConfig(\"Moxi Metal scene\", 640.0, 420.0))",
        ))
        self.entries.append(DemoEntry(
            DEMO_CORETEXT_ID,
            "CoreText Shaping",
            DEMO_CATEGORY_TEXT,
            "Native shaped runs for Unicode, bidi, and fallback-face metadata.",
            "examples/coretext.mojo",
            "text-demo",
            DEMO_PAGE_STATIC,
            False,
            "var shaper = MacOSTextShaper()\nvar result = shaper.shape(\"Moxi • שלום • 🙂\", style, 0.0, 1)",
        ))
        self.entries.append(DemoEntry(
            DEMO_HARFBUZZ_ID,
            "HarfBuzz Shaping",
            DEMO_CATEGORY_TEXT,
            "Optional OpenType shaping through the host-linked HarfBuzz adapter.",
            "examples/harfbuzz.mojo",
            "harfbuzz-demo",
            DEMO_PAGE_STATIC,
            False,
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

    var counter: ComponentSlot[CounterState]
    var form: ComponentSlot[FormState]
    var nested: ComponentSlot[NestedState]
    var composed: ComponentSlot[ComposedState]
    var wx_style: ComponentSlot[WxStyleState]
    var row: ComponentSlot[RowState]
    var alignment: ComponentSlot[AlignmentState]
    var wrapped: ComponentSlot[WrappedTextState]

    def __init__(out self):
        self.search = TextInputState()
        self.category = DEMO_CATEGORY_ALL
        self.selected_id = DEMO_HELLO_WINDOW_ID
        self.tab = DEMO_TAB_OVERVIEW
        self.status = "Ready. Select a demo to inspect its overview, source, or live page."
        self.pending_task = ""
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
        self.row = ComponentSlot[RowState](
            RowState(), DEMO_ROW_SLOT_ID, DEMO_ROW_ID_OFFSET
        )
        self.alignment = ComponentSlot[AlignmentState](
            AlignmentState(), DEMO_ALIGNMENT_SLOT_ID, DEMO_ALIGNMENT_ID_OFFSET
        )
        self.wrapped = ComponentSlot[WrappedTextState](
            WrappedTextState(), DEMO_WRAPPED_SLOT_ID, DEMO_WRAPPED_ID_OFFSET
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

    def take_pending_task(mut self) -> String:
        """Take one standalone task request produced by the Run action."""
        var task = self.pending_task
        self.pending_task = ""
        return task

    def set_task_result(mut self, task: String, launched: Bool):
        """Record the host result after attempting a catalog task launch."""
        if launched:
            self.status = String("Launched pixi run ", task, ".")
        else:
            self.status = String(
                "Could not launch pixi run ", task,
                "; it may already be running or unavailable.",
            )

    def set_task_completion(mut self, task: String, status_code: Int):
        """Record the terminal status of a standalone task."""
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
                self.tab = DEMO_TAB_OVERVIEW
                return

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
        elif self.selected_id == DEMO_ROW_ID:
            self.row.component = RowState()
        elif self.selected_id == DEMO_ALIGNMENT_ID:
            self.alignment.component = AlignmentState()
        elif self.selected_id == DEMO_WRAPPED_ID:
            self.wrapped.component = WrappedTextState()

    def build(self, bounds: Rect) -> ColumnView:
        """Build the browser shell and the selected page."""
        var root = ColumnView(bounds, 12.0, 0.0)
        root.set_surface_style(default_surface_style())
        root.set_clip_to_bounds()
        root.set_row_layout()

        var nav = root.add_column(DEMO_NAV_ID, 0.0, 14.0, 8.0)
        var main = root.add_column(DEMO_MAIN_ID, 0.0, 20.0, 10.0)
        root.set_fixed_width(nav, 320.0)
        root.set_container_alignment(nav, JUSTIFY_START, ALIGN_STRETCH)
        root.set_container_alignment(main, JUSTIFY_START, ALIGN_STRETCH)

        root.add_label_to(nav, DEMO_TITLE_ID, "Moxi Demo Browser", 32.0)
        root.add_label_to(
            nav,
            DEMO_METADATA_ID,
            "Search examples, then run a live page or its checked-in script.",
            38.0,
        )
        var search = TextInputControl(
            DEMO_SEARCH_ID,
            self.search.text,
            self.search.cursor,
            self.search.anchor,
            38.0,
        )
        root.add_to(nav, search.node())
        root.set_accessibility_label(DEMO_SEARCH_ID, "Search demos")
        root.set_accessibility_hint(
            DEMO_SEARCH_ID,
            "Search names, descriptions, source paths, or tasks",
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

        root.add_label_to(
            nav,
            DEMO_NAV_COUNT_ID,
            String(self.visible_count(), " demos visible"),
            24.0,
        )

        var nav_height = bounds.height - 206.0
        if nav_height < 120.0:
            nav_height = 120.0
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
        var catalog = DemoCatalog()
        for index in range(catalog.count()):
            if not catalog.matches(index, self.search.text, self.category):
                continue
            var item = catalog.entry(index)
            if item.category != last_category:
                root.add_label_to(
                    nav_portal,
                    DEMO_CATEGORY_LABEL_BASE + item.category,
                    demo_category_name(item.category),
                    24.0,
                )
                last_category = item.category
            var item_id = DEMO_ENTRY_VIEW_BASE + item.id
            var item_text = item.name
            if item.id == self.selected_id:
                item_text = String("› ", item.name)
            var item_style = default_button_style()
            if item.id == self.selected_id:
                item_style.fill = Color(0.10, 0.34, 0.62, 1.0)
                item_style.border = Color(0.35, 0.74, 1.0, 1.0)
                item_style.border_width = 1.0
            var item_button = ButtonControl(item_id, item_text, 32.0, item_style)
            root.add_to(nav_portal, item_button.node())
            root.set_accessibility_label(item_id, item.name)
            root.set_accessibility_value(item_id, item.summary)
            added += 1
        if added == 0:
            _add_wrapped_label(
                root,
                nav_portal,
                DEMO_CATEGORY_BUTTON_BASE + 100,
                "No demos match this filter. Clear search or choose All.",
                260.0,
            )

        var entry = self.selected_entry()
        var header = root.add_column_to(main, DEMO_HEADER_ID, 70.0, 0.0, 4.0)
        root.add_label_to(header, DEMO_HEADER_TITLE_ID, entry.name, 32.0)
        root.add_label_to(
            header,
            DEMO_HEADER_METADATA_ID,
            String(demo_category_name(entry.category), " · ", entry.source),
            24.0,
        )

        var tabs = root.add_row_to(main, DEMO_TABS_ID, 0.0, 38.0, 0.0, 6.0)
        self.add_tab_button(root, tabs, DEMO_TAB_OVERVIEW, "Overview", DEMO_TAB_OVERVIEW_ID)
        self.add_tab_button(root, tabs, DEMO_TAB_SOURCE, "Source", DEMO_TAB_SOURCE_ID)
        self.add_tab_button(root, tabs, DEMO_TAB_DEMO, "Demo", DEMO_TAB_DEMO_ID)

        var toolbar = root.add_row_to(main, DEMO_TOOLBAR_ID, 0.0, 42.0, 0.0, 8.0)
        var run_text = "Run script"
        if entry.in_process:
            run_text = "Run in browser"
        root.add_button_to(toolbar, DEMO_RUN_BUTTON_ID, run_text, 34.0)
        root.set_intrinsic_width(DEMO_RUN_BUTTON_ID)
        root.add_button_to(toolbar, DEMO_RESET_BUTTON_ID, "Reset", 34.0)
        root.set_intrinsic_width(DEMO_RESET_BUTTON_ID)
        root.add_flexible_spacer_to(toolbar, DEMO_TOOLBAR_SPACER_ID)
        var run_info = "standalone task"
        if entry.in_process:
            run_info = "typed component"
        root.add_label_to(toolbar, DEMO_RUN_INFO_ID, run_info, 26.0)

        var content_height = bounds.height - 190.0
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
            self.build_overview(root, content, entry, bounds.width - 370.0)
        elif self.tab == DEMO_TAB_SOURCE:
            self.build_source(root, content, entry, bounds.width - 370.0)
        else:
            self.build_demo(root, content, entry, bounds.width - 370.0, content_height)
        root.add_label_to(main, DEMO_STATUS_ID, self.status, 30.0)
        root.set_accessibility_label(DEMO_STATUS_ID, "Demo browser status")
        root.set_accessibility_value(DEMO_STATUS_ID, self.status)

        root.layout()
        return root^

    def add_category_button(
        self,
        mut root: ColumnView,
        parent_id: Int,
        category: Int,
    ):
        var label = demo_category_short_name(category)
        label = _active_text(label, self.category == category)
        var style = default_button_style()
        if self.category == category:
            style.fill = Color(0.10, 0.34, 0.62, 1.0)
        var button = ButtonControl(
            DEMO_CATEGORY_BUTTON_BASE + category,
            label,
            28.0,
            style,
        )
        root.add_to(parent_id, button.node())
        root.set_fixed_width(DEMO_CATEGORY_BUTTON_BASE + category, 62.0)

    def add_tab_button(
        self,
        mut root: ColumnView,
        parent_id: Int,
        tab: Int,
        label: String,
        id: Int,
    ):
        var style = default_button_style()
        if self.tab == tab:
            style.fill = Color(0.10, 0.34, 0.62, 1.0)
        var button = ButtonControl(id, _active_text(label, self.tab == tab), 34.0, style)
        root.add_to(parent_id, button.node())
        root.set_fixed_width(id, 118.0)

    def build_overview(
        self,
        mut root: ColumnView,
        parent_id: Int,
        entry: DemoEntry,
        width: Float32,
    ):
        root.add_label_to(parent_id, DEMO_PAGE_TITLE_ID, "Overview", 30.0)
        _add_wrapped_label(root, parent_id, DEMO_PAGE_BODY_ID, entry.summary, width)
        root.add_label_to(
            parent_id,
            DEMO_PAGE_COMMAND_ID,
            String("Runnable command: ", entry.command()),
            30.0,
        )
        root.add_label_to(
            parent_id,
            DEMO_PAGE_CANVAS_ID,
            String("Source: ", entry.source),
            28.0,
        )
        var usage = "Select Demo to mount the stateful page in this browser."
        if not entry.in_process:
            usage = "Run script launches the checked-in Pixi task as a sibling process."
        _add_wrapped_label(
            root,
            parent_id,
            DEMO_SOURCE_HINT_ID,
            usage,
            width,
        )
        root.add_label_to(
            parent_id,
            DEMO_CONTRACT_TITLE_ID,
            "The browser contract",
            28.0,
        )
        _add_wrapped_label(
            root,
            parent_id,
            DEMO_CONTRACT_BODY_ID,
            "Every catalog item names a real examples/ script and a Pixi task. Component pages share the same value-based App and event-routing contracts as their standalone scripts; scene, plot, GPU, and text examples retain their own deterministic command-line entrypoints.",
            width,
        )

    def build_source(
        self,
        mut root: ColumnView,
        parent_id: Int,
        entry: DemoEntry,
        width: Float32,
    ):
        root.add_label_to(parent_id, DEMO_PAGE_TITLE_ID, "Source", 30.0)
        root.add_label_to(
            parent_id,
            DEMO_PAGE_COMMAND_ID,
            String("File: ", entry.source, " · Task: ", entry.command()),
            28.0,
        )
        root.add_multiline_text_to(
            parent_id,
            DEMO_SOURCE_TEXT_ID,
            entry.source_excerpt,
            210.0,
        )
        root.set_enabled(DEMO_SOURCE_TEXT_ID, False)
        root.set_accessibility_label(DEMO_SOURCE_TEXT_ID, "Source excerpt")
        _add_wrapped_label(
            root,
            parent_id,
            DEMO_SOURCE_HINT_ID,
            "The source path and task are part of the catalog metadata. The checked-in file is the executable reference; this compact excerpt keeps the browser lightweight and deterministic.",
            width,
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

        # Non-widget examples keep their real standalone script as the
        # executable surface, while the browser gives them a useful preview
        # card and a canvas-shaped semantic affordance.
        var page = root.add_column_to(
            parent_id,
            DEMO_PAGE_CONTAINER_ID,
            page_height,
            14.0,
            8.0,
        )
        root.add_label_to(page, DEMO_PAGE_TITLE_ID, entry.name, 30.0)
        _add_wrapped_label(root, page, DEMO_PAGE_BODY_ID, entry.summary, page_width)
        root.add_canvas_to(
            page,
            DEMO_PAGE_CANVAS_ID,
            String("Preview surface · ", demo_category_name(entry.category)),
            180.0,
        )
        root.add_label_to(
            page,
            DEMO_PAGE_COMMAND_ID,
            String("Run this script: ", entry.command()),
            30.0,
        )
        _add_wrapped_label(
            root,
            page,
            DEMO_SOURCE_HINT_ID,
            "This entry is intentionally not reimplemented as a fake widget page. Its standalone script is the runnable reference and can be inspected from Source.",
            page_width,
        )

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        """Handle browser controls before routing to the active page."""
        if self.tab == DEMO_TAB_DEMO:
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
            if self.selected_id == DEMO_ROW_ID and self.row.contains(event.target, view):
                return self.row.route(event, view)
            if self.selected_id == DEMO_ALIGNMENT_ID and self.alignment.contains(event.target, view):
                return self.alignment.route(event, view)
            if self.selected_id == DEMO_WRAPPED_ID and self.wrapped.contains(event.target, view):
                return self.wrapped.route(event, view)

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
                return self.search.handle_key(event.key, event.modifiers)

        if _is_activation(event):
            if event.target >= DEMO_ENTRY_VIEW_BASE and event.target < DEMO_ENTRY_VIEW_BASE + 100:
                var id = event.target - DEMO_ENTRY_VIEW_BASE
                var catalog = DemoCatalog()
                if catalog.index_for_id(id) >= 0 and self.selected_id != id:
                    self.selected_id = id
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
            _ = self.search.cut_selection()
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
            return self.search.insert_text(text)
        if self.tab == DEMO_TAB_DEMO:
            if self.selected_id == DEMO_FORM_ID and self.form.contains(target, view):
                return self.form.clipboard_paste(target, text, view)
            if self.selected_id == DEMO_NESTED_ID and self.nested.contains(target, view):
                return self.nested.clipboard_paste(target, text, view)
            if self.selected_id == DEMO_WX_STYLE_ID and self.wx_style.contains(target, view):
                return self.wx_style.clipboard_paste(target, text, view)
        return False
