"""Emit deterministic software-renderer frames for the visual corpus."""

from moxi import (
    App,
    Color,
    ColumnRuntime,
    ColumnView,
    Point,
    Rect,
    Scene,
    SoftwareSceneRenderer,
    SliderControl,
    ThemeShowcaseState,
    Transform,
    canonical_scenarios,
    make_plot_scenario,
    scene_from_paint,
    test_check,
)


comptime GOLDEN_RENDERER_VERSION = "software-v1"


def emit(
    label: String,
    scenario: String,
    renderer: SoftwareSceneRenderer,
):
    print(
        "BEGIN ",
        label,
        " ",
        scenario,
        " ",
        renderer.width,
        " ",
        renderer.height,
        " ",
        renderer.checksum(),
        " ",
        GOLDEN_RENDERER_VERSION,
    )
    print(renderer.ppm())
    print("END ", label)


def theme_frame(label: String, mode: Int) raises:
    var app = App[ThemeShowcaseState](
        ThemeShowcaseState(),
        Rect(0.0, 0.0, 240.0, 160.0),
    )
    app.component.theme_mode = mode
    app.rebuild()
    var renderer = SoftwareSceneRenderer(
        240,
        160,
        Color(0.04, 0.05, 0.08, 1.0),
    )
    renderer.render_scene(scene_from_paint(app.paint()))
    emit(label, "theme", renderer)


def text_fallback_frame() raises:
    # Text remains a resource-dependent operation in the software oracle, but
    # the surrounding geometry and command order are still exact. Keeping the
    # mixed-script labels in the scene makes fallback coverage reviewable by a
    # native text backend without inventing glyph pixels here.
    var scene = Scene()
    scene.append_rect(
        1,
        Rect(0.0, 0.0, 256.0, 96.0),
        Color(0.06, 0.08, 0.13, 1.0),
    )
    scene.append_text(
        2,
        "Latin · Ελληνικά · שלום · हिन्दी · 🙂",
        Rect(16.0, 18.0, 224.0, 24.0),
        Color(0.92, 0.95, 1.0, 1.0),
    )
    scene.append_text(
        3,
        "fallback and bidi probe",
        Rect(16.0, 52.0, 224.0, 20.0),
        Color(0.48, 0.82, 0.72, 1.0),
    )
    var renderer = SoftwareSceneRenderer(
        256,
        96,
        Color(0.06, 0.08, 0.13, 1.0),
    )
    renderer.render_scene(scene)
    test_check(scene.count() == 3)
    emit("text-mixed-fallback", "text", renderer)


def nested_clip_frame() raises:
    var scene = Scene()
    scene.append_rect(
        1,
        Rect(0.0, 0.0, 240.0, 128.0),
        Color(0.04, 0.05, 0.08, 1.0),
    )
    scene.push_clip(2, Rect(16.0, 16.0, 208.0, 96.0))
    scene.append_rect(
        3,
        Rect(-24.0, 24.0, 288.0, 32.0),
        Color(0.12, 0.28, 0.45, 1.0),
    )
    scene.push_clip(4, Rect(42.0, 32.0, 112.0, 48.0))
    scene.append_rounded_rect(
        5,
        Rect(24.0, 24.0, 184.0, 64.0),
        Color(0.30, 0.78, 0.62, 0.72),
        9.0,
    )
    scene.pop_clip()
    scene.append_transform(6, moxi_transform())
    scene.append_rect(
        7,
        Rect(172.0, 76.0, 72.0, 42.0),
        Color(0.95, 0.43, 0.24, 1.0),
    )
    scene.reset_transform()
    scene.pop_clip()
    var renderer = SoftwareSceneRenderer(
        240,
        128,
        Color(0.04, 0.05, 0.08, 1.0),
    )
    renderer.render_scene(scene)
    test_check(renderer.pixel(20, 30).blue > 0.1)
    test_check(renderer.pixel(4, 4).blue < 0.1)
    emit("nested-clipping-scrolling", "collection", renderer)


def moxi_transform() -> Transform:
    return Transform().translated(-18.0, 8.0)


def accessibility_focus_frame() raises:
    var view = ColumnView(Rect(0.0, 0.0, 240.0, 128.0), 12.0, 8.0)
    view.add_button(10, "Focused action", 32.0)
    view.add(SliderControl(11, "Volume", 0.5, 0.0, 1.0, 0.1, 28.0).node())
    view.layout()
    var runtime = ColumnRuntime()
    runtime.reconcile(view)
    test_check(runtime.set_focus(11))
    var semantics = runtime.accessibility()
    test_check(semantics.node_for_id(11).focused)

    # Paint an explicit focus ring alongside the retained command stream. The
    # ring is deliberately simple so every backend can compare its bounds and
    # color even when control text/glyphs use different native resources.
    var scene = scene_from_paint(runtime.paint())
    scene.append_rect(
        90,
        Rect(8.0, 52.0, 224.0, 36.0),
        Color(0.20, 0.78, 0.64, 0.35),
    )
    scene.append_rect(
        91,
        Rect(11.0, 55.0, 218.0, 30.0),
        Color(0.04, 0.05, 0.08, 1.0),
    )
    var renderer = SoftwareSceneRenderer(
        240,
        128,
        Color(0.04, 0.05, 0.08, 1.0),
    )
    renderer.render_scene(scene)
    emit("accessibility-focused-control", "form", renderer)


def plot_frame() raises:
    var plot = make_plot_scenario(Rect(0.0, 0.0, 320.0, 200.0))
    var renderer = SoftwareSceneRenderer(
        320,
        200,
        Color(0.04, 0.05, 0.08, 1.0),
    )
    renderer.render_scene(plot.build_scene())
    emit("plot-gallery", "plot", renderer)


def main() raises:
    var registry = canonical_scenarios()
    test_check(registry.is_valid())
    test_check(registry.index_for_fixture("theme") >= 0)
    test_check(registry.index_for_fixture("text") >= 0)
    test_check(registry.index_for_fixture("collection") >= 0)
    test_check(registry.index_for_fixture("plot") >= 0)

    theme_frame("theme-dark", 0)
    theme_frame("theme-light", 1)
    theme_frame("theme-emerald", 3)
    text_fallback_frame()
    nested_clip_frame()
    accessibility_focus_frame()
    plot_frame()
    print("Moxi software golden render passed")
