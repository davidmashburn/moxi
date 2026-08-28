"""Retained widgets and the minimal reconciliation runtime."""

from std.collections import List

from .geometry import Point, Rect
from .paint import PANEL_KIND, SURFACE_KIND, PaintCommand, PaintCommands
from .style import (
    Panel,
    Style,
    default_button_style,
    default_label_style,
    default_panel_style,
    default_surface_style,
)
from .view import BUTTON_KIND, CounterView, LABEL_KIND, ColumnView, Label, ViewNode


struct Widget(ImplicitlyCopyable):
    """Retained runtime state corresponding to a declarative Label."""

    var kind: Int
    var id: Int
    var text: String
    var bounds: Rect
    var preferred_height: Float32
    var style: Style

    def __init__(out self, id: Int, text: String, bounds: Rect):
        self.kind = LABEL_KIND
        self.id = id
        self.text = text
        self.bounds = bounds
        self.preferred_height = bounds.height
        self.style = default_label_style()

    def __init__(out self, node: ViewNode):
        self.kind = node.kind
        self.id = node.id
        self.text = node.text
        self.bounds = node.bounds
        self.preferred_height = node.preferred_height
        self.style = node.style


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


struct ColumnRuntime:
    """Retained children reconciled from a declarative ColumnView."""

    var widgets: List[Widget]
    var root_bounds: Rect
    var surface_style: Style
    var panel: Panel
    var has_panel: Bool

    def __init__(out self):
        self.widgets = List[Widget]()
        self.root_bounds = Rect(0.0, 0.0, 0.0, 0.0)
        self.surface_style = default_surface_style()
        self.panel = Panel(0, Rect(0.0, 0.0, 0.0, 0.0), default_panel_style())
        self.has_panel = False

    def reconcile(mut self, view: ColumnView):
        self.root_bounds = view.layout_spec.bounds
        self.surface_style = view.surface_style
        self.panel = view.panel
        self.has_panel = view.has_panel
        self.widgets = List[Widget](capacity=view.child_count())
        for index in range(view.child_count()):
            self.widgets.append(Widget(view.child(index)))

    def widget_count(self) -> Int:
        return len(self.widgets)

    def widget(self, index: Int) -> Widget:
        return self.widgets[index]

    def paint(self) -> PaintCommands:
        var commands = PaintCommands()
        commands.append(
            PaintCommand(
                SURFACE_KIND,
                0,
                0,
                "",
                self.root_bounds,
                self.surface_style,
            )
        )
        if self.has_panel:
            commands.append(
                PaintCommand(
                    PANEL_KIND,
                    self.panel.id,
                    0,
                    "",
                    self.panel.bounds,
                    self.panel.style,
                )
            )
        var label_slot = 0
        var button_slot = 0
        for index in range(len(self.widgets)):
            var widget = self.widgets[index]
            var slot = label_slot
            if widget.kind == BUTTON_KIND:
                slot = button_slot
                button_slot += 1
            else:
                label_slot += 1
            commands.append(
                PaintCommand(
                    widget.kind,
                    widget.id,
                    slot,
                    widget.text,
                    widget.bounds,
                    widget.style,
                )
            )
        return commands^

    def hit_test(self, position: Point) -> Int:
        for index in range(len(self.widgets)):
            var widget = self.widgets[index]
            if widget.kind == BUTTON_KIND and widget.bounds.contains(position):
                return widget.id
        return -1


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

    def paint(self) -> PaintCommands:
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
