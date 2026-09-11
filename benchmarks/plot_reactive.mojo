"""Retained reactive plot dispatch benchmark.

This compares direct `PlotView.dispatch` against the same view driven through
`TypedSubtreeExecutor`, so the cost of the retained component path is visible
next to the imperative escape hatch.  Host wall-clock timing stays inside the
executable to exclude compiler startup.

This program is a standalone diagnostic. It is deliberately absent from the
quick and full benchmark profiles in `scripts/benchmark.sh`: its ratio is a
comparison between two paths in the same process rather than a deterministic
counter, so it does not belong in the policy-checked baseline matrix.
"""

from std.ffi import external_call

from moxi import (
    Color,
    Event,
    POINTER_MOVE_KIND,
    Point,
    PointerEvent,
    Rect,
    TypedSubtreeExecutor,
)
from moxi_plot import PlotDataTable, PlotSpec, PlotView


comptime RETAINED_PASSES: Int = 100000


def make_view(row_count: Int) -> PlotView:
    var data = PlotDataTable()
    for index in range(row_count):
        var x = Float32(index % 10000) * 0.01
        var y = Float32((index * 37) % 10000) * 0.01
        _ = data.append(x, y)
    var spec = PlotSpec("Reactive interaction")
    _ = spec.add_line("interaction", "x", "y", Color(0.25, 0.75, 1.0, 0.85))
    _ = spec.add_hover(False, True)
    return PlotView(spec, data, Rect(0.0, 0.0, 1280.0, 720.0))


def hover_event(index: Int) -> Event:
    var fraction = Float32((index * 17) % 997) / 996.0
    return Event(
        PointerEvent(
            POINTER_MOVE_KIND,
            Point(64.0 + 1152.0 * fraction, 36.0 + 648.0 * (1.0 - fraction)),
        )
    )


def run_retained_case(row_count: Int):
    var direct = make_view(row_count)
    var reactive = TypedSubtreeExecutor[PlotView](
        make_view(row_count),
        Rect(0.0, 0.0, 1280.0, 720.0),
    )
    var direct_start = external_call["moxi_benchmark_time_ns", Int64]()
    for index in range(RETAINED_PASSES):
        _ = direct.dispatch(hover_event(index))
    var direct_end = external_call["moxi_benchmark_time_ns", Int64]()
    var reactive_start = external_call["moxi_benchmark_time_ns", Int64]()
    for index in range(RETAINED_PASSES):
        _ = reactive.dispatch(hover_event(index))
    var reactive_end = external_call["moxi_benchmark_time_ns", Int64]()
    var direct_ms = Float64(direct_end - direct_start) / 1000000.0
    var reactive_ms = Float64(reactive_end - reactive_start) / 1000000.0
    print("Moxi retained rows/passes: ", row_count, "/", RETAINED_PASSES)
    print("  direct PlotView ms: ", direct_ms)
    print("  reactive retained ms: ", reactive_ms)
    print("  reactive/direct ratio: ", reactive_ms / direct_ms)
    print("  retained component builds: ", reactive.work_counters().component_builds)


def main():
    print("=== Moxi Retained Reactive Plot Benchmark ===")
    run_retained_case(10000)
    print("Retained timing excludes compiler startup; /usr/bin/time still includes process startup.")
