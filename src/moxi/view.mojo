"""Declarative view values and the first composable container."""

from std.collections import List

from .geometry import Point, Rect
from .layout import ColumnLayout
from .style import (
    Panel,
    Style,
    default_button_style,
    default_label_style,
    default_panel_style,
    default_surface_style,
)


comptime LABEL_KIND = 1
comptime BUTTON_KIND = 2


struct Label(ImplicitlyCopyable):
    """A declarative text view with stable identity and bounds."""

    var id: Int
    var text: String
    var bounds: Rect

    def __init__(out self, id: Int, text: String, bounds: Rect):
        self.id = id
        self.text = text
        self.bounds = bounds


struct Button(ImplicitlyCopyable):
    """A declarative clickable text view with stable identity and bounds."""

    var id: Int
    var text: String
    var bounds: Rect

    def __init__(out self, id: Int, text: String, bounds: Rect):
        self.id = id
        self.text = text
        self.bounds = bounds


struct ViewNode(ImplicitlyCopyable):
    """A lightweight leaf in a declarative Moxi view tree."""

    var kind: Int
    var id: Int
    var text: String
    var preferred_height: Float32
    var bounds: Rect
    var style: Style

    def __init__(
        out self,
        kind: Int,
        id: Int,
        text: String,
        preferred_height: Float32,
    ):
        var style = default_label_style()
        if kind == BUTTON_KIND:
            style = default_button_style()
        self.kind = kind
        self.id = id
        self.text = text
        self.preferred_height = preferred_height
        self.bounds = Rect(0.0, 0.0, 0.0, 0.0)
        self.style = style

    def __init__(
        out self,
        kind: Int,
        id: Int,
        text: String,
        preferred_height: Float32,
        style: Style,
    ):
        self.kind = kind
        self.id = id
        self.text = text
        self.preferred_height = preferred_height
        self.bounds = Rect(0.0, 0.0, 0.0, 0.0)
        self.style = style


def make_counter_column(count: Int, bounds: Rect) -> ColumnView:
    """Build the counter's composed view tree from its current state."""
    var count_text = String("Count: ", count)
    var column = ColumnView(
        bounds,
        32.0,
        8.0,
    )
    var panel_width = bounds.width - 40.0
    var panel_height = bounds.height - 40.0
    if panel_width < 0.0:
        panel_width = 0.0
    if panel_height < 0.0:
        panel_height = 0.0
    column.set_surface_style(default_surface_style())
    column.set_panel(
        0,
        Rect(bounds.x + 20.0, bounds.y + 20.0, panel_width, panel_height),
        default_panel_style(),
    )
    column.add_label(1, "Moxi Counter", 28.0)
    column.add_label(2, count_text, 40.0)
    column.add_button(3, "Increment", 36.0)
    column.layout()
    return column^


struct ColumnView:
    """A lightweight vertical container of composable leaf views."""

    var layout_spec: ColumnLayout
    var children: List[ViewNode]
    var surface_style: Style
    var panel: Panel
    var has_panel: Bool

    def __init__(
        out self,
        bounds: Rect,
        padding: Float32,
        spacing: Float32,
    ):
        self.layout_spec = ColumnLayout(bounds, padding, spacing)
        self.children = List[ViewNode]()
        self.surface_style = default_surface_style()
        self.panel = Panel(
            0,
            Rect(0.0, 0.0, 0.0, 0.0),
            default_panel_style(),
        )
        self.has_panel = False

    def add(mut self, child: ViewNode):
        """Append a declarative child before running layout."""
        self.children.append(child)

    def add_label(
        mut self,
        id: Int,
        text: String,
        preferred_height: Float32,
    ):
        self.add(ViewNode(LABEL_KIND, id, text, preferred_height))

    def add_button(
        mut self,
        id: Int,
        text: String,
        preferred_height: Float32,
    ):
        self.add(ViewNode(BUTTON_KIND, id, text, preferred_height))

    def add_label_styled(
        mut self,
        id: Int,
        text: String,
        preferred_height: Float32,
        style: Style,
    ):
        self.add(ViewNode(LABEL_KIND, id, text, preferred_height, style))

    def add_button_styled(
        mut self,
        id: Int,
        text: String,
        preferred_height: Float32,
        style: Style,
    ):
        self.add(ViewNode(BUTTON_KIND, id, text, preferred_height, style))

    def set_surface_style(mut self, style: Style):
        self.surface_style = style

    def set_panel(mut self, id: Int, bounds: Rect, style: Style):
        self.panel = Panel(id, bounds, style)
        self.has_panel = True

    def layout(mut self):
        """Assign deterministic bounds to children in declaration order."""
        var cursor = self.layout_spec.bounds.y + self.layout_spec.padding
        for index in range(len(self.children)):
            var height = self.children[index].preferred_height
            self.children[index].bounds = self.layout_spec.child_rect(cursor, height)
            cursor += height + self.layout_spec.spacing

    def layout_children(mut self):
        """Compatibility spelling for the layout pass."""
        self.layout()

    def child_count(self) -> Int:
        return len(self.children)

    def child(self, index: Int) -> ViewNode:
        return self.children[index]

    def bounds_for(self, id: Int) -> Rect:
        for index in range(len(self.children)):
            if self.children[index].id == id:
                return self.children[index].bounds
        return Rect(0.0, 0.0, 0.0, 0.0)

    def hit_test(self, position: Point) -> Int:
        """Return the button id under a point, or -1 when there is no target."""
        for index in range(len(self.children)):
            var child = self.children[index]
            if child.kind == BUTTON_KIND and child.bounds.contains(position):
                return child.id
        return -1


struct CounterView:
    """The counter screen expressed as a small composed view tree."""

    var column: ColumnView
    var label: Label
    var button: Button

    def __init__(out self, count: Int):
        var count_text = String("Count: ", count)
        self.column = make_counter_column(
            count,
            Rect(0.0, 0.0, 384.0, 184.0),
        )

        self.label = Label(2, count_text, self.column.bounds_for(2))
        self.button = Button(
            3,
            "Increment",
            self.column.bounds_for(3),
        )

    def hit_test(self, position: Point) -> Int:
        """Route a point through the laid-out composed view tree."""
        return self.column.hit_test(position)
