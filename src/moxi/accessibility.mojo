"""Backend-neutral accessibility metadata for the current view tree."""

from std.collections import List

from .geometry import Rect


comptime ROLE_NONE = 0
comptime ROLE_LABEL = 1
comptime ROLE_BUTTON = 2
comptime ROLE_TEXT_INPUT = 3
comptime ROLE_SPACER = 4
comptime ROLE_CONTAINER = 5
comptime ROLE_CHECKBOX = 6
comptime ROLE_PROGRESS_INDICATOR = 7
comptime ROLE_SLIDER = 8
comptime ROLE_SWITCH = 9
comptime ROLE_RADIO = 10
comptime ROLE_IMAGE = 11
comptime ROLE_TEXT_AREA = 12
comptime ROLE_COMBO_BOX = 13
comptime ROLE_LIST = 14
comptime ROLE_TABLE = 15
comptime ROLE_TREE = 16
comptime ROLE_MENU = 17
comptime ROLE_DIALOG = 18
comptime ROLE_TAB_GROUP = 19
comptime ROLE_CANVAS = 20
comptime ROLE_SEPARATOR = 21

comptime ACTION_NONE = 0
comptime ACTION_PRESS = 1
comptime ACTION_INCREMENT = 2
comptime ACTION_DECREMENT = 4
comptime ACTION_SELECT = 8
comptime ACTION_EXPAND = 16
comptime ACTION_COLLAPSE = 32

comptime VIEW_LABEL_KIND = 1
comptime VIEW_BUTTON_KIND = 2
comptime VIEW_TEXT_INPUT_KIND = 5
comptime VIEW_SPACER_KIND = 6
comptime VIEW_CONTAINER_KIND = 7
comptime VIEW_CHECKBOX_KIND = 8
comptime VIEW_PROGRESS_KIND = 9
comptime VIEW_SLIDER_KIND = 10
comptime VIEW_SWITCH_KIND = 11
comptime VIEW_RADIO_KIND = 12
comptime VIEW_IMAGE_KIND = 13
comptime VIEW_MULTILINE_TEXT_KIND = 14
comptime VIEW_COMBO_BOX_KIND = 15
comptime VIEW_LIST_KIND = 16
comptime VIEW_TABLE_KIND = 17
comptime VIEW_TREE_KIND = 18
comptime VIEW_MENU_KIND = 19
comptime VIEW_DIALOG_KIND = 20
comptime VIEW_TABS_KIND = 21
comptime VIEW_CANVAS_KIND = 22
comptime VIEW_SEPARATOR_KIND = 23


struct Semantics(ImplicitlyCopyable):
    """Accessible identity and state for one view node.

    This is deliberately backend-neutral. Platform adapters can map the
    stable role/name/value/state fields to their native accessibility APIs
    without making those APIs part of the Mojo view contract.
    """

    var id: Int
    var parent_id: Int
    var role: Int
    var label: String
    var value: String
    var hint: String
    var bounds: Rect
    var enabled: Bool
    var focused: Bool
    var selected: Bool
    var actions: Int

    def __init__(out self, id: Int, role: Int, label: String):
        self.id = id
        self.parent_id = -1
        self.role = role
        self.label = label
        self.value = ""
        self.hint = ""
        self.bounds = Rect(0.0, 0.0, 0.0, 0.0)
        self.enabled = True
        self.focused = False
        self.selected = False
        self.actions = ACTION_NONE

    def set_actions(mut self, actions: Int):
        self.actions = actions

    def supports_action(self, action: Int) -> Bool:
        return (self.actions & action) != 0


def role_for_kind(kind: Int) -> Int:
    """Return the default semantic role for a public view kind."""
    if kind == VIEW_LABEL_KIND:
        return ROLE_LABEL
    if kind == VIEW_BUTTON_KIND:
        return ROLE_BUTTON
    if kind == VIEW_TEXT_INPUT_KIND:
        return ROLE_TEXT_INPUT
    if kind == VIEW_SPACER_KIND:
        return ROLE_SPACER
    if kind == VIEW_CONTAINER_KIND:
        return ROLE_CONTAINER
    if kind == VIEW_CHECKBOX_KIND:
        return ROLE_CHECKBOX
    if kind == VIEW_PROGRESS_KIND:
        return ROLE_PROGRESS_INDICATOR
    if kind == VIEW_SLIDER_KIND:
        return ROLE_SLIDER
    if kind == VIEW_SWITCH_KIND:
        return ROLE_SWITCH
    if kind == VIEW_RADIO_KIND:
        return ROLE_RADIO
    if kind == VIEW_IMAGE_KIND:
        return ROLE_IMAGE
    if kind == VIEW_MULTILINE_TEXT_KIND:
        return ROLE_TEXT_AREA
    if kind == VIEW_COMBO_BOX_KIND:
        return ROLE_COMBO_BOX
    if kind == VIEW_LIST_KIND:
        return ROLE_LIST
    if kind == VIEW_TABLE_KIND:
        return ROLE_TABLE
    if kind == VIEW_TREE_KIND:
        return ROLE_TREE
    if kind == VIEW_MENU_KIND:
        return ROLE_MENU
    if kind == VIEW_DIALOG_KIND:
        return ROLE_DIALOG
    if kind == VIEW_TABS_KIND:
        return ROLE_TAB_GROUP
    if kind == VIEW_CANVAS_KIND:
        return ROLE_CANVAS
    if kind == VIEW_SEPARATOR_KIND:
        return ROLE_SEPARATOR
    return ROLE_NONE


