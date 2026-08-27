"""Minimal visible Moxi demo."""

from moxi import Label, Rect, Runtime
from moxi.macos import MacOSBackend


def main() raises:
    var runtime = Runtime()
    var view = Label(1, "Hello from Moxi", Rect(32.0, 28.0, 320.0, 56.0))
    runtime.reconcile(view)
    var command = runtime.paint()

    var backend = MacOSBackend()
    backend.draw_label(command)
