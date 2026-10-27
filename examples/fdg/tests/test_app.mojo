from std.testing import assert_true, assert_almost_equal, assert_equal
from moxi import App, Rect, Point, Event, PointerEvent, ScrollEvent, SvgSceneRenderer, KeyEvent, ClickEvent
from moxi.event import POINTER_DOWN_KIND, POINTER_MOVE_KIND, POINTER_CANCEL_KIND, POINTER_UP_KIND, KEY_LEFT, KEY_ENTER
from graph_app import GraphApp, CANVAS, PAUSE, RESTART, dispatch_graph_event
from layout import sample_graph

def main() raises:
    var app = App[GraphApp](GraphApp(sample_graph()), Rect(0, 0, 1000, 760))
    var bounds = app.view.bounds_for(CANVAS)
    app.component.fit(bounds)
    var p = app.component.screen(0, bounds)
    assert_equal(app.component.hit(p, bounds), 0)
    var anchor = app.component.world(p, bounds)
    app.component.zoom_at(p, bounds, 1.5)
    var after = app.component.world(p, bounds)
    assert_almost_equal(anchor.x, after.x, atol=0.001)
    assert_almost_equal(anchor.y, after.y, atol=0.001)
    p = app.component.screen(0, bounds)
    _ = app.dispatch(Event(PointerEvent(POINTER_DOWN_KIND, p)))
    assert_true(app.component.graph.nodes[0].pinned)
    var original = app.component.graph.nodes[0].x
    _ = app.dispatch(Event(PointerEvent(POINTER_MOVE_KIND, Point(p.x + 30, p.y))))
    assert_almost_equal(Float32(app.component.graph.nodes[0].x - original), 30 / app.component.zoom, atol=0.01)
    _ = app.dispatch(Event(PointerEvent(POINTER_CANCEL_KIND, p)))
    assert_true(not app.component.graph.nodes[0].pinned and not app.component.dragging)
    # Native App turns an in-bounds release into CLICK_KIND.
    p = app.component.screen(0, bounds)
    _ = app.dispatch(Event(PointerEvent(POINTER_DOWN_KIND, p)))
    _ = app.dispatch(Event(PointerEvent(POINTER_UP_KIND, p)))
    assert_true(not app.component.graph.nodes[0].pinned and not app.component.dragging)
    _ = dispatch_graph_event(app, Event(KeyEvent(KEY_LEFT)))
    assert_equal(app.component.selected, len(app.component.graph.nodes) - 1)
    assert_equal(app.runtime.focus_id(), CANVAS)
    _ = dispatch_graph_event(app, Event(KeyEvent(KEY_ENTER)))
    assert_true(app.component.neighbors_only)
    var old_zoom = app.component.zoom
    _ = app.dispatch(Event(ScrollEvent(p, Point(0, 3))))
    assert_true(app.component.zoom > old_zoom)
    # A background drag pans, then release ends capture.
    var corner = Point(bounds.x + 10, bounds.y + 10)
    assert_equal(app.component.hit(corner, bounds), -1)
    var old_pan = app.component.pan
    _ = app.dispatch(Event(PointerEvent(POINTER_DOWN_KIND, corner)))
    _ = app.dispatch(Event(PointerEvent(POINTER_MOVE_KIND, Point(corner.x + 25, corner.y + 25))))
    _ = app.dispatch(Event(PointerEvent(POINTER_UP_KIND, corner)))
    assert_almost_equal(app.component.pan.x, old_pan.x + 25, atol=0.001)
    assert_true(not app.component.dragging)
    var pause = app.view.bounds_for(PAUSE)
    _ = app.dispatch(Event(ClickEvent(Point(pause.x + 5, pause.y + 5))))
    assert_true(app.component.graph.paused)
    var restart = app.view.bounds_for(RESTART)
    _ = app.dispatch(Event(ClickEvent(Point(restart.x + 5, restart.y + 5))))
    assert_true(not app.component.graph.paused and app.component.graph.active())
    app.component.query.set_text("node-12")
    app.component.find_next()
    assert_equal(app.component.selected, 12)
    app.component.query.set_text("no such node")
    app.component.find_next()
    assert_true(app.component.message.startswith("No match:"))
    var renderer = SvgSceneRenderer(1000, 760)
    renderer.render_scene(app.component.scene(bounds))
    assert_true(renderer.markup().startswith("<svg"))
    with open("/tmp/moxi-fdg-test.svg", "w") as out:
        out.write(renderer.markup())
    print("app: drag/release/cancel, background pan, routed wheel/keys, pause/restart, search, scene SVG pass")
