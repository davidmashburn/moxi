"""Geometry shared by views, retained widgets, and render backends."""

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
