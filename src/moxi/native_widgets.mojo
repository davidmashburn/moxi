"""Semantic/native-widget mapping shared by platform presenters."""

from std.collections import List

from .accessibility import (
    ACTION_COLLAPSE,
    ACTION_EXPAND,
    ACTION_INCREMENT,
    ACTION_PRESS,
    ACTION_SELECT,
    AccessibilitySnapshot,
    ROLE_BUTTON,
    ROLE_CHECKBOX,
    ROLE_COMBO_BOX,
    ROLE_DIALOG,
    ROLE_IMAGE,
    ROLE_LABEL,
    ROLE_LIST,
    ROLE_MENU,
    ROLE_PROGRESS_INDICATOR,
    ROLE_RADIO,
    ROLE_SEPARATOR,
    ROLE_SLIDER,
    ROLE_SWITCH,
    ROLE_TAB_GROUP,
    ROLE_TABLE,
    ROLE_TEXT_AREA,
    ROLE_TEXT_INPUT,
    ROLE_TREE,
)
from .geometry import Rect


comptime NATIVE_WIDGET_LABEL = 1
comptime NATIVE_WIDGET_BUTTON = 2
comptime NATIVE_WIDGET_TEXT_INPUT = 3
comptime NATIVE_WIDGET_CHECKBOX = 4
comptime NATIVE_WIDGET_SLIDER = 5
comptime NATIVE_WIDGET_SWITCH = 6
comptime NATIVE_WIDGET_RADIO = 7
comptime NATIVE_WIDGET_IMAGE = 8
comptime NATIVE_WIDGET_TEXT_AREA = 9
comptime NATIVE_WIDGET_COMBO_BOX = 10
comptime NATIVE_WIDGET_LIST = 11
comptime NATIVE_WIDGET_TABLE = 12
comptime NATIVE_WIDGET_TREE = 13
comptime NATIVE_WIDGET_MENU = 14
comptime NATIVE_WIDGET_DIALOG = 15
comptime NATIVE_WIDGET_TABS = 16
comptime NATIVE_WIDGET_SEPARATOR = 17
comptime NATIVE_WIDGET_CANVAS = 18
comptime NATIVE_WIDGET_CUSTOM = 19


def native_widget_kind(role: Int) -> Int:
    """Map a semantic role to a platform presenter category."""
    if role == ROLE_LABEL:
        return NATIVE_WIDGET_LABEL
    if role == ROLE_BUTTON:
        return NATIVE_WIDGET_BUTTON
    if role == ROLE_TEXT_INPUT:
        return NATIVE_WIDGET_TEXT_INPUT
    if role == ROLE_CHECKBOX:
        return NATIVE_WIDGET_CHECKBOX
    if role == ROLE_SLIDER:
        return NATIVE_WIDGET_SLIDER
    if role == ROLE_SWITCH:
        return NATIVE_WIDGET_SWITCH
    if role == ROLE_RADIO:
        return NATIVE_WIDGET_RADIO
    if role == ROLE_IMAGE:
        return NATIVE_WIDGET_IMAGE
    if role == ROLE_TEXT_AREA:
        return NATIVE_WIDGET_TEXT_AREA
    if role == ROLE_COMBO_BOX:
        return NATIVE_WIDGET_COMBO_BOX
    if role == ROLE_LIST:
        return NATIVE_WIDGET_LIST
    if role == ROLE_TABLE:
        return NATIVE_WIDGET_TABLE
    if role == ROLE_TREE:
        return NATIVE_WIDGET_TREE
    if role == ROLE_MENU:
        return NATIVE_WIDGET_MENU
    if role == ROLE_DIALOG:
        return NATIVE_WIDGET_DIALOG
    if role == ROLE_TAB_GROUP:
        return NATIVE_WIDGET_TABS
    if role == ROLE_SEPARATOR:
        return NATIVE_WIDGET_SEPARATOR
    return NATIVE_WIDGET_CUSTOM


struct NativeWidgetDescriptor(ImplicitlyCopyable):
    """A presenter's typed view of one semantic widget."""

    var id: Int
    var parent_id: Int
    var kind: Int
    var label: String
    var value: String
    var bounds: Rect
    var enabled: Bool
    var focused: Bool
    var selected: Bool
    var actions: Int

    def __init__(out self):
        self.id = -1
        self.parent_id = -1
        self.kind = NATIVE_WIDGET_CUSTOM
        self.label = ""
        self.value = ""
        self.bounds = Rect(0.0, 0.0, 0.0, 0.0)
        self.enabled = False
        self.focused = False
        self.selected = False
        self.actions = 0

    def supports(self, action: Int) -> Bool:
        return (self.actions & action) != 0


struct NativeWidgetRegistry:
    """Rebuildable semantic registry consumed by native widget presenters."""

    var widgets: List[NativeWidgetDescriptor]
    var version: Int

    def __init__(out self):
        self.widgets = List[NativeWidgetDescriptor]()
        self.version = 0

    def sync(mut self, snapshot: AccessibilitySnapshot):
        self.widgets = List[NativeWidgetDescriptor](capacity=snapshot.count())
        for index in range(snapshot.count()):
            var semantics = snapshot.node(index)
            var descriptor = NativeWidgetDescriptor()
            descriptor.id = semantics.id
            descriptor.parent_id = semantics.parent_id
            descriptor.kind = native_widget_kind(semantics.role)
            descriptor.label = semantics.label
            descriptor.value = semantics.value
            descriptor.bounds = semantics.bounds
            descriptor.enabled = semantics.enabled
            descriptor.focused = semantics.focused
            descriptor.selected = semantics.selected
            descriptor.actions = semantics.actions
            self.widgets.append(descriptor)
        self.version += 1

    def count(self) -> Int:
        return len(self.widgets)

    def widget(self, index: Int) -> NativeWidgetDescriptor:
        if index < 0 or index >= len(self.widgets):
            return NativeWidgetDescriptor()
        return self.widgets[index]

    def widget_for_id(self, id: Int) -> NativeWidgetDescriptor:
        for index in range(len(self.widgets)):
            if self.widgets[index].id == id:
                return self.widgets[index]
        return NativeWidgetDescriptor()
