"""Deterministic composition, layout, and hit-testing contract test."""

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

    assert column.child_count() == 3

    var title = column.child(0)
    var count = column.child(1)
    var button = column.child(2)

    assert title.bounds.x == 10.0
    assert title.bounds.y == 10.0
    assert title.bounds.width == 180.0
    assert title.bounds.height == 20.0
    assert count.bounds.y == 35.0
    assert button.bounds.y == 70.0
    assert button.bounds.height == 40.0

    assert column.hit_test(Point(20.0, 80.0)) == 3
    assert column.hit_test(Point(20.0, 50.0)) == -1

    var runtime = ColumnRuntime()
    runtime.reconcile(column)
    var commands = runtime.paint()
    assert runtime.widget_count() == 3
    assert commands.count() == 5
    assert commands.command(0).kind == SURFACE_KIND
    assert commands.command(1).kind == PANEL_KIND
    assert commands.command(1).id == 9
    assert commands.command(2).text == "Title"
    assert commands.command(2).slot == 0
    assert commands.command(3).slot == 1
    assert commands.command(4).kind == BUTTON_KIND
    assert commands.command(4).slot == 0
    assert commands.command(4).style.corner_radius == 6.0
    assert runtime.hit_test(Point(20.0, 80.0)) == 3
    print("Moxi layout test passed")
