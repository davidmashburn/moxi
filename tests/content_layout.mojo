"""Contract fixtures for the retained content/fill layout slice."""

from std.collections import List

from moxi import test_check
from moxi.content_layout import (
    AXIS_FILL,
    LAYOUT_COLUMN,
    LAYOUT_ROW,
    AxisSize,
    LayoutNode,
    LayoutStyle,
    LayoutTree,
)
from moxi.geometry import Rect


def _check_close(value: Float32, expected: Float32):
    test_check(value > expected - 0.01 and value < expected + 0.01)


def _column_nodes() -> List[LayoutNode]:
    var result = List[LayoutNode]()
    var root_style = LayoutStyle(
        AxisSize.fixed(280.0),
        AxisSize.fixed(180.0),
        axis=LAYOUT_COLUMN,
        padding=10.0,
        gap=5.0,
    )
    result.append(LayoutNode(100, -1, root_style, True))
    result.append(
        LayoutNode(
            101,
            0,
            LayoutStyle(AxisSize.fill(), AxisSize.fixed(20.0)),
            False,
            "Header",
            16.0,
        )
    )
    result.append(
        LayoutNode(
            102,
            0,
            LayoutStyle(
                AxisSize.fill(),
                AxisSize.fill(),
                min_height=40.0,
            ),
            False,
            "Body",
            16.0,
        )
    )
    return result^


def _row_nodes() -> List[LayoutNode]:
    var result = List[LayoutNode]()
    result.append(
        LayoutNode(
            200,
            -1,
            LayoutStyle(
                AxisSize.fixed(300.0),
                AxisSize.fixed(80.0),
                axis=LAYOUT_ROW,
                gap=10.0,
            ),
            True,
        )
    )
    result.append(
        LayoutNode(
            201,
            0,
            LayoutStyle(
                AxisSize.fill(1.0),
                AxisSize.fill(),
                max_width=60.0,
            ),
            False,
            "A",
            16.0,
        )
    )
    result.append(
        LayoutNode(
            202,
            0,
            LayoutStyle(AxisSize.fill(2.0), AxisSize.fill()),
            False,
            "B",
            16.0,
        )
    )
    return result^


