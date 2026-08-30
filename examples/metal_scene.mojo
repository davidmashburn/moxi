"""GPU scene smoke demo; links the offscreen Metal renderer."""

from moxi import Color, MacOSMetalRenderer, Point, Rect, Scene


def main() raises:
    var scene = Scene()
    scene.append_rect(
        1,
        Rect(32.0, 32.0, 240.0, 140.0),
        Color(0.12, 0.35, 0.80, 1.0),
    )
    scene.append_line(
        2,
        Point(32.0, 32.0),
        Point(272.0, 172.0),
        Color(1.0, 0.45, 0.2, 1.0),
        4.0,
    )
    var renderer = MacOSMetalRenderer(320, 220)
    if not renderer.is_ready():
        print("Moxi Metal unavailable")
        return
    renderer.render_scene(scene)
    print("Moxi Metal frames: ", renderer.frame_count())
    print("Moxi Metal vertices: ", renderer.vertex_count())
    print("Moxi Metal checksum: ", renderer.checksum())
    renderer.shutdown()
