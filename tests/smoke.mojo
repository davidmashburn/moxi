"""Contract smoke test for the first Moxi vertical slice."""

from moxi import test_check
from moxi import Label, Rect, Runtime, moxi_version


def main():
    var runtime = Runtime()
    var view = Label(7, "Smoke test", Rect(1.0, 2.0, 120.0, 32.0))
    runtime.reconcile(view)
    var command = runtime.paint()

    test_check(runtime.widget.id == 7)
    test_check(runtime.widget.text == "Smoke test")
    test_check(command.bounds.width == 120.0)
    test_check(moxi_version() == "0.5.0")
    print("Moxi smoke test passed")
