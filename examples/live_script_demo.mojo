"""Headless smoke test for the editable live-component source module."""

from moxi import Rect, SoftwareSceneRenderer
from editable_showcase import EditableShowcase


def main() raises:
    var component = EditableShowcase()
    var scene = component.scene(Rect(0.0, 0.0, 640.0, 360.0))
    var renderer = SoftwareSceneRenderer(640, 360)
    renderer.render_scene(scene)
    print("Moxi editable component scene commands: ", scene.count())
    print("Moxi editable component checksum: ", renderer.checksum())
