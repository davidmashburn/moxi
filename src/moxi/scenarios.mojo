"""Shared showcase scenarios consumed by demos, tests, and benchmarks."""

from std.collections import List

from .collection_state import CollectionSelection, TreeCollectionState
from .geometry import Rect
from .plot_data import PlotDataTable
from .plotting import PLOT_LINE, PLOT_SCATTER, Plot
from .popup import POPUP_COMBO, POPUP_PLACE_BELOW, PopupLayerState
from .reorder import ReorderInteraction
from .scrollbar import SCROLLBAR_VERTICAL, ScrollbarState
from .style import Color
from .text_layout import TEXT_DIRECTION_AUTO, TEXT_DIRECTION_LTR, TEXT_DIRECTION_RTL


comptime SCENARIO_NONE = 0
comptime SCENARIO_FORM = 1
comptime SCENARIO_THEME = 2
comptime SCENARIO_COLLECTION = 3
comptime SCENARIO_TEXT = 4
comptime SCENARIO_PLOT = 5
comptime SCENARIO_CAPABILITY = 6
comptime SCENARIO_FRACTAL = 7


struct ScenarioDescriptor(ImplicitlyCopyable):
    """Stable metadata for one canonical demo/test/benchmark scenario."""

    var id: Int
    var name: String
    var fixture: String
    var source: String
    var task: String
    var test_source: String
    var benchmark_source: String
    var golden_names: String
    # The deterministic size/seed pair is the fixture contract. Consumers
    # should derive their default workload from these values rather than
    # repeating scenario data literals in tests, demos, or benchmarks.
    var fixture_size: Int
    var fixture_seed: Int
    var default_width: Float32
    var default_height: Float32
    var stateful: Bool
    var semantic_hint: String
    var counter_hint: String

    def __init__(
        out self,
        id: Int,
        name: String,
        fixture: String,
        source: String,
        task: String,
        test_source: String,
        benchmark_source: String,
        golden_names: String,
        fixture_size: Int,
        fixture_seed: Int,
        default_width: Float32,
        default_height: Float32,
        stateful: Bool,
        semantic_hint: String,
        counter_hint: String,
    ):
        self.id = id
        self.name = name
        self.fixture = fixture
        self.source = source
        self.task = task
        self.test_source = test_source
        self.benchmark_source = benchmark_source
        self.golden_names = golden_names
        self.fixture_size = fixture_size
        self.fixture_seed = fixture_seed
        self.default_width = default_width
        self.default_height = default_height
        self.stateful = stateful
        self.semantic_hint = semantic_hint
        self.counter_hint = counter_hint

    def command(self) -> String:
        """Return the checked-in Pixi task for this scenario."""
        return String("pixi run ", self.task)


struct ThemeModeFixture(ImplicitlyCopyable):
    """One palette state used by the theme showcase and visual corpus."""

    var mode: Int
    var name: String
    var button_label: String
    var action_id: Int
    var status_message: String
    var golden: Bool

    def __init__(
        out self,
        mode: Int,
        name: String,
        button_label: String,
        action_id: Int,
        status_message: String,
        golden: Bool,
    ):
        self.mode = mode
        self.name = name
        self.button_label = button_label
        self.action_id = action_id
        self.status_message = status_message
        self.golden = golden


struct ScenarioStep(ImplicitlyCopyable):
    """One deterministic step in a canonical walkthrough fixture."""

    var ordinal: Int
    var title: String
    var body: String

    def __init__(out self, ordinal: Int, title: String, body: String):
        self.ordinal = ordinal
        self.title = title
        self.body = body


struct FractalBenchmarkFixture(ImplicitlyCopyable):
    """One preset/depth pair in the canonical fractal workload."""

    var preset_id: Int
    var depth: Int

    def __init__(out self, preset_id: Int, depth: Int):
        self.preset_id = preset_id
        self.depth = depth


struct TextCorpusFixture(ImplicitlyCopyable):
    """One shared text case for portable and native conformance checks."""

    var id: String
    var text: String
    var direction: Int
    var max_width: Float32
    var expect_bidi: Bool
    var expect_fallback: Bool
    var expect_wrapping: Bool

    def __init__(
        out self,
        id: String,
        text: String,
        direction: Int,
        max_width: Float32,
        expect_bidi: Bool,
        expect_fallback: Bool,
        expect_wrapping: Bool,
    ):
        self.id = id
        self.text = text
        self.direction = direction
        self.max_width = max_width
        self.expect_bidi = expect_bidi
        self.expect_fallback = expect_fallback
        self.expect_wrapping = expect_wrapping


