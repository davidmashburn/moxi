"""Collection and container control descriptors (list-shaped views)."""


from .view_node import (
    COMBO_BOX_KIND,
    DIALOG_KIND,
    LIST_KIND,
    MENU_KIND,
    TABLE_KIND,
    TABS_KIND,
    TREE_KIND,
    ViewNode,
)


struct ComboBoxControl(ImplicitlyCopyable):
    """A focusable single-selection combo-box descriptor."""

    var id: Int
    var text: String
    var selection: String
    var preferred_height: Float32
    var expanded: Bool

    def __init__(
        out self,
        id: Int,
        text: String,
        selection: String,
        preferred_height: Float32,
        expanded: Bool = False,
    ):
        self.id = id
        self.text = text
        self.selection = selection
        self.preferred_height = preferred_height
        self.expanded = expanded

    def node(self) -> ViewNode:
        var node = ViewNode(COMBO_BOX_KIND, self.id, self.text, self.preferred_height)
        node.set_accessibility_value(self.selection)
        node.set_expanded(self.expanded)
        return node


struct ListControl(ImplicitlyCopyable):
    """A list descriptor with item-count semantics."""

    var id: Int
    var text: String
    var item_count: Int
    var preferred_height: Float32

    def __init__(out self, id: Int, text: String, item_count: Int, preferred_height: Float32):
        self.id = id
        self.text = text
        self.item_count = item_count if item_count > 0 else 0
        self.preferred_height = preferred_height

    def node(self) -> ViewNode:
        var node = ViewNode(LIST_KIND, self.id, self.text, self.preferred_height)
        node.set_accessibility_value(String("items ", self.item_count))
        return node


struct TableControl(ImplicitlyCopyable):
    """A table descriptor; cells remain application-owned child views."""

    var id: Int
    var text: String
    var columns: Int
    var preferred_height: Float32

    def __init__(out self, id: Int, text: String, columns: Int, preferred_height: Float32):
        self.id = id
        self.text = text
        self.columns = columns if columns > 0 else 1
        self.preferred_height = preferred_height

    def node(self) -> ViewNode:
        var node = ViewNode(TABLE_KIND, self.id, self.text, self.preferred_height)
        node.set_accessibility_value(String("columns ", self.columns))
        return node


struct TreeControl(ImplicitlyCopyable):
    """A tree descriptor whose expanded children are ordinary view nodes."""

    var id: Int
    var text: String
    var expanded: Bool
    var preferred_height: Float32

    def __init__(out self, id: Int, text: String, expanded: Bool, preferred_height: Float32):
        self.id = id
        self.text = text
        self.expanded = expanded
        self.preferred_height = preferred_height

    def node(self) -> ViewNode:
        var node = ViewNode(TREE_KIND, self.id, self.text, self.preferred_height)
        if self.expanded:
            node.set_accessibility_value("expanded")
        else:
            node.set_accessibility_value("collapsed")
        node.set_expanded(self.expanded)
        return node


struct MenuControl(ImplicitlyCopyable):
    """A menu descriptor with application-owned menu-item children."""

    var id: Int
    var text: String
    var preferred_height: Float32

    def __init__(out self, id: Int, text: String, preferred_height: Float32):
        self.id = id
        self.text = text
        self.preferred_height = preferred_height

    def node(self) -> ViewNode:
        return ViewNode(MENU_KIND, self.id, self.text, self.preferred_height)


struct DialogControl(ImplicitlyCopyable):
    """A dialog surface descriptor; buttons can be composed beneath it."""

    var id: Int
    var text: String
    var open: Bool
    var preferred_height: Float32

    def __init__(out self, id: Int, text: String, open: Bool, preferred_height: Float32):
        self.id = id
        self.text = text
        self.open = open
        self.preferred_height = preferred_height

    def node(self) -> ViewNode:
        var node = ViewNode(DIALOG_KIND, self.id, self.text, self.preferred_height)
        node.enabled = self.open
        node.semantics.enabled = self.open
        node.set_expanded(self.open)
        return node


struct TabsControl(ImplicitlyCopyable):
    """A tab-group descriptor with a selected-tab semantic value."""

    var id: Int
    var text: String
    var selected_index: Int
    var preferred_height: Float32

    def __init__(out self, id: Int, text: String, selected_index: Int, preferred_height: Float32):
        self.id = id
        self.text = text
        self.selected_index = selected_index if selected_index >= 0 else 0
        self.preferred_height = preferred_height

    def node(self) -> ViewNode:
        var node = ViewNode(TABS_KIND, self.id, self.text, self.preferred_height)
        node.set_accessibility_value(String("selected ", self.selected_index))
        return node


