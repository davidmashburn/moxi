"""Contract tests for stack, grid, split, portal, and virtualization math."""

from moxi import (
    COLUMN_AXIS,
    ColumnView,
    LAYOUT_GRID,
    LAYOUT_PORTAL,
    LAYOUT_SPLIT,
    LAYOUT_STACK,
    Point,
    Rect,
    ScrollState,
    VirtualListState,
    visible_range,
)
from moxi.testing import test_check


def main():
    var view = ColumnView(Rect(0.0, 0.0, 320.0, 240.0), 10.0, 10.0)
    var stack = view.add_stack(10, 80.0, 4.0, 4.0)
    view.add_label_to(stack, 11, "top", 24.0)
    view.add_button_to(stack, 12, "button", 24.0)
    var grid = view.add_grid(20, 100.0, 2, 4.0, 4.0)
    view.add_label_to(grid, 21, "one", 20.0)
    view.add_label_to(grid, 22, "two", 20.0)
    view.add_label_to(grid, 23, "three", 20.0)
    var split = view.add_split(30, 0.0, 80.0, COLUMN_AXIS, 0.25, 2.0, 2.0)
    view.add_label_to(split, 31, "left", 20.0)
    view.add_label_to(split, 32, "right", 20.0)
    var portal = view.add_portal(40, 60.0, 2.0, 2.0, 18.0)
    view.add_label_to(portal, 41, "first", 20.0)
    view.add_label_to(portal, 42, "second", 20.0)
    view.add_label_to(portal, 43, "third", 20.0)
    view.layout()

    test_check(view.children[0].container_layout_kind == LAYOUT_STACK)
    test_check(view.children[3].container_layout_kind == LAYOUT_GRID)
    test_check(view.children[7].container_layout_kind == LAYOUT_SPLIT)
    test_check(view.children[10].container_layout_kind == LAYOUT_PORTAL)
    test_check(view.bounds_for(11).width == view.bounds_for(12).width)
    test_check(view.bounds_for(21).x < view.bounds_for(22).x)
    test_check(view.bounds_for(23).y > view.bounds_for(21).y)
    test_check(view.bounds_for(31).y < view.bounds_for(32).y)
    test_check(view.bounds_for(41).y < view.bounds_for(42).y)
    test_check(view.hit_test(Point(-1.0, -1.0)) == -1)

    var scroll = ScrollState()
    scroll.set_viewport(100.0, 80.0)
    scroll.set_content(100.0, 500.0)
    scroll.scroll_by(0.0, 1000.0)
    test_check(scroll.offset_y == 420.0)
    scroll.scroll_by(0.0, -500.0)
    test_check(scroll.offset_y == 0.0)

    var range = visible_range(100, 20.0, 100.0, 80.0, 1)
    test_check(range.start == 4)
    test_check(range.end == 11)
    test_check(range.count() == 7)

    var list = VirtualListState(100, 20.0, 2, True)
    list.set_viewport(100.0, 80.0)
    list.scroll_by(0.0, 100.0)
    test_check(list.visible().start == 3)
    test_check(list.visible().end > list.visible().start)

    print("Moxi layout-primitives test passed")
