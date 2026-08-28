"""Interactive composed counter demo using Moxi's component lifecycle."""

from moxi import App, ClickEvent, CounterState, Rect, WindowConfig
from moxi.macos import MacOSRenderer, MacOSWindow


def main() raises:
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    window.open(WindowConfig("Moxi Counter", 384.0, 184.0))
    var size = window.size()
    var app = App[CounterState](
        CounterState(),
        Rect(0.0, 0.0, size.width, size.height),
    )
    app.render(renderer)
    var previous_size = size

    while window.is_open():
        window.pump()
        var current_size = window.size()
        if current_size.width != previous_size.width or current_size.height != previous_size.height:
            previous_size = current_size
            if app.resize(Rect(0.0, 0.0, current_size.width, current_size.height)):
                app.render(renderer)
        if window.poll_click():
            var event = ClickEvent(window.click_position())
            if app.update(event):
                app.render(renderer)
