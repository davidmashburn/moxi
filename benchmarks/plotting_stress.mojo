"""Million-row scatter benchmark with deterministic level-of-detail output."""

from moxi import Color, PLOT_SCATTER, Plot, Rect


def main():
    var plot = Plot(Rect(0.0, 0.0, 1280.0, 720.0))
    var series_id = plot.add_series("1m scatter", Color(0.35, 0.75, 1.0, 0.75), PLOT_SCATTER)
    for index in range(1000000):
        var x = Float32(index % 10000) * 0.001
        var y = Float32((index * 37) % 10000) * 0.0001
        _ = plot.add_point(series_id, x, y)
    plot.set_scatter_point_limit(50000)
    plot.fit_to_data()
    var scene = plot.build_scene()
    print("Moxi stress scatter source rows: ", plot.point_count(series_id))
    print("Moxi stress scatter rendered limit: 50000")
    print("Moxi stress scatter scene commands: ", scene.count())
    print("Moxi stress timing: /usr/bin/time reports wall-clock process time")
