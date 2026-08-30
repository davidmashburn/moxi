"""Checkbox and progress-control contract test."""

from moxi import test_check
from moxi import (
    CHECKBOX_KIND,
    ColumnRuntime,
    ColumnView,
    CheckboxControl,
    ProgressControl,
    Rect,
    ROLE_CHECKBOX,
    ROLE_PROGRESS_INDICATOR,
)


def main():
    var view = ColumnView(Rect(0.0, 0.0, 360.0, 180.0), 12.0, 8.0)
    var remember = CheckboxControl(1, "Remember name", True, 28.0)
    view.add(remember.node())
    var progress = ProgressControl(2, "Completion", 0.5, 24.0)
    view.add(progress.node())
    view.layout()

    test_check(view.child(0).kind == CHECKBOX_KIND)
    test_check(view.child(0).checked)
    test_check(view.child(0).semantics.role == ROLE_CHECKBOX)
    test_check(view.child(0).semantics.value == "checked")
    test_check(view.child(1).semantics.role == ROLE_PROGRESS_INDICATOR)
    test_check(view.child(1).semantics.value == "50%")

    var runtime = ColumnRuntime()
    runtime.reconcile(view)
    test_check(runtime.focus_id() == 1)
    var commands = runtime.paint()
    test_check(commands.count() == 3)
    test_check(commands.command(1).checked)
    test_check(commands.command(2).progress == 0.5)
    print("Moxi controls test passed")
