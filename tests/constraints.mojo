"""Minimum and maximum size contract test."""

from moxi import test_check
from moxi import (
    ColumnRuntime,
    ColumnView,
    CONTAINER_KIND,
    LABEL_KIND,
    Point,
    Rect,
    ViewNode,
    make_row,
)


def main():
    var column = ColumnView(Rect(0.0, 0.0, 240.0, 160.0), 10.0, 4.0)
    column.add_label(1, "Constrained", 20.0)
    column.set_min_height(1, 32.0)
    column.set_max_width(1, 120.0)
    column.layout()
    test_check(column.child(0).bounds.height == 32.0)
    test_check(column.child(0).bounds.width == 120.0)

    var row = make_row(Rect(0.0, 0.0, 320.0, 100.0), 10.0, 8.0)
    row.add_label(2, "Fixed", 20.0)
    row.add_label(3, "Flexible", 20.0)
    row.set_fixed_width(2, 80.0)
    row.set_min_width(2, 120.0)
    row.set_max_width(3, 100.0)
    row.set_min_height(3, 36.0)
    row.layout()
    test_check(row.child(0).bounds.width == 120.0)
    test_check(row.child(1).bounds.width == 100.0)
    test_check(row.child(1).bounds.height == 80.0)

    var normalized = ColumnView(Rect(0.0, 0.0, 100.0, 80.0), 4.0, 2.0)
    normalized.add_label(4, "normalized", 20.0)
    normalized.set_min_width(4, 120.0)
    normalized.set_max_width(4, 80.0)
    normalized.layout()
    test_check(normalized.child(0).min_width == 80.0)
    test_check(normalized.child(0).max_width == 80.0)
    test_check(normalized.child(0).bounds.width == 80.0)

    var duplicate = ColumnView(Rect(0.0, 0.0, 100.0, 80.0), 4.0, 2.0)
    duplicate.add_label(1, "one", 20.0)
    duplicate.add_label(1, "again", 20.0)
    test_check(not duplicate.is_valid())
    var invalid_runtime = ColumnRuntime()
    invalid_runtime.reconcile(duplicate)
    test_check(invalid_runtime.validation_failed())
    test_check(invalid_runtime.widget_count() == 0)

    var orphan = ColumnView(Rect(0.0, 0.0, 100.0, 80.0), 4.0, 2.0)
    orphan.add_to(404, ViewNode(LABEL_KIND, 2, "orphan", 20.0))
    test_check(not orphan.validate())

    var cycle = ColumnView(Rect(0.0, 0.0, 100.0, 80.0), 4.0, 2.0)
    var first_container = ViewNode(CONTAINER_KIND, 30, "", 20.0)
    first_container.parent_id = 31
    cycle.add(first_container)
    var second_container = ViewNode(CONTAINER_KIND, 31, "", 20.0)
    second_container.parent_id = 30
    cycle.add(second_container)
    test_check(not cycle.is_valid())

    var overlap = ColumnView(Rect(0.0, 0.0, 100.0, 80.0), 0.0, 0.0)
    overlap.add_button(20, "back", 20.0)
    overlap.add_button(21, "front", 20.0)
    overlap.children[0].bounds = Rect(10.0, 10.0, 60.0, 30.0)
    overlap.children[1].bounds = Rect(20.0, 20.0, 60.0, 30.0)
    test_check(overlap.hit_test(Point(30.0, 30.0)) == 21)
    var overlap_runtime = ColumnRuntime()
    overlap_runtime.reconcile(overlap)
    test_check(overlap_runtime.hit_test(Point(30.0, 30.0)) == 21)

    print("Moxi constraints test passed")
