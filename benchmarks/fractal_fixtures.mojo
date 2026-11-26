"""Matched colored inputs for the native and browser throughput benchmarks."""
from moxi import FractalState, Point, fractal_preset_geometry
from moxi.fractal import _geometry_from_points


def set_fixture(mut state: FractalState, index: Int) -> Bool:
    if index < 0 or index > 2:
        return False
    var depth = 6
    if index == 0:
        state.geometry = _geometry_from_points([
            Point(250, 250), Point(250 + 350.0 / 3, 250),
            Point(425, 250 - 350 * 0.28867513459481287),
            Point(250 + 700.0 / 3, 250), Point(600, 250),
        ])
    elif index == 1:
        depth = 16
        state.geometry = _geometry_from_points([
            Point(250, 250), Point(425, 75), Point(600, 250),
        ])
    else:
        state.geometry = fractal_preset_geometry(12)
    state.preset_id = 12 if index == 2 else 0
    state.random_colors = True
    state.endpoint0_revealed = False
    state.endpoint1_revealed = False
    state.dragging = False
    _ = state.set_depth(depth)
    state.reset_render_progress()
    return True
