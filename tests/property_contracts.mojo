"""Deterministic property-style checks for edge cases in public contracts."""

from moxi import (
    AccessibilitySnapshot,
    ColumnView,
    Point,
    Rect,
    ScrollState,
    Semantics,
    VirtualListState,
    ROLE_CONTAINER,
    ROLE_LABEL,
    test_check,
    visible_range,
)


def main():
    # The virtual range must remain a bounded half-open interval for empty,
    # zero-viewport, negative-offset, and overscanned inputs.
    for count in range(65):
        for overscan in range(5):
            var visible = visible_range(
                count,
                Float32(count - 32),
                Float32(count * 3 - 20),
                Float32(count * 2 - 10),
                overscan,
            )
            test_check(visible.start >= 0)
            test_check(visible.end >= visible.start)
            test_check(visible.end <= count)

    var virtual = VirtualListState(100, 20.0, 2)
    virtual.set_viewport(200.0, 100.0)
    virtual.scroll_by(0.0, 100000.0)
    var virtual_range = virtual.visible()
    test_check(virtual_range.start >= 0)
    test_check(virtual_range.end <= 100)
    test_check(virtual_range.end > virtual_range.start)

    var scroll = ScrollState()
    scroll.set_content(320.0, 480.0)
    scroll.set_viewport(100.0, 120.0)
    scroll.set_offset(10000.0, -10.0)
    test_check(scroll.offset_x == scroll.max_offset_x())
    test_check(scroll.offset_y == 0.0)
    scroll.set_viewport(400.0, 600.0)
    test_check(scroll.offset_x == 0.0)
    test_check(scroll.offset_y == 0.0)

    # A generated tree with unique ids remains valid, while the smallest
    # duplicate is rejected before it reaches retained runtime state.
    var tree = ColumnView(Rect(0.0, 0.0, 320.0, 320.0), 4.0, 2.0)
    var container = tree.add_column(1, 240.0, 2.0, 2.0)
    for index in range(24):
        tree.add_label_to(container, index + 2, String("item ", index), 16.0)
    test_check(tree.is_valid())
    tree.layout()
    test_check(tree.child(1).bounds.y >= tree.child(0).bounds.y)

    var duplicate = ColumnView(Rect(0.0, 0.0, 10.0, 10.0), 0.0, 0.0)
    duplicate.add_label(1, "one", 1.0)
    duplicate.add_label(1, "two", 1.0)
    test_check(not duplicate.is_valid())

    var semantics = AccessibilitySnapshot()
    semantics.append(Semantics(1, ROLE_CONTAINER, "root"))
    var child = Semantics(2, ROLE_LABEL, "child")
    child.parent_id = 1
    semantics.append(child)
    test_check(semantics.is_valid())
    semantics.nodes[0].parent_id = 2
    test_check(not semantics.is_valid())

    var edge = Rect(0.0, 0.0, 4.0, 4.0).intersection(
        Rect(20.0, 20.0, 2.0, 2.0)
    )
    test_check(edge.width == 0.0)
    test_check(edge.height == 0.0)
    var boundary = Rect(0.0, 0.0, 4.0, 4.0)
    test_check(boundary.contains(Point(0.0, 0.0)))
    test_check(not boundary.contains(Point(4.0, 2.0)))
    test_check(not boundary.contains(Point(2.0, 4.0)))
    test_check(not Rect(0.0, 0.0, 0.0, 4.0).contains(Point(0.0, 1.0)))
    _ = Point(0.0, 0.0)
    print("Moxi property-contract test passed")
