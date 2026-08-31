"""Headless plotting showcase using the portable Moxi scene contract."""

from moxi import (
    Rect,
    SHOWCASE_PLOT,
    ShowcaseState,
    SoftwareSceneRenderer,
)


def main() raises:
    var component = ShowcaseState(SHOWCASE_PLOT)
    var bounds = Rect(0.0, 0.0, 640.0, 420.0)
    var scene = component.scene(bounds)
    var renderer = SoftwareSceneRenderer(640, 420)
    renderer.render_scene(scene)
    print("Moxi plot scene commands: ", scene.count())
    print("Moxi plot scene checksum: ", renderer.checksum())
    print("Moxi plot component scene: ", component.has_scene())
