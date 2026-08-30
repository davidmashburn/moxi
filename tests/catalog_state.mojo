"""Behavior contracts for list-like, modal, tab, and canvas state."""

from moxi import (
    CanvasState,
    ComboBoxState,
    DialogState,
    ListState,
    MenuState,
    Point,
    SelectionState,
    TableState,
    TabsState,
    TreeState,
    test_check,
)


def main():
    var selection = SelectionState(3, 1)
    test_check(selection.is_selected(1))
    test_check(selection.select_next())
    test_check(selection.selected_index == 2)
    test_check(not selection.select_next())
    test_check(selection.select_previous())
    test_check(selection.selected_index == 1)
    test_check(selection.set_item_count(1))
    test_check(selection.selected_index == 0)

    var combo = ComboBoxState(3)
    test_check(combo.toggle())
    test_check(combo.expanded)
    test_check(combo.select(2))
    test_check(not combo.expanded)
    test_check(combo.selection.selected_index == 2)

    var list = ListState(3)
    test_check(list.next())
    test_check(list.next())
    test_check(list.selection.selected_index == 1)

    var table = TableState(4, 3)
    test_check(table.select(1, 2))
    test_check(table.move(1, -1))
    test_check(table.selected_row == 2)
    test_check(table.selected_column == 1)

    var tree = TreeState(3)
    test_check(tree.toggle_expanded())
    test_check(tree.expanded)
    test_check(tree.select(1))

    var menu = MenuState(2)
    test_check(menu.show())
    test_check(menu.activate(1))
    test_check(not menu.open)

    var dialog = DialogState()
    test_check(dialog.show())
    test_check(dialog.resolve(2))
    test_check(not dialog.open)
    test_check(dialog.result == 2)

    var tabs = TabsState(3)
    test_check(tabs.select(1))
    test_check(tabs.next())
    test_check(tabs.selection.selected_index == 2)

    var canvas = CanvasState()
    test_check(not canvas.update(Point(2.0, 3.0)))
    test_check(canvas.begin(Point(2.0, 3.0)))
    test_check(canvas.update(Point(4.0, 5.0)))
    test_check(canvas.end(Point(6.0, 7.0)))
    test_check(not canvas.dragging)
    print("Moxi catalog-state test passed")