struct ScenarioRegistry:
    """Static scenario inventory shared by demos, tests, and benchmarks."""

    var entries: List[ScenarioDescriptor]

    def __init__(out self):
        self.entries = List[ScenarioDescriptor](capacity=7)
        self.entries.append(ScenarioDescriptor(
            SCENARIO_FORM,
            "Form and component slot",
            "form",
            "examples/form.mojo",
            "form-demo",
            "tests/form.mojo",
            "",
            "accessibility-focused-control",
            1,
            101,
            520.0,
            320.0,
            True,
            "text input, submit, cancel, clipboard, and IME",
            "focus transitions and action dispatch",
        ))
        self.entries.append(ScenarioDescriptor(
            SCENARIO_THEME,
            "Theme control states",
            "theme",
            "examples/theme_showcase.mojo",
            "theme-showcase-demo",
            "tests/tokens_recipes.mojo",
            "",
            "theme-dark,theme-light,theme-emerald",
            4,
            202,
            680.0,
            520.0,
            True,
            "theme presets, recipes, and control states",
            "theme selection and retained component state",
        ))
        self.entries.append(ScenarioDescriptor(
            SCENARIO_COLLECTION,
            "Stable-key collection",
            "collection",
            "examples/interaction_showcase.mojo",
            "interaction-showcase-demo",
            "tests/interaction_foundation.mojo",
            "benchmarks/interaction_foundation.mojo",
            "nested-clipping-scrolling",
            10000,
            1000,
            980.0,
            720.0,
            True,
            "list/table/tree, popup, scrollbar, and reorder semantics",
            "active slots, selected keys, and reorder commands",
        ))
        self.entries.append(ScenarioDescriptor(
            SCENARIO_TEXT,
            "Mixed text",
            "text",
            "examples/coretext.mojo",
            "text-demo",
            "tests/text_shaping.mojo",
            "",
            "text-mixed-fallback",
            1,
            404,
            640.0,
            360.0,
            False,
            "Unicode shaping, bidi, fallback reporting, and text bounds",
            "glyph runs, fallback flags, and measured lines",
        ))
        self.entries.append(ScenarioDescriptor(
            SCENARIO_PLOT,
            "Plot gallery",
            "plot",
            "examples/plot_gallery.mojo",
            "plot-gallery",
            "tests/plotting.mojo",
            "benchmarks/plotting.mojo",
            "plot-gallery",
            48,
            1700000000,
            760.0,
            520.0,
            True,
            "typed data, axes, facets, selections, and canvas output",
            "scene commands, packet batches, and checksum",
        ))
        self.entries.append(ScenarioDescriptor(
            SCENARIO_CAPABILITY,
            "Capability walkthrough",
            "capability",
            "examples/capability_bus.mojo",
            "capability-bus-demo",
            "tests/capability.mojo",
            "",
            "",
            10,
            606,
            720.0,
            560.0,
            True,
            "manifest, approval, replay, and semantic action status",
            "handler results, approvals, and queue state",
        ))
        self.entries.append(ScenarioDescriptor(
            SCENARIO_FRACTAL,
            "Interactive fractal canvas",
            "fractal",
            "examples/interactive_fractal.mojo",
            "interactive-fractal-demo",
            "tests/fractal.mojo",
            "benchmarks/interactive_fractal.mojo",
            "",
            6,
            707,
            920.0,
            620.0,
            True,
            "editable generator geometry and a component-owned canvas",
            "expanded segments, commands, vertices, and frame timing",
        ))

    def count(self) -> Int:
        return len(self.entries)

    def entry(self, index: Int) -> ScenarioDescriptor:
        return self.entries[index]

    def index_for_id(self, id: Int) -> Int:
        for index in range(len(self.entries)):
            if self.entries[index].id == id:
                return index
        return -1

    def index_for_fixture(self, fixture: String) -> Int:
        for index in range(len(self.entries)):
            if self.entries[index].fixture == fixture:
                return index
        return -1

    def is_valid(self) -> Bool:
        for index in range(len(self.entries)):
            var current = self.entries[index]
            if current.id <= SCENARIO_NONE or current.name.count_codepoints() == 0:
                return False
            if current.fixture.count_codepoints() == 0 or current.source.count_codepoints() == 0:
                return False
            if current.task.count_codepoints() == 0:
                return False
            if current.fixture_size <= 0 or current.fixture_seed < 0:
                return False
            if current.test_source.count_codepoints() == 0:
                return False
            if current.default_width <= 0.0 or current.default_height <= 0.0:
                return False
            if self.index_for_id(current.id) != index:
                return False
            if self.index_for_fixture(current.fixture) != index:
                return False
        return True


