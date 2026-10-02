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
    var renderer = MacOSRenderer()
    var painter = MacOSCanvasPainter()
    for workload in range(7):
        var host_width = 1500 if workload==4 else 2000 if workload==5 else 1100
        var host_height = 1000 if workload==4 else 1400 if workload==5 else 900 if workload==6 else 800
        external_call["moxi_layout_benchmark_host", NoneType](Int32(host_width),Int32(host_height))
        screen.rtl = False
        screen.summary = False
        # Warm the complete submission/AX/paint pipeline, not just layout.
        for iteration in range(-10,120):
            var sample = max(0,iteration)
            var width = Float32(host_width)
            if workload==1:
                screen.offset_y = Float64(sample*48)
            elif workload==2:
                width = Float32(1050 if iteration%2==0 else 1100)
            elif workload==3:
                screen.summary = iteration%2==0
            elif workload==6:
                screen.summary = iteration%3==0
                screen.rtl = iteration%2==0
                screen.offset_y = Float64(sample*48)
                screen.offset_x = Float64(sample%4*60)
                screen.form_width = Float32(280+sample%5*12)
                width = Float32(1100 if iteration%2==0 else 540)
            var measurements = screen.tree.measurements()
            var measure_time = screen.tree.measurement_nanoseconds()
            var edits = screen.tree.mutations()
            var solvers = screen.form.solver_builds
            var created = screen.table.created
            start = external_call["moxi_benchmark_time_ns", Int64]()
            var presentation = screen.frame[True](Size(width,Float32(host_height)))
            var layout_end = external_call["moxi_benchmark_time_ns", Int64]()
            external_call["moxi_layout_benchmark_size", NoneType](Int32(width),Int32(host_height))
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
            if workload==0 and iteration>=0:
                assert_equal(measured,UInt64(0))
                assert_equal(rebuilt,0)
                assert_equal(screen.tree.mutations(),edits)
                assert_equal(screen.tree.measurement_nanoseconds(),measure_time)
                assert_equal(screen.table.created,created)
            assert_true(screen.table.realized()<250)
            if iteration<0:
                continue
            var phases = screen._phase_ns.copy()
            var provider_ns = screen.tree.measurement_nanoseconds()-measure_time
            print("frame=",workload," sample=",iteration," layout_ns=",layout_end-start," submission_ns=",submission_end-layout_end," commands_ns=",commands_end-layout_end," accessibility_ns=",accessibility_end-commands_end," draw_ns=",end-submission_end," total_ns=",end-start," measures=",measured," solvers=",rebuilt," created=",screen.table.created-created," realized=",screen.table.realized()," nodes=",presentation.snapshot.count()," engine_edits=",screen.tree.mutations()-edits," provider_ns=",provider_ns," declarations_ns=",phases[1]-phases[0]," allocation_ns=",phases[2]-phases[1]," constraints_ns=",phases[3]-phases[2]," collection_ns=",phases[4]-phases[3]," realization_ns=",phases[5]-phases[4]," arrangement_ns=",phases[6]-phases[5]," validation_ns=",phases[7]-phases[6]," publication_ns=",phases[8]-phases[7]," presentation_ns=",phases[9]-phases[8])
