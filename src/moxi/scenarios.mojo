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
        self.default_width = default_width
        self.default_height = default_height
        self.stateful = stateful
        self.semantic_hint = semantic_hint
        self.counter_hint = counter_hint

    def command(self) -> String:
        """Return the checked-in Pixi task for this scenario."""
        return String("pixi run ", self.task)


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
    item_count: Int = 10000,
) -> InteractionScenario:
    """Build the canonical stable-key collection interaction workload."""
    var result = InteractionScenario()
    var count = item_count if item_count > 0 else 0
    var keys = List[Int](capacity=count)
    for index in range(count):
        # Deliberately avoid index identity so reconciliation tests exercise
        # stable keys rather than accidentally relying on positions.
        keys.append(1000 + index * 3)
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


def make_plot_data_fixture() -> PlotDataTable:
    """Build the shared telemetry/statistics fixture for demos and benchmarks."""
    var data = PlotDataTable()
    _ = data.add_timestamp_column("time")
    _ = data.add_float_column("value")
    _ = data.add_float_column("size")
    _ = data.add_category_column("series")
    _ = data.add_category_column("region")
    for index in range(48):
        var x = Float32(index % 12)
        var value = 1.0 + Float32((index * 7) % 17) * 0.35
        _ = data.append(x, value)
        _ = data.set_int_field(
            "time", index, Int64(1700000000 + index * 3600)
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