def canonical_scenarios() -> ScenarioRegistry:
    """Return the repository's canonical scenario inventory."""
    return ScenarioRegistry()


def canonical_form_title() -> String:
    """Return the title used by the canonical form fixture."""
    return "Moxi Form"


def canonical_form_hint() -> String:
    """Return the editing hint used by the canonical form fixture."""
    return "Type a name, then submit"


def canonical_form_submit_label() -> String:
    """Return the action label used by the canonical form fixture."""
    return "Submit"


def canonical_theme_title() -> String:
    """Return the title used by the canonical theme fixture."""
    return "Moxi Design Tokens & Recipes"


def canonical_theme_selector_label() -> String:
    """Return the palette selector label used by the theme fixture."""
    return "Select Palette:"


def canonical_theme_golden_mode(index: Int) -> Int:
    """Return the theme mode for one checked-in software golden."""
    var modes = canonical_theme_modes()
    var golden_index = 0
    for mode_index in range(len(modes)):
        if modes[mode_index].golden:
            if golden_index == index:
                return modes[mode_index].mode
            golden_index += 1
    return -1


def canonical_theme_modes() -> List[ThemeModeFixture]:
    """Return the complete deterministic palette state table."""
    var result = List[ThemeModeFixture](capacity=4)
    result.append(ThemeModeFixture(
        0,
        "Dark",
        "Dark Slate",
        1,
        "Switched to Dark Slate palette.",
        True,
    ))
    result.append(ThemeModeFixture(
        1,
        "Light",
        "Clean Light",
        2,
        "Switched to Clean Light palette.",
        True,
    ))
    result.append(ThemeModeFixture(
        2,
        "Zinc",
        "Neutral Zinc",
        3,
        "Switched to Neutral Zinc palette.",
        False,
    ))
    result.append(ThemeModeFixture(
        3,
        "Emerald",
        "Emerald Teal",
        4,
        "Switched to Emerald Teal palette.",
        True,
    ))
    return result^


def canonical_theme_mode_name(mode: Int) -> String:
    """Return the display name for one canonical palette mode."""
    var modes = canonical_theme_modes()
    for index in range(len(modes)):
        if modes[index].mode == mode:
            return modes[index].name
    return "Unknown"


def canonical_theme_status(mode: Int) -> String:
    """Return the status copy for one canonical palette mode."""
    var modes = canonical_theme_modes()
    for index in range(len(modes)):
        if modes[index].mode == mode:
            return modes[index].status_message
    return "Unknown theme palette."


def canonical_capability_steps() -> List[ScenarioStep]:
    """Return the complete deterministic capability walkthrough table."""
    var result = List[ScenarioStep](capacity=10)
    result.append(ScenarioStep(
        1,
        "1 · Define the Component boundary",
        "A Moxi component owns value state and returns a lightweight view. The native window and renderer remain host concerns.",
    ))
    result.append(ScenarioStep(
        2,
        "2 · Build the view tree",
        "Implement build(bounds) -> ColumnView. Add labels, controls, or a canvas, configure layout, and return the completed tree.",
    ))
    result.append(ScenarioStep(
        3,
        "3 · Route events through update",
        "App routes a click or key event to update. The component changes its own state, then App rebuilds and reconciles the view.",
    ))
    result.append(ScenarioStep(
        4,
        "4 · Register a capability descriptor",
        "CapabilityDescriptor makes the action inspectable: stable name, side-effect class, approval policy, concurrency, and input schema.",
    ))
    result.append(ScenarioStep(
        5,
        "5 · Authorize the UI mutation",
        "The UI creates a CapabilityInvocation and sends it through authorize. Only after policy accepts it does application code apply the mutation.",
    ))
    result.append(ScenarioStep(
        6,
        "6 · Reuse the envelope for agents",
        "An agent uses the same request envelope with caller, idempotency, and reasoning metadata. It does not receive a mutable reference to component state.",
    ))
    result.append(ScenarioStep(
        7,
        "7 · Require trusted approval",
        "Destructive or network work cannot use a caller-supplied Boolean as approval. The bus issues a token bound to this exact request.",
    ))
    result.append(ScenarioStep(
        8,
        "8 · Execute through a typed handler",
        "Register a CapabilityHandler and call invoke_handler when the application wants a typed executor. Executor-less invoke calls are rejected.",
    ))
    result.append(ScenarioStep(
        9,
        "9 · Keep replay and queue behavior bounded",
        "The bus preserves a bounded FIFO and recent idempotent completions. Queue pressure, replay, and exclusive leases stay observable.",
    ))
    result.append(ScenarioStep(
        10,
        "10 · Verify the contract and ship",
        "Tests cover descriptors, schemas, approval, leases, handlers, replay, and queue limits. Run pixi run check before recording the final walkthrough.",
    ))
    return result^


