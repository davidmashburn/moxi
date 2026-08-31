"""GPU scene smoke demo; links the offscreen Metal renderer."""

from moxi import (
    MacOSMetalRenderer,
    Rect,
    SHOWCASE_METAL_SCENE,
    ShowcaseState,
)


def main() raises:
    var component = ShowcaseState(SHOWCASE_METAL_SCENE)
    var scene = component.scene(Rect(0.0, 0.0, 320.0, 220.0))
    var renderer = MacOSMetalRenderer(320, 220)
    if not renderer.is_ready():
        print("Moxi Metal unavailable")
        return
    renderer.render_scene(scene)
    print("Moxi Metal frames: ", renderer.frame_count())
    print("Moxi Metal vertices: ", renderer.vertex_count())
    print("Moxi Metal checksum: ", renderer.checksum())
    renderer.shutdown()
