"""P05: bounded snapshot application; no FDG or browser geometry dependency."""
from std.sys import argv
from std.math import isfinite
from std.time import perf_counter_ns
from moxi import Rect, Color, PlotSelection, SvgSceneRenderer, SCENE_CLIP
from moxi_plot import PlotDataTable, PlotSpec, PlotRuntime, plot_from_spec

comptime SCHEMA_VERSION = 1
comptime MAX_ROWS = 64
comptime WIDTH = 720
comptime HEIGHT = 360


struct LinkedState:
    var runtime: PlotRuntime
    var spec: PlotSpec

    def __init__(out self, data: PlotDataTable, selected: Int, minimum: Float32):
        self.spec = PlotSpec("Assay response by dose")
        _ = self.spec.add_scatter("Samples", "x", "y", Color(0.12, 0.53, 0.68, 1.0))
        self.spec.add_filter_between("y", minimum, 100.0)
        _ = self.spec.add_click_select()
        _ = self.spec.add_keyboard()
        self.runtime = PlotRuntime(Rect(0, 0, WIDTH, HEIGHT))
        self.runtime.configure(self.spec)
        self.runtime.plot = plot_from_spec(self.spec, data, Rect(0, 0, WIDTH, HEIGHT))
        var selection = PlotSelection()
        if selected >= 0:
            _ = selection.add(selected)
        self.runtime.set_linked_selection(selection)


def main() raises:
    var args = argv()
    if len(args) < 6 or (len(args) - 4) % 2 != 0:
        raise Error("expected schema, selected key, minimum response, x/y pairs")
    var count = (len(args) - 4) // 2
    var version = Int(args[1])
    var selected = Int(args[2])
    var minimum = Float64(String(args[3]))
    if version != SCHEMA_VERSION or count > MAX_ROWS or selected < -1 or selected >= count:
        raise Error("unsupported schema or selection/row range")
    if not isfinite(minimum) or minimum < 0 or minimum > 100:
        raise Error("minimum response must be finite and in [0,100]")
    var data = PlotDataTable()
    for i in range(count):
        var x = Float64(String(args[4 + i * 2]))
        var y = Float64(String(args[5 + i * 2]))
        if not isfinite(x) or not isfinite(y) or x < 0 or x > 100 or y < 0 or y > 100:
            raise Error("coordinates must be finite and in [0,100]")
        _ = data.append_with_key(i, Float32(x), Float32(y))
    var start = perf_counter_ns()
    var state = LinkedState(data, selected, Float32(minimum))
    var layout_ns = perf_counter_ns() - start
    start = perf_counter_ns()
    var scene = state.runtime.build_scene()
    # This fixed-domain consumer has no pan/zoom and all marks fit the plot.
    # Existing Plot builds axes inside the data clip. Keep its real geometry,
    # but use the application canvas clip so axis labels survive standalone SVG.
    # This is local presentation policy, not a change to shared plot geometry.
    for i in range(scene.count()):
        var command = scene.command(i)
        if command.kind == SCENE_CLIP:
            command.bounds = Rect(0, 0, WIDTH, HEIGHT)
            scene.commands[i] = command
    var scene_ns = perf_counter_ns() - start
    start = perf_counter_ns()
    var renderer = SvgSceneRenderer(WIDTH, HEIGHT)
    renderer.render_scene(scene)
    var svg_ns = perf_counter_ns() - start
    var points = String("[")
    for i in range(state.runtime.plot.series[0].count()):
        var point = state.runtime.plot.series[0].points[i]
        var screen = state.runtime.plot.screen_point(point)
        if i > 0:
            points += ","
        points += String("{\"key\":", point.row_key, ",\"x\":", screen.x, ",\"y\":", screen.y, "}")
    points += "]"
    # The selected key and semantic node come from the actual Moxi runtime,
    # including clearing details when a filter removes the selected record.
    var key = -1
    if state.runtime.selected.found():
        key = state.runtime.selected.row_key
    var semantics = state.runtime.accessibility()
    print(String("{\"schema\":", SCHEMA_VERSION, ",\"selected\":", key,
                 ",\"points\":", points, ",\"sceneCommands\":", scene.count(),
                 ",\"semanticsCount\":", semantics.count(),
                 ",\"selectionSemantic\":", Int(semantics.node_for_id(20001).selected),
                 ",\"layoutNs\":", layout_ns, ",\"sceneNs\":", scene_ns,
                 ",\"svgNs\":", svg_ns, ",\"spec\":", state.spec.to_json(), "}"))
    print(renderer.markup())
