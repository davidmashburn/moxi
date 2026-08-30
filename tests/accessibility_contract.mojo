"""Contract tests for semantic actions and snapshot integrity."""

from moxi import (
    ACTION_DECREMENT,
    ACTION_INCREMENT,
    ACTION_PRESS,
    AccessibilitySnapshot,
    ButtonControl,
    ColumnRuntime,
    ColumnView,
    ROLE_BUTTON,
    ROLE_SLIDER,
    Semantics,
    SliderControl,
    Rect,
    test_check,
)


def main():
    var button = Semantics(1, ROLE_BUTTON, "OK")
    button.set_actions(ACTION_PRESS)
    test_check(button.supports_action(ACTION_PRESS))

    var view = ColumnView(Rect(0.0, 0.0, 320.0, 160.0), 8.0, 4.0)
    view.add(ButtonControl(1, "OK", 32.0).node())
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

    var invalid = AccessibilitySnapshot()
    invalid.append(Semantics(1, ROLE_BUTTON, "one"))
    invalid.append(Semantics(1, ROLE_BUTTON, "duplicate"))
    test_check(not invalid.is_valid())
    print("Moxi accessibility-contract test passed")
