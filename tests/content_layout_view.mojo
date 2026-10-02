"""Content layout integration: authoring, retained measurements, and geometry."""
from moxi import ColumnView, ColumnRuntime, Rect, Point, ROOT_SCROLL_ID, test_check
from moxi.content_layout import AxisSize


def _check(condition: Bool, message: String):
    if not condition:
        print(message)
    test_check(condition)


def main():
    var view = ColumnView(Rect(0, 0, 300, 200), 10, 5)
    view.add_label(1, "Header", 20)
    view.add_canvas(2, "Chart", 1)
    view.set_sizing(2, AxisSize.fill(), AxisSize.fill())
    view.set_min_height(2, 40)
    view.layout()
    _check(view.content_layout_active, "content layout is active")
    _check(view.bounds_for(2).y == 35, "chart follows padded header and gap")
    _check(view.bounds_for(2).height == 155, "chart receives remaining height")
    view.layout()
    _check(view.content_layout_tree.leaf_measurements() == 0, "unchanged layout reuses leaf measurements")
    # Inserting a summary consumes chart space without changing chart policy.
    view.add_label(3, "Summary", 25)
    view.layout()
    _check(view.bounds_for(2).height == 125, "inserted summary reduces chart allocation")
    _check(view.bounds_for(3).y == 165, "summary follows chart")
    var runtime = ColumnRuntime()
    runtime.reconcile(view)
    var commands = runtime.paint()
    var found = False
    for index in range(commands.count()):
        var command = commands.command(index)
        if command.id == 2:
            _check(command.bounds.y == view.bounds_for(2).y, "paint uses published chart position")
            _check(command.bounds.height == view.bounds_for(2).height, "paint uses published chart height")
            found = True
    _check(found, "paint contains chart")
    var semantics = runtime.accessibility().node_for_id(2)
    _check(semantics.bounds.y == view.bounds_for(2).y, "accessibility uses published chart position")
    _check(semantics.bounds.height == view.bounds_for(2).height, "accessibility uses published chart height")
    var copied = view.clone()
    copied.layout()
    _check(copied.content_layout_tree.leaf_measurements() == 0, "clone retains clean measurements")

    var wrapped = ColumnView(Rect(0, 0, 160, 200), 0, 0)
    wrapped.add_label(10, "A long label that must wrap under parent constraints", 1)
    wrapped.set_sizing(10, AxisSize.fill(), AxisSize.content())
    wrapped.set_wrap_text(10)
    wrapped.layout()
    var wide_height = wrapped.bounds_for(10).height
    wrapped.layout_spec.bounds.width = 80
    wrapped.layout()
    _check(wrapped.bounds_for(10).height > wide_height, "narrow width increases wrapped height")

    var rows = ColumnView(Rect(0, 0, 200, 300), 0, 5)
    _ = rows.add_row(20, 0, 0, 4, 8)
    rows.add_label_to(20, 21, "This label wraps across several lines", 0)
    rows.add_label_to(20, 22, "Another label which wraps", 0)
    rows.set_sizing(20, AxisSize.fill(), AxisSize.content())
    rows.set_sizing(21, AxisSize.fill(), AxisSize.content())
    rows.set_sizing(22, AxisSize.fill(), AxisSize.content())
    rows.set_wrap_text(21)
    rows.set_wrap_text(22)
    rows.add_button(23, "Below", 32)
    rows.layout()
    _check(rows.bounds_for(20).height >= rows.bounds_for(21).height + 8, "content row encloses wrapped child and padding")
    _check(rows.bounds_for(23).y >= rows.bounds_for(21).y + rows.bounds_for(21).height, "following button clears wrapped content")
    var old_row_height = rows.bounds_for(20).height
    rows.children[1].text += " Added content that must invalidate the parent measurement."
    rows.layout()
    _check(rows.bounds_for(20).height > old_row_height, "text mutation invalidates parent height")
    rows.layout()
    _check(rows.content_layout_tree.leaf_measurements() == 0, "wrapped row keeps natural and allocated measurement caches")

    var scrolling = ColumnView(Rect(0, 0, 100, 50), 0, 0)
    scrolling.set_clip_to_bounds(True)
    scrolling.add_button(1, "First", 40)
    scrolling.add_button(2, "Second", 40)
    scrolling.enable_content_layout()
    scrolling.layout()
    _check(scrolling.scroll_max_offset(ROOT_SCROLL_ID) == 30, "root scroll range includes both children")
    scrolling.set_scroll_offset(ROOT_SCROLL_ID, 30)
    scrolling.layout()
    _check(scrolling.content_layout_tree.leaf_measurements() == 0, "root scroll reuses measurements")
    _check(scrolling.bounds_for(2).y == 10, "root scroll translates child bounds")
    _check(scrolling.hit_test(Point(5, 20)) == 2, "view hit testing follows scroll")
    runtime.reconcile(scrolling)
    _check(runtime.hit_test(Point(5, 20)) == 2, "runtime hit testing follows scroll")
    # A fixed nested viewport scrolls its actual child content, not its own
    # fixed measured height. Root and nested translations remain independent.
    var nested = ColumnView(Rect(0, 0, 100, 100), 0, 0)
    _ = nested.add_column(10, 50, 0, 0)
    nested.set_clip_children(10)
    nested.add_button_to(10, 11, "First", 40)
    nested.add_button_to(10, 12, "Second", 40)
    nested.enable_content_layout()
    nested.layout()
    _check(nested.scroll_max_offset(10) == 30, "fixed nested viewport exposes child overflow")
    nested.set_scroll_offset(10, 30)
    nested.layout()
    _check(nested.content_layout_tree.leaf_measurements() == 0, "nested scroll reuses measurements")
    _check(nested.bounds_for(12).y == 10, "nested scroll translates children")
    _check(nested.bounds_for(10).y == 0, "nested scroll keeps viewport anchored")
    _check(nested.hit_test(Point(5, 20)) == 12, "nested scroll hit test follows published bounds")

    # A wrapped content-sized label can overflow a fixed nested viewport after
    # its final width is allocated.  Without an explicit clip_children flag,
    # both hit-test paths still need to clip by the modern scroll range.
    var wrapped_nested = ColumnView(Rect(0, 0, 80, 100), 0, 0)
    _ = wrapped_nested.add_column(30, 40, 0, 0)
    wrapped_nested.add_label_to(
        30,
        31,
        "A wrapped label whose final narrow width produces several lines of content",
        0,
    )
    wrapped_nested.set_sizing(30, AxisSize.fill(), AxisSize.fixed(40))
    wrapped_nested.set_sizing(31, AxisSize.fill(), AxisSize.content())
    wrapped_nested.set_wrap_text(31)
    # Labels are normally non-interactive; make this diagnostic target
    # focusable so both public hit-test paths can be compared directly.
    wrapped_nested.children[1].focusable = True
    wrapped_nested.enable_content_layout()
    wrapped_nested.layout()
    var wrapped_viewport = wrapped_nested.bounds_for(30)
    var wrapped_label = wrapped_nested.bounds_for(31)
    _check(
        wrapped_label.height > wrapped_viewport.height + 2.0,
        "wrapped label did not overflow fixed nested viewport",
    )
    var before_inside = Point(wrapped_label.x + 1.0, wrapped_viewport.y + 1.0)
    var before_outside = Point(
        wrapped_label.x + 1.0,
        wrapped_viewport.y + wrapped_viewport.height + 1.0,
    )
    _check(wrapped_label.contains(before_outside), "pre-scroll outside point misses wrapped label")
    _check(not wrapped_viewport.contains(before_outside), "pre-scroll outside point is inside viewport")
    var wrapped_runtime = ColumnRuntime()
    wrapped_runtime.reconcile(wrapped_nested)
    _check(wrapped_nested.hit_test(before_inside) == 31, "view hit test misses visible wrapped label")
    _check(wrapped_runtime.hit_test(before_inside) == 31, "runtime hit test misses visible wrapped label")
    _check(wrapped_nested.hit_test(before_outside) == -1, "view hit test leaks outside nested viewport")
    _check(wrapped_runtime.hit_test(before_outside) == -1, "runtime hit test leaks outside nested viewport")

    var wrapped_max = wrapped_nested.scroll_max_offset(30)
    _check(wrapped_max > 2.0, "wrapped nested viewport has no scroll range")
    wrapped_nested.set_scroll_offset(30, wrapped_max)
    wrapped_nested.layout()
    wrapped_runtime.reconcile(wrapped_nested)
    var after_viewport = wrapped_nested.bounds_for(30)
    var after_label = wrapped_nested.bounds_for(31)
    var after_inside = Point(
        after_label.x + 1.0,
        after_viewport.y + after_viewport.height - 1.0,
    )
    var after_outside = Point(after_label.x + 1.0, after_viewport.y - 1.0)
    _check(after_label.contains(after_inside), "post-scroll inside point misses wrapped label")
    _check(after_label.contains(after_outside), "post-scroll outside point misses translated label")
    _check(not after_viewport.contains(after_outside), "post-scroll outside point is inside viewport")
    _check(wrapped_nested.hit_test(after_inside) == 31, "view hit test misses scrolled wrapped label")
    _check(wrapped_runtime.hit_test(after_inside) == 31, "runtime hit test misses scrolled wrapped label")
    _check(wrapped_nested.hit_test(after_outside) == -1, "view hit test leaks after nested scroll")
    _check(wrapped_runtime.hit_test(after_outside) == -1, "runtime hit test leaks after nested scroll")
    print("Moxi content layout view test passed")
