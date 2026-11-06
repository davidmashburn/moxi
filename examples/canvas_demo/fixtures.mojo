"""Two actual consumers, sharing only public canvas APIs and ordinary controls."""
from moxi import Rect
from moxi_canvas import CanvasDocument, CanvasObject, Port, PortDirection, GraphEdge, CanvasView, ConnectionPolicy
from .nodes import RichNode, GraphNode


def document(count: Int) raises -> CanvasDocument:
    var doc = CanvasDocument()
    var names = List[String](["Source · editable input", "Transform · adjust level", "Review · approve output", "Export · final stage"])
    for i in range(count):
        var id = i + 1
        doc.add(CanvasObject(id, Rect(40 + Float32(i % 2) * 410, 35 + Float32(i // 2) * 260, 290, 220), names[i]))
        doc.add_port(Port(id * 10, id, PortDirection.INPUT, 0, 0.5, 1, 1))
        doc.add_port(Port(id * 10 + 1, id, PortDirection.OUTPUT, 1, 0.5, 1))
    _ = doc.connect(GraphEdge(1, 11, 20, "samples"), ConnectionPolicy())
    if count == 2:
        doc.add_port(Port(22, 2, PortDirection.INPUT, 0, 0.82, 1, 1))
    if count > 2:
        _ = doc.connect(GraphEdge(2, 21, 30, "processed"), ConnectionPolicy())
        _ = doc.connect(GraphEdge(3, 31, 40, "approved"), ConnectionPolicy())
    return doc^


def rich_probe() raises -> CanvasView[RichNode]:
    var canvas = CanvasView[RichNode](document(2))
    canvas.mount(1, RichNode("Café · edit, select, compose"))
    canvas.mount(2, RichNode("Independent retained component"))
    return canvas^


def freeform_graph() raises -> CanvasView[GraphNode]:
    var canvas = CanvasView[GraphNode](document(4))
    for i in range(1, 5):
        canvas.mount(i, GraphNode(String("Stage ", i, " · configure processing")))
    return canvas^
