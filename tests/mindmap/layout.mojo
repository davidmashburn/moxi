from moxi_mindmap.model import *
from moxi_mindmap.layout import MapLayout
from std.collections import List

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
