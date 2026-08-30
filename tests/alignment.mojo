"""0.5 alignment and layout contract test."""

from moxi import test_check
from moxi import (
    ALIGN_CENTER,
    AlignmentState,
    App,
    ButtonControl,
    ColumnView,
    ClickEvent,
    Event,
    JUSTIFY_END,
    JUSTIFY_CENTER,
    JUSTIFY_SPACE_BETWEEN,
    Point,
    Rect,
    make_row,
)


def main():
    var app = App[AlignmentState](AlignmentState(), Rect(0.0, 0.0, 500.0, 300.0))
    test_check(app.view.main_alignment == JUSTIFY_CENTER)
    test_check(app.view.cross_alignment == ALIGN_CENTER)
    var title = app.view.child(0)
    var first = app.view.child(1)
    test_check(title.bounds.width == 180.0)
    test_check(first.bounds.width == 180.0)
    test_check(first.bounds.x == 160.0)
    test_check(first.bounds.y > 24.0)
    test_check(app.dispatch(
        Event(ClickEvent(Point(first.bounds.x + 2.0, first.bounds.y + 2.0)))
    ))
    test_check(app.component.selected == 2)

    var row = make_row(Rect(0.0, 0.0, 400.0, 100.0), 10.0, 10.0)
    row.add(ButtonControl(10, "One", 40.0).node())
    row.add(ButtonControl(11, "Two", 40.0).node())
    row.set_fixed_width(10, 80.0)
    row.set_fixed_width(11, 80.0)
    row.set_justify_content(JUSTIFY_END)
    row.set_align_items(ALIGN_CENTER)
    row.layout()
    test_check(row.child(0).bounds.x == 220.0)
    test_check(row.child(0).bounds.y == 30.0)
    test_check(row.child(1).bounds.x == 310.0)

    row.set_justify_content(JUSTIFY_SPACE_BETWEEN)
    row.layout()
    test_check(row.child(0).bounds.x == 10.0)
    test_check(row.child(1).bounds.x == 310.0)

    var column = ColumnView(Rect(0.0, 0.0, 200.0, 200.0), 10.0, 10.0)
    column.add(ButtonControl(20, "Top", 40.0).node())
    column.add(ButtonControl(21, "Bottom", 40.0).node())
    column.set_fixed_width(20, 80.0)
    column.set_fixed_width(21, 80.0)
    column.set_main_alignment(JUSTIFY_END)
    column.set_cross_alignment(ALIGN_CENTER)
    column.layout()
    test_check(column.child(0).bounds.x == 60.0)
    test_check(column.child(0).bounds.y == 100.0)
    print("Moxi alignment test passed")
