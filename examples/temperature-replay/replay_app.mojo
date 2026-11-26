"""Example-owned offline host for an ordinary Moxi App and real Plot scenes."""
from std.sys import argv
from std.collections import List
from std.math import isfinite
from moxi import App, ColumnView, Component, Color, Rect, Scene, SvgSceneRenderer, SCENE_CLIP
from moxi.json import json_quote
from moxi_plot import Plot, PlotDataTable, PlotPoint, PlotSpec, plot_from_spec, PLOT_INTERVAL, PLOT_SCATTER

comptime WIDTH = 820
comptime TEMPERATURE_HEIGHT = 280
comptime PROXY_HEIGHT = 180
comptime TEMPERATURE_CANVAS = 1
comptime PROXY_CANVAS = 2
comptime SAMPLE_COUNT = 25
comptime CADENCE = 10
comptime HORIZON = 30


struct ReplayMode(ImplicitlyCopyable):
    var value: Int
    comptime TEMPERATURE = Self(0)
    comptime PROXY = Self(1)

    def __init__(out self, value: Int):
        self.value = value


def style_plot(mut plot: Plot):
    plot.background = Color(0.97, 0.98, 0.97, 1)
    plot.axis_color = Color(0.12, 0.22, 0.23, 1)
    plot.grid_color = Color(0.75, 0.81, 0.79, 0.6)
    plot.show_legend = False
    plot.set_x_domain(0, 240)


def segment(mut plot: Plot, label: String, color: Color, time: Float32,
            origin: Float32, prediction: Float32):
    var id = plot.add_series(label, color)
    _ = plot.add_point(id, time, origin)
    _ = plot.add_point(id, time + HORIZON, prediction)


def residual_interval(mut plot: Plot, color: Color, width: Float32, time: Float32,
                      prediction: Float32, radius: Float32):
    var id = plot.add_series("Calibration residual interval", color, PLOT_INTERVAL)
    var index = plot.series_index(id)
    plot.series[index].line_width = width
    var end = PlotPoint(time + HORIZON, prediction - radius)
    end.y2 = prediction + radius
    end.has_y2 = True
    plot.series[index].append(end)