def canonical_text_coretext_fixture() -> String:
    """Return the mixed-script string used by the CoreText smoke demo."""
    return "Moxi • שלום • 🙂"


def canonical_text_fallback_fixture() -> String:
    """Return the mixed-script string used by the software fallback golden."""
    return "Latin · Ελληνικά · שלום · हिन्दी · 🙂"


def canonical_text_fallback_caption() -> String:
    """Return the caption paired with the fallback golden fixture."""
    return "fallback and bidi probe"


def canonical_text_combining_fixture() -> String:
    """Return the combining-mark sample used by shaping and boundary tests."""
    return "A e\u0301 🙂"


def canonical_text_rtl_fixture() -> String:
    """Return the explicit right-to-left shaping sample."""
    return "אבג"


def canonical_text_auto_rtl_fixture() -> String:
    """Return the auto-direction right-to-left shaping sample."""
    return "...אבג"


def canonical_text_mixed_bidi_fixture() -> String:
    """Return the mixed-direction shaping sample."""
    return "abc אבג"


def canonical_text_corpus() -> List[TextCorpusFixture]:
    """Return the shared shaping/editing corpus in deterministic order."""
    var result = List[TextCorpusFixture](capacity=5)
    result.append(TextCorpusFixture(
        "combining",
        canonical_text_combining_fixture(),
        TEXT_DIRECTION_LTR,
        0.0,
        False,
        True,
        False,
    ))
    result.append(TextCorpusFixture(
        "rtl",
        canonical_text_rtl_fixture(),
        TEXT_DIRECTION_RTL,
        0.0,
        True,
        True,
        False,
    ))
    result.append(TextCorpusFixture(
        "auto-rtl",
        canonical_text_auto_rtl_fixture(),
        TEXT_DIRECTION_AUTO,
        0.0,
        True,
        True,
        False,
    ))
    result.append(TextCorpusFixture(
        "mixed-bidi",
        canonical_text_mixed_bidi_fixture(),
        TEXT_DIRECTION_LTR,
        0.0,
        True,
        True,
        False,
    ))
    result.append(TextCorpusFixture(
        "fallback-wrap",
        canonical_text_fallback_fixture(),
        TEXT_DIRECTION_LTR,
        120.0,
        True,
        True,
        True,
    ))
    return result^


def canonical_capability_title() -> String:
    """Return the title used by the capability walkthrough fixture."""
    return "Moxi · Capability Bus Walkthrough"


def canonical_capability_initial_status() -> String:
    """Return the initial status used by the capability walkthrough."""
    return "Ready. Use Next to authorize the first step."


def canonical_capability_hint() -> String:
    """Return the explanatory hint used by the capability walkthrough."""
    return "The buttons below are normal Component events. Their mutations cross the same CapabilityBus boundary used by an agent adapter."


def canonical_fractal_cases() -> List[FractalBenchmarkFixture]:
    """Return the canonical fractal preset/depth workload table."""
    var result = List[FractalBenchmarkFixture](capacity=6)
    result.append(FractalBenchmarkFixture(0, 5))
    result.append(FractalBenchmarkFixture(4, 4))
    result.append(FractalBenchmarkFixture(10, 5))
    result.append(FractalBenchmarkFixture(19, 4))
    result.append(FractalBenchmarkFixture(25, 4))
    result.append(FractalBenchmarkFixture(12, 4))
    return result^


def canonical_fractal_preset_ids() -> List[Int]:
    """Return the deterministic preset order for the fractal benchmark."""
    var result = List[Int](capacity=6)
    var cases = canonical_fractal_cases()
    for index in range(len(cases)):
        result.append(cases[index].preset_id)
    return result^


