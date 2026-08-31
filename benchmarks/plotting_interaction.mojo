"""Indexed plot interaction benchmark.

This separates one-time index construction from hot pointer queries and
records packet-cache reuse.  Host wall-clock timing is intentionally kept
inside the executable so the interaction path is measured independently of
compiler startup; the benchmark still reports deterministic candidate counts.
"""

from std.ffi import external_call

from moxi import (
    Color,
    Event,
    MOD_SHIFT,
    POINTER_DOWN_KIND,
    POINTER_UP_KIND,
    PlotRuntime,
    Point,
    PointerEvent,
    Rect,
)


comptime QUERY_PASSES: Int = 120


def make_runtime(row_count: Int) -> PlotRuntime:
    var runtime = PlotRuntime(Rect(0.0, 0.0, 1280.0, 720.0))
    var series = runtime.plot.add_series(
        "interaction",
        Color(0.25, 0.75, 1.0, 0.85),
    )
    for index in range(row_count):
        var x = Float32(index % 10000) * 0.01
        var y = Float32((index * 37) % 10000) * 0.01
        _ = runtime.plot.add_point(series, x, y)
    runtime.plot.fit_to_data()
    return runtime^


def run_case(row_count: Int):
    var runtime = make_runtime(row_count)
    var area = runtime.plot.plot_area
    var query = Point(area.x + area.width * 0.53, area.y + area.height * 0.47)

    var cold_start = external_call["moxi_benchmark_time_ns", Int64]()
    var cold_hit = runtime.hit_test(query)
    var cold_end = external_call["moxi_benchmark_time_ns", Int64]()

    var found = 0
    var hot_start = external_call["moxi_benchmark_time_ns", Int64]()
    for index in range(QUERY_PASSES):
        var fraction = Float32((index * 17) % 97) / 96.0
        var next_query = Point(
            area.x + area.width * fraction,
            area.y + area.height * (1.0 - fraction),
        )
        var hit = runtime.hit_test(next_query)
        if hit.found():
            found += 1
    var hot_end = external_call["moxi_benchmark_time_ns", Int64]()
    var hot_candidates = runtime.last_query_candidates()

    var first_packet = runtime.build_render_packet()
    var packet_rebuilds_after_first = runtime.packet_rebuilds()
    var second_packet = runtime.build_render_packet()
    var packet_rebuilds_after_second = runtime.packet_rebuilds()

    var brush_start = Point(area.x + 4.0, area.y + 4.0)
    var brush_end = Point(area.x + area.width * 0.25, area.y + area.height * 0.25)
    var down = Event(PointerEvent(POINTER_DOWN_KIND, brush_start))
    down.modifiers = MOD_SHIFT
    _ = runtime.dispatch(down)
    var brush_clock_start = external_call["moxi_benchmark_time_ns", Int64]()
    _ = runtime.dispatch(Event(PointerEvent(POINTER_UP_KIND, brush_end)))
    var brush_clock_end = external_call["moxi_benchmark_time_ns", Int64]()
    var brush_candidates = runtime.last_query_candidates()

    var cold_ms = Float64(cold_end - cold_start) / 1000000.0
    var hot_ms = Float64(hot_end - hot_start) / 1000000.0
    var brush_ms = Float64(brush_clock_end - brush_clock_start) / 1000000.0
    print("Moxi interaction rows: ", row_count)
    print("  cold index/query ms: ", cold_ms)
    print("  hot queries/count/ms: ", QUERY_PASSES, "/", found, "/", hot_ms)
    print("  hot query ms: ", hot_ms / Float64(QUERY_PASSES))
    print("  index rebuilds/hot candidates/brush candidates: ", runtime.spatial_index_rebuilds(), "/", hot_candidates, "/", brush_candidates)
    print("  packet marks/bytes: ", first_packet.mark_count(), "/", first_packet.total_byte_count())
    print("  packet rebuilds first/second: ", packet_rebuilds_after_first, "/", packet_rebuilds_after_second)
    print("  cached packet stable: ", first_packet.mark_count() == second_packet.mark_count())
    print("  brush ms/selected: ", brush_ms, "/", runtime.selected_count())
    print("  cold hit found: ", cold_hit.found())


def main():
    print("=== Moxi Plot Interaction Benchmark ===")
    run_case(100000)
    run_case(1000000)
    print("Interaction timing excludes compiler startup; /usr/bin/time still includes process startup.")
