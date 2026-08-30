"""Integration test for automatic portal scrolling and offset persistence."""

from moxi import (
    App,
    ColumnView,
    Component,
    Point,
    Rect,
    ScrollEvent,
    Event,
    SCROLL_KIND,
    test_check,
)


struct ScrollState(Component):
    def __init__(out self):
        pass

    def build(self, bounds: Rect) -> ColumnView:
        var view = ColumnView(bounds, 0.0, 0.0)
        var portal = view.add_portal(10, 40.0, 0.0, 0.0)
        view.add_label_to(portal, 11, "one", 20.0)
        view.add_label_to(portal, 12, "two", 20.0)
        view.add_label_to(portal, 13, "three", 20.0)
        view.add_label_to(portal, 14, "four", 20.0)
        view.layout()
        return view^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        return False


def main():
    var app = App[ScrollState](ScrollState(), Rect(0.0, 0.0, 200.0, 100.0))
    var initial = app.view.scroll_offset_for(10)
    test_check(initial == 0.0)
    test_check(app.dispatch(Event(ScrollEvent(Point(10.0, 10.0), Point(0.0, 30.0)))))
    test_check(app.view.scroll_offset_for(10) > 0.0)
    test_check(app.view.scroll_offset_for(10) <= app.view.scroll_max_offset(10))
    test_check(app.dispatch(Event(ScrollEvent(Point(10.0, 10.0), Point(0.0, -1000.0)))))
    test_check(app.view.scroll_offset_for(10) == 0.0)
    print("Moxi scroll-app test passed")
