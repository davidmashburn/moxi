"""Renderer-independent scrollbar geometry and movement policy."""

from .geometry import Point, Rect


comptime SCROLLBAR_VERTICAL = 0
comptime SCROLLBAR_HORIZONTAL = 1

comptime SCROLLBAR_HIT_NONE = 0
comptime SCROLLBAR_HIT_THUMB = 1
comptime SCROLLBAR_HIT_TRACK = 2

comptime SCROLLBAR_NO_COMMAND = 0
comptime SCROLLBAR_STEP_BACKWARD = 1
comptime SCROLLBAR_STEP_FORWARD = 2
comptime SCROLLBAR_PAGE_BACKWARD = 3
comptime SCROLLBAR_PAGE_FORWARD = 4
comptime SCROLLBAR_HOME = 5
comptime SCROLLBAR_END = 6


def _positive(value: Float32) -> Float32:
    return value if value > 0.0 else 0.0


struct ScrollbarGeometry(ImplicitlyCopyable):
    """A computed track/thumb pair suitable for any renderer."""

    var track: Rect
    var thumb: Rect
    var visible: Bool
    var offset: Float32
    var max_offset: Float32

    def __init__(
        out self,
        track: Rect = Rect(0.0, 0.0, 0.0, 0.0),
        thumb: Rect = Rect(0.0, 0.0, 0.0, 0.0),
        visible: Bool = False,
        offset: Float32 = 0.0,
        max_offset: Float32 = 0.0,
    ):
        self.track = track
        self.thumb = thumb
        self.visible = visible
        self.offset = offset
        self.max_offset = max_offset


struct ScrollbarState(ImplicitlyCopyable):
    """Scroll metrics and commands for fixed or variable-height content."""

    var orientation: Int
    var content_extent: Float32
    var viewport_extent: Float32
    var offset: Float32
    var step: Float32
    var min_thumb_extent: Float32

    def __init__(
        out self,
        orientation: Int = SCROLLBAR_VERTICAL,
        min_thumb_extent: Float32 = 18.0,
    ):
        self.orientation = (
            SCROLLBAR_HORIZONTAL
            if orientation == SCROLLBAR_HORIZONTAL
            else SCROLLBAR_VERTICAL
        )
        self.content_extent = 0.0
        self.viewport_extent = 0.0
        self.offset = 0.0
        self.step = 16.0
        self.min_thumb_extent = (
            min_thumb_extent if min_thumb_extent > 0.0 else 1.0
        )

    def max_offset(self) -> Float32:
        var result = self.content_extent - self.viewport_extent
        return result if result > 0.0 else 0.0

    def can_scroll(self) -> Bool:
        return self.max_offset() > 0.0

    def set_metrics(
        mut self,
        content_extent: Float32,
        viewport_extent: Float32,
    ):
        self.content_extent = _positive(content_extent)
        self.viewport_extent = _positive(viewport_extent)
        _ = self.set_offset(self.offset)

    def set_step(mut self, step: Float32):
        self.step = step if step > 0.0 else 1.0

    def set_offset(mut self, offset: Float32) -> Bool:
        var next = _positive(offset)
        var maximum = self.max_offset()
        if next > maximum:
            next = maximum
        if self.offset == next:
            return False
        self.offset = next
        return True

    def scroll_by(mut self, delta: Float32) -> Bool:
        return self.set_offset(self.offset + delta)

    def apply_command(mut self, command: Int) -> Bool:
        if command == SCROLLBAR_STEP_BACKWARD:
            return self.scroll_by(-self.step)
        if command == SCROLLBAR_STEP_FORWARD:
            return self.scroll_by(self.step)
        if command == SCROLLBAR_PAGE_BACKWARD:
            return self.scroll_by(-self.viewport_extent)
        if command == SCROLLBAR_PAGE_FORWARD:
            return self.scroll_by(self.viewport_extent)
        if command == SCROLLBAR_HOME:
            return self.set_offset(0.0)
        if command == SCROLLBAR_END:
            return self.set_offset(self.max_offset())
        return False

    def geometry(self, track: Rect) -> ScrollbarGeometry:
        var track_extent = (
            track.height
            if self.orientation == SCROLLBAR_VERTICAL
            else track.width
        )
        if track_extent <= 0.0 or not self.can_scroll():
            return ScrollbarGeometry(
                track,
                track,
                False,
                self.offset,
                self.max_offset(),
            )

        var ratio: Float32 = Float32(
            self.viewport_extent / self.content_extent
        )
        if ratio < 0.0:
            ratio = 0.0
        if ratio > 1.0:
            ratio = 1.0
        var thumb_extent = track_extent * ratio
        if thumb_extent < self.min_thumb_extent:
            thumb_extent = self.min_thumb_extent
        if thumb_extent > track_extent:
            thumb_extent = track_extent
        var travel = track_extent - thumb_extent
        var position: Float32 = 0.0
        if travel > 0.0 and self.max_offset() > 0.0:
            position = travel * Float32(self.offset / self.max_offset())

        var thumb = (
            Rect(track.x, track.y + position, track.width, thumb_extent)
            if self.orientation == SCROLLBAR_VERTICAL
            else Rect(track.x + position, track.y, thumb_extent, track.height)
        )
        return ScrollbarGeometry(
            track,
            thumb,
            True,
            self.offset,
            self.max_offset(),
        )

    def hit_test(self, track: Rect, point: Point) -> Int:
        var geometry = self.geometry(track)
        if not geometry.visible or not track.contains(point):
            return SCROLLBAR_HIT_NONE
        if geometry.thumb.contains(point):
            return SCROLLBAR_HIT_THUMB
        return SCROLLBAR_HIT_TRACK

    def offset_for_thumb_position(
        self,
        track: Rect,
        point: Point,
        grab_offset: Float32 = 0.0,
    ) -> Float32:
        """Map a dragged thumb position back to content offset."""
        var geometry = self.geometry(track)
        if not geometry.visible:
            return self.offset
        var track_extent = (
            track.height
            if self.orientation == SCROLLBAR_VERTICAL
            else track.width
        )
        var thumb_extent = (
            geometry.thumb.height
            if self.orientation == SCROLLBAR_VERTICAL
            else geometry.thumb.width
        )
        var travel = track_extent - thumb_extent
        if travel <= 0.0:
            return 0.0
        var coordinate = (
            point.y - track.y - grab_offset
            if self.orientation == SCROLLBAR_VERTICAL
            else point.x - track.x - grab_offset
        )
        if coordinate < 0.0:
            coordinate = 0.0
        if coordinate > travel:
            coordinate = travel
        return self.max_offset() * (coordinate / travel)

    def handle_track_click(mut self, track: Rect, point: Point) -> Bool:
        """Page toward the clicked side of the thumb."""
        var geometry = self.geometry(track)
        if not geometry.visible or not track.contains(point):
            return False
        if geometry.thumb.contains(point):
            return False
        var before = (
            point.y < geometry.thumb.y
            if self.orientation == SCROLLBAR_VERTICAL
            else point.x < geometry.thumb.x
        )
        return self.apply_command(
            SCROLLBAR_PAGE_BACKWARD if before else SCROLLBAR_PAGE_FORWARD
        )
