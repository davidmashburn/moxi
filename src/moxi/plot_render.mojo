"""Compact, ordered render packets for dense plot marks.

``Scene`` remains the portable, inspectable drawing contract.  This packet is
the optional hot path for a renderer that can consume repeated plot geometry in
contiguous buffers.  It deliberately stores screen-space values only; source
rows, stable keys, and accessibility remain owned by ``Plot``.
"""

from std.collections import List

from .geometry import Point, Rect
from .style import Color


comptime PLOT_RENDER_LINES = 1
comptime PLOT_RENDER_INSTANCES = 2
comptime PLOT_RENDER_LINE_STRIDE = 10
comptime PLOT_RENDER_INSTANCE_STRIDE = 10


struct PlotRenderBatch(ImplicitlyCopyable):
    """One ordered contiguous range in a plot packet."""

    var kind: Int
    var offset: Int
    var count: Int

    def __init__(out self, kind: Int, offset: Int, count: Int):
        self.kind = kind
        self.offset = offset
        self.count = count


struct PlotRenderLine(ImplicitlyCopyable):
    """A typed view of one packed line segment."""

    var start: Point
    var end: Point
    var color: Color
    var width: Float32
    var opacity: Float32

    def __init__(
        out self,
        start: Point,
        end: Point,
        color: Color,
        width: Float32,
        opacity: Float32,
    ):
        self.start = start
        self.end = end
        self.color = color
        self.width = width
        self.opacity = opacity


struct PlotRenderInstance(ImplicitlyCopyable):
    """A typed view of one packed marker or rectangle instance."""

    var bounds: Rect
    var color: Color
    var opacity: Float32
    var corner_radius: Float32

    def __init__(
        out self,
        bounds: Rect,
        color: Color,
        opacity: Float32,
        corner_radius: Float32,
    ):
        self.bounds = bounds
        self.color = color
        self.opacity = opacity
        self.corner_radius = corner_radius


