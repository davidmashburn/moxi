"""Native presenter mapping contract test."""

from moxi import (
    AccessibilitySnapshot,
    NativeWidgetRegistry,
    NATIVE_WIDGET_BUTTON,
    NATIVE_WIDGET_COMBO_BOX,
    NATIVE_WIDGET_TEXT_INPUT,
    ROLE_BUTTON,
    ROLE_COMBO_BOX,
    ROLE_SLIDER,
    ROLE_TREE,
    ROLE_TEXT_INPUT,
    Semantics,
    Rect,
    test_check,
)


def main():
    var snapshot = AccessibilitySnapshot()
    var button = Semantics(1, ROLE_BUTTON, "Save")
    button.bounds = Rect(0.0, 0.0, 80.0, 24.0)
    var input = Semantics(2, ROLE_TEXT_INPUT, "Name")
    input.value = "Moxi"
    var slider = Semantics(3, ROLE_SLIDER, "Zoom")
    slider.set_value_range(1.0, 10.0, 4.0)
    var tree = Semantics(4, ROLE_TREE, "Outline")
    tree.set_expanded(True)
    var combo = Semantics(5, ROLE_COMBO_BOX, "Theme")
    combo.set_expanded(True)
    snapshot.append(button)
    snapshot.append(input)
    snapshot.append(slider)
    snapshot.append(tree)
    snapshot.append(combo)
    var registry = NativeWidgetRegistry()
    registry.sync(snapshot)
    test_check(registry.count() == 5)
    test_check(registry.widget(0).kind == NATIVE_WIDGET_BUTTON)
    test_check(registry.widget_for_id(2).kind == NATIVE_WIDGET_TEXT_INPUT)
    test_check(registry.widget_for_id(2).value == "Moxi")
    test_check(registry.widget_for_id(3).has_value_range)
    test_check(registry.widget_for_id(3).value_now == 4.0)
    test_check(registry.widget_for_id(4).expanded)
    test_check(registry.widget_for_id(5).kind == NATIVE_WIDGET_COMBO_BOX)
    test_check(registry.widget_for_id(5).expanded)
    print("Moxi native-widgets test passed")
