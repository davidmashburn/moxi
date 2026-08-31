"""Metal plot-packet benchmark over the shared line/scatter fixture."""

from moxi import MacOSMetalRenderer, Rect, make_plot_scenario


comptime BENCHMARK_PASSES: Int = 25


def main() raises:
    var plot = make_plot_scenario(Rect(0.0, 0.0, 640.0, 420.0))
    var packet = plot.build_render_packet()
    print("Moxi Metal plot-packet benchmark")
    print("  source points: ", packet.source_point_count)
    print("  emitted points: ", packet.emitted_point_count)
    print("  line segments: ", packet.line_count())
    print("  instances: ", packet.instance_count())
    print("  ordered batches: ", packet.batch_count())
    print("  packet bytes: ", packet.total_byte_count())
    print("  fallback required: ", packet.fallback_required)

    var renderer = MacOSMetalRenderer(640, 420)
    if not renderer.is_ready():
        print("Moxi Metal plot-packet benchmark skipped: device unavailable")
        return
    var rendered = True
    for _ in range(BENCHMARK_PASSES):
        rendered = renderer.render_plot_packet(packet)
    var packet_frame_ms = renderer.frame_time_ms()
    var packet_gpu_ms = renderer.gpu_time_ms()
    var full_rendered = renderer.render_plot(plot)
    var full_frame_ms = renderer.frame_time_ms()
    var full_gpu_ms = renderer.gpu_time_ms()
    print("  rendered: ", rendered)
    print("  full plot rendered: ", full_rendered)
    print("  passes: ", BENCHMARK_PASSES)
    print("  GPU line segments/frame: ", renderer.rendered_plot_line_count())
    print("  GPU instances/frame: ", renderer.rendered_plot_instance_count())
    print("  GPU submissions/frame: ", renderer.plot_submission_count())
    print("  vertices/frame: ", renderer.vertex_count())
    print("  packet frame/GPU ms: ", packet_frame_ms, "/", packet_gpu_ms)
    print("  full plot frame/GPU ms: ", full_frame_ms, "/", full_gpu_ms)
    print("  checksum: ", renderer.checksum())
    renderer.shutdown()
