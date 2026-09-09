"""Series identity and nearest-point hit results: `PlotSeries` and `PlotHit`."""


from std.collections import List


from moxi.style import Color
from .plot_marks import PLOT_LINE
from .plot_point import PlotPoint


struct PlotSeries:
    """Stable identity, style, and points for one plotted series."""

    var id: Int
    var label: String
    var kind: Int
    var color: Color
    var line_width: Float32
    var marker_size: Float32
    var opacity: Float32
    var points: List[PlotPoint]
    var visible: Bool

    def __init__(
        out self,
        id: Int,
        label: String,
        color: Color,
        kind: Int = PLOT_LINE,
    ):
        self.id = id
        self.label = label
        self.kind = kind
        self.color = color
        self.line_width = 2.0
        self.marker_size = 6.0
        self.opacity = 1.0
        self.points = List[PlotPoint]()
        self.visible = True

    def append(mut self, point: PlotPoint):
        self.points.append(point)

    def count(self) -> Int:
        return len(self.points)


struct PlotHit(ImplicitlyCopyable):
    """Nearest point hit result for interaction and accessibility overlays."""

    var series_id: Int
    var point_index: Int
    var row_key: Int
    var distance_squared: Float32

    def __init__(out self):
        self.series_id = -1
        self.point_index = -1
        self.row_key = -1
        self.distance_squared = 0.0

    def found(self) -> Bool:
        return self.series_id != -1 and self.point_index != -1


