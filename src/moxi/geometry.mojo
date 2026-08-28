"""Geometry shared by views, retained widgets, and render backends."""


struct Point(ImplicitlyCopyable):
    """A point in window content coordinates."""

    var x: Float32
    var y: Float32

    def __init__(out self, x: Float32, y: Float32):
        self.x = x
        self.y = y

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

    def contains(self, point: Point) -> Bool:
        """Return whether a point falls inside this rectangle."""
        if point.x < self.x or point.y < self.y:
            return False
        if point.x > self.x + self.width or point.y > self.y + self.height:
            return False
        return True
