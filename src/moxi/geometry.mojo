"""Geometry shared by views, retained widgets, and render backends."""


struct Point(ImplicitlyCopyable):
    """A point in window content coordinates."""

    var x: Float32
    var y: Float32

    def __init__(out self, x: Float32, y: Float32):
        self.x = x
        self.y = y


struct Size(ImplicitlyCopyable):
    """A window or layout extent in content coordinates."""

    var width: Float32
    var height: Float32

    def __init__(out self, width: Float32, height: Float32):
        self.width = width
        self.height = height


struct Transform(ImplicitlyCopyable):
    """A 2D affine transform in renderer-neutral coordinates."""

    var m11: Float32
    var m12: Float32
    var m21: Float32
    var m22: Float32
    var tx: Float32
    var ty: Float32

    def __init__(
        out self,
        m11: Float32 = 1.0,
        m12: Float32 = 0.0,
        m21: Float32 = 0.0,
        m22: Float32 = 1.0,
        tx: Float32 = 0.0,
        ty: Float32 = 0.0,
    ):
        self.m11 = m11
        self.m12 = m12
        self.m21 = m21
        self.m22 = m22
        self.tx = tx
        self.ty = ty

    def apply(self, point: Point) -> Point:
        return Point(
            self.m11 * point.x + self.m21 * point.y + self.tx,
            self.m12 * point.x + self.m22 * point.y + self.ty,
        )

    def translated(self, x: Float32, y: Float32) -> Transform:
        var result = self
        result.tx += x
        result.ty += y
        return result

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
        """Return whether a point is inside the rectangle's half-open bounds."""
        if self.width <= 0.0 or self.height <= 0.0:
            return False
        if point.x < self.x or point.y < self.y:
            return False
        if point.x >= self.x + self.width or point.y >= self.y + self.height:
            return False
        return True

    def intersection(self, other: Rect) -> Rect:
        """Return the overlapping rectangle, or an empty rectangle."""
        var left = self.x
        if other.x > left:
            left = other.x
        var top = self.y
        if other.y > top:
            top = other.y
        var right = self.x + self.width
        if other.x + other.width < right:
            right = other.x + other.width
        var bottom = self.y + self.height
        if other.y + other.height < bottom:
            bottom = other.y + other.height
        var width = right - left
        var height = bottom - top
        if width < 0.0:
            width = 0.0
        if height < 0.0:
            height = 0.0
        return Rect(left, top, width, height)
