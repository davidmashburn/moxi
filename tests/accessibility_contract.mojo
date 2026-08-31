"""Contract tests for semantic actions and snapshot integrity."""

from moxi import (
    ACTION_DECREMENT,
    ACTION_EXPAND,
    ACTION_COLLAPSE,
    ACTION_INCREMENT,
    ACTION_PRESS,
    AccessibilitySnapshot,
    ButtonControl,
    CheckboxControl,
    ComboBoxControl,
    ColumnRuntime,
    ColumnView,
    ROLE_BUTTON,
    ROLE_COMBO_BOX,
    ROLE_SLIDER,
    Semantics,
    SliderControl,
    RadioControl,
    Rect,
    test_check,
)


def main():
    var button = Semantics(1, ROLE_BUTTON, "OK")
    button.set_actions(ACTION_PRESS)
    test_check(button.supports_action(ACTION_PRESS))
    button.set_checked(True)
    button.set_expanded(True)
    button.set_value_range(0.0, 10.0, 4.0)
    test_check(button.checked)
    test_check(button.expanded)
    test_check(button.has_value_range)
    test_check(button.value_now == 4.0)

    var view = ColumnView(Rect(0.0, 0.0, 320.0, 160.0), 8.0, 4.0)
    view.add(ButtonControl(1, "OK", 32.0).node())
    view.add(CheckboxControl(3, "Remember", True, 28.0).node())
    view.add(SliderControl(2, "Volume", 0.5, 0.0, 1.0, 0.1, 24.0).node())
    view.layout()
    var runtime = ColumnRuntime()
    runtime.reconcile(view)
    var snapshot = runtime.accessibility()
    test_check(snapshot.is_valid())
    test_check(snapshot.node_for_id(1).supports_action(ACTION_PRESS))
    test_check(snapshot.node_for_id(2).role == ROLE_SLIDER)
    test_check(snapshot.node_for_id(2).supports_action(ACTION_INCREMENT))
    test_check(snapshot.node_for_id(2).supports_action(ACTION_DECREMENT))
    test_check(snapshot.node_for_id(2).has_value_range)
    test_check(snapshot.node_for_id(2).value_min == 0.0)
    test_check(snapshot.node_for_id(2).value_max == 1.0)
    test_check(snapshot.node_for_id(2).value_now == 0.5)
    test_check(snapshot.node_for_id(3).checked)

    var radio = RadioControl(5, 2, "Dark", True, 28.0).node()
    test_check(radio.semantics.selected)
    test_check(radio.semantics.checked)

    var combo = ComboBoxControl(4, "Theme", "Dark", 28.0, True).node()
    test_check(combo.semantics.role == ROLE_COMBO_BOX)
    test_check(combo.semantics.expanded)
    test_check(combo.semantics.supports_action(ACTION_EXPAND))
    test_check(combo.semantics.supports_action(ACTION_COLLAPSE))

    var invalid = AccessibilitySnapshot()
    invalid.append(Semantics(1, ROLE_BUTTON, "one"))
    invalid.append(Semantics(1, ROLE_BUTTON, "duplicate"))
    test_check(not invalid.is_valid())
    print("Moxi accessibility-contract test passed")
