"""SVG Web-target serialization contract test."""

from moxi import Rect, SvgSceneRenderer, make_plot_scenario, test_check


def main() raises:
    var plot = make_plot_scenario(Rect(0.0, 0.0, 320.0, 240.0))
    var renderer = SvgSceneRenderer(320, 240)
    renderer.render_scene(plot.build_scene())
    test_check(renderer.frame_count == 1)
    test_check(renderer.markup().count_codepoints() > 100)
    test_check(renderer.markup().startswith("<svg"))
    test_check(renderer.markup().endswith("</svg>"))
    print("Moxi SVG test passed")
