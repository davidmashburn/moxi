"""Native-window showcase for Moxi's collection interaction primitives."""

from moxi import (
    App,
    INTERACTION_SHOWCASE_CANVAS_ID,
    InteractionShowcaseState,
    NONE_KIND,
    Rect,
    WindowConfig,
)
from moxi.macos import MacOSCanvasSceneRenderer, MacOSRenderer, MacOSWindow


def render_frame(
    mut app: App[InteractionShowcaseState],
    mut renderer: MacOSRenderer,
    mut scene_renderer: MacOSCanvasSceneRenderer,
) raises:
    app.render(renderer)
    var surface = app.view.bounds_for(INTERACTION_SHOWCASE_CANVAS_ID)
    scene_renderer.set_clip(surface)
    scene_renderer.render_scene(app.component.scene(surface))


def main() raises:
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    window.open(WindowConfig("Moxi · Collection Interaction Lab", 900.0, 760.0))
    var size = window.size()
    var app = App[InteractionShowcaseState](
        InteractionShowcaseState(),
        Rect(0.0, 0.0, size.width, size.height),
    )
    var scene_renderer = MacOSCanvasSceneRenderer()
    render_frame(app, renderer, scene_renderer)
    while window.is_open():
        window.pump()
        var event = window.poll_event()
        var changed = app.tick(1.0 / 60.0)
        if event.kind != NONE_KIND:
            changed = app.dispatch(event) or changed
        if changed:
            render_frame(app, renderer, scene_renderer)
