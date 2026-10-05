"""Identical portable frame workloads with production macOS or Linux paint.

The host publishes semantics and presents to a bitmap; the renderer consumes
the same packet and chart projection as the interactive workbench. Compile-time
parameters select the backend and the explicit full or smoke sample profile.
"""
from std.ffi import external_call
from std.testing import assert_equal, assert_true
from std.sys.defines import get_defined_int
from moxi.accessibility import AccessibilitySnapshot
from moxi.backend import BACKEND_MACOS_APPKIT
from moxi.frame import FrameHost, SurfaceMetrics
from moxi.layout_workbench import LayoutWorkbench
from moxi.layout_workbench_replay import layout_workbench_chart
from moxi.geometry import Size
from moxi.native_frame import NativeFrameRenderer
from moxi.native_window import publish_native_accessibility


comptime BENCHMARK_BACKEND = get_defined_int["MOXI_BENCHMARK_BACKEND", BACKEND_MACOS_APPKIT]()
comptime BENCHMARK_SAMPLES = get_defined_int["MOXI_BENCHMARK_SAMPLES", 120]()
comptime BENCHMARK_WARMUP = get_defined_int["MOXI_BENCHMARK_WARMUP", 10]()
comptime BENCHMARK_PROFILE = get_defined_int["MOXI_BENCHMARK_PROFILE", 0]()


struct BenchmarkHost(FrameHost):
    var size: Size

    def __init__(out self, size: Size):
        self.size = size

    def metrics(self) -> SurfaceMetrics:
        return SurfaceMetrics(self.size)

    def publish_accessibility(mut self, snapshot: AccessibilitySnapshot) raises:
        publish_native_accessibility(snapshot)

    def present(mut self):
        external_call["moxi_window_end_frame", NoneType]()
        external_call["moxi_layout_benchmark_draw", NoneType]()


def main() raises:
    assert_true(BENCHMARK_SAMPLES > 0 and BENCHMARK_WARMUP > 0)
    print("benchmark_profile=",BENCHMARK_PROFILE," samples_per_workload=",BENCHMARK_SAMPLES," warmup_frames_per_workload=",BENCHMARK_WARMUP," backend_kind=",BENCHMARK_BACKEND)
    var start = external_call["moxi_benchmark_time_ns", Int64]()
    var screen = LayoutWorkbench()
    print("source_init_ns=",external_call["moxi_benchmark_time_ns", Int64]()-start)
    screen.focused = -1
    var renderer = NativeFrameRenderer[BENCHMARK_BACKEND]()
    for workload in range(7):
        var host_width = 1500 if workload==4 else 2000 if workload==5 else 1100
        var host_height = 1000 if workload==4 else 1400 if workload==5 else 900 if workload==6 else 800
        external_call["moxi_layout_benchmark_host", NoneType](Int32(host_width),Int32(host_height))
        var host = BenchmarkHost(Size(Float32(host_width),Float32(host_height)))
        screen.rtl = False
        screen.summary = False
        screen.offset_x = 0
        screen.offset_y = 0
        screen.form_width = 320
        # Warm the complete submission/AX/paint pipeline, not just layout.
        for iteration in range(-BENCHMARK_WARMUP,BENCHMARK_SAMPLES):
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
            host.size = Size(width,Float32(host_height))
            var packet = presentation.packet(host.metrics())
            packet.custom_layer = 22
            packet.scene_clip = presentation.snapshot.bounds(22)
            packet.scene = layout_workbench_chart(packet.scene_clip)
            var packet_end = external_call["moxi_benchmark_time_ns", Int64]()
            renderer.bind_resources(presentation.snapshot)
            var resources_end = external_call["moxi_benchmark_time_ns", Int64]()
            renderer.render(packet)
            var commands_end = external_call["moxi_benchmark_time_ns", Int64]()
            host.publish_accessibility(packet.semantics)
            var accessibility_end = external_call["moxi_benchmark_time_ns", Int64]()
            host.present()
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
            print("frame=",workload," sample=",iteration," layout_ns=",layout_end-start," submission_ns=",accessibility_end-layout_end," packet_ns=",packet_end-layout_end," resources_ns=",resources_end-packet_end," commands_ns=",commands_end-resources_end," accessibility_ns=",accessibility_end-commands_end," draw_ns=",end-accessibility_end," total_ns=",end-start," measures=",measured," solvers=",rebuilt," created=",screen.table.created-created," realized=",screen.table.realized()," nodes=",presentation.snapshot.count()," engine_edits=",screen.tree.mutations()-edits," provider_ns=",provider_ns," declarations_ns=",phases[1]-phases[0]," allocation_ns=",phases[2]-phases[1]," constraints_ns=",phases[3]-phases[2]," collection_ns=",phases[4]-phases[3]," realization_ns=",phases[5]-phases[4]," arrangement_ns=",phases[6]-phases[5]," validation_ns=",phases[7]-phases[6]," publication_ns=",phases[8]-phases[7]," presentation_ns=",phases[9]-phases[8])
