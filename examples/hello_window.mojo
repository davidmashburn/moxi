"""Minimal visible Moxi demo."""

from moxi import Label, Rect, Runtime, WindowConfig
from moxi.macos import MacOSRenderer, MacOSWindow


def main() raises:
    var runtime = Runtime()
    var view = Label(1, "Hello from Moxi", Rect(32.0, 28.0, 320.0, 56.0))
    runtime.reconcile(view)
    var command = runtime.paint()

    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    window.open(WindowConfig("Moxi", 384.0, 144.0))
    renderer.begin_frame()
    renderer.draw_label(command)
    window.run()
