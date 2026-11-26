"""Canvas 2D implementation of the same painter used by the desktop explorer."""
from std.ffi import external_call
from moxi.fractal import FractalCanvasPainter
from moxi.geometry import Point, Rect
from moxi.raster import RasterImage
from moxi.style import Color
from web_view import rgba


struct WebCanvasPainter(FractalCanvasPainter):
    def __init__(out self):
        pass

    def begin(mut self, clip: Rect) raises:
        external_call["moxi_clip", NoneType](clip.x, clip.y, clip.width, clip.height)

    def end(mut self) raises:
        external_call["moxi_end", NoneType]()

    def fill_rect(mut self, bounds: Rect, fill: Color, border: Color, border_width: Float32) raises:
        external_call["moxi_rect", NoneType](bounds.x, bounds.y, bounds.width, bounds.height, rgba(fill), rgba(border), border_width)

    def line(mut self, start: Point, end: Point, color: Color, width: Float32) raises:
        external_call["moxi_line", NoneType](start.x, start.y, end.x, end.y, rgba(color), width)

    def circle(mut self, center: Point, radius: Float32, fill: Color, stroke: Color, stroke_width: Float32) raises:
        external_call["moxi_circle", NoneType](center.x, center.y, radius, rgba(fill), rgba(stroke), stroke_width)

    def bitmap(mut self, raster: RasterImage, bounds: Rect) raises:
        external_call["moxi_bitmap", NoneType](raster.pixels.unsafe_ptr(), Int32(raster.width), Int32(raster.height), bounds.x, bounds.y, bounds.width, bounds.height)
