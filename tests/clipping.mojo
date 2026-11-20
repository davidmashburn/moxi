"""Backend-neutral clipping contract test."""

from moxi import test_check
from moxi import ColumnRuntime, ColumnView, Point, Rect, SCROLLBAR_KIND


def check_nested_scrollbar_clip(root_clip: Bool):
    var root = ColumnView(Rect(0, 0, 300, 180), 0, 0)
    root.set_clip_to_bounds(root_clip)
    root.add_label(1, "Fixed header", 24)
    var outer = root.add_portal(10, 120, 0, 0)
    var inner = root.add_portal_to(outer, 20, 200, 0, 0)
    root.add_label_to(inner, 21, "Overflowing content", 400)
    root.set_scroll_offset(outer, 80)
    root.layout()
    test_check(root.bounds_for(inner).y < root.bounds_for(outer).y)
    var runtime = ColumnRuntime()
    runtime.reconcile(root)
    var commands = runtime.paint()
    var found = False
    for index in range(commands.count()):
        var command = commands.command(index)
        if command.kind == SCROLLBAR_KIND and command.id == inner:
            found = True
            test_check(command.has_clip)
            test_check(command.clip_bounds.y == root.bounds_for(outer).y)
            test_check(command.clip_bounds.height == root.bounds_for(outer).height)
    test_check(found)


def main():
    var overlap = Rect(0.0, 0.0, 20.0, 20.0).intersection(
        Rect(10.0, 5.0, 20.0, 30.0)
    )
    test_check(overlap.x == 10.0)
    test_check(overlap.y == 5.0)
    test_check(overlap.width == 10.0)
    test_check(overlap.height == 15.0)

    var root = ColumnView(Rect(0.0, 0.0, 300.0, 180.0), 8.0, 4.0)
    var clipped = root.add_column(10, 72.0, 4.0, 2.0)
    root.add_button_to(clipped, 11, "Clipped child", 24.0)
    root.set_clip_children(clipped)
    root.set_clip_to_bounds()
    root.layout()

    var runtime = ColumnRuntime()
    runtime.reconcile(root)
    var commands = runtime.paint()
    test_check(commands.count() == 2)
    test_check(commands.command(1).has_clip)
    test_check(commands.command(1).clip_bounds.x == root.child(0).bounds.x)
    test_check(commands.command(1).clip_bounds.y == root.child(0).bounds.y)
    test_check(commands.command(1).clip_bounds.width == root.child(0).bounds.width)
    test_check(commands.command(1).clip_bounds.height == root.child(0).bounds.height)
    test_check(
        runtime.hit_test(Point(root.child(0).bounds.x + 1.0, root.child(0).bounds.y + 1.0))
        == -1
    )

    var clipped_child = root.child(1).bounds
    test_check(runtime.hit_test(Point(clipped_child.x + 1.0, clipped_child.y + 1.0)) == 11)
    test_check(runtime.hit_test(Point(clipped_child.x + 1.0, root.child(0).bounds.y - 1.0)) == -1)

    var plain = ColumnView(Rect(0.0, 0.0, 200.0, 80.0), 8.0, 4.0)
    plain.add_label(1, "No clip", 24.0)
    plain.layout()
    var plain_runtime = ColumnRuntime()
    plain_runtime.reconcile(plain)
    test_check(not plain_runtime.paint().command(1).has_clip)
    check_nested_scrollbar_clip(False)
    check_nested_scrollbar_clip(True)
    print("Moxi clipping test passed")