def main():
    var tree = LayoutTree()
    var nodes = _column_nodes()
    tree.sync(nodes)
    tree.layout(Rect(0.0, 0.0, 300.0, 200.0))
    _check_close(tree.bounds(1).y, 10.0)
    _check_close(tree.bounds(1).height, 20.0)
    _check_close(tree.bounds(2).y, 35.0)
    _check_close(tree.bounds(2).height, 155.0)
    _check_close(tree.bounds(2).width, 280.0)
    test_check(tree.leaf_measurements() == 2)

    tree.sync(nodes)
    tree.layout(Rect(0.0, 0.0, 300.0, 200.0))
    test_check(tree.leaf_measurements() == 0)
    test_check(tree.cache_hits() > 0)

    var row = LayoutTree()
    var row_nodes = _row_nodes()
    row.sync(row_nodes)
    row.layout(Rect(0.0, 0.0, 300.0, 80.0))
    _check_close(row.bounds(1).width, 60.0)
    _check_close(row.bounds(2).width, 230.0)

    var wrapped_nodes = List[LayoutNode]()
    wrapped_nodes.append(
        LayoutNode(
            300,
            -1,
            LayoutStyle(AxisSize.fixed(120.0), AxisSize.content(), padding=10.0),
            True,
        )
    )
    wrapped_nodes.append(
        LayoutNode(
            301,
            0,
            LayoutStyle(AxisSize.fill(), AxisSize.content()),
            False,
            "abcdefghijabcdefghij",
            16.0,
            True,
        )
    )
    var wrapped = LayoutTree()
    wrapped.sync(wrapped_nodes)
    wrapped.layout(Rect(0.0, 0.0, 120.0, 200.0))
    test_check(wrapped.content_extent(1).height > 16.0)

    # A column's finite cross-axis proposal is bounded by the child's own
    # max width before wrapped text is measured.  Otherwise placement could
    # shrink a one-line measurement without recomputing its line count.
    var bounded_wrap_nodes = List[LayoutNode]()
    bounded_wrap_nodes.append(
        LayoutNode(
            325,
            -1,
            LayoutStyle(AxisSize.fixed(200.0), AxisSize.content()),
            True,
        )
    )
    bounded_wrap_nodes.append(
        LayoutNode(
            326,
            0,
            LayoutStyle(
                AxisSize.fill(),
                AxisSize.content(),
                max_width=40.0,
            ),
            False,
            "abcdefghijabcdefghijabcdefghij",
            16.0,
            True,
        )
    )
    var bounded_wrap = LayoutTree()
    bounded_wrap.sync(bounded_wrap_nodes)
    bounded_wrap.layout(Rect(0.0, 0.0, 200.0, 200.0))
    test_check(bounded_wrap.bounds(1).width <= 40.01)
    _check_close(bounded_wrap.bounds(1).height, 160.0)

    # A row must allocate its final widths before measuring wrapped heights;
    # the row's own content extent therefore includes the resulting lines.
    var wrapped_row_nodes = List[LayoutNode]()
    wrapped_row_nodes.append(
        LayoutNode(
            350,
            -1,
            LayoutStyle(
                AxisSize.fixed(120.0),
                AxisSize.content(),
                axis=LAYOUT_ROW,
            ),
            True,
        )
    )
    wrapped_row_nodes.append(
        LayoutNode(
            351,
            0,
            LayoutStyle(AxisSize.fill(), AxisSize.content()),
            False,
            "abcdefghijabcdefghij",
            16.0,
            True,
        )
    )
    var wrapped_row = LayoutTree()
    wrapped_row.sync(wrapped_row_nodes)
    wrapped_row.layout(Rect(0.0, 0.0, 120.0, 200.0))
    test_check(wrapped_row.bounds(1).height > 16.0)
    test_check(wrapped_row.content_extent(0).height > 16.0)

    # A changed descendant invalidates its container, while the following
    # unchanged pass reuses both natural and allocated-width leaf queries.
    var changed_nodes = _column_nodes()
    changed_nodes[2].text = "Body content changed"
    tree.sync(changed_nodes)
    tree.layout(Rect(0.0, 0.0, 300.0, 200.0))
    test_check(tree.leaf_measurements() > 0)
    tree.layout(Rect(0.0, 0.0, 300.0, 200.0))
    test_check(tree.leaf_measurements() == 0)

    var overflow_nodes = List[LayoutNode]()
    overflow_nodes.append(
        LayoutNode(
            400,
            -1,
            LayoutStyle(AxisSize.fixed(80.0), AxisSize.fixed(30.0), padding=50.0),
            True,
        )
    )
    var overflow = LayoutTree()
    overflow.sync(overflow_nodes)
    overflow.layout(Rect(0.0, 0.0, 80.0, 30.0))
    test_check(overflow.overflow())

    var overflowing_children = List[LayoutNode]()
    overflowing_children.append(
        LayoutNode(
            500,
            -1,
            LayoutStyle(AxisSize.fixed(100.0), AxisSize.fixed(100.0)),
            True,
        )
    )
    overflowing_children.append(
        LayoutNode(
            501,
            0,
            LayoutStyle(AxisSize.fill(), AxisSize.fixed(80.0)),
            False,
        )
    )
    overflowing_children.append(
        LayoutNode(
            502,
            0,
            LayoutStyle(AxisSize.fill(), AxisSize.fixed(80.0)),
            False,
        )
    )
    var fixed_viewport = LayoutTree()
    fixed_viewport.sync(overflowing_children)
    fixed_viewport.layout(Rect(0.0, 0.0, 100.0, 100.0))
    test_check(fixed_viewport.content_extent(0).height >= 160.0)
    test_check(fixed_viewport.overflow_count() > 0)

    var cyclic = List[LayoutNode]()
    cyclic.append(
        LayoutNode(
            600,
            1,
            LayoutStyle(AxisSize.content(), AxisSize.content()),
            True,
        )
    )
    cyclic.append(
        LayoutNode(
            601,
            0,
            LayoutStyle(AxisSize.content(), AxisSize.content()),
            True,
        )
    )
    var invalid = LayoutTree()
    invalid.sync(cyclic)
    test_check(not invalid.is_valid())
    invalid.layout(Rect(0.0, 0.0, 100.0, 100.0))
    test_check(invalid.node_visits() == 0)
    # Replacing one stable ID at the same length still invalidates ancestors.
    var replacement = List[LayoutNode]()
    replacement.append(LayoutNode(700, -1, LayoutStyle(AxisSize.fill(), AxisSize.content()), True))
    replacement.append(LayoutNode(701, 0, LayoutStyle(AxisSize.fill(), AxisSize.content()), False, "one", 16))
    var replaced = LayoutTree()
    replaced.sync(replacement)
    replaced.layout(Rect(0, 0, 200, 10))
    _check_close(replaced.content_extent(0).height, 20)
    replacement[1] = LayoutNode(702, 0, LayoutStyle(AxisSize.fill(), AxisSize.content()), False, "one\ntwo\nthree", 16)
    replaced.sync(replacement)
    replaced.layout(Rect(0, 0, 200, 10))
    _check_close(replaced.content_extent(0).height, 60)
    _ = replaced.add(LayoutNode(703, 0, LayoutStyle(AxisSize.fill(), AxisSize.content()), False, "four", 16))
    replaced.layout(Rect(0, 0, 200, 10))
    _check_close(replaced.content_extent(0).height, 80)
    print("Moxi content layout test passed")
