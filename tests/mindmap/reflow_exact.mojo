from moxi_mindmap.reflow import NeighborReflow, MotionPolicy
from moxi_canvas import CanvasDocument, CanvasObject
from moxi import Rect
from std.collections import List

def main() raises:
    var flow = NeighborReflow()
    var a = CanvasDocument()
    a.add(CanvasObject(1, Rect(1000000,0,100,100), "A"))
    var b = CanvasDocument()
    b.add(CanvasObject(1, Rect(-0.3,0,100,100), "A"))
    var ids = List[Int]()
    flow.begin(a, b, ids)
    var result = b
    flow.apply(result)
    if result.objects[0].bounds.x != a.objects[0].bounds.x:
        raise Error("First reflow frame changed origin")
    _ = flow.advance(NeighborReflow.DURATION)
    flow.apply(result)
    if result.objects[0].bounds.x != b.objects[0].bounds.x:
        raise Error("Completed reflow retained rounding error")
    flow.policy = MotionPolicy.REDUCED
    flow.begin(a, b, ids)
    flow.apply(result)
    if flow.active or result.objects[0].bounds.x != b.objects[0].bounds.x:
        raise Error("Reduced motion retained rounding error")
    print("PASS exact final reflow bounds across large-coordinate cancellation")
