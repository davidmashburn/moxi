"""State and hit-testing contract test for the counter scenario."""

from moxi import test_check
from moxi import App, ClickEvent, CounterState, Point, Rect


def main():
    var component = CounterState()
    var app = App[CounterState](component, Rect(0.0, 0.0, 384.0, 184.0))

    test_check(not app.update(ClickEvent(Point(12.0, 12.0))))
    test_check(app.component.count == 0)

    test_check(app.update(ClickEvent(Point(72.0, 130.0))))
    test_check(app.component.count == 1)
    test_check(app.view.child(1).text == "Count: 1")

    test_check(app.update(ClickEvent(Point(72.0, 130.0))))
    test_check(app.component.count == 2)
    print("Moxi counter test passed")
