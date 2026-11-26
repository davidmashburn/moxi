"""Full colored render, excluding setup and presentation. Export both inputs and timing."""

from std.time import perf_counter_ns
from moxi import FractalState
from fractal_fixtures import set_fixture


def main() raises:
    for case_id in range(3):
        var state = FractalState()
        _ = set_fixture(state, case_id)
        var geometry = state.geometry
        print("CASE", case_id, state.depth.text(), geometry.baseline_start.x, geometry.baseline_start.y,
              geometry.baseline_end.x, geometry.baseline_end.y)
        for line in state.local_segments:
            print("LINE", line.start.x, line.start.y, line.end.x, line.end.y)
        for trial in range(9):
            state.reset_render_progress()
            var start = perf_counter_ns()
            while not state.render_complete():
                _ = state.advance_render(1_000_000)
            var elapsed = perf_counter_ns() - start
            print("TIME", trial, state.cursor.emitted.text(), Float64(elapsed) / 1e6)
        var painted = False
        for i in range(3, len(state.raster.pixels), 4):
            if state.raster.pixels[i] != 0:
                painted = True
                break
        if not painted or state.coordinate_overflow:
            raise Error("Expected visible, representable fractal lines")
