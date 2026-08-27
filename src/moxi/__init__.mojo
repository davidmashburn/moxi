"""The smallest useful Moxi view, retained-widget, and paint model."""

struct Rect(ImplicitlyCopyable):
    var x: Float32
    var y: Float32
    var width: Float32
    var height: Float32

    def __init__(out self, x: Float32, y: Float32, width: Float32, height: Float32):
        self.x = x
        self.y = y
        self.width = width
        self.height = height


struct Label:
    """A declarative text view with stable identity and bounds."""

    var id: Int
    var text: String
    var bounds: Rect

    def __init__(out self, id: Int, text: String, bounds: Rect):
        self.id = id
        self.text = text
        self.bounds = bounds


struct Widget:
    """The retained runtime state corresponding to a declarative Label."""

    var id: Int
    var text: String
    var bounds: Rect

    def __init__(out self, id: Int, text: String, bounds: Rect):
        self.id = id
        self.text = text
        self.bounds = bounds


struct PaintCommand:
    """A backend-neutral command for the first visible rendering slice."""

    var text: String
    var bounds: Rect

    def __init__(out self, text: String, bounds: Rect):
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


def moxi_version() -> String:
    """Return the package version embedded in this release."""
    return "0.1.0"
