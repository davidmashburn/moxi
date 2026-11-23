"""Bounded neighbor reflow; derived presentation only, never document history."""
from std.collections import List
from std.math import isfinite
from moxi import Rect
from moxi_canvas import CanvasDocument

def _overlap_interval(distance: Float32, delta: Float32, mut enter: Float32, mut leave: Float32) -> Bool:
    if delta == 0:
        return distance <= 0
    var crossing = -distance / delta
    if delta > 0:
        leave = min(leave, crossing)
    else:
        enter = max(enter, crossing)
    return enter <= leave

def _last_collision(a: Rect, b: Rect, obstacle: Rect) -> Float32:
    # Each edge moves linearly, so overlap occupies one interval along the path.
    # A one-point margin keeps the new origin clear despite Float32 rounding.
    var enter: Float32 = 0
    var leave: Float32 = 1
    if not _overlap_interval(a.x - obstacle.x - obstacle.width - 1, b.x - a.x, enter, leave):
        return 0
    if not _overlap_interval(obstacle.x - 1 - a.x - a.width, a.x + a.width - b.x - b.width, enter, leave):
        return 0
    if not _overlap_interval(a.y - obstacle.y - obstacle.height - 1, b.y - a.y, enter, leave):
        return 0
    if not _overlap_interval(obstacle.y - 1 - a.y - a.height, a.y + a.height - b.y - b.height, enter, leave):
        return 0
    return leave

@fieldwise_init
struct MotionPolicy(Equatable, ImplicitlyCopyable):
    var value: Int
    comptime NEIGHBORS = Self(0)
    comptime REDUCED = Self(1)

struct NeighborReflow:
    var policy: MotionPolicy
    var active: Bool
    var elapsed: Float32
    var origin: CanvasDocument
    var target: CanvasDocument
    comptime DURATION: Float32 = 0.18

    def __init__(out self):
        self.policy = MotionPolicy.NEIGHBORS
        self.active = False
        self.elapsed = 0
        self.origin = CanvasDocument()
        self.target = CanvasDocument()

    @no_inline
    def begin(mut self, previous: CanvasDocument, target: CanvasDocument, excluded: List[Int]):
        self.target = target
        self.origin = target
        self.elapsed = 0
        self.active = False
        if self.policy == MotionPolicy.REDUCED:
            return
        var obstacles = List[Rect]()
        for id in excluded:
            var index = target.object_index.get(id, -1)
            if index >= 0 and not target.objects[index].hidden:
                obstacles.append(target.objects[index].bounds)
        for i in range(len(target.objects)):
            var item = target.objects[i]
            var index = previous.object_index.get(item.id, -1)
            var skip = item.hidden or index < 0
            for id in excluded:
                skip = skip or id == item.id
            if skip:
                continue
            if previous.objects[index].hidden:
                continue
            var a = previous.objects[index].bounds
            var b = item.bounds
            if a.x != b.x or a.y != b.y or a.width != b.width or a.height != b.height:
                var start: Float32 = 0
                for obstacle in obstacles:
                    start = max(start, _last_collision(a, b, obstacle))
                if start < 1:
                    # The branch is already committed. Start a conflicting
                    # neighbor past the last obstruction, keeping the remainder
                    # of its path; safe neighbors retain the exact old bounds.
                    if start > 0:
                        a = Rect(a.x + (b.x - a.x) * start, a.y + (b.y - a.y) * start, a.width + (b.width - a.width) * start, a.height + (b.height - a.height) * start)
                    self.origin.objects[i].bounds = a
                    self.active = True

    @no_inline
    def apply(self, mut document: CanvasDocument):
        if not self.active:
            for i in range(len(document.objects)):
                document.objects[i].bounds = self.target.objects[i].bounds
            return
        var t = min(Float32(1), self.elapsed / Self.DURATION)
        var eased = t * t * (3 - 2 * t)
        for i in range(len(document.objects)):
            var a = self.origin.objects[i].bounds
            var b = self.target.objects[i].bounds
            document.objects[i].bounds = Rect(a.x + (b.x - a.x) * eased, a.y + (b.y - a.y) * eased, a.width + (b.width - a.width) * eased, a.height + (b.height - a.height) * eased)

    @no_inline
    def advance(mut self, delta: Float32) -> Bool:
        if not self.active or not isfinite(delta) or delta <= 0:
            return False
        self.elapsed = min(Self.DURATION, self.elapsed + delta)
        if self.elapsed >= Self.DURATION or self.policy == MotionPolicy.REDUCED:
            self.active = False
        return True

@no_inline
def neighbor_reflow(previous: CanvasDocument, target: CanvasDocument, excluded: List[Int], policy: MotionPolicy) -> NeighborReflow:
    var result = NeighborReflow()
    result.policy = policy
    result.begin(previous, target, excluded)
    return result^
