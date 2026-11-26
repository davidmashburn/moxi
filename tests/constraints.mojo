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


def linear_validation(view: ColumnView) -> Bool:
    """Independent pre-index validation oracle for malformed-tree equivalence."""
    var count = view.child_count()
    for index in range(count):
        var node = view.children[index]
        if node.id < 0:
            return False
        for previous in range(index):
            if view.children[previous].id == node.id:
                return False
        if node.parent_id == node.id:
            return False
        var parent_id = node.parent_id
        var hops = 0
        while parent_id != -1:
            if parent_id == node.id:
                return False
            var found = False
            var next_parent = -1
            for parent_index in range(count):
                var parent = view.children[parent_index]
                if parent.id == parent_id:
                    if parent.kind != CONTAINER_KIND:
                        return False
                    found = True
                    next_parent = parent.parent_id
                    break
            if not found:
                return False
            parent_id = next_parent
            hops += 1
            if hops > count:
                return False
    return True


def check_validation_equivalence():
    # Exhaust every parent assignment and container/leaf combination for four
    # sparse IDs. Includes forward links, missing parents and disjoint cycles.
    for parents in range(1296):  # Six parent choices to the fourth power.
        for kinds in range(16):
            var view = ColumnView(Rect(0, 0, 100, 100), 0, 0)
            var choices = parents
            for index in range(4):
                var kind = CONTAINER_KIND if (kinds & (1 << index)) != 0 else LABEL_KIND
                var node = ViewNode(kind, (index + 1) * 10, "", 20)
                var choice = choices % 6
                choices //= 6
                node.parent_id = choice - 2 if choice < 2 else (choice - 1) * 10
                view.add(node)
            test_check(view.is_valid() == linear_validation(view))

    var deep = ColumnView(Rect(0, 0, 100, 100), 0, 0)
    for index in range(96):
        var node = ViewNode(CONTAINER_KIND, (index + 1) * 1000000, "", 20)
        node.parent_id = (index + 2) * 1000000 if index < 95 else -1
        deep.add(node)
    test_check(deep.is_valid() and linear_validation(deep))
    # The first node reaches a cycle among ancestors that excludes itself.
    deep.children[95].parent_id = 64000000
    test_check(not deep.is_valid() and not linear_validation(deep))
    var empty = ColumnView(Rect(0, 0, 100, 100), 0, 0)
    test_check(empty.is_valid() and linear_validation(empty))
    var negative = ColumnView(Rect(0, 0, 100, 100), 0, 0)
    negative.add_label(-1, "invalid identity", 20)
    test_check(not negative.is_valid() and not linear_validation(negative))


def main():
    check_validation_equivalence()
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