def canonical_fractal_depths() -> List[Int]:
    """Return the deterministic depth order for the fractal benchmark."""
    var result = List[Int](capacity=6)
    var cases = canonical_fractal_cases()
    for index in range(len(cases)):
        result.append(cases[index].depth)
    return result^


struct InteractionScenario:
    """Shared collection/scroll/popup workload for tests and benchmarks."""

    var collection: CollectionSelection
    var tree: TreeCollectionState
    var scrollbar: ScrollbarState
    var popups: PopupLayerState
    var reorder: ReorderInteraction

    def __init__(out self):
        self.collection = CollectionSelection(0, True)
        self.tree = TreeCollectionState(True)
        self.scrollbar = ScrollbarState(SCROLLBAR_VERTICAL, 18.0)
        self.popups = PopupLayerState()
        self.reorder = ReorderInteraction()


def make_interaction_foundation_scenario(
    item_count: Int = -1,
) -> InteractionScenario:
    """Build the canonical stable-key collection interaction workload."""
    var result = InteractionScenario()
    var registry = canonical_scenarios()
    var descriptor = registry.entry(registry.index_for_id(SCENARIO_COLLECTION))
    var requested_count = item_count
    if requested_count < 0:
        requested_count = descriptor.fixture_size
    var count = requested_count if requested_count > 0 else 0
    var keys = List[Int](capacity=count)
    var key_seed = descriptor.fixture_seed
    for index in range(count):
        # Deliberately avoid index identity so reconciliation tests exercise
        # stable keys rather than accidentally relying on positions.
        keys.append(key_seed + index * 3)
    _ = result.collection.set_keys(keys)
    _ = result.reorder.set_item_count(result.collection.item_count())

    _ = result.tree.add_node(10, -1, True)
    _ = result.tree.add_node(20, 10, False)
    _ = result.tree.add_node(30, 20, False)
    _ = result.tree.add_node(40)
    result.scrollbar.set_metrics(Float32(count) * 24.0, 320.0)

    _ = result.popups.open_root(
        100,
        POPUP_COMBO,
        7,
        Rect(16.0, 16.0, 120.0, 28.0),
        Rect(16.0, 44.0, 180.0, 160.0),
        POPUP_PLACE_BELOW,
        False,
        101,
        7,
    )
    var actions = List[Int]()
    actions.append(500)
    actions.append(501)
    _ = result.popups.set_actions(100, actions)
    return result^


def make_plot_scenario(bounds: Rect) -> Plot:
    """Build the canonical small plot used across the repository."""
    var plot = Plot(bounds)
    plot.set_title("Moxi plotting preview")
    var line = plot.add_series(
        "signal",
        Color(0.25, 0.72, 1.0, 1.0),
        PLOT_LINE,
    )
    var points = plot.add_series(
        "samples",
        Color(1.0, 0.45, 0.25, 1.0),
        PLOT_SCATTER,
    )
    for index in range(12):
        var x = Float32(index)
        var y = 0.5 + Float32((index * 7) % 5) * 0.35
        _ = plot.add_point(line, x, y)
        _ = plot.add_point(points, x, y + 0.2)
    plot.fit_to_data()
    return plot^


def make_plot_data_fixture(row_count: Int = -1) -> PlotDataTable:
    """Build the shared telemetry/statistics fixture for demos and benchmarks."""
    var registry = canonical_scenarios()
    var descriptor = registry.entry(registry.index_for_id(SCENARIO_PLOT))
    var requested_count = row_count
    if requested_count < 0:
        requested_count = descriptor.fixture_size
    var count = requested_count if requested_count > 0 else 0
    var timestamp_seed = descriptor.fixture_seed
    var data = PlotDataTable()
    _ = data.add_timestamp_column("time")
    _ = data.add_float_column("value")
    _ = data.add_float_column("size")
    _ = data.add_category_column("series")
    _ = data.add_category_column("region")
    for index in range(count):
        var x = Float32(index % 12)
        var value = 1.0 + Float32((index * 7) % 17) * 0.35
        _ = data.append(x, value)
        _ = data.set_int_field(
            "time", index, Int64(timestamp_seed + index * 3600)
        )
        _ = data.set_float_field("value", index, value)
        _ = data.set_float_field("size", index, 4.0 + Float32(index % 5) * 1.5)
        _ = data.set_category_field(
            "series", index, "A" if index % 2 == 0 else "B"
        )
        _ = data.set_category_field(
            "region", index, "north" if index < 24 else "south"
        )
    return data^
