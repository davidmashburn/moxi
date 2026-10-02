"""Emit shared Taffy fixture geometry for differential verification."""
from std.collections import List
from moxi import Rect
from moxi.content_layout import AxisSize, LayoutStyle, LayoutNode, LayoutTree


def report(name: String, tree: LayoutTree):
    for index in range(tree.count()):
        var b = tree.bounds(index)
        print(name, index, b.x, b.y, b.width, b.height)


def main():
    var row = List[LayoutNode]()
    row.append(LayoutNode(0, -1, LayoutStyle(AxisSize.fill(), AxisSize.fill(), axis=1, gap=10), True))
    row.append(LayoutNode(1, 0, LayoutStyle(AxisSize.fill(1), AxisSize.fill(), max_width=60)))
    row.append(LayoutNode(2, 0, LayoutStyle(AxisSize.fill(2), AxisSize.fill())))
    var tree = LayoutTree()
    tree.sync(row^)
    tree.layout(Rect(0, 0, 300, 40))
    report("row-weighted-fill-min-max", tree)

    var column = List[LayoutNode]()
    column.append(LayoutNode(0, -1, LayoutStyle(AxisSize.fill(), AxisSize.fill(), padding=10, gap=5), True))
    column.append(LayoutNode(1, 0, LayoutStyle(AxisSize.fill(), AxisSize.fixed(20))))
    column.append(LayoutNode(2, 0, LayoutStyle(AxisSize.fill(), AxisSize.fill(), min_height=40)))
    tree.sync(column^)
    tree.layout(Rect(0, 0, 300, 200))
    report("column-content-header-fill-body", tree)

    var wrapped = List[LayoutNode]()
    wrapped.append(LayoutNode(0, -1, LayoutStyle(AxisSize.fill(), AxisSize.content(), axis=1, gap=10), True))
    wrapped.append(LayoutNode(1, 0, LayoutStyle(AxisSize.fill(), AxisSize.content()), False, "abcdefghijklmnopqrst", 16, True))
    wrapped.append(LayoutNode(2, 0, LayoutStyle(AxisSize.fill(), AxisSize.content()), False, "abcdefghijklmnopqrstuvwxyzabcd", 16, True))
    tree.sync(wrapped^)
    tree.layout(Rect(0, 0, 200, 60))
    report("wrapped-text-at-offered-width", tree)