def default_semantics(id: Int, kind: Int, text: String) -> Semantics:
    """Create the default semantics associated with a view node kind."""
    var role = role_for_kind(kind)
    var label = text
    var value = ""
    if role == ROLE_TEXT_INPUT:
        label = "Text input"
        value = text
    elif role == ROLE_PROGRESS_INDICATOR:
        label = text if text.count_codepoints() > 0 else "Progress"
    elif role == ROLE_SLIDER:
        label = text if text.count_codepoints() > 0 else "Slider"
    elif role == ROLE_SWITCH:
        label = text if text.count_codepoints() > 0 else "Switch"
    elif role == ROLE_RADIO:
        label = text if text.count_codepoints() > 0 else "Radio"
    elif role == ROLE_IMAGE:
        label = text if text.count_codepoints() > 0 else "Image"
    elif role == ROLE_TEXT_AREA:
        label = text if text.count_codepoints() > 0 else "Text area"
    elif role == ROLE_COMBO_BOX:
        label = text if text.count_codepoints() > 0 else "Combo box"
    elif role == ROLE_LIST:
        label = text if text.count_codepoints() > 0 else "List"
    elif role == ROLE_TABLE:
        label = text if text.count_codepoints() > 0 else "Table"
    elif role == ROLE_TREE:
        label = text if text.count_codepoints() > 0 else "Tree"
    elif role == ROLE_MENU:
        label = text if text.count_codepoints() > 0 else "Menu"
    elif role == ROLE_DIALOG:
        label = text if text.count_codepoints() > 0 else "Dialog"
    elif role == ROLE_TAB_GROUP:
        label = text if text.count_codepoints() > 0 else "Tabs"
    elif role == ROLE_CANVAS:
        label = text if text.count_codepoints() > 0 else "Canvas"
    elif role == ROLE_SEPARATOR:
        label = "Separator"
    var semantics = Semantics(id, role, label)
    semantics.value = value
    if role == ROLE_BUTTON or role == ROLE_CHECKBOX or role == ROLE_SWITCH or role == ROLE_RADIO:
        semantics.actions = ACTION_PRESS
    elif role == ROLE_SLIDER:
        semantics.actions = ACTION_INCREMENT | ACTION_DECREMENT
    elif role == ROLE_COMBO_BOX or role == ROLE_LIST or role == ROLE_TABLE or role == ROLE_TAB_GROUP:
        semantics.actions = ACTION_SELECT
    elif role == ROLE_TREE:
        semantics.actions = ACTION_SELECT | ACTION_EXPAND | ACTION_COLLAPSE
    elif role == ROLE_MENU or role == ROLE_DIALOG:
        semantics.actions = ACTION_PRESS | ACTION_SELECT
    return semantics^


struct AccessibilitySnapshot:
    """Ordered semantics for one laid-out frame."""

    var nodes: List[Semantics]

    def __init__(out self):
        self.nodes = List[Semantics]()

    def append(mut self, node: Semantics):
        self.nodes.append(node)

    def count(self) -> Int:
        return len(self.nodes)

    def node(self, index: Int) -> Semantics:
        return self.nodes[index]

    def node_for_id(self, id: Int) -> Semantics:
        for index in range(len(self.nodes)):
            if self.nodes[index].id == id:
                return self.nodes[index]
        return Semantics(-1, ROLE_NONE, "")

    def is_valid(self) -> Bool:
        """Check stable ids and parent links in the semantic snapshot."""
        for index in range(len(self.nodes)):
            var node = self.nodes[index]
            for previous in range(index):
                if self.nodes[previous].id == node.id:
                    return False
            if node.parent_id == node.id:
                return False
            if node.parent_id == -1:
                continue
            var found_parent = False
            for parent in range(len(self.nodes)):
                if self.nodes[parent].id == node.parent_id:
                    found_parent = True
                    break
            if not found_parent:
                return False
            var current_parent = node.parent_id
            var hops = 0
            while current_parent != -1:
                if current_parent == node.id:
                    return False
                var parent_found = False
                for parent in range(len(self.nodes)):
                    if self.nodes[parent].id == current_parent:
                        current_parent = self.nodes[parent].parent_id
                        parent_found = True
                        break
                if not parent_found:
                    return False
                hops += 1
                if hops > len(self.nodes):
                    return False
        return True
