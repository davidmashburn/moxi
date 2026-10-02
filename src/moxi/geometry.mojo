"""Geometry shared by views, retained widgets, and render backends."""

from std.math import isfinite


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

    def composed(self, child: Transform) -> Transform:
        """Apply child coordinates first, then this transform."""
        var origin = self.apply(Point(child.tx, child.ty))
        return Transform(self.m11 * child.m11 + self.m21 * child.m12,
                         self.m12 * child.m11 + self.m22 * child.m12,
                         self.m11 * child.m21 + self.m21 * child.m22,
                         self.m12 * child.m21 + self.m22 * child.m22,
                         origin.x, origin.y)

    def inverse(self) raises -> Transform:
        var determinant = self.m11 * self.m22 - self.m21 * self.m12
        if not isfinite(determinant) or determinant == 0:
            raise Error("Cannot invert a singular or nonfinite transform")
        var result = Transform(self.m22 / determinant, -self.m12 / determinant,
                               -self.m21 / determinant, self.m11 / determinant)
        var origin = result.apply(Point(-self.tx, -self.ty))
        result.tx = origin.x
        result.ty = origin.y
        if not isfinite(result.m11) or not isfinite(result.m12) or not isfinite(result.m21) or not isfinite(result.m22) or not isfinite(result.tx) or not isfinite(result.ty):
            raise Error("Inverse transform exceeds geometry precision")
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

    def transformed(self, transform: Transform) -> Rect:
        """Axis-aligned presentation bounds of all four transformed corners."""
        var a = transform.apply(Point(self.x, self.y))
        var b = transform.apply(Point(self.x + self.width, self.y))
        var c = transform.apply(Point(self.x, self.y + self.height))
        var d = transform.apply(Point(self.x + self.width, self.y + self.height))
        var left = min(min(a.x,b.x),min(c.x,d.x))
        var top = min(min(a.y,b.y),min(c.y,d.y))
        return Rect(left,top,max(max(a.x,b.x),max(c.x,d.x))-left,
                    max(max(a.y,b.y),max(c.y,d.y))-top)

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
