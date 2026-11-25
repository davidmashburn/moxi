"""A fixed-size RGBA accumulator for streamed geometry, independent of hosts."""

from std.collections import List
from std.math import abs, floor, isfinite

from .geometry import Point
from .style import Color


struct RasterImage(ImplicitlyCopyable):
    """Straight-alpha, top-to-bottom RGBA bytes; no retained drawing history."""

    var width: Int
    var height: Int
    var pixels: List[UInt8]

    def __init__(out self, width: Int = 0, height: Int = 0):
        self.width = max(width, 0)
        self.height = max(height, 0)
        self.pixels = List[UInt8](capacity=self.width * self.height * 4)
        for _ in range(self.width * self.height * 4):
            self.pixels.append(0)

    def __init__(out self, *, copy: Self):
        self.width = copy.width
        self.height = copy.height
        self.pixels = copy.pixels.copy()

    def is_empty(self) -> Bool:
        return self.width == 0 or self.height == 0

    def _blend(mut self, x: Int, y: Int, color: Color, coverage: Float64):
        if x < 0 or y < 0 or x >= self.width or y >= self.height:
            return
        var offset = (y * self.width + x) * 4
        var source_alpha = Float64(color.alpha) * max(0.0, min(coverage, 1.0))
        var destination_alpha = Float64(self.pixels[offset + 3]) / 255.0
        var alpha = source_alpha + destination_alpha * (1.0 - source_alpha)
        if alpha <= 0.0:
            return
        var channels = SIMD[DType.float64, 4](Float64(color.red), Float64(color.green), Float64(color.blue), 0.0)
        for channel in range(3):
            var value = (channels[channel] * source_alpha + Float64(self.pixels[offset + channel]) / 255.0 * destination_alpha * (1.0 - source_alpha)) / alpha
            self.pixels[offset + channel] = UInt8(max(0.0, min(value * 255.0 + 0.5, 255.0)))
        self.pixels[offset + 3] = UInt8(min(alpha * 255.0 + 0.5, 255.0))

    def stroke_line(mut self, start: Point, end: Point, color: Color) -> Bool:
        """Clip before integer conversion; each line costs at most a canvas axis.

        Nonfinite float geometry is unrepresentable, rather than safe to send to
        native drawing. It is reported to the caller without ending traversal.
        """
        if self.is_empty():
            return True
        if not isfinite(color.red) or not isfinite(color.green) or not isfinite(color.blue) or not isfinite(color.alpha):
            return False
        var x0 = Float64(start.x)
        var y0 = Float64(start.y)
        var x1 = Float64(end.x)
        var y1 = Float64(end.y)
        if not isfinite(x0) or not isfinite(y0) or not isfinite(x1) or not isfinite(y1):
            return False
        # Keep the original line equation when clipping either endpoint. An
        # origin-plus-delta intersection loses viewport-sized coordinates when
        # subtracting enormous endpoints, and can even depend on their order.
        # Products of Float32 inputs fit in Float64 without overflowing.
        var line_dx = x1 - x0
        var line_dy = y1 - y0
        var line_cross = x0 * y1 - y0 * x1
        while True:
            var code0 = _outcode(x0, y0, self.width, self.height)
            var code1 = _outcode(x1, y1, self.width, self.height)
            if (code0 | code1) == 0:
                break
            if (code0 & code1) != 0:
                return True
            var code = code0 if code0 != 0 else code1
            var x: Float64
            var y: Float64
            if code & 8:
                y = Float64(self.height - 1)
                x = (line_dx * y + line_cross) / line_dy
            elif code & 4:
                y = 0.0
                x = line_cross / line_dy
            elif code & 2:
                x = Float64(self.width - 1)
                y = (line_dy * x - line_cross) / line_dx
            else:
                x = 0.0
                y = -line_cross / line_dx
            if code == code0:
                x0, y0 = x, y
            else:
                x1, y1 = x, y
        var steep = abs(y1 - y0) > abs(x1 - x0)
        if steep:
            x0, y0 = y0, x0
            x1, y1 = y1, x1
        if x0 > x1:
            x0, x1 = x1, x0
            y0, y1 = y1, y0
        var span = x1 - x0
        if span == 0.0:
            if steep:
                self._blend(Int(y0), Int(x0), color, 1.0)
            else:
                self._blend(Int(x0), Int(y0), color, 1.0)
            return True
        var slope = (y1 - y0) / span
        for x in range(Int(floor(x0)), Int(floor(x1)) + 1):
            var y = y0 + (Float64(x) - x0) * slope
            var iy = Int(floor(y))
            var fraction = y - floor(y)
            var coverage = min(Float64(x + 1), x1 + 0.5) - max(Float64(x), x0 - 0.5)
            if steep:
                self._blend(iy, x, color, (1.0 - fraction) * coverage)
                self._blend(iy + 1, x, color, fraction * coverage)
            else:
                self._blend(x, iy, color, (1.0 - fraction) * coverage)
                self._blend(x, iy + 1, color, fraction * coverage)
        return True


def _outcode(x: Float64, y: Float64, width: Int, height: Int) -> Int:
    var result = 0
    if x < 0.0:
        result |= 1
    elif x > Float64(width - 1):
        result |= 2
    if y < 0.0:
        result |= 4
    elif y > Float64(height - 1):
        result |= 8
    return result
