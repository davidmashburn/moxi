"""One native host for the interactive entry point and its UI replay."""
from moxi import App, Rect, WindowConfig
from moxi.event import NONE_KIND, FRAME_TICK_KIND, Event
from moxi.macos import MacOSWindow, MacOSRenderer, MacOSCanvasSceneRenderer
from editor import MotionEditor, CANVAS
from drawing import draw

comptime MotionApp = App[MotionEditor]


def open_app(mut window: MacOSWindow) raises -> MotionApp:
    var config = WindowConfig("Moxi / Motion from a sketch", 1120, 860)
    config.set_min_size(960, 760)
    window.open(config)
    var size = window.size()
    return MotionApp(MotionEditor(), Rect(0, 0, size.width, size.height))


def render(mut app: MotionApp, mut window: MacOSWindow, mut paint: MacOSRenderer, mut graph: MacOSCanvasSceneRenderer) raises:
    app.render(paint)
    var bounds = app.view.bounds_for(CANVAS)
    var scene = draw(app.component.studio, bounds)
    graph.set_clip(bounds)
    graph.begin_scene()
    for i in range(scene.count()):
        graph.draw_scene_command(scene.command(i))
    graph.end_scene()
    window.present()


def drain(mut app: MotionApp, mut window: MacOSWindow) raises -> Bool:
    window.pump()
    var changed = False
    var event = window.poll_event()
    while event.kind != NONE_KIND:
        changed = app.dispatch(event) or changed
        event = window.poll_event()
    return changed


def tick(mut app: MotionApp, delta: Float32 = 0) -> Bool:
    var event = Event()
    event.kind = FRAME_TICK_KIND
    event.delta_seconds = delta
    return app.dispatch(event)
