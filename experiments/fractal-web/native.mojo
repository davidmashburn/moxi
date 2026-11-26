"""Independent native renderer oracle; never imports the browser ABI."""
from std.sys import argv
from moxi import FractalState
from fractal_fixtures import set_fixture

def main() raises:
    var args = argv()
    for index in range(3):
        var state = FractalState()
        _ = set_fixture(state, index)
        var loops = 0
        while not state.render_complete():
            _ = state.advance_render(1000000)
            loops += 1
        with open(String(args[1], "/native-", index, ".pixels.json"), "w") as file:
            file.write(state.raster.pixels)
        print("CASE", index, state.depth.text(), state.cursor.emitted.text(), Int(state.coordinate_overflow), loops)