struct ReplayApp(Component):
    var data: PlotDataTable
    var mode: ReplayMode
    var time: Int
    var without: Float32
    var with_proxy: Float32
    var radius_without: Float32
    var radius_with: Float32
    var minimum: Float32
    var maximum: Float32

    def __init__(out self, data: PlotDataTable, mode: ReplayMode, time: Int,
                 without: Float32, with_proxy: Float32, radius_without: Float32,
                 radius_with: Float32, minimum: Float32, maximum: Float32):
        self.data = data
        self.mode = mode
        self.time = time
        self.without = without
        self.with_proxy = with_proxy
        self.radius_without = radius_without
        self.radius_with = radius_with
        self.minimum = minimum
        self.maximum = maximum

    def build(self, bounds: Rect) -> ColumnView:
        var view = ColumnView(bounds, 0, 0)
        view.add_canvas(TEMPERATURE_CANVAS, "Temperature forecast", TEMPERATURE_HEIGHT)
        if self.mode.value == ReplayMode.PROXY.value:
            view.add_canvas(PROXY_CANVAS, "Artificial indoor CO2 proxy", PROXY_HEIGHT)
        view.layout()
        return view^

    def temperature_plot(self, bounds: Rect) -> Plot:
        var spec = PlotSpec("Temperature (C) / elapsed seconds")
        _ = spec.add_line("Retrospective synthetic trace", "x", "y", Color(0.10, 0.37, 0.39, 1))
        var plot = plot_from_spec(spec, self.data, bounds)
        style_plot(plot)
        plot.set_y_domain(self.minimum, self.maximum)
        var origin = self.data.float_field_at("y", self.time // CADENCE)
        residual_interval(plot, Color(0.75, 0.38, 0.05, 0.45), 8, Float32(self.time),
                          self.without, self.radius_without)
        if self.mode.value == ReplayMode.PROXY.value:
            residual_interval(plot, Color(0.10, 0.45, 0.32, 0.65), 4, Float32(self.time),
                              self.with_proxy, self.radius_with)
        segment(plot, "Persistence", Color(0.40, 0.42, 0.50, 1), Float32(self.time), origin, origin)
        segment(plot, "Without proxy", Color(0.75, 0.38, 0.05, 1), Float32(self.time), origin, self.without)
        if self.mode.value == ReplayMode.PROXY.value:
            segment(plot, "With proxy", Color(0.10, 0.45, 0.32, 1), Float32(self.time), origin, self.with_proxy)
        var selected = plot.add_series("Origin and outcome", Color(0.32, 0.23, 0.62, 1), PLOT_SCATTER)
        _ = plot.add_point(selected, Float32(self.time), origin)
        _ = plot.add_point(selected, Float32(self.time + HORIZON),
                           self.data.float_field_at("y", (self.time + HORIZON) // CADENCE))
        return plot^

    def proxy_plot(self, bounds: Rect) -> Plot:
        var spec = PlotSpec("Artificial CO2 proxy (arbitrary units) / elapsed seconds")
        _ = spec.add_line("Constructed proxy", "x", "proxy", Color(0.24, 0.31, 0.65, 1))
        var plot = plot_from_spec(spec, self.data, bounds)
        style_plot(plot)
        plot.set_y_domain(300, 1000)
        var selected = plot.add_series("Input at origin", Color(0.32, 0.23, 0.62, 1), PLOT_SCATTER)
        _ = plot.add_point(selected, Float32(self.time), self.data.float_field_at("proxy", self.time // CADENCE))
        return plot^

    def scene(self, view: ColumnView) -> Scene:
        # Like the normal native hosts, use the App's reconciled canvas bounds.
        var plot = self.temperature_plot(view.bounds_for(TEMPERATURE_CANVAS))
        var scene = plot.build_scene()
        if self.mode.value == ReplayMode.PROXY.value:
            var proxy = self.proxy_plot(view.bounds_for(PROXY_CANVAS))
            var other = proxy.build_scene()
            for i in range(other.count()):
                scene.append(other.command(i))
        # The shared plot clips its own tick labels to the data area. This
        # fixed-domain offline host has no pan/zoom: widen only its scene clips
        # to the application bounds, keeping all genuine Moxi geometry.
        var height = TEMPERATURE_HEIGHT
        if self.mode.value == ReplayMode.PROXY.value:
            height += PROXY_HEIGHT
        for i in range(scene.count()):
            var command = scene.command(i)
            if command.kind == SCENE_CLIP:
                command.bounds = Rect(0, 0, WIDTH, Float32(height))
                scene.commands[i] = command
        return scene^


def main() raises:
    var args = argv()
    # mode, origin, both predictions/radii, fixed y domain, then 25 triples.
    if len(args) != 9 + SAMPLE_COUNT * 3:
        raise Error("expected mode, origin, predictions, radii, domain, 25 time/temperature/proxy triples")
    var mode_value = Int(args[1])
    if mode_value != ReplayMode.TEMPERATURE.value and mode_value != ReplayMode.PROXY.value:
        raise Error("unsupported replay mode")
    var time = Int(args[2])
    if time < CADENCE or time > 240 - HORIZON or time % CADENCE != 0:
        raise Error("origin must align to an eligible sample")
    var numbers = List[Float32]()
    for i in range(3, len(args)):
        var value = Float64(String(args[i]))
        if not isfinite(value) or abs(value) > 10000:
            raise Error("bounded finite fixture values required")
        numbers.append(Float32(value))
    if numbers[2] < 0 or numbers[3] < 0 or numbers[4] >= numbers[5]:
        raise Error("invalid calibration radii or y domain")
    var data = PlotDataTable()
    _ = data.add_float_column("proxy")
    for i in range(SAMPLE_COUNT):
        var offset = 6 + i * 3
        if numbers[offset] != Float32(i * CADENCE):
            raise Error("fixture times must use the fixed cadence")
        _ = data.append_with_key(i, numbers[offset], numbers[offset + 1])
        _ = data.set_float_field("proxy", i, numbers[offset + 2])
    var mode = ReplayMode(mode_value)
    var height = TEMPERATURE_HEIGHT
    if mode.value == ReplayMode.PROXY.value:
        height += PROXY_HEIGHT
    var app = App[ReplayApp](ReplayApp(data, mode, time, numbers[0], numbers[1],
        numbers[2], numbers[3], numbers[4], numbers[5]), Rect(0, 0, WIDTH, Float32(height)))
    if app.view.bounds_for(TEMPERATURE_CANVAS).height <= 0:
        raise Error("Moxi App did not lay out the temperature canvas")
    var scene = app.component.scene(app.view)
    var renderer = SvgSceneRenderer(WIDTH, height)
    renderer.render_scene(scene)
    var commands = app.paint()
    print(String("{\"origin\":", time, ",\"sceneCommands\":", scene.count(),
        ",\"appPaintCommands\":", commands.count(), ",\"sampleCount\":", data.row_count(),
        ",\"canvases\":", 1 + mode.value, ",\"without\":", numbers[0],
        ",\"withProxy\":", numbers[1], ",\"svg\":", json_quote(renderer.markup()), "}"))
