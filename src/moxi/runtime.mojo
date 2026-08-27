"""Retained widgets and the minimal reconciliation runtime."""

from .geometry import Rect
from .paint import PaintCommand
from .view import Label


struct Widget:
    """Retained runtime state corresponding to a declarative Label."""

    var id: Int
    var text: String
    var bounds: Rect

    def __init__(out self, id: Int, text: String, bounds: Rect):
        self.id = id
        self.text = text
        self.bounds = bounds


struct Runtime:
    """Reconciles one declarative Label into one retained Widget."""

    var widget: Widget

    def __init__(out self):
        self.widget = Widget(0, "", Rect(0.0, 0.0, 0.0, 0.0))

    def reconcile(mut self, view: Label):
        self.widget.id = view.id
        self.widget.text = view.text
        self.widget.bounds = view.bounds

    def paint(self) -> PaintCommand:
        return PaintCommand(self.widget.text, self.widget.bounds)
