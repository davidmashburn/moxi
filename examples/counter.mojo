"""Interactive counter demo for Moxi's first event-driven slice."""

from moxi import ClickEvent, CounterRuntime, CounterState, WindowConfig
from moxi.macos import MacOSRenderer, MacOSWindow


def main() raises:
    var state = CounterState()
    var view = state.view()
    var runtime = CounterRuntime()
    runtime.reconcile(view)

    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    window.open(WindowConfig("Moxi Counter", 384.0, 144.0))
    renderer.draw_label(runtime.paint_label())
    renderer.draw_button(runtime.paint_button())

    while window.is_open():
        window.pump()
        if window.poll_click():
            var event = ClickEvent(window.click_position())
            state.update(event, view.button)
            view = state.view()
            runtime.reconcile(view)
            renderer.draw_label(runtime.paint_label())
            renderer.draw_button(runtime.paint_button())
