"""Contract smoke test for the first Moxi vertical slice."""

from moxi import Label, Rect, Runtime


def main():
    var runtime = Runtime()
    var view = Label(7, "Smoke test", Rect(1.0, 2.0, 120.0, 32.0))
    runtime.reconcile(view)
    var command = runtime.paint()

    assert runtime.widget.id == 7
    assert runtime.widget.text == "Smoke test"
    assert command.bounds.width == 120.0
    print("Moxi smoke test passed")
