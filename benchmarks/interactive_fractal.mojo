"""Moxi counterpart to Xilem's interactive_paint benchmark.

The workload intentionally uses the same canvas size, generator presets, and
minimum segment length as the Xilem example. It reports component expansion,
neutral canvas command generation, Metal line geometry/tessellation, CPU
encoding, GPU completion, and synchronized frame time separately.
"""

from std.ffi import external_call

from moxi import (
    FRACTAL_CANVAS_HEIGHT,
    FRACTAL_CANVAS_WIDTH,
    FractalCanvasPainter,
    FractalState,
    MacOSMetalCanvasPainter,
    Point,
    Rect,
    Color,
    fractal_preset_geometry,
    fractal_preset_name,
)


comptime BENCHMARK_ITERATIONS: Int = 25
comptime BENCHMARK_CANVAS_X: Float32 = 0.0
comptime BENCHMARK_CANVAS_Y: Float32 = 0.0
comptime BENCHMARK_PRESET_COUNT: Int = 6


struct BenchmarkPainter(FractalCanvasPainter):
    """Count the same canvas operations the native painter receives."""

    var rect_count: Int
    var line_count: Int
    var circle_count: Int
    var checksum: Int

    def __init__(out self):
        self.rect_count = 0
        self.line_count = 0
        self.circle_count = 0
        self.checksum = 0

    def begin(mut self, clip: Rect) raises:
        self.checksum += Int(clip.width) + Int(clip.height)

    def end(mut self) raises:
        pass

    def fill_rect(
        mut self,
        bounds: Rect,
        fill: Color,
        border: Color,
        border_width: Float32,
    ) raises:
        self.rect_count += 1
        self.checksum += Int(bounds.width) + Int(bounds.height)
        self.checksum += Int(fill.alpha * 255.0)
        self.checksum += Int(border.alpha * 255.0) + Int(border_width)

    def line(
        mut self,
        start: Point,
        end: Point,
        color: Color,
        width: Float32,
    ) raises:
        self.line_count += 1
        self.checksum += Int(start.x) + Int(start.y) + Int(end.x) + Int(end.y)
        self.checksum += Int(color.alpha * 255.0) + Int(width)

    def circle(
        mut self,
        center: Point,
        radius: Float32,
        fill: Color,
        stroke: Color,
        stroke_width: Float32,
    ) raises:
        self.circle_count += 1
        self.checksum += Int(center.x) + Int(center.y) + Int(radius)
        self.checksum += Int(fill.alpha * 255.0)
        self.checksum += Int(stroke.alpha * 255.0) + Int(stroke_width)


def preset_id_for_benchmark(index: Int) -> Int:
    if index == 0:
        return 0
    if index == 1:
        return 4
    if index == 2:
        return 10
    if index == 3:
        return 19
    if index == 4:
        return 25
    return 12


def benchmark_depth(index: Int) -> Int:
    # These are the same low-growth rows used by the Xilem benchmark, while
    # keeping every Moxi case below FRACTAL_MAX_RENDERED_SEGMENTS.
    if index == 0:
        return 5
    if index == 1:
        return 4
    if index == 2:
        return 5
    if index == 3:
        return 4
    if index == 4:
        return 4
    return 4


def run_case(
    preset_id: Int,
    depth: Int,
    mut metal_painter: MacOSMetalCanvasPainter,
) raises:
    var state = FractalState()
    state.preset_id = preset_id
    state.geometry = fractal_preset_geometry(preset_id)
    state.depth = depth
    state.reset_render_progress()

    var expansion_start = external_call["moxi_benchmark_time_ns", Int64]()
    while not state.render_complete():
        _ = state.advance_render(1000000)
    var expansion_end = external_call["moxi_benchmark_time_ns", Int64]()

    var painter = BenchmarkPainter()
    var canvas = Rect(
        BENCHMARK_CANVAS_X,
        BENCHMARK_CANVAS_Y,
        FRACTAL_CANVAS_WIDTH,
        FRACTAL_CANVAS_HEIGHT,
    )
    var paint_start = external_call["moxi_benchmark_time_ns", Int64]()
    for _ in range(BENCHMARK_ITERATIONS):
        state.paint_canvas(painter, canvas, canvas)
    var paint_end = external_call["moxi_benchmark_time_ns", Int64]()

    var expansion_ms = Float64(expansion_end - expansion_start) / 1000000.0
    var paint_ms = Float64(paint_end - paint_start) / 1000000.0
    var lines_per_second = Float64(state.rendered_segment_count()) * 1000.0 / expansion_ms
    var paint_lines_per_second = Float64(painter.line_count) * 1000.0 / paint_ms
    metal_painter.reset_metrics()
    var metal_start = external_call["moxi_benchmark_time_ns", Int64]()
    for _ in range(BENCHMARK_ITERATIONS):
        state.paint_canvas(metal_painter, canvas, canvas)
    var metal_end = external_call["moxi_benchmark_time_ns", Int64]()
    var metal_wall_ms = Float64(metal_end - metal_start) / 1000000.0
    print(
        fractal_preset_name(preset_id),
        " depth ",
        depth,
        ": lines=",
        state.rendered_segment_count(),
        " expansion_ms=",
        expansion_ms,
        " expansion_lines_sec=",
        lines_per_second,
        " paint_ms/",
        BENCHMARK_ITERATIONS,
        "=",
        paint_ms,
        " paint_lines_sec=",
        paint_lines_per_second,
        " metal_wall_total_ms=",
        metal_wall_ms,
        " metal_wall_ms/frame=",
        metal_wall_ms / Float64(BENCHMARK_ITERATIONS),
        " metal_line_geometry_ms/frame=",
        metal_painter.average_line_geometry_ms(),
        " metal_cpu_encode_ms/frame=",
        metal_painter.average_cpu_encode_ms(),
        " metal_cpu_wait_ms/frame=",
        metal_painter.average_cpu_wait_ms(),
        " metal_gpu_ms/frame=",
        metal_painter.average_gpu_ms(),
        " metal_frame_ms/frame=",
        metal_painter.average_frame_ms(),
        " gpu_timing=",
        metal_painter.gpu_timing_available(),
        " metal_vertices=",
        metal_painter.vertex_count(),
        " metal_submissions=",
        metal_painter.draw_submission_count(),
        " metal_overflows=",
        metal_painter.overflow_count(),
        " rects=",
        painter.rect_count,
        " lines=",
        painter.line_count,
        " circles=",
        painter.circle_count,
        " checksum=",
        painter.checksum,
    )


def main() raises:
    print("=== Moxi Interactive Fractal Benchmark ===")
    print(
        "Canvas: ",
        FRACTAL_CANVAS_WIDTH,
        "x",
        FRACTAL_CANVAS_HEIGHT,
        "; iterations: ",
        BENCHMARK_ITERATIONS,
    )
    var metal_painter = MacOSMetalCanvasPainter(
        Int(FRACTAL_CANVAS_WIDTH),
        Int(FRACTAL_CANVAS_HEIGHT),
    )
    if not metal_painter.is_ready():
        print("Moxi Metal fractal benchmark skipped: device unavailable")
        return
    for index in range(BENCHMARK_PRESET_COUNT):
        var preset_id = preset_id_for_benchmark(index)
        run_case(preset_id, benchmark_depth(index), metal_painter)
    metal_painter.shutdown()
