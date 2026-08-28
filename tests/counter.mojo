"""State and hit-testing contract test for the counter scenario."""

from moxi import App, ClickEvent, CounterState, Point, Rect


def main():
    var component = CounterState()
    var app = App[CounterState](component, Rect(0.0, 0.0, 384.0, 184.0))

    assert not app.update(ClickEvent(Point(12.0, 12.0)))
    assert app.component.count == 0

    assert app.update(ClickEvent(Point(72.0, 130.0)))
    assert app.component.count == 1
    assert app.view.child(1).text == "Count: 1"

    assert app.update(ClickEvent(Point(72.0, 130.0)))
    assert app.component.count == 2
    print("Moxi counter test passed")
