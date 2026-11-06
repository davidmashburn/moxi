from moxi_mindmap import MindMapDocument, Side
from moxi_mindmap.layout import MapLayout
from moxi_mindmap.history import MapHistory
from moxi_mindmap.codec import encode, decode
from moxi_canvas import CanvasView
from moxi_mindmap.topic_control import TopicControl

def main() raises:
    var doc = MindMapDocument("Clean public consumer")
    var child = doc.create(doc.root, 0, "日本語")
    doc.topics[doc.at(child)].side = Side.LEFT
    var layout = MapLayout()
    layout.compute(decode(encode(doc)))
    var canvas = CanvasView[TopicControl](layout.project(doc))
    canvas.mount(child, TopicControl("日本語"))
    if len(canvas.document.objects) != 2:
        raise Error("public projection")
    print("PASS clean precompiled moxi/moxi_canvas/moxi_mindmap consumer")
