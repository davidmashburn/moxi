"""State and hit-testing contract test for the counter scenario."""

from moxi import ClickEvent, CounterState, Point


def main():
    var state = CounterState()
    var view = state.view()

    state.update(ClickEvent(Point(12.0, 12.0)), view.button)
    assert state.count == 0

    state.update(ClickEvent(Point(72.0, 102.0)), view.button)
    assert state.count == 1
    view = state.view()
    assert view.label.text == "Count: 1"

    state.update(ClickEvent(Point(72.0, 102.0)), view.button)
    assert state.count == 2
    print("Moxi counter test passed")
