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
