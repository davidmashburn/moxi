"""Contract tests for capture-aware pointer and drag/drop routing."""

from moxi import (
    App,
    ButtonControl,
    CLICK_KIND,
    Component,
    ColumnView,
    DRAG_BEGIN_KIND,
    DRAG_UPDATE_KIND,
    DROP_KIND,
    DragEvent,
    Event,
    POINTER_CANCEL_KIND,
    POINTER_MOVE_KIND,
    POINTER_UP_KIND,
    PointerEvent,
    Point,
    Rect,
    test_check,
)


struct InputState(Component):
    var last_kind: Int
    var last_target: Int
    var drops: Int

    def __init__(out self):
        self.last_kind = 0
        self.last_target = -1
        self.drops = 0

    def build(self, bounds: Rect) -> ColumnView:
        var view = ColumnView(bounds, 8.0, 4.0)
        view.add(ButtonControl(1, "Drag target", 40.0).node())
        view.layout()
        return view^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        self.last_kind = event.kind
        self.last_target = event.target
        if event.kind == DROP_KIND:
            self.drops += 1
            return True
        if event.kind == DRAG_UPDATE_KIND:
            return True
        return False


def main():
    var app = App[InputState](InputState(), Rect(0.0, 0.0, 240.0, 100.0))
    var point = Point(20.0, 20.0)
    test_check(app.dispatch(Event(PointerEvent(DRAG_BEGIN_KIND, point))))
    test_check(app.pressed_id() == 1)
    test_check(app.dispatch(Event(PointerEvent(DRAG_UPDATE_KIND, Point(500.0, 500.0)))))
    test_check(app.component.last_kind == DRAG_UPDATE_KIND)
    test_check(app.component.last_target == 1)
    test_check(app.dispatch(Event(DragEvent(DROP_KIND, Point(500.0, 500.0), payload="file"))))
    test_check(app.component.drops == 1)
    test_check(app.pressed_id() == -1)

    test_check(app.dispatch(Event(PointerEvent(DRAG_BEGIN_KIND, point))))
    test_check(app.dispatch(Event(PointerEvent(POINTER_UP_KIND, Point(500.0, 500.0)))))
    test_check(app.component.last_kind == POINTER_UP_KIND)
    test_check(app.component.last_target == 1)
    test_check(app.pressed_id() == -1)

    test_check(app.dispatch(Event(PointerEvent(DRAG_BEGIN_KIND, point))))
    _ = app.dispatch(Event(PointerEvent(POINTER_MOVE_KIND, Point(500.0, 500.0))))
    test_check(app.component.last_target == 1)
    test_check(app.dispatch(Event(PointerEvent(POINTER_CANCEL_KIND, Point(500.0, 500.0)))))
    test_check(app.pressed_id() == -1)
    test_check(app.dispatch(Event(PointerEvent(POINTER_MOVE_KIND, point))))
    test_check(app.hover_id() == 1)
    test_check(app.dispatch(Event(PointerEvent(POINTER_CANCEL_KIND, point))))
    test_check(app.hover_id() == -1)

    print("Moxi input-routing test passed")
