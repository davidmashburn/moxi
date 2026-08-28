"""Declarative view values."""

from .geometry import Rect


struct Label:
    """A declarative text view with stable identity and bounds."""

    var id: Int
    var text: String
    var bounds: Rect

    def __init__(out self, id: Int, text: String, bounds: Rect):
        self.id = id
        self.text = text
        self.bounds = bounds


struct Button:
    """A declarative clickable text view with stable identity and bounds."""

    var id: Int
    var text: String
    var bounds: Rect

    def __init__(out self, id: Int, text: String, bounds: Rect):
        self.id = id
        self.text = text
        self.bounds = bounds


struct CounterView:
    """The fixed-geometry two-widget view used by the counter example."""

    var label: Label
    var button: Button

    def __init__(out self, count: Int):
        self.label = Label(
            1, String("Count: ", count), Rect(32.0, 28.0, 320.0, 40.0)
        )
        self.button = Button(
            2, "Increment", Rect(32.0, 84.0, 140.0, 36.0)
        )
