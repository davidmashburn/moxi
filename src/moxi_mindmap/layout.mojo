"""Deterministic iterative tree layout; measured topic boxes independent of camera."""
from std.collections import List, Dict
from moxi import Rect
from moxi.measure import measure_text_wrapped
from moxi.style import default_panel_style
from moxi_canvas import CanvasDocument, CanvasObject, Port, PortDirection, GraphEdge, ConnectionPolicy
from .model import *

struct MapLayout(ImplicitlyCopyable):
    var boxes: Dict[Int, Rect]
    var measured_text: Dict[Int, String]
    var sizes: Dict[Int, Rect]
    var measured: Int
    var changed: Int
    var visible: Int

    def __init__(out self):
        self.boxes = Dict[Int, Rect]()
        self.measured_text = Dict[Int, String]()
        self.sizes = Dict[Int, Rect]()
        self.measured = 0
        self.changed = 0
        self.visible = 0

    def __init__(out self, *, copy: Self):
        self.boxes = copy.boxes.copy()
        self.measured_text = copy.measured_text.copy()
        self.sizes = copy.sizes.copy()
        self.measured = copy.measured
        self.changed = copy.changed
        self.visible = copy.visible

    def compute(mut self, doc: MindMapDocument, reveal: List[Int] = List[Int](), filter: String = "", partial: Dict[Int, Int] = Dict[Int, Int]()) raises:
        self.measured = 0
        self.changed = 0
        var removed = List[Int]()
        for id in self.measured_text.keys():
            if not doc.contains(id):
                removed.append(id)
        for id in removed:
            _ = self.measured_text.pop(id)
            _ = self.sizes.pop(id)
        var previous = self.boxes.copy()
        self.boxes = Dict[Int, Rect]()
        var shown = Dict[Int, Bool]()
        var sides = Dict[Int, Side]()
        var order = List[Int]()
        var stack = List[Int]([doc.root])
        sides[doc.root] = Side.RIGHT
        while len(stack):
            var id = stack.pop()
            var topic = doc.topics[doc.at(id)]
            shown[id] = True
            order.append(id)
            var expanded = not topic.folded
            for target in reveal:
                expanded = expanded or doc.descendant(target, id)
            if expanded:
                for i in range(len(topic.children) - 1, -1, -1):
                    var child = topic.children[i]
                    var included = i < partial.get(id, len(topic.children))
                    for target in reveal:
                        included = included or doc.descendant(target, child)
                    if not included:
                        continue
                    sides[child] = doc.topics[doc.at(child)].side if id == doc.root else sides[id]
                    if doc.arrangement == Arrangement.RIGHT_ONLY:
                        sides[child] = Side.RIGHT
                    stack.append(child)
        if filter != "":
            var matches = Dict[Int, Bool]()
            for id in order:
                if filter.lower() in doc.topics[doc.at(id)].text.lower():
                    var current = id
                    while doc.contains(current):
                        matches[current] = True
                        current = doc.topics[doc.at(current)].parent
            var filtered = List[Int]()
            for id in order:
                if id in matches or id == doc.root:
                    filtered.append(id)
                else:
                    _ = shown.pop(id)
            order = filtered^
        var spans = Dict[Int, Float32]()
        for id in order:
            var text = doc.topics[doc.at(id)].text
            if id not in self.measured_text or self.measured_text[id] != text:
                var style = default_panel_style()
                style.font_size = 15
                var m = measure_text_wrapped(text, style, 245)
                self.sizes[id] = Rect(0, 0, max(Float32(175), min(Float32(280), m.size.width + 36)), max(Float32(116), min(Float32(300), m.size.height + 96)))
                self.measured_text[id] = text
                self.measured += 1
        for i in range(len(order) - 1, -1, -1):
            var id = order[i]
            var extent: Float32 = 0
            for child in doc.topics[doc.at(id)].children:
                if child in shown:
                    extent += spans[child] + 26 + Float32(max(0, doc.topics[doc.at(child)].spacing))
            spans[id] = max(self.sizes[id].height, extent - 26)
        var root_box = self.sizes[doc.root]
        root_box.x = 0
        root_box.y = -root_box.height / 2
        self.boxes[doc.root] = root_box
        for id in order:
            var parent_box = self.boxes[id]
            for side in List[Side]([Side.LEFT, Side.RIGHT]):
                var total: Float32 = 0
                for child in doc.topics[doc.at(id)].children:
                    if child in shown and sides[child] == side:
                        total += spans[child] + 26 + Float32(max(0, doc.topics[doc.at(child)].spacing))
                var y = parent_box.y + parent_box.height / 2 - max(Float32(0), total - 26) / 2
                for child in doc.topics[doc.at(id)].children:
                    if child not in shown or sides[child] != side:
                        continue
                    var box = self.sizes[child]
                    var requested = doc.topics[doc.at(child)].spacing
                    var gap = max(Float32(28), Float32(90 + requested))
                    box.x = parent_box.x + parent_box.width + gap if side == Side.RIGHT else parent_box.x - gap - box.width
                    box.y = y + (spans[child] - box.height) / 2
                    self.boxes[child] = box
                    y += spans[child] + 26 + Float32(max(0, requested))
        self.visible = len(self.boxes)
        for id in order:
            var b = self.boxes[id]
            var a = previous.get(id, Rect(0, 0, 0, 0))
            if a.x != b.x or a.y != b.y or a.width != b.width or a.height != b.height:
                self.changed += 1

    def project(self, doc: MindMapDocument) raises -> CanvasDocument:
        var canvas = CanvasDocument()
        canvas.revision = doc.revision
        # Stable record order lets semantic destination previews compare identities.
        for topic in doc.topics:
            var shown = topic.id in self.boxes
            var box = self.boxes.get(topic.id, self.sizes.get(topic.id, Rect(0, 0, 175, 116)))
            canvas.add(CanvasObject(topic.id, box, String("#", topic.id, " · ", topic.text), hidden=not shown))
            var side = doc.branch_side(topic.id)
            if doc.arrangement == Arrangement.RIGHT_ONLY:
                side = Side.RIGHT
            canvas.add_port(Port(topic.id * 2, topic.id, PortDirection.INPUT, Float32(0 if side == Side.RIGHT else 1), 0.5))
            canvas.add_port(Port(topic.id * 2 + 1, topic.id, PortDirection.OUTPUT, Float32(1 if side == Side.RIGHT else 0), 0.5))
        for topic in doc.topics:
            if topic.parent != -1:
                canvas.edges.append(GraphEdge(topic.id, topic.parent * 2 + 1, topic.id * 2))
        for link in doc.links:
            canvas.edges.append(GraphEdge(MAX_ID + link.id, link.source * 2 + 1, link.target * 2, link.label))
        return canvas^
