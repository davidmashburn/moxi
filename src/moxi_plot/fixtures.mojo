"""Shared plot fixtures consumed by demos, tests, and benchmarks."""

from moxi.geometry import Rect
from moxi.scene import Scene
from moxi.style import Color
from moxi.scenarios import (
    CANVAS_SCENE_PLOT,
    CANVAS_SCENE_PRIMITIVES,
    SCENARIO_PLOT,
    canonical_canvas_scene_fixture,
    canonical_scenarios,
    make_canvas_scene as _make_core_canvas_scene,
)
from .plot_data import PlotDataTable
from .plotting import PLOT_LINE, PLOT_SCATTER, Plot


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


def make_canvas_scene(fixture_id: Int = CANVAS_SCENE_PRIMITIVES) -> Scene:
    """Build one canonical scene shared by parity tests and export demos.

    Wraps `moxi.scenarios.make_canvas_scene` and adds the `CANVAS_SCENE_PLOT`
    branch, since only this package may depend on the plot model.
    """
    if fixture_id == CANVAS_SCENE_PLOT:
        var plot_fixture = canonical_canvas_scene_fixture(CANVAS_SCENE_PLOT)
        var plot = make_plot_scenario(
            Rect(
                0.0,
                0.0,
                Float32(plot_fixture.width),
                Float32(plot_fixture.height),
            )
        )
        plot.set_title("Canvas scene export")
        return plot.build_scene()
    return _make_core_canvas_scene(fixture_id)
