"""Intrinsic text and opt-in control sizing contract test."""

from moxi import test_check
from moxi import (
    ALIGN_START,
    ButtonControl,
    ColumnRuntime,
    ColumnView,
    Color,
    Rect,
    Style,
    measure_text,
    measure_text_wrapped,
)


def main():
    var style = Style(
        Color(0.0, 0.0, 0.0, 0.0),
        Color(1.0, 1.0, 1.0, 1.0),
        0.0,
        20.0,
    )
    var measured = measure_text("Moxi", style)
    test_check(measured.width > 0.0)
    test_check(measured.height >= 25.0)

    var wrapped = measure_text_wrapped(
        "Moxi wraps deterministic text across lines",
        style,
        80.0,
    )
    test_check(wrapped.line_count > 1)
    test_check(wrapped.size.width <= 80.0)
    test_check(wrapped.size.height > measured.height)

    var button = ButtonControl(1, "OK", 0.0).node()
    var button_size = button.intrinsic_size()
    test_check(button_size.width > measured.width)
    test_check(button_size.height > measured.height)

    var row = ColumnView(Rect(0.0, 0.0, 400.0, 80.0), 10.0, 8.0)
    row.set_horizontal_layout()
    row.add(ButtonControl(1, "OK", 0.0).node())
    row.add(ButtonControl(2, "Cancel", 0.0).node())
    row.set_intrinsic_width(1)
    row.set_intrinsic_width(2)
    row.layout()
    test_check(row.child(0).bounds.width > 0.0)
    test_check(row.child(1).bounds.width > row.child(0).bounds.width)
    test_check(row.child(0).bounds.width < 100.0)

    var column = ColumnView(Rect(0.0, 0.0, 200.0, 100.0), 10.0, 5.0)
    column.add_label(3, "Intrinsic label", 0.0)
    column.set_intrinsic_height(3)
    column.layout()
    test_check(column.child(0).bounds.height > 0.0)
    test_check(column.intrinsic_size().width > 0.0)

    var wrapped_column = ColumnView(
        Rect(0.0, 0.0, 240.0, 160.0),
        10.0,
        5.0,
    )
    wrapped_column.set_cross_alignment(ALIGN_START)
    wrapped_column.add_label(4, "Moxi wraps this label across lines", 0.0)
    wrapped_column.set_preferred_width(4, 80.0)
    wrapped_column.set_wrap(4)
    wrapped_column.set_intrinsic_height(4)
    wrapped_column.layout()
    test_check(wrapped_column.child(0).wrap_text)
    test_check(wrapped_column.child(0).bounds.width == 80.0)
    test_check(wrapped_column.child(0).bounds.height > measured.height)
    var wrapped_runtime = ColumnRuntime()
    wrapped_runtime.reconcile(wrapped_column)
    var wrapped_commands = wrapped_runtime.paint()
    test_check(wrapped_commands.command(1).wrap_text)
    print("Moxi measurement test passed")
