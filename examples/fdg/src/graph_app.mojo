"""Native graph exploration state; layout remains an independent value module."""
from std.math import sqrt
from moxi import App, Component, ColumnView, Event, Point, Rect, Scene, Color
from moxi.event import (
    POINTER_DOWN_KIND, POINTER_MOVE_KIND, POINTER_UP_KIND, POINTER_CANCEL_KIND,
    DRAG_UPDATE_KIND, DROP_KIND, CLICK_KIND, ACTION_KIND, FRAME_TICK_KIND,
    SCROLL_KIND, KEY_DOWN_KIND, TEXT_INPUT_KIND, COMPOSITION_UPDATE_KIND,
    COMPOSITION_END_KIND, KEY_ENTER, KEY_ESCAPE, KEY_LEFT, KEY_RIGHT,
)
from moxi.accessibility import ACTION_PRESS
from moxi.controls_text import TextInputState, TextInputControl
from layout import Layout

comptime CANVAS = 100
comptime PAUSE = 10
comptime RESTART = 11
comptime FIT = 12
comptime LABELS = 13
comptime NEIGHBORS = 14
comptime EXPORT = 15
comptime SEARCH = 20
comptime FIND = 21
comptime LESS = 22
comptime MORE = 23

struct GraphApp(Component):
    var graph: Layout
    var zoom: Float32
    var pan: Point
    var selected: Int
    var labels: Bool
    var neighbors_only: Bool
    var dragging: Bool
    var drag_node: Int
    var drag_start: Point
    var pan_start: Point
    var node_offset: Point
    var query: TextInputState
    var message: String
    var export_requested: Bool

    def __init__(out self, var graph: Layout):
        self.graph = graph^
        self.zoom = 1
        self.pan = Point(0, 0)
        self.selected = -1
        self.labels = True
        self.neighbors_only = False
        self.dragging = False
        self.drag_node = -1
        self.drag_start = Point(0, 0)
        self.pan_start = Point(0, 0)
        self.node_offset = Point(0, 0)
        self.query = TextInputState("")
        self.message = "Select a node to inspect its connections"
        self.export_requested = False

    def __init__(out self, *, copy: Self):
        self.graph = copy.graph
        self.zoom = copy.zoom
        self.pan = copy.pan
        self.selected = copy.selected
        self.labels = copy.labels
        self.neighbors_only = copy.neighbors_only
        self.dragging = copy.dragging
        self.drag_node = copy.drag_node
        self.drag_start = copy.drag_start
        self.pan_start = copy.pan_start
        self.node_offset = copy.node_offset
        self.query = copy.query
        self.message = copy.message
        self.export_requested = copy.export_requested

    def build(self, bounds: Rect) -> ColumnView:
        var root = ColumnView(bounds, 16, 8)
        root.set_clip_to_bounds()
        root.add_label(1, "FORCE / Moxi graph explorer", 30)
        var bar = root.add_row(2, 0, 36, 0, 8)
        root.add_button_to(bar, PAUSE, "Resume" if self.graph.paused else "Pause", 32)
        root.add_button_to(bar, RESTART, "Reheat", 32)
        root.add_button_to(bar, FIT, "Fit graph", 32)
        root.add_button_to(bar, LABELS, "Hide labels" if self.labels else "Show labels", 32)
        root.add_button_to(bar, NEIGHBORS, "All nodes" if self.neighbors_only else "Neighbors", 32)
        root.add_button_to(bar, EXPORT, "Export SVG", 32)
        for id in range(PAUSE, EXPORT + 1):
            root.set_fixed_width(id, 118)
        var search = root.add_row(3, 0, 36, 0, 8)
        var input = TextInputControl(SEARCH, self.query.text, self.query.cursor, self.query.anchor, 32)
        input.set_composition(self.query.composition, self.query.composition_selection_start, self.query.composition_selection_end)
        root.add_to(search, input.node())
        root.set_fixed_width(SEARCH, 240)
        root.set_accessibility_label(SEARCH, "Find a node by ID")
        root.add_button_to(search, FIND, "Find next", 32)
        root.set_fixed_width(FIND, 100)
        root.add_button_to(search, LESS, "Less repulsion", 32)
        root.add_button_to(search, MORE, "More repulsion", 32)
        root.set_fixed_width(LESS, 138)
        root.set_fixed_width(MORE, 138)
        root.add_label(4, String(len(self.graph.nodes), " nodes · ", len(self.graph.links), " links · ", self.message), 28)
        root.add_canvas(CANVAS, "Force-directed graph", max(Float32(100), bounds.height - 240))
        root.set_accessibility_label(CANVAS, "Graph: arrows select nodes, Enter toggles neighbors, Escape clears selection")
        root.add_label(5, "Drag: move/pan · Scroll: zoom · Arrows: select · Enter: neighbors", 26)
        root.layout()
        return root^

    def screen(self, node: Int, bounds: Rect) -> Point:
        return Point(bounds.x + bounds.width * 0.5 + self.pan.x + Float32(self.graph.nodes[node].x) * self.zoom,
                     bounds.y + bounds.height * 0.5 + self.pan.y + Float32(self.graph.nodes[node].y) * self.zoom)

    def world(self, position: Point, bounds: Rect) -> Point:
        return Point((position.x - bounds.x - bounds.width * 0.5 - self.pan.x) / self.zoom,
                     (position.y - bounds.y - bounds.height * 0.5 - self.pan.y) / self.zoom)

    def visible(self, index: Int) -> Bool:
        return not self.neighbors_only or self.selected < 0 or self.graph.adjacent(self.selected, index)

    def hit(self, position: Point, bounds: Rect) -> Int:
        for i in range(len(self.graph.nodes) - 1, -1, -1):
            if not self.visible(i):
                continue
            var p = self.screen(i, bounds)
            var dx = p.x - position.x
            var dy = p.y - position.y
            if dx * dx + dy * dy <= 144:
                return i
        return -1

    def fit(mut self, bounds: Rect):
        if len(self.graph.nodes) == 0:
            self.zoom = 1
            self.pan = Point(0, 0)
            return
        var xmin: Float64 = 1e30
        var xmax: Float64 = -1e30
        var ymin: Float64 = 1e30
        var ymax: Float64 = -1e30
        for i in range(len(self.graph.nodes)):
            if self.visible(i):
                xmin = min(xmin, self.graph.nodes[i].x)
                xmax = max(xmax, self.graph.nodes[i].x)
                ymin = min(ymin, self.graph.nodes[i].y)
                ymax = max(ymax, self.graph.nodes[i].y)
        self.zoom = max(Float32(0.05), min(Float32(5), min(max(Float32(1), bounds.width - 160) / Float32(max(1.0, xmax - xmin)), max(Float32(1), bounds.height - 80) / Float32(max(1.0, ymax - ymin)))))
        self.pan = Point(-Float32((xmin + xmax) * 0.5) * self.zoom, -Float32((ymin + ymax) * 0.5) * self.zoom)

    def zoom_at(mut self, position: Point, bounds: Rect, factor: Float32):
        var before = self.world(position, bounds)
        self.zoom = max(Float32(0.05), min(Float32(8), self.zoom * factor))
        self.pan = Point(position.x - bounds.x - bounds.width * 0.5 - before.x * self.zoom,
                         position.y - bounds.y - bounds.height * 0.5 - before.y * self.zoom)

    def select(mut self, index: Int):
        self.selected = index
        if index >= 0:
            self.message = String(self.graph.nodes[index].id, " · degree ", self.graph.degrees[index])
        else:
            self.message = "Select a node to inspect its connections"

    def find_next(mut self):
        if self.query.text == "":
            self.select(-1)
            return
        for offset in range(1, len(self.graph.nodes) + 1):
            var i = (self.selected + offset) % len(self.graph.nodes)
            if self.query.text in self.graph.nodes[i].id:
                self.select(i)
                self.pan = Point(-Float32(self.graph.nodes[i].x) * self.zoom, -Float32(self.graph.nodes[i].y) * self.zoom)
                return
        self.message = String("No match: ", self.query.text)

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        if event.kind == FRAME_TICK_KIND:
            return self.graph.step()
        if event.target == SEARCH:
            if event.kind == TEXT_INPUT_KIND:
                if event.replacement_start >= 0 and event.replacement_end >= 0:
                    return self.query.replace_text_range(event.text, event.replacement_start, event.replacement_end)
                return self.query.insert_text(event.text)
            if event.kind == COMPOSITION_UPDATE_KIND:
                self.query.set_composition(event.text, event.selection_start, event.selection_end)
                return True
            if event.kind == COMPOSITION_END_KIND:
                self.query.clear_composition()
                return True
            if event.kind == KEY_DOWN_KIND:
                if event.key == KEY_ENTER:
                    self.find_next()
                    return True
                return self.query.handle_key(event.key, event.modifiers)
        var bounds = view.bounds_for(CANVAS)
        # A native pointer release inside the pressed canvas becomes a click.
        if self.dragging and (event.kind == POINTER_UP_KIND or event.kind == POINTER_CANCEL_KIND or event.kind == DROP_KIND or event.kind == CLICK_KIND):
            if self.drag_node >= 0:
                self.graph.release(self.drag_node)
            self.dragging = False
            self.drag_node = -1
            return True
        # Moxi addresses wheel events to a scroll ancestor. Own canvas gestures
        # by position before the ancestor applies its default scrolling.
        if event.kind == SCROLL_KIND and bounds.contains(event.position):
            self.zoom_at(event.position, bounds, max(Float32(0.5), min(Float32(2), 1 + event.scroll_delta.y * 0.03)))
            return True
        if event.kind == CLICK_KIND or (event.kind == ACTION_KIND and event.action_id == ACTION_PRESS):
            if event.target == PAUSE:
                self.graph.paused = not self.graph.paused
            elif event.target == RESTART:
                self.graph.restart()
                self.graph.paused = False
            elif event.target == FIT:
                self.fit(bounds)
            elif event.target == LABELS:
                self.labels = not self.labels
            elif event.target == NEIGHBORS:
                self.neighbors_only = not self.neighbors_only
            elif event.target == FIND:
                self.find_next()
            elif event.target == LESS or event.target == MORE:
                var factor: Float64 = 0.8 if event.target == LESS else 1.25
                self.graph.charge = max(1.0, min(2000.0, self.graph.charge * factor))
                self.graph.restart()
            elif event.target == EXPORT:
                self.export_requested = True
            else:
                return False
            return True
        if event.kind == KEY_DOWN_KIND and event.target == CANVAS:
            if event.key == KEY_ESCAPE:
                self.select(-1)
                self.neighbors_only = False
            elif event.key == KEY_ENTER:
                self.neighbors_only = not self.neighbors_only
            elif (event.key == KEY_LEFT or event.key == KEY_RIGHT) and len(self.graph.nodes) > 0:
                var delta = -1 if event.key == KEY_LEFT else 1
                self.select(0 if self.selected < 0 else (self.selected + delta + len(self.graph.nodes)) % len(self.graph.nodes))
            else:
                return False
            return True
        if self.dragging and (event.kind == POINTER_MOVE_KIND or event.kind == DRAG_UPDATE_KIND):
            if self.drag_node >= 0:
                var p = self.world(event.position, bounds)
                self.graph.pin(self.drag_node, Float64(p.x + self.node_offset.x), Float64(p.y + self.node_offset.y))
            else:
                self.pan = Point(self.pan_start.x + event.position.x - self.drag_start.x, self.pan_start.y + event.position.y - self.drag_start.y)
            return True
        if event.target != CANVAS:
            return False
        if event.kind == POINTER_DOWN_KIND:
            self.drag_node = self.hit(event.position, bounds)
            self.select(self.drag_node)
            self.dragging = True
            self.drag_start = event.position
            self.pan_start = self.pan
            if self.drag_node >= 0:
                var p = self.world(event.position, bounds)
                var node = self.graph.nodes[self.drag_node]
                self.node_offset = Point(Float32(node.x) - p.x, Float32(node.y) - p.y)
                self.graph.pin(self.drag_node, node.x, node.y)
            return True
        return False

    def scene(self, bounds: Rect) -> Scene:
        var result = Scene()
        result.append_rect(0, bounds, Color(0.965, 0.97, 0.98, 1))
        # Native adapter clips at its boundary; SVG consumes the matching clip.
        result.push_clip(1, bounds)
        for i in range(len(self.graph.links)):
            var edge = self.graph.links[i]
            if not self.visible(edge.source) or not self.visible(edge.target):
                continue
            var emphasized = self.selected == edge.source or self.selected == edge.target
            var color = Color(0.23, 0.36, 0.51, 0.75) if emphasized else Color(0.58, 0.64, 0.72, 0.4)
            var a = self.screen(edge.source, bounds)
            var b = self.screen(edge.target, bounds)
            var width = min(Float32(8), max(Float32(0.5), Float32(sqrt(edge.weight))))
            if edge.source == edge.target:
                # A visible triangular loop; the solver deliberately ignores it.
                result.append_line(1000 + i * 4, a, Point(a.x + 20, a.y - 22), color, width)
                result.append_line(1001 + i * 4, Point(a.x + 20, a.y - 22), Point(a.x - 20, a.y - 22), color, width)
                result.append_line(1002 + i * 4, Point(a.x - 20, a.y - 22), a, color, width)
            else:
                result.append_line(1000 + i * 4, a, b, color, width)
        for i in range(len(self.graph.nodes)):
            if not self.visible(i):
                continue
            var p = self.screen(i, bounds)
            var radius: Float32 = 8 if self.selected != i else 11
            var color = group_color(self.graph.nodes[i].group)
            if self.selected >= 0 and not self.graph.adjacent(self.selected, i):
                color.alpha = 0.25
            result.append_rounded_rect(10000 + i * 3, Rect(p.x - radius - 2, p.y - radius - 2, radius * 2 + 4, radius * 2 + 4), Color(1, 1, 1, 1), radius + 2)
            result.append_rounded_rect(10001 + i * 3, Rect(p.x - radius, p.y - radius, radius * 2, radius * 2), color, radius)
            if self.labels or self.selected == i:
                result.append_text(10002 + i * 3, self.graph.nodes[i].id, Rect(p.x + radius + 5, p.y - 9, 180, 20), Color(0.12, 0.18, 0.27, color.alpha))
        result.pop_clip(1)
        return result^

def group_color(group: Int) -> Color:
    var index = group % 6
    if index == 0:
        return Color(0.1, 0.48, 0.57, 1)
    if index == 1:
        return Color(0.87, 0.43, 0.27, 1)
    if index == 2:
        return Color(0.43, 0.36, 0.68, 1)
    if index == 3:
        return Color(0.55, 0.62, 0.2, 1)
    if index == 4:
        return Color(0.79, 0.34, 0.55, 1)
    return Color(0.25, 0.5, 0.85, 1)

def dispatch_graph_event(mut app: App[GraphApp], var event: Event) -> Bool:
    # Canvas arrows belong to graph selection; Moxi's general App dispatcher
    # otherwise uses them to move focus between controls first.
    if event.kind == KEY_DOWN_KIND and app.runtime.focus_id() == CANVAS and (event.key == KEY_LEFT or event.key == KEY_RIGHT):
        event.set_target(CANVAS)
        var changed = app.component.update(event, app.view)
        if changed:
            app.rebuild()
        return changed
    return app.dispatch(event)
