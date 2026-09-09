"""`CounterView`: the counter screen expressed as a small composed view tree."""


from .column_view import ColumnView, make_counter_column
from .geometry import Point, Rect
from .view_leaf import Button, Label


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
