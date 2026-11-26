"""Full colored render, excluding setup and presentation. Export both inputs and timing."""

from std.time import perf_counter_ns
from moxi import FractalState, Point, fractal_preset_geometry
from moxi.fractal import _geometry_from_points


def main() raises:
    for case_id in range(3):
        var state = FractalState()
        var depth = 6
        if case_id == 0:
            # Original Koch generator on its 350-pixel horizontal baseline.
            state.geometry = _geometry_from_points([
                Point(250, 250), Point(250 + 350.0 / 3, 250),
                Point(425, 250 - 350 * 0.28867513459481287),
                Point(250 + 700.0 / 3, 250), Point(600, 250),
            ])
        elif case_id == 1:
            depth = 16
            state.geometry = _geometry_from_points([
                Point(250, 250), Point(425, 75), Point(600, 250),
            ])
        else:
            state.geometry = fractal_preset_geometry(12)  # Peano Serpent

        state.random_colors = True
        _ = state.set_depth(depth)
        state.reset_render_progress()
        var geometry = state.geometry
        print("CASE", case_id, depth, geometry.baseline_start.x, geometry.baseline_start.y,
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
