"""Legacy declarative leaf views: `Label` and `Button`."""


from .geometry import Rect


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

