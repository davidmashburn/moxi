from moxi import App, Rect, Event, Point, SvgSceneRenderer
from moxi.paint import scene_from_paint
from moxi.event import POINTER_DOWN_KIND, POINTER_MOVE_KIND, POINTER_UP_KIND, SCROLL_KIND
from app import Density, CANVAS, CELLS, READY

def main() raises:
    var app = App[Density](Density(), Rect(0, 0, 640, 480))
    for i in range(CELLS):
        app.component.counts.append(i % 100)
    app.component.status = READY
    app.rebuild()
    var event = Event()
    event.kind = POINTER_DOWN_KIND
    event.position = Point(200, 200)
    _ = app.dispatch(event)
    event.kind = POINTER_MOVE_KIND
    event.position = Point(270, 230)
    _ = app.dispatch(event)
    event.kind = POINTER_UP_KIND
    _ = app.dispatch(event)
    event.kind = SCROLL_KIND
    event.scroll_delta = Point(0, 4)
    _ = app.dispatch(event)
    var scene = scene_from_paint(app.paint())
    var data = app.component.scene(app.view.bounds_for(CANVAS))
    for command in data.commands:
        scene.append(command)
    var renderer = SvgSceneRenderer(640, 480)
    renderer.render_scene(scene)
    print(renderer.markup())
