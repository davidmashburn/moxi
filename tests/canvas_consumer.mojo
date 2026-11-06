"""Compile an independent ordinary component through only the public canvas API."""
from moxi import Component, ColumnView, Rect, Event, Point, App
from moxi_canvas import dispatch_canvas, invoke_canvas
from moxi_canvas import CanvasView, CanvasDocument, CanvasObject, Port, PortDirection, GraphEdge, CanvasCommand

struct ExternalNode(Component):
    def __init__(out self):
        pass
    def build(self, bounds: Rect) -> ColumnView:
        var view = ColumnView(bounds, 8, 6)
        view.add_button(1, "Ordinary public component", 30)
        view.layout()
        return view^

def main() raises:
    var doc = CanvasDocument()
    doc.add(CanvasObject(1, Rect(10, 10, 240, 210), "Public consumer"))
    var canvas = CanvasView[ExternalNode](doc)
    canvas.mount(1, ExternalNode())
    var view = canvas.localized_view(Rect(0, 0, 1020, 720))
    _ = canvas.localized_dispatch(Event(), view)
    var scene = canvas.scene()
    _ = canvas.command(CanvasCommand.FIT_ALL)
    var app = App(canvas, Rect(0, 0, 1020, 720))
    _ = dispatch_canvas(app, Event())
    _ = invoke_canvas(app, CanvasCommand.CREATE)
    _ = invoke_canvas(app, CanvasCommand.GROUP)
    print("Public consumer:", view.child_count(), scene.count())
