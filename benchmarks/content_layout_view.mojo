"""End-to-end declaration sync, layout, and geometry publication timings.

The fixture uses fixed-height controls, so it measures adapter overhead against
layout_baseline, not native text quality. Compile once, run the binary repeatedly.
"""
from std.ffi import external_call
from moxi import ColumnView, Rect


def run(n: Int):
    var view = ColumnView(Rect(0, 0, 1000, Float32(n) * 24), 0, 0)
    view.enable_content_layout()
    for i in range(n):
        view.add_label(i, "layout benchmark", 24)
    var start = external_call["moxi_benchmark_time_ns", Int64]()
    view.layout()
    var cold = external_call["moxi_benchmark_time_ns", Int64]() - start
    var cold_measurements = view.content_layout_tree.leaf_measurements()
    start = external_call["moxi_benchmark_time_ns", Int64]()
    for _ in range(20):
        view.layout()
    var hot = external_call["moxi_benchmark_time_ns", Int64]() - start
    print(n, " cold_ns=", cold, " unchanged_mean_ns=", hot // 20,
          " cold_measures=", cold_measurements,
          " unchanged_measures=", view.content_layout_tree.leaf_measurements(),
          " last_y=", view.bounds_for(n-1).y)


def main():
    run(100)
    run(1000)
    run(10000)