struct PlotRenderPacket:
    """An ordered, backend-neutral packet for dense mark rendering.

    The two value arrays are intentionally flat and contain only ``Float32``
    values.  That makes their ABI stable for native backends and permits one
    borrowed-buffer transfer per contiguous batch.  ``batches`` retains the
    original mark ordering when lines and instances are interleaved.
    """

    var bounds: Rect
    var clip: Rect
    var line_values: List[Float32]
    var instance_values: List[Float32]
    var batches: List[PlotRenderBatch]
    var source_point_count: Int
    var emitted_point_count: Int
    var fallback_required: Bool

    def __init__(out self, bounds: Rect, clip: Rect):
        self.bounds = bounds
        self.clip = clip
        self.line_values = List[Float32]()
        self.instance_values = List[Float32]()
        self.batches = List[PlotRenderBatch]()
        self.source_point_count = 0
        self.emitted_point_count = 0
        self.fallback_required = False

    def reserve(mut self, line_count: Int, instance_count: Int, batch_count: Int):
        """Reserve wire-record storage before compiling a dense mark layer."""
        if line_count > 0:
            self.line_values = List[Float32](
                capacity=line_count * PLOT_RENDER_LINE_STRIDE
            )
        if instance_count > 0:
            self.instance_values = List[Float32](
                capacity=instance_count * PLOT_RENDER_INSTANCE_STRIDE
            )
        if batch_count > 0:
            self.batches = List[PlotRenderBatch](capacity=batch_count)

    def _append_batch(mut self, kind: Int, offset: Int):
        if len(self.batches) > 0:
            var last = self.batches[len(self.batches) - 1]
            if last.kind == kind and last.offset + last.count == offset:
                last.count += 1
                self.batches[len(self.batches) - 1] = last
                return
        self.batches.append(PlotRenderBatch(kind, offset, 1))

    def append_line(
        mut self,
        start: Point,
        end: Point,
        color: Color,
        width: Float32,
        opacity: Float32 = 1.0,
    ):
        var offset = self.line_count()
        self.line_values.append(start.x)
        self.line_values.append(start.y)
        self.line_values.append(end.x)
        self.line_values.append(end.y)
        self.line_values.append(color.red)
        self.line_values.append(color.green)
        self.line_values.append(color.blue)
        self.line_values.append(color.alpha)
        self.line_values.append(width if width > 0.0 else 1.0)
        var safe_opacity = opacity
        if safe_opacity < 0.0:
            safe_opacity = 0.0
        if safe_opacity > 1.0:
            safe_opacity = 1.0
        self.line_values.append(safe_opacity)
        self._append_batch(PLOT_RENDER_LINES, offset)

    def append_marker(
        mut self,
        center: Point,
        size: Float32,
        color: Color,
        opacity: Float32 = 1.0,
    ):
        var safe_size = size if size > 0.0 else 1.0
        self.append_instance(
            Rect(
                center.x - safe_size * 0.5,
                center.y - safe_size * 0.5,
                safe_size,
                safe_size,
            ),
            color,
            opacity,
            safe_size * 0.5,
        )

    def append_rect(
        mut self,
        bounds: Rect,
        color: Color,
        opacity: Float32 = 1.0,
    ):
        self.append_instance(bounds, color, opacity, 0.0)

    def append_instance(
        mut self,
        bounds: Rect,
        color: Color,
        opacity: Float32,
        corner_radius: Float32,
    ):
        var offset = self.instance_count()
        self.instance_values.append(bounds.x)
        self.instance_values.append(bounds.y)
        self.instance_values.append(bounds.width)
        self.instance_values.append(bounds.height)
        self.instance_values.append(color.red)
        self.instance_values.append(color.green)
        self.instance_values.append(color.blue)
        self.instance_values.append(color.alpha)
        var safe_opacity = opacity
        if safe_opacity < 0.0:
            safe_opacity = 0.0
        if safe_opacity > 1.0:
            safe_opacity = 1.0
        self.instance_values.append(safe_opacity)
        self.instance_values.append(corner_radius if corner_radius > 0.0 else 0.0)
        self._append_batch(PLOT_RENDER_INSTANCES, offset)

    def line_count(self) -> Int:
        return len(self.line_values) // PLOT_RENDER_LINE_STRIDE

    def instance_count(self) -> Int:
        return len(self.instance_values) // PLOT_RENDER_INSTANCE_STRIDE

    def batch_count(self) -> Int:
        return len(self.batches)

    def batch(self, index: Int) -> PlotRenderBatch:
        return self.batches[index]

    def line(self, index: Int) -> PlotRenderLine:
        var offset = index * PLOT_RENDER_LINE_STRIDE
        return PlotRenderLine(
            Point(self.line_values[offset], self.line_values[offset + 1]),
            Point(self.line_values[offset + 2], self.line_values[offset + 3]),
            Color(
                self.line_values[offset + 4],
                self.line_values[offset + 5],
                self.line_values[offset + 6],
                self.line_values[offset + 7],
            ),
            self.line_values[offset + 8],
            self.line_values[offset + 9],
        )

    def instance(self, index: Int) -> PlotRenderInstance:
        var offset = index * PLOT_RENDER_INSTANCE_STRIDE
        return PlotRenderInstance(
            Rect(
                self.instance_values[offset],
                self.instance_values[offset + 1],
                self.instance_values[offset + 2],
                self.instance_values[offset + 3],
            ),
            Color(
                self.instance_values[offset + 4],
                self.instance_values[offset + 5],
                self.instance_values[offset + 6],
                self.instance_values[offset + 7],
            ),
            self.instance_values[offset + 8],
            self.instance_values[offset + 9],
        )

    def line_byte_count(self) -> Int:
        return len(self.line_values) * 4

    def instance_byte_count(self) -> Int:
        return len(self.instance_values) * 4

    def total_byte_count(self) -> Int:
        return self.line_byte_count() + self.instance_byte_count()

    def mark_count(self) -> Int:
        return self.line_count() + self.instance_count()

    def reduction_count(self) -> Int:
        var result = self.source_point_count - self.emitted_point_count
        return result if result > 0 else 0
