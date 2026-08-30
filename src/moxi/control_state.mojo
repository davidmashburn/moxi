"""Small value-oriented state machines for the catalog controls."""

from .geometry import Point


struct SelectionState(ImplicitlyCopyable):
    """Bounded single-selection state shared by list-like controls."""

    var item_count: Int
    var selected_index: Int

    def __init__(out self, item_count: Int = 0, selected_index: Int = -1):
        self.item_count = item_count if item_count > 0 else 0
        self.selected_index = -1
        _ = self.set_selected(selected_index)

    def set_item_count(mut self, item_count: Int) -> Bool:
        var next_count = item_count if item_count > 0 else 0
        if next_count == self.item_count:
            return False
        self.item_count = next_count
        if self.selected_index >= next_count:
            self.selected_index = next_count - 1
        if next_count == 0:
            self.selected_index = -1
        return True

    def set_selected(mut self, index: Int) -> Bool:
        if index < -1 or index >= self.item_count:
            return False
        if self.selected_index == index:
            return False
        self.selected_index = index
        return True

    def select_next(mut self) -> Bool:
        if self.item_count == 0:
            return False
        var next = self.selected_index + 1
        if next >= self.item_count:
            next = self.item_count - 1
        return self.set_selected(next)

    def select_previous(mut self) -> Bool:
        if self.item_count == 0:
            return False
        var next = self.selected_index - 1
        if next < 0:
            next = 0
        return self.set_selected(next)

    def is_selected(self, index: Int) -> Bool:
        return self.selected_index == index


struct ComboBoxState(ImplicitlyCopyable):
    """Open/selection state for a combo box."""

    var selection: SelectionState
    var expanded: Bool

    def __init__(out self, item_count: Int = 0, selected_index: Int = -1):
        self.selection = SelectionState(item_count, selected_index)
        self.expanded = False

    def toggle(mut self) -> Bool:
        self.expanded = not self.expanded
        return True

    def close(mut self) -> Bool:
        if not self.expanded:
            return False
        self.expanded = False
        return True

    def select(mut self, index: Int) -> Bool:
        var changed = self.selection.set_selected(index)
        if changed:
            self.expanded = False
        return changed


struct ListState(ImplicitlyCopyable):
    """Selection and keyboard movement for a list control."""

    var selection: SelectionState

    def __init__(out self, item_count: Int = 0, selected_index: Int = -1):
        self.selection = SelectionState(item_count, selected_index)

    def select(mut self, index: Int) -> Bool:
        return self.selection.set_selected(index)

    def next(mut self) -> Bool:
        return self.selection.select_next()

    def previous(mut self) -> Bool:
        return self.selection.select_previous()


struct TableState(ImplicitlyCopyable):
    """Two-dimensional cursor state for a table control."""

    var row_count: Int
    var column_count: Int
    var selected_row: Int
    var selected_column: Int

    def __init__(
        out self,
        row_count: Int = 0,
        column_count: Int = 1,
    ):
        self.row_count = row_count if row_count > 0 else 0
        self.column_count = column_count if column_count > 0 else 1
        self.selected_row = -1
        self.selected_column = 0

    def select(mut self, row: Int, column: Int = 0) -> Bool:
        if row < 0 or row >= self.row_count:
            return False
        if column < 0 or column >= self.column_count:
            return False
        if self.selected_row == row and self.selected_column == column:
            return False
        self.selected_row = row
        self.selected_column = column
        return True

    def move(mut self, row_delta: Int, column_delta: Int) -> Bool:
        var row = self.selected_row if self.selected_row >= 0 else 0
        var column = self.selected_column
        row += row_delta
        column += column_delta
        if row < 0:
            row = 0
        if row >= self.row_count:
            row = self.row_count - 1
        if column < 0:
            column = 0
        if column >= self.column_count:
            column = self.column_count - 1
        return self.select(row, column)


struct TreeState(ImplicitlyCopyable):
    """Selection and disclosure state for an outline/tree control."""

    var selection: SelectionState
    var expanded: Bool

    def __init__(out self, item_count: Int = 0, expanded: Bool = False):
        self.selection = SelectionState(item_count)
        self.expanded = expanded

    def select(mut self, index: Int) -> Bool:
        return self.selection.set_selected(index)

    def toggle_expanded(mut self) -> Bool:
        self.expanded = not self.expanded
        return True


struct MenuState(ImplicitlyCopyable):
    """Open state and highlighted item for a menu."""

    var selection: SelectionState
    var open: Bool

    def __init__(out self, item_count: Int = 0):
        self.selection = SelectionState(item_count)
        self.open = False

    def show(mut self) -> Bool:
        if self.open:
            return False
        self.open = True
        return True

    def dismiss(mut self) -> Bool:
        if not self.open:
            return False
        self.open = False
        return True

    def activate(mut self, index: Int) -> Bool:
        var changed = self.selection.set_selected(index)
        if self.open:
            self.open = False
            changed = True
        return changed


struct DialogState(ImplicitlyCopyable):
    """Explicit open/close result state for modal dialog composition."""

    var open: Bool
    var result: Int

    def __init__(out self, open: Bool = False):
        self.open = open
        self.result = 0

    def show(mut self) -> Bool:
        if self.open:
            return False
        self.open = True
        self.result = 0
        return True

    def resolve(mut self, result: Int) -> Bool:
        self.open = False
        self.result = result
        return True


struct TabsState(ImplicitlyCopyable):
    """Selected tab state with bounded keyboard navigation."""

    var selection: SelectionState

    def __init__(out self, tab_count: Int = 0, selected_index: Int = 0):
        self.selection = SelectionState(tab_count, selected_index)

    def select(mut self, index: Int) -> Bool:
        return self.selection.set_selected(index)

    def next(mut self) -> Bool:
        return self.selection.select_next()

    def previous(mut self) -> Bool:
        return self.selection.select_previous()


struct CanvasState(ImplicitlyCopyable):
    """Pointer/drag state that a canvas component can use with Scene."""

    var pointer: Point
    var dragging: Bool

    def __init__(out self):
        self.pointer = Point(0.0, 0.0)
        self.dragging = False

    def begin(mut self, position: Point) -> Bool:
        self.pointer = position
        self.dragging = True
        return True

    def update(mut self, position: Point) -> Bool:
        if not self.dragging:
            return False
        self.pointer = position
        return True

    def end(mut self, position: Point) -> Bool:
        self.pointer = position
        var changed = self.dragging
        self.dragging = False
        return changed
