"""The demo browser catalog: `DemoEntry` metadata and the `DemoCatalog` registry."""


from std.collections import List


from moxi.scenarios import SCENARIO_NONE, canonical_scenarios
from .demo_style import (
    _contains_insensitive,
    DEMO_ALIGNMENT_ID,
    DEMO_ANIMATION_ID,
    DEMO_CAPABILITY_WALKTHROUGH_ID,
    DEMO_CATEGORY_ALL,
    DEMO_CATEGORY_COMPONENTS,
    DEMO_CATEGORY_LAYOUT,
    DEMO_CATEGORY_PLOTTING,
    DEMO_CATEGORY_RENDERING,
    DEMO_CATEGORY_START,
    DEMO_CATEGORY_TEXT,
    DEMO_COMPOSED_ID,
    DEMO_CORETEXT_ID,
    DEMO_COUNTER_ID,
    DEMO_FORM_ID,
    DEMO_FRACTAL_ID,
    DEMO_HARFBUZZ_ID,
    DEMO_HELLO_COMPONENT_ID,
    DEMO_HELLO_WINDOW_ID,
    DEMO_INTERACTION_ID,
    DEMO_LIVE_SCRIPT_ID,
    DEMO_METAL_SCENE_ID,
    DEMO_METAL_WINDOW_ID,
    DEMO_NESTED_ID,
    DEMO_PAGE_ALIGNMENT,
    DEMO_PAGE_CAPABILITY_WALKTHROUGH,
    DEMO_PAGE_COMPOSED,
    DEMO_PAGE_COUNTER,
    DEMO_PAGE_FORM,
    DEMO_PAGE_FRACTAL,
    DEMO_PAGE_INTERACTION,
    DEMO_PAGE_LIVE_SCRIPT,
    DEMO_PAGE_NESTED,
    DEMO_PAGE_ROW,
    DEMO_PAGE_SHOWCASE,
    DEMO_PAGE_THEME_SHOWCASE,
    DEMO_PAGE_WRAPPED,
    DEMO_PAGE_WX_STYLE,
    DEMO_PLOT_GALLERY_ID,
    DEMO_PLOT_ID,
    DEMO_PLOT_SVG_ID,
    DEMO_ROW_ID,
    DEMO_THEME_SHOWCASE_ID,
    DEMO_WRAPPED_ID,
    DEMO_WX_STYLE_ID,
)


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
            "struct HelloWindow(Component):\n    def build(self, bounds: Rect) -> ColumnView:\n        var root = ColumnView(bounds, 24.0, 12.0)\n        root.add_label(1, \"Hello from Moxi\", 36.0)\n        root.add_label(2, \"This view is built by a Component.\", 0.0)\n        root.layout()\n        return root^\n\nvar app = App[HelloWindow](HelloWindow(), bounds)\napp.run(window, renderer)",
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
            "struct HelloComponent(Component):\n    def build(self, bounds: Rect) -> ColumnView:\n        var root = ColumnView(bounds, 24.0, 12.0)\n        root.add_label(1, \"A reusable Moxi component\", 34.0)\n        root.add_label(2, \"The host owns the window.\", 0.0)\n        root.layout()\n        return root^\n\nvar app = App[HelloComponent](HelloComponent(), bounds)\napp.run(window, renderer)",
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
            "struct CounterState(Component):\n    var count: Int\n\n    def build(self, bounds: Rect) -> ColumnView:\n        var view = make_counter_column(self.count, bounds)\n        view.set_action(3, COUNTER_INCREMENT_ACTION)\n        return view^\n\n    def update(mut self, event: Event, view: ColumnView) -> Bool:\n        if event.target == 3 and event.kind == CLICK_KIND:\n            self.count += 1\n            return True\n        return False",
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
            "struct FormState(Component):\n    var input: TextInputState\n\n    def build(self, bounds: Rect) -> ColumnView:\n        var root = ColumnView(bounds, 32.0, 8.0)\n        var input = TextInputControl(2, self.input.text, self.input.cursor, self.input.anchor, 44.0)\n        root.add(input.node())\n        root.add_label(3, String(\"Submitted: \", self.submissions), 28.0)\n        root.add_button(4, \"Submit\", 40.0)\n        root.layout()\n        return root^",
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
            "struct NestedState(Component):\n    def build(self, bounds: Rect) -> ColumnView:\n        var root = ColumnView(bounds, 16.0, 12.0)\n        var content = root.add_column(10, 150.0, 8.0, 6.0)\n        root.add_to(content, TextInputControl(12, \"Nested\", 0, 0, 40.0).node())\n        var actions = root.add_row(20, 0.0, 48.0, 8.0, 8.0)\n        root.add_button_to(actions, 21, \"One\", 32.0)\n        root.add_button_to(actions, 22, \"Two\", 32.0)\n        root.layout()\n        return root^",
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
            "struct ComposedState(Component):\n    var counter: ComponentSlot[CounterState]\n\n    def build(self, bounds: Rect) -> ColumnView:\n        var child_bounds = Rect(bounds.x + 32.0, bounds.y + 72.0, bounds.width - 64.0, bounds.height - 88.0)\n        var child = self.counter.build(child_bounds)\n        root.add_component_view_to(-1, 10, child, 1000)\n        root.layout()\n        return root^",
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
            "struct WxStyleState(Component):\n    def build(self, bounds: Rect) -> ColumnView:\n        var root = ColumnView(bounds, 24.0, 12.0)\n        var frame = root.add_column(WX_PANEL_ID, 0.0, 12.0, 8.0)\n        root.add_label_to(frame, WX_TITLE_ID, \"Moxi Frame\", 34.0)\n        root.add_button_to(frame, WX_OK_BUTTON_ID, \"OK\", 34.0)\n        root.layout()\n        return root^\n\nvar app = App[WxStyleState](WxStyleState(), bounds)",
        ))
        self.entries.append(DemoEntry(
            DEMO_THEME_SHOWCASE_ID,
            "Theme & Recipe Showcase",
            DEMO_CATEGORY_COMPONENTS,
            "Token-driven palettes, shadcn-style recipes, and live theme switching.",
            "examples/theme_showcase.mojo",
            "theme-showcase-demo",
            DEMO_PAGE_THEME_SHOWCASE,
            True,
            "struct ThemeShowcaseState(Component):\n    def build(self, bounds: Rect) -> ColumnView:\n        var tokens = self.current_tokens()\n        var view = ColumnView(bounds, tokens.spacing.space_lg, tokens.spacing.space_md)\n        view.set_theme(theme_from_tokens(tokens))\n        view.add_to(2100, primary_button(20, \"Primary\", 34.0, 5, tokens))\n        view.layout()\n        return view^",
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
            "struct InteractionShowcaseState(Component):\n    def build(self, bounds: Rect) -> ColumnView:\n        var root = ColumnView(bounds, 16.0, 10.0)\n        root.add_label(11, \"Collection & interaction lab\", 34.0)\n        root.add_canvas(1, \"Interactive collection canvas\", bounds.height - 100.0)\n        root.layout()\n        return root^\n\nvar app = App[InteractionShowcaseState](InteractionShowcaseState(), bounds)",
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
            "struct EditableShowcase(Component):\n    def build(self, bounds: Rect) -> ColumnView:\n        var root = ColumnView(bounds, 22.0, 10.0)\n        root.add_label(1, \"Editable component\", 34.0)\n        root.add_canvas(3, \"Editable scene canvas\", bounds.height - 120.0)\n        root.layout()\n        return root^\n\n@export\ndef moxi_live_frame(x, y, width, height) abi(\"C\") -> Int32:",
        ))
        self.entries.append(DemoEntry(
            DEMO_CAPABILITY_WALKTHROUGH_ID,
            "Capability Bus Walkthrough",
            DEMO_CATEGORY_COMPONENTS,
            "A ten-step interactive lesson that routes UI and agent actions through CapabilityBus.",
            "examples/capability_bus.mojo",
            "capability-bus-demo",
            DEMO_PAGE_CAPABILITY_WALKTHROUGH,
            True,
            "struct CapabilityWalkthroughState(Component):\n    var bus: CapabilityBus\n    var step: Int\n\n    def build(self, bounds: Rect) -> ColumnView:\n        var root = ColumnView(bounds, 20.0, 12.0)\n        root.add_label(1, self.step_title(), 30.0)\n        root.add_progress(4, \"Walkthrough progress\", Float32(self.step + 1) / 10.0, 32.0)\n        root.add_button(6, \"Next\", 40.0)\n        root.layout()\n        return root^\n\n    def update(mut self, event: Event, view: ColumnView) -> Bool:\n        var request = CapabilityInvocation(\"next-1\", \"walkthrough.next\", CALLER_UI, \"{}\")\n        var result = self.bus.invoke_handler(self.next_handler, request)\n        if result.completed():\n            self.step += 1\n        return result.completed()\n\n    def approve_agent_reset(mut self, request: CapabilityInvocation):\n        var approval = self.bus.issue_approval(request, \"capability-walkthrough-confirmation\")\n        request.set_approval(approval)\n\nvar app = App[CapabilityWalkthroughState](CapabilityWalkthroughState(), bounds)",
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
            "struct RowState(Component):\n    def build(self, bounds: Rect) -> ColumnView:\n        var row = make_row(bounds, 24.0, 16.0)\n        row.add(ButtonControl(1, \"Previous\", 44.0).node())\n        row.add_spacer(2, 32.0)\n        row.add(ButtonControl(3, \"Next\", 44.0).node())\n        row.layout()\n        return row^",
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
            "struct AlignmentState(Component):\n    def build(self, bounds: Rect) -> ColumnView:\n        var column = ColumnView(bounds, 24.0, 10.0)\n        column.add_button(2, \"Start\", 40.0)\n        column.add_button(3, \"Center\", 40.0)\n        column.add_button(4, \"End\", 40.0)\n        column.set_main_alignment(JUSTIFY_CENTER)\n        column.set_cross_alignment(ALIGN_CENTER)\n        column.layout()\n        return column^",
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
            "struct WrappedTextState(Component):\n    def build(self, bounds: Rect) -> ColumnView:\n        var column = ColumnView(bounds, 24.0, 12.0)\n        column.add_label(1, \"Moxi Text Layout\", 30.0)\n        column.add_label(2, \"Resize to reflow this text.\", 0.0)\n        column.set_wrap(2)\n        column.set_intrinsic_height(2)\n        column.layout()\n        return column^",
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
            "struct AnimationDemo(Component):\n    var animation = Animation(0.0, 1.0, 1.0, EASE_IN_OUT)\n\n    def build(self, bounds: Rect) -> ColumnView:\n        var root = ColumnView(bounds, 24.0, 12.0)\n        root.add_progress(1, \"Frame\", self.animation.progress(), 36.0)\n        root.add_button(2, \"Restart animation\", 36.0)\n        root.layout()\n        return root^\n\nvar app = App[AnimationDemo](AnimationDemo(), bounds)\napp.tick(0.25)",
        ))
        self.entries.append(DemoEntry(
            DEMO_PLOT_ID,
            "Plot Scene",
            DEMO_CATEGORY_PLOTTING,
            "A live line/scatter scene with hover, selection, pan/zoom, and source updates.",
            "examples/plot.mojo",
            "plot-demo",
            DEMO_PAGE_SHOWCASE,
            True,
            "struct PlotDemo(Component):\n    def build(self, bounds: Rect) -> ColumnView:\n        var root = ColumnView(bounds, 20.0, 10.0)\n        root.add_canvas(1, \"Plot scene\", bounds.height - 100.0)\n        root.layout()\n        return root^\n\n    def scene(self, bounds: Rect) -> Scene:\n        var plot = make_plot_scenario(bounds)\n        return plot.build_scene()",
        ))
        self.entries.append(DemoEntry(
            DEMO_PLOT_GALLERY_ID,
            "Plot Gallery",
            DEMO_CATEGORY_PLOTTING,
            "Typed data, facets, linked selection, and reactive interactions.",
            "examples/plot_gallery.mojo",
            "plot-gallery",
            DEMO_PAGE_SHOWCASE,
            True,
            "var data = make_plot_data_fixture()\nvar spec = PlotSpec(\"Telemetry gallery\")\nvar line = spec.add_line(\"signal\", \"time\", \"value\", color)\n_ = spec.encode(line, CHANNEL_COLOR, \"series\", TYPE_NOMINAL)\nspec.set_scale(CHANNEL_X, SCALE_TEMPORAL)\nspec.set_facet(\"region\")\nvar view = PlotView(spec, data, bounds)\nrenderer.render_scene(view.build_scene())",
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
            "struct PlotSvgDemo(Component):\n    def scene(self, bounds: Rect) -> Scene:\n        var plot = make_plot_scenario(bounds)\n        plot.set_title(\"SVG export scene\")\n        return plot.build_scene()\n\nvar app = App[PlotSvgDemo](PlotSvgDemo(), bounds)\nvar scene = app.component.scene(bounds)\nrenderer.render_scene(scene)",
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
            "struct FractalState(Component):\n    def build(self, bounds: Rect) -> ColumnView:\n        var root = ColumnView(bounds, 16.0, 10.0)\n        root.add_canvas(FRACTAL_CANVAS_ID, \"Interactive line fractal\", 720.0)\n        root.layout()\n        return root^\n\nvar app = App[FractalState](FractalState(), bounds)\napp.component.advance_render()\napp.component.paint_canvas(painter, canvas, clip)",
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
            "struct MetalSceneDemo(Component):\n    def build(self, bounds: Rect) -> ColumnView:\n        var root = ColumnView(bounds, 20.0, 10.0)\n        root.add_canvas(1, \"Metal scene\", bounds.height - 100.0)\n        root.layout()\n        return root^\n\nvar app = App[MetalSceneDemo](MetalSceneDemo(), bounds)\nvar scene = app.component.scene(bounds)\nrenderer.render_scene(scene)",
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
            "struct MetalWindowDemo(Component):\n    def build(self, bounds: Rect) -> ColumnView:\n        var root = ColumnView(bounds, 20.0, 10.0)\n        root.add_canvas(2, \"Metal scene\", bounds.height - 80.0)\n        root.layout()\n        return root^\n\nvar component = MetalWindowDemo()\nvar scene = component.scene(bounds)\nrenderer.render_scene(scene)",
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

    def scenario_id_for(self, index: Int) -> Int:
        """Return the canonical scenario id backing a catalog entry."""
        if index < 0 or index >= len(self.entries):
            return SCENARIO_NONE
        var item = self.entries[index]
        var registry = canonical_scenarios()
        for scenario_index in range(registry.count()):
            var scenario = registry.entry(scenario_index)
            if scenario.source == item.source and scenario.task == item.task:
                return scenario.id
        return SCENARIO_NONE

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


