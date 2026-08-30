"""Native presenter mapping contract test."""

from moxi import (
    AccessibilitySnapshot,
    NativeWidgetRegistry,
    NATIVE_WIDGET_BUTTON,
    NATIVE_WIDGET_TEXT_INPUT,
    ROLE_BUTTON,
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
    snapshot.append(button)
    snapshot.append(input)
    var registry = NativeWidgetRegistry()
    registry.sync(snapshot)
    test_check(registry.count() == 2)
    test_check(registry.widget(0).kind == NATIVE_WIDGET_BUTTON)
    test_check(registry.widget_for_id(2).kind == NATIVE_WIDGET_TEXT_INPUT)
    test_check(registry.widget_for_id(2).value == "Moxi")
    print("Moxi native-widgets test passed")
