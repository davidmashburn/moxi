"""Typed component-slot and stable action-routing contract test."""

from moxi import test_check
from moxi import (
    App,
    CLICK_KIND,
    COMPOSED_COUNTER_ID_OFFSET,
    COMPOSED_COUNTER_SLOT_ID,
    ComposedState,
    COUNTER_INCREMENT_ACTION,
    Event,
    Point,
    Rect,
)


def main():
    var app = App[ComposedState](
        ComposedState(),
        Rect(0.0, 0.0, 480.0, 360.0),
    )
    test_check(app.view_is_valid())
    test_check(app.view.child(1).id == COMPOSED_COUNTER_SLOT_ID)
    test_check(app.view.child(2).id == COMPOSED_COUNTER_ID_OFFSET + 1)
    test_check(app.view.child(4).id == COMPOSED_COUNTER_ID_OFFSET + 3)
    test_check(app.action_id(COMPOSED_COUNTER_ID_OFFSET + 3) == COUNTER_INCREMENT_ACTION)

    var button = app.view.child(4).bounds
    var click = Event()
    click.kind = CLICK_KIND
    click.position = Point(
        button.x + button.width * 0.5,
        button.y + button.height * 0.5,
    )
    test_check(app.dispatch(click))
    test_check(app.component.counter.component.count == 1)
    test_check(app.view.child(4).text == "Increment")
    var commands = app.paint()
    test_check(commands.command(5).action_id == COUNTER_INCREMENT_ACTION)
    test_check(app.runtime.widget_count() == 5)

    var local = app.component.counter.project_view(app.view)
    test_check(local.child(2).id == 3)
    test_check(local.child(2).text == "Increment")
    print("Moxi composed-component test passed")
