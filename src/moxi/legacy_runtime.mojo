"""Legacy reconciliation runtimes: single-`Label` `Runtime` and `CounterRuntime`."""


from .column_runtime import ColumnRuntime
from .geometry import Point, Rect
from .paint import PaintCommand, PaintCommands
from .style import default_button_style
from .view import BUTTON_KIND, CounterView, Label
from .widget import Widget


struct Runtime:
    """Reconciles one declarative Label into one retained Widget."""

    var widget: Widget

    def __init__(out self):
        self.widget = Widget(0, "", Rect(0.0, 0.0, 0.0, 0.0))

    def reconcile(mut self, view: Label):
        self.widget.id = view.id
        self.widget.text = view.text
        self.widget.bounds = view.bounds
        self.widget.semantics.label = view.text
        self.widget.semantics.bounds = view.bounds

    def paint(self) -> PaintCommand:
        return PaintCommand(self.widget.text, self.widget.bounds)

struct CounterRuntime:
    """Retained state for the composed counter screen."""

    var column: ColumnRuntime
    var label: Widget
    var button: Widget

    def __init__(out self):
        self.column = ColumnRuntime()
        self.label = Widget(0, "", Rect(0.0, 0.0, 0.0, 0.0))
        self.button = Widget(0, "", Rect(0.0, 0.0, 0.0, 0.0))

    def reconcile(mut self, view: CounterView):
        """Reconcile the complete declarative column."""
        self.column.reconcile(view.column)
        self.label = Widget(
            view.label.id,
            view.label.text,
            view.label.bounds,
        )
        self.button = Widget(
            view.button.id,
            view.button.text,
            view.button.bounds,
        )
        self.button.kind = BUTTON_KIND
        self.button.style = default_button_style()

    def paint(mut self) -> PaintCommands:
        return self.column.paint()

    def hit_test(self, position: Point) -> Int:
        return self.column.hit_test(position)

    def paint_label(self) -> PaintCommand:
        return PaintCommand(self.label.text, self.label.bounds)

    def paint_button(self) -> PaintCommand:
        return PaintCommand(
            BUTTON_KIND,
            self.button.id,
            0,
            self.button.text,
            self.button.bounds,
            self.button.style,
        )
