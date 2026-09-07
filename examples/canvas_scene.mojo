"""Export the canonical Moxi plot scene through canvas_mojo."""

from moxi import (
    CanvasSceneRenderer,
    CANVAS_SCENE_PLOT,
    canonical_canvas_scene_fixture,
    make_canvas_scene,
)


def main() raises:
    var fixture = canonical_canvas_scene_fixture(CANVAS_SCENE_PLOT)
    var scene = make_canvas_scene(fixture.id)
    var renderer = CanvasSceneRenderer(
        fixture.width,
        fixture.height,
        fixture.background,
    )
    renderer.render_scene(scene)
    renderer.write_png("/tmp/moxi-canvas-scene.png")
    print("Moxi canvas scene commands: ", renderer.command_count)
    print("Moxi canvas scene fallbacks: ", renderer.fallback_count)
    print("Moxi canvas scene checksum: ", renderer.checksum())
    print("Moxi canvas scene output: /tmp/moxi-canvas-scene.png")
