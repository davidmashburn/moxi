"""Deterministic composition, layout, and hit-testing contract test."""

from moxi import test_check
from moxi import (
    BUTTON_KIND,
    PANEL_KIND,
    SURFACE_KIND,
    Color,
    ColumnRuntime,
    ColumnView,
    Point,
    Rect,
    Style,
)


def main():
    var column = ColumnView(Rect(0.0, 0.0, 200.0, 160.0), 10.0, 5.0)
    column.add_label(1, "Title", 20.0)
    column.add_label(2, "Count: 0", 30.0)
    column.add_button_styled(
        3,
        "Increment",
        40.0,
        Style(
            Color(0.90, 0.20, 0.25, 1.0),
            Color(1.0, 1.0, 1.0, 1.0),
            6.0,
            14.0,
        ),
    )
    column.set_panel(
        9,
        Rect(4.0, 4.0, 192.0, 152.0),
        Style(
            Color(0.12, 0.14, 0.22, 1.0),
            Color(1.0, 1.0, 1.0, 1.0),
            12.0,
            0.0,
        ),
    )
    column.layout()

    test_check(column.child_count() == 3)

    var title = column.child(0)
    var count = column.child(1)
    var button = column.child(2)

    test_check(title.bounds.x == 10.0)
    test_check(title.bounds.y == 10.0)
    test_check(title.bounds.width == 180.0)
    test_check(title.bounds.height == 20.0)
    test_check(count.bounds.y == 35.0)
    test_check(button.bounds.y == 70.0)
    test_check(button.bounds.height == 40.0)

    test_check(column.hit_test(Point(20.0, 80.0)) == 3)
    test_check(column.hit_test(Point(20.0, 50.0)) == -1)

    var runtime = ColumnRuntime()
    runtime.reconcile(column)
    var commands = runtime.paint()
    test_check(runtime.widget_count() == 3)
    test_check(commands.count() == 5)
    test_check(commands.command(0).kind == SURFACE_KIND)
    test_check(commands.command(1).kind == PANEL_KIND)
    test_check(commands.command(1).id == 9)
    test_check(commands.command(2).text == "Title")
    test_check(commands.command(2).slot == 0)
    test_check(commands.command(3).slot == 1)
    test_check(commands.command(4).kind == BUTTON_KIND)
    test_check(commands.command(4).slot == 0)
    test_check(commands.command(4).style.corner_radius == 6.0)
    test_check(runtime.hit_test(Point(20.0, 80.0)) == 3)
    print("Moxi layout test passed")
