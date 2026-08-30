"""Repeated plotting workload over the shared showcase scenario."""

from moxi import PerformanceCounters, SoftwareSceneRenderer, make_plot_scenario
from moxi import Rect


def main() raises:
    var plot = make_plot_scenario(Rect(0.0, 0.0, 640.0, 420.0))
    var renderer = SoftwareSceneRenderer(640, 420)
    var metrics = PerformanceCounters()
    var passes = 100
    for _ in range(passes):
        var scene = plot.build_scene()
        renderer.render_scene(scene)
        metrics.record_frame(0, 0, scene.count(), scene.count(), renderer.rasterized_pixels)
    print("Moxi plot benchmark passes: ", passes)
    print("Moxi plot benchmark commands/frame: ", metrics.scene_commands // passes)
    print("Moxi plot benchmark rasterized pixels/frame: ", metrics.rasterized_pixels // passes)
    print("Moxi plot benchmark checksum: ", renderer.checksum())
    print("Moxi plot benchmark timing: /usr/bin/time reports wall-clock process time")
