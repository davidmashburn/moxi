"""Wrapped-text measurement, layout, and paint contract test."""

from moxi import test_check
from moxi import (
    App,
    Color,
    Rect,
    Style,
    WrappedTextState,
    measure_text_wrapped,
)


def main():
    var style = Style(
        Color(0.0, 0.0, 0.0, 0.0),
        Color(1.0, 1.0, 1.0, 1.0),
        0.0,
        20.0,
    )
    var measured = measure_text_wrapped(
        "wrap this deterministic paragraph",
        style,
        90.0,
    )
    test_check(measured.line_count > 1)
    test_check(measured.size.width <= 90.0)

    var app = App[WrappedTextState](
        WrappedTextState(),
        Rect(0.0, 0.0, 560.0, 320.0),
    )
    test_check(app.view_is_valid())
    test_check(app.view.child(1).wrap_text)
    test_check(app.view.child(1).bounds.width == 496.0)
    test_check(app.view.child(1).bounds.height > 25.0)
    var initial_height = app.view.child(1).bounds.height
    test_check(app.resize(Rect(0.0, 0.0, 320.0, 320.0)))
    test_check(app.view.child(1).bounds.width == 256.0)
    test_check(app.view.child(1).bounds.height > initial_height)
    var commands = app.paint()
    test_check(commands.command(3).wrap_text)
    print("Moxi wrapped-text test passed")
