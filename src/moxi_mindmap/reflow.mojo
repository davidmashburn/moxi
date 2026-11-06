"""Bounded neighbor reflow; derived presentation only, never document history."""
from std.collections import List
from std.math import isfinite
from moxi import Rect
from moxi_canvas import CanvasDocument

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
