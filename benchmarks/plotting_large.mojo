"""Large-data plot scene-generation benchmark without rasterizing every point."""

from moxi import Color, PLOT_SCATTER, PerformanceCounters, Plot, Rect


def main():
    var line = Plot(Rect(0.0, 0.0, 1280.0, 720.0))
    var line_id = line.add_series("10k line", Color(0.2, 0.8, 1.0, 1.0))
    for index in range(10000):
        var x = Float32(index) * 0.01
        var y = Float32((index * 37) % 100) * 0.01
        _ = line.add_point(line_id, x, y)
    line.fit_to_data()
    line.set_line_point_limit(2048)
    var line_scene = line.build_scene()

    var scatter = Plot(Rect(0.0, 0.0, 1280.0, 720.0))
    var scatter_id = scatter.add_series(
        "100k scatter",
        Color(1.0, 0.45, 0.25, 0.8),
        PLOT_SCATTER,
    )
    for index in range(100000):
        var x = Float32(index % 1000) * 0.01
        var y = Float32((index * 17) % 1000) * 0.001
        _ = scatter.add_point(scatter_id, x, y)
    scatter.set_scatter_point_limit(20000)
    scatter.fit_to_data()
    var scatter_scene = scatter.build_scene()

    var metrics = PerformanceCounters()
    metrics.record_frame(0, 10000, line_scene.count(), line_scene.count())
    metrics.record_frame(0, 100000, scatter_scene.count(), scatter_scene.count())
    print("Moxi large-plot line rows: 10000")
    print("Moxi large-plot line commands: ", line_scene.count())
    print("Moxi large-plot line limit: 2048")
    print("Moxi large-plot scatter rows: 100000")
    print("Moxi large-plot scatter rendered limit: 20000")
    print("Moxi large-plot scatter commands: ", scatter_scene.count())
    print("Moxi large-plot average operations/frame: ", metrics.average_operations())
    print("Moxi large-plot timing: /usr/bin/time reports wall-clock process time")
