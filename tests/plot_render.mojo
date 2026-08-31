"""Compact plot render-packet contract tests."""

from moxi import (
    Color,
    PLOT_BAR,
    PLOT_LINE,
    PLOT_RENDER_INSTANCES,
    PLOT_RENDER_LINES,
    PLOT_SCATTER,
    Plot,
    Point,
    Rect,
    SoftwareSceneRenderer,
    test_check,
)


def main() raises:
    var plot = Plot(Rect(0.0, 0.0, 320.0, 240.0))
    var line = plot.add_series("line", Color(0.2, 0.8, 1.0, 1.0), PLOT_LINE)
    _ = plot.add_point(line, 0.0, 0.0)
    _ = plot.add_point(line, 1.0, 2.0)
    _ = plot.add_point(line, 2.0, 1.0)
    var bars = plot.add_series("bars", Color(1.0, 0.4, 0.2, 1.0), PLOT_BAR)
    _ = plot.add_point(bars, 0.0, 1.0)
    _ = plot.add_point(bars, 1.0, 2.0)
    var points = plot.add_series(
        "points", Color(0.3, 1.0, 0.4, 1.0), PLOT_SCATTER
    )
    _ = plot.add_point(points, 0.5, 0.5)
    plot.fit_to_data()

    var packet = plot.build_render_packet()
    test_check(packet.source_point_count == 6)
    test_check(packet.emitted_point_count == 6)
    test_check(packet.line_count() == 2)
    test_check(packet.instance_count() == 3)
    test_check(packet.mark_count() == 5)
    test_check(packet.total_byte_count() == (2 * 10 + 3 * 10) * 4)
    test_check(packet.batch_count() == 2)
    test_check(packet.batch(0).kind == PLOT_RENDER_LINES)
    test_check(packet.batch(0).count == 2)
    test_check(packet.batch(1).kind == PLOT_RENDER_INSTANCES)
    test_check(packet.batch(1).count == 3)
    var first_line = packet.line(0)
    test_check(first_line.start.x != first_line.end.x)
    var first_marker = packet.instance(2)
    test_check(first_marker.corner_radius > 0.0)
    var chrome = plot.build_scene(False)
    test_check(chrome.count() < plot.build_scene().count())
    var complete_renderer = SoftwareSceneRenderer(320, 240)
    complete_renderer.render_scene(plot.build_scene())
    var complete_checksum = complete_renderer.checksum()
    var split_renderer = SoftwareSceneRenderer(320, 240)
    split_renderer.render_scene(chrome)
    split_renderer.draw_plot_packet(packet)
    test_check(split_renderer.checksum() == complete_checksum)

    var dense = Plot(Rect(0.0, 0.0, 180.0, 100.0))
    var dense_id = dense.add_series(
        "dense", Color(0.2, 0.8, 0.4, 1.0), PLOT_SCATTER
    )
    for index in range(10000):
        _ = dense.add_point(
            dense_id,
            Float32(index % 1000) * 0.01,
            Float32((index * 37) % 1000) * 0.01,
        )
    dense.fit_to_data()
    var dense_packet = dense.build_render_packet()
    test_check(dense_packet.source_point_count == 10000)
    test_check(dense_packet.emitted_point_count <= 100 * 36 // 4 + 1)
    test_check(dense_packet.emitted_point_count < dense_packet.source_point_count)

    var renderer = SoftwareSceneRenderer(320, 240)
    renderer.render_plot_packet(packet)
    test_check(renderer.checksum() > 0)
    test_check(renderer.frame_count == 1)
    print("Moxi plot-render packet test passed")
