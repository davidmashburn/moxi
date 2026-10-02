"""100k-row mixed-strategy frame timings including publication and native paint.

Reference budget declared before optimization: p95 <= 16.67 ms at 1100x800 for
warm unchanged/scroll/resize/summary frames on the recorded Apple M4 host.
The bitmap draw includes AppKit/CoreText CPU paint but excludes compositor,
display scanout, event-loop latency and native IME interaction.
"""
from std.ffi import external_call
from std.testing import assert_equal, assert_true
from std.math import sin
from moxi.layout_workbench import LayoutWorkbench
from moxi.geometry import Size, Point, Rect
from moxi.macos import MacOSRenderer, MacOSCanvasPainter
from moxi.style import Color


def main() raises:
    var start = external_call["moxi_benchmark_time_ns", Int64]()
    var screen = LayoutWorkbench()
    print("source_init_ns=",external_call["moxi_benchmark_time_ns", Int64]()-start)
    screen.focused = -1
    external_call["moxi_layout_benchmark_host", NoneType](Int32(1100),Int32(800))
    var renderer = MacOSRenderer()
    var painter = MacOSCanvasPainter()
    # Warm provider, AppKit and paragraph caches; exclude this first frame.
    _ = screen.frame(Size(1100,800))
    for workload in range(4):
        for iteration in range(120):
            var width = Float32(1100)
            if workload==1:
                screen.offset_y = Float64(iteration*48)
            elif workload==2:
                width = Float32(1050 if iteration%2==0 else 1100)
            elif workload==3:
                screen.summary = iteration%2==0
            var measurements = screen.tree.measurements()
            var solvers = screen.form.solver_builds
            var created = screen.table.created
            start = external_call["moxi_benchmark_time_ns", Int64]()
            var presentation = screen.frame(Size(width,800))
            var layout_end = external_call["moxi_benchmark_time_ns", Int64]()
            renderer.begin_frame()
            presentation.draw_commands(renderer,custom_layer=22)
            var commands_end = external_call["moxi_benchmark_time_ns", Int64]()
            presentation.draw_accessibility(renderer)
            var accessibility_end = external_call["moxi_benchmark_time_ns", Int64]()
            var chart = presentation.snapshot.bounds(22)
            painter.begin(chart)
            painter.fill_rect(chart,Color(0.10,0.14,0.21,1),Color(0.24,0.34,0.44,1),1)
            for i in range(1,121):
                var x0 = Float32(i-1)/120
                var x1 = Float32(i)/120
                painter.line(Point(chart.x+16+x0*(chart.width-32),chart.y+chart.height*(0.5-0.25*sin(x0*12))),Point(chart.x+16+x1*(chart.width-32),chart.y+chart.height*(0.5-0.25*sin(x1*12))),Color(0.35,0.85,0.75,1),2)
            painter.end()
            var submission_end = external_call["moxi_benchmark_time_ns", Int64]()
            external_call["moxi_layout_benchmark_draw", NoneType]()
            var end = external_call["moxi_benchmark_time_ns", Int64]()
            var measured = screen.tree.measurements()-measurements
            var rebuilt = screen.form.solver_builds-solvers
            if workload==0:
                assert_equal(measured,UInt64(0))
                assert_equal(rebuilt,0)
                assert_equal(screen.table.created,created)
            assert_true(screen.table.realized()<200)
            print("frame=",workload," sample=",iteration," layout_ns=",layout_end-start," submission_ns=",submission_end-layout_end," commands_ns=",commands_end-layout_end," accessibility_ns=",accessibility_end-commands_end," draw_ns=",end-submission_end," total_ns=",end-start," measures=",measured," solvers=",rebuilt," created=",screen.table.created-created," realized=",screen.table.realized())
