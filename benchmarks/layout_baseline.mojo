"""Legacy fixed-height wide-tree baseline; excludes construction and compilation.

Build with native/benchmark_clock.o. This workload is not a comparison with
content measurement, and its timings must not be presented as one.
"""

from std.ffi import external_call
from moxi import ColumnView, Rect

def run(n: Int):
    var v = ColumnView(Rect(0, 0, 1000, Float32(n) * 24), 0, 0)
    for i in range(n):
        v.add_label(i, "layout benchmark", 24)
    var start = external_call["moxi_benchmark_time_ns", Int64]()
    v.layout()
    var cold = external_call["moxi_benchmark_time_ns", Int64]() - start
    start = external_call["moxi_benchmark_time_ns", Int64]()
    for _ in range(20):
        v.layout()
    var hot = external_call["moxi_benchmark_time_ns", Int64]() - start
    print(n, " cold_ns=", cold, " unchanged_mean_ns=", hot // 20, " last_y=", v.bounds_for(n-1).y)

def main():
    run(100)
    run(1000)
    run(10000)
