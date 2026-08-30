"""Visible-window view builder contract test."""

from moxi import (
    LABEL_KIND,
    Rect,
    ViewNode,
    VirtualItemBuilder,
    VirtualizedList,
    test_check,
)


struct ItemBuilder(VirtualItemBuilder):
    def __init__(out self):
        pass

    def build(self, index: Int, key: Int, bounds: Rect) -> ViewNode:
        return ViewNode(LABEL_KIND, key, String("item ", index), bounds.height)


def main():
    var list = VirtualizedList(ItemBuilder(), 10000, 20.0, 1)
    var view = list.build(Rect(0.0, 0.0, 300.0, 80.0))
    test_check(view.child_count() == 6)
    test_check(view.child(0).id == 0)
    list.set_offset(100.0)
    view = list.build(Rect(0.0, 0.0, 300.0, 80.0))
    test_check(view.child_count() == 7)
    test_check(view.child(0).bounds.y == -20.0)
    test_check(list.ensure_visible(9999, 80.0) == 199920.0)
    view = list.build(Rect(0.0, 0.0, 300.0, 80.0))
    test_check(view.child_count() == 5)
    _ = list.set_key(5, 50000)
    list.set_offset(100.0)
    view = list.build(Rect(0.0, 0.0, 300.0, 80.0))
    test_check(view.child(1).id == 50000)
    print("Moxi virtual-view test passed")
