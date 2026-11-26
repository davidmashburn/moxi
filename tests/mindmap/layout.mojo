from moxi_mindmap.model import *
from moxi_mindmap.layout import MapLayout
from std.collections import List
from moxi import Point, Rect
from moxi_canvas import PathKind
from moxi_canvas.geometry import CanvasSnapshot, Camera

def main() raises:
    var doc = MindMapDocument("Map")
    var a = doc.create(1, 0, "Left")
    var b = doc.create(1, 1, "Right 日本語")
    doc.topics[doc.at(a)].side = Side.LEFT
    var c = doc.create(a, 0, "Long\nlabel")
    var layout = MapLayout()
    layout.compute(doc)
    if layout.boxes[a].x >= 0 or layout.boxes[b].x <= 0:
        raise Error("root side")
    layout.compute(doc)
    if layout.measured != 0 or layout.changed != 0:
        raise Error("retained measurement and deterministic layout")
    doc.topics[doc.at(a)].folded = True
    layout.compute(doc)
    if c in layout.boxes:
        raise Error("hidden descendants must not publish")
    layout.compute(doc, List[Int]([c]))
    if c not in layout.boxes or not doc.topics[doc.at(a)].folded:
        raise Error("search reveal preserves folds")
    var canvas = layout.project(doc)
    print("mindmap layout: deterministic retained boxes, two sides, fold/reveal, public projection PASS", len(canvas.objects))

    for i in range(8):
        _ = doc.create(doc.root, i, String("Sibling ", i))
    doc.connect(b, a, "crosslink")
    layout.compute(doc)
    canvas = layout.project(doc)
    var camera = Camera(Rect(0, 0, 3000, 3000))
    camera.x = -1500
    camera.y = -1500
    var snapshot = CanvasSnapshot(canvas, camera)
    for edge in canvas.edges:
        if edge.label != "":
            if edge.path != PathKind.CUBIC:
                raise Error("Crosslink lost its distinct route")
            continue
        var topic = doc.topics[doc.at(edge.id)]
        if topic.parent != doc.root:
            continue
        if edge.path != PathKind.ORTHOGONAL:
            raise Error("Dense siblings must share a trunk")
        var start = camera.point(canvas.anchor(edge.source))
        var end = camera.point(canvas.anchor(edge.target))
        if (start.x > end.x) != (topic.side == Side.LEFT):
            raise Error("Dense route starts on wrong side")
        var stub = Point((start.x + 3 * end.x) / 4, end.y)
        if snapshot.hit_edge(stub) != edge.id:
            raise Error("Dense terminal stub lost its individual edge hit")
    print("Dense two-sided sibling stubs preserve edge hits and crosslink routing PASS")
