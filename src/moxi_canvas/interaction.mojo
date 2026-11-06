"""Replayable canvas sessions and commands. The same reducer serves keys and pointer."""
from std.collections import List, Dict
from moxi.geometry import Rect, Point
from .model import CanvasDocument, CanvasHistory, CanvasObject, GraphEdge, ConnectionPolicy, SessionKind, ObjectKind, PortDirection, valid_bounds
from .geometry import Camera, CanvasSnapshot, WindowPoint, overlaps, union, distance


@fieldwise_init
struct CanvasCommand(Equatable, ImplicitlyCopyable):
    var value: Int
    comptime NONE = Self(0)
    comptime SELECT_ALL = Self(1)
    comptime MOVE = Self(2)
    comptime RESIZE = Self(3)
    comptime CONNECT = Self(4)
    comptime RECONNECT = Self(5)
    comptime DELETE = Self(6)
    comptime UNDO = Self(7)
    comptime REDO = Self(8)
    comptime FIT_ALL = Self(9)
    comptime FIT_SELECTION = Self(10)
    comptime ZOOM_IN = Self(11)
    comptime ZOOM_OUT = Self(12)
    comptime RESET_ZOOM = Self(13)
    comptime CANCEL = Self(14)
    comptime COMMIT = Self(15)
    comptime NEXT = Self(16)
    comptime PREVIOUS = Self(17)
    comptime TOGGLE = Self(18)
    comptime NEIGHBORS = Self(19)
    comptime CREATE = Self(20)
    comptime GROUP = Self(21)
    comptime UNGROUP = Self(22)
    comptime ENTER_CONTROLS = Self(23)
    comptime LEAVE_CONTROLS = Self(24)
    comptime SEARCH = Self(25)
    comptime NEXT_EDGE = Self(26)
    comptime NEXT_SOURCE = Self(27)
    comptime PAN_LEFT = Self(28)
    comptime PAN_RIGHT = Self(29)
    comptime PAN_UP = Self(30)
    comptime PAN_DOWN = Self(31)
    comptime TOGGLE_SNAP = Self(32)
    comptime TOGGLE_ASPECT = Self(33)


def command_title(command: CanvasCommand) -> String:
    var titles = List[String](["Select all", "Move selection", "Resize selection", "Connect ports", "Reconnect selected edge", "Delete selection", "Undo", "Redo", "Fit all", "Fit selection", "Zoom in", "Zoom out", "Reset zoom", "Cancel preview", "Commit preview", "Next object or port", "Previous object or port", "Toggle selection", "Select neighbors", "Create node", "Group selection", "Ungroup selection", "Enter node controls", "Leave node controls", "Search commands and objects", "Next edge", "Next source port", "Pan left", "Pan right", "Pan up", "Pan down", "Toggle grid snapping", "Toggle aspect constraint"])
    return titles[command.value - 1] if command.value >= 1 and command.value <= len(titles) else "Unknown command"


struct CanvasState(ImplicitlyCopyable):
    var camera: Camera
    var selected: List[Int]
    var focus: Int
    var anchor: Int
    var selected_edge: Int
    var session: SessionKind
    var pointer: Int
    var start: Point
    var last: Point
    var dx: Float32
    var dy: Float32
    var active: Bool
    var base_revision: Int
    var source: Int
    var target: Int
    var replacing: Int
    var snap: Bool
    var aspect: Bool
    var status: String
    var history: CanvasHistory
    var elapsed: Float64

    def __init__(out self, camera: Camera = Camera()):
        self.camera = camera
        self.selected = List[Int]()
        self.focus = -1
        self.anchor = -1
        self.selected_edge = -1
        self.session = SessionKind.IDLE
        self.pointer = -1
        self.start = Point(0, 0)
        self.last = Point(0, 0)
        self.dx = 0
        self.dy = 0
        self.active = False
        self.base_revision = -1
        self.source = -1
        self.target = -1
        self.replacing = -1
        self.snap = False
        self.aspect = False
        self.status = "Canvas · arrows navigate · M move · R resize · C connect · / search"
        self.history = CanvasHistory()
        self.elapsed = 0

    def __init__(out self, *, copy: Self):
        self.camera = copy.camera
        self.selected = copy.selected.copy()
        self.focus = copy.focus
        self.anchor = copy.anchor
        self.selected_edge = copy.selected_edge
        self.session = copy.session
        self.pointer = copy.pointer
        self.start = copy.start
        self.last = copy.last
        self.dx = copy.dx
        self.dy = copy.dy
        self.active = copy.active
        self.base_revision = copy.base_revision
        self.source = copy.source
        self.target = copy.target
        self.replacing = copy.replacing
        self.snap = copy.snap
        self.aspect = copy.aspect
        self.status = copy.status
        self.history = copy.history
        self.elapsed = copy.elapsed

    def is_selected(self, id: Int) -> Bool:
        for candidate in self.selected:
            if candidate == id:
                return True
        return False

    def select(mut self, id: Int, toggle: Bool = False):
        if not toggle:
            self.selected.clear()
        if id >= 0:
            var result = List[Int]()
            var found = False
            for prior in self.selected:
                if prior == id:
                    found = True
                else:
                    result.append(prior)
            if not found:
                result.append(id)
            self.selected = result^
            self.focus = id
            if not toggle or self.anchor < 0:
                self.anchor = id
        self.selected_edge = -1

    def begin(mut self, doc: CanvasDocument, kind: SessionKind, at: Point = Point(0, 0), pointer: Int = -1):
        self.cancel()
        self.session = kind
        self.pointer = pointer
        self.start = at
        self.last = at
        self.base_revision = doc.revision
        self.active = pointer < 0
        self.status = "Preview · arrows adjust · Enter commits · Escape cancels"

    def cancel(mut self):
        self.session = SessionKind.IDLE
        self.active = False
        self.pointer = -1
        self.dx = 0
        self.dy = 0
        self.target = -1
        self.replacing = -1
        self.elapsed = 0
        self.status = "Cancelled · committed document unchanged"

    def motion(mut self, doc: CanvasDocument, at: Point, pointer: Int) -> Bool:
        if self.session == SessionKind.IDLE or self.pointer != pointer:
            return False
        if doc.revision != self.base_revision:
            self.cancel()
            self.status = "Cancelled: document changed during preview"
            return True
        if self.session == SessionKind.PAN:
            self.camera.pan(at.x - self.last.x, at.y - self.last.y)
            self.last = at
            self.active = True
            return True
        self.last = at
        if distance(self.start, at) >= 4:
            self.active = True
        if self.active:
            self.dx = (at.x - self.start.x) / Float32(self.camera.zoom)
            self.dy = (at.y - self.start.y) / Float32(self.camera.zoom)
            if self.snap and self.session == SessionKind.MOVE:
                self.dx = Float32(Int(self.dx / 10 + Float32(0.5 if self.dx >= 0 else -0.5))) * 10
                self.dy = Float32(Int(self.dy / 10 + Float32(0.5 if self.dy >= 0 else -0.5))) * 10
        return True

    def nudge(mut self, dx: Float32, dy: Float32):
        if self.session == SessionKind.MOVE or self.session == SessionKind.RESIZE:
            self.dx += dx
            self.dy += dy
            self.active = True
            self.status = String("Preview Δ ", self.dx, ", ", self.dy, " · minimum 120×180 · Enter commit · Esc cancel")

    def preview(self, doc: CanvasDocument) -> CanvasDocument:
        var result = doc
        if doc.revision != self.base_revision or not self.active:
            return result^
        if self.session != SessionKind.MOVE and self.session != SessionKind.RESIZE:
            return result^
        for i in range(len(result.objects)):
            ref object = result.objects[i]
            if not self.is_selected(object.id):
                continue
            if self.session == SessionKind.MOVE:
                if object.parent >= 0 and self.is_selected(object.parent):
                    continue
                object.bounds.x = max(Float32(-1000000), min(Float32(1000000), object.bounds.x + self.dx))
                object.bounds.y = max(Float32(-1000000), min(Float32(1000000), object.bounds.y + self.dy))
            else:
                var ratio = object.bounds.height / object.bounds.width
                object.bounds.width = max(Float32(120), min(Float32(100000), object.bounds.width + self.dx))
                object.bounds.height = max(Float32(180), min(Float32(100000), object.bounds.height + self.dy))
                if self.aspect:
                    var minimum = max(Float32(120), Float32(180) / ratio)
                    var maximum = min(Float32(100000), Float32(100000) / ratio)
                    object.bounds.width = max(minimum, min(maximum, object.bounds.width))
                    object.bounds.height = object.bounds.width * ratio
        return result^

    def commit(mut self, mut doc: CanvasDocument, policy: ConnectionPolicy = ConnectionPolicy()) -> Bool:
        if self.session == SessionKind.IDLE:
            return False
        if self.base_revision != doc.revision:
            self.cancel()
            self.status = "Cancelled: stale document revision"
            return False
        var before = doc
        var changed = False
        if self.session == SessionKind.MOVE or self.session == SessionKind.RESIZE:
            if self.active and (self.dx != 0 or self.dy != 0) and len(self.selected) > 0:
                var next = self.preview(doc)
                for i in range(len(doc.objects)):
                    var a = doc.objects[i].bounds
                    var b = next.objects[i].bounds
                    if a.x != b.x or a.y != b.y or a.width != b.width or a.height != b.height:
                        changed = True
                if changed:
                    doc = next^
        elif self.session == SessionKind.MARQUEE:
            var box = Rect(min(self.start.x, self.last.x), min(self.start.y, self.last.y), abs(self.last.x - self.start.x), abs(self.last.y - self.start.y))
            self.selected.clear()
            for object in doc.objects:
                if doc.visible(object.id) and overlaps(self.camera.rect(doc.world_bounds(object.id)), box):
                    self.selected.append(object.id)
        elif self.session == SessionKind.CONNECT:
            var reason = policy.rejection(doc, self.source, self.target, self.replacing)
            if reason != "":
                self.status = reason
                return False
            if self.replacing >= 0:
                for i in range(len(doc.edges)):
                    if doc.edges[i].id == self.replacing and doc.edges[i].target != self.target:
                        doc.edges[i].target = self.target
                        changed = True
            else:
                if len(doc.edges) >= 20000:
                    self.status = "Canvas edge limit is 20000"
                    return False
                var id = 1
                for edge in doc.edges:
                    id = max(id, edge.id + 1)
                doc.edges.append(GraphEdge(id, self.source, self.target, "Connection"))
                changed = True
        if changed:
            doc.revision += 1
            self.history.record(before, doc, "Canvas edit")
        self.cancel()
        self.status = "Committed one undo unit" if changed else "No document change"
        return changed

    def start_connection(mut self, doc: CanvasDocument, port: Int, replacing: Int = -1, pointer: Int = -1):
        if port not in doc.port_index:
            self.status = "Port was removed"
            return
        self.begin(doc, SessionKind.CONNECT, self.camera.point(doc.anchor(port)), pointer)
        self.source = port
        self.replacing = replacing
        self.status = "Connect · arrows choose target · Enter commits · Escape cancels"

    def choose_target(mut self, doc: CanvasDocument, direction: Int):
        var candidates = List[Int]()
        for port in doc.ports:
            if port.direction == PortDirection.INPUT and doc.visible(port.object):
                candidates.append(port.id)
        if len(candidates) == 0:
            self.target = -1
            return
        var index = -1 if direction > 0 else 0
        for i in range(len(candidates)):
            if candidates[i] == self.target:
                index = i
        self.target = candidates[(index + direction + len(candidates)) % len(candidates)]
        self.camera.reveal(doc.world_bounds(doc.ports[doc.port_index.get(self.target, -1)].object))

    def autopan(mut self, doc: CanvasDocument, seconds: Float64) -> Bool:
        if not self.active or self.pointer < 0 or (self.session != SessionKind.MOVE and self.session != SessionKind.CONNECT):
            return False
        if doc.revision != self.base_revision:
            self.cancel()
            return False
        var dt = Float32(max(0.0, min(0.05, seconds)))
        var bounds = self.camera.viewport
        var vx: Float32 = 0
        var vy: Float32 = 0
        if self.last.x < bounds.x + 24:
            vx = min(Float32(240), (bounds.x + 24 - self.last.x) * 8)
        elif self.last.x > bounds.x + bounds.width - 24:
            vx = -min(Float32(240), (self.last.x - bounds.x - bounds.width + 24) * 8)
        if self.last.y < bounds.y + 24:
            vy = min(Float32(240), (bounds.y + 24 - self.last.y) * 8)
        elif self.last.y > bounds.y + bounds.height - 24:
            vy = -min(Float32(240), (self.last.y - bounds.y - bounds.height + 24) * 8)
        self.camera.pan(vx * dt, vy * dt)
        self.dx -= vx * dt / Float32(self.camera.zoom)
        self.dy -= vy * dt / Float32(self.camera.zoom)
        self.start.x += vx * dt
        self.start.y += vy * dt
        self.elapsed += Float64(dt)
        return vx != 0 or vy != 0

    def navigation(mut self, doc: CanvasDocument, direction: Int, extend: Bool = False):
        var ids = List[Int]()
        for object in doc.objects:
            if doc.visible(object.id):
                ids.append(object.id)
        if len(ids) == 0:
            return
        var index = -1 if direction > 0 else 0
        for i in range(len(ids)):
            if ids[i] == self.focus:
                index = i
        self.focus = ids[(index + direction + len(ids)) % len(ids)]
        if extend:
            var lo = -1
            var hi = -1
            for i in range(len(ids)):
                if ids[i] == self.anchor:
                    lo = i
                if ids[i] == self.focus:
                    hi = i
            self.selected.clear()
            for i in range(min(lo, hi), max(lo, hi) + 1):
                if i >= 0:
                    self.selected.append(ids[i])
        else:
            self.select(self.focus)
        self.camera.reveal(doc.world_bounds(self.focus))

    def enabled(self, command: CanvasCommand, doc: CanvasDocument) -> String:
        if (command == CanvasCommand.MOVE or command == CanvasCommand.RESIZE or command == CanvasCommand.DELETE or command == CanvasCommand.FIT_SELECTION) and len(self.selected) == 0 and self.selected_edge < 0:
            return "Select an object first"
        if command == CanvasCommand.UNDO and self.history.cursor == 0:
            return "Nothing to undo"
        if command == CanvasCommand.REDO and self.history.cursor == len(self.history.before):
            return "Nothing to redo"
        if command == CanvasCommand.RECONNECT and self.selected_edge < 0:
            return "Select an edge first"
        return ""

    def dispatch(mut self, command: CanvasCommand, mut doc: CanvasDocument, policy: ConnectionPolicy = ConnectionPolicy()) -> Bool:
        var reason = self.enabled(command, doc)
        if reason != "":
            self.status = reason
            return False
        if command == CanvasCommand.CANCEL:
            self.cancel()
        elif command == CanvasCommand.COMMIT:
            return self.commit(doc, policy)
        elif command == CanvasCommand.MOVE:
            self.begin(doc, SessionKind.MOVE)
        elif command == CanvasCommand.RESIZE:
            self.begin(doc, SessionKind.RESIZE)
        elif command == CanvasCommand.SELECT_ALL:
            self.selected.clear()
            for object in doc.objects:
                if doc.visible(object.id):
                    self.selected.append(object.id)
        elif command == CanvasCommand.TOGGLE:
            self.select(self.focus, True)
        elif command == CanvasCommand.NEXT or command == CanvasCommand.PREVIOUS:
            self.navigation(doc, 1 if command == CanvasCommand.NEXT else -1)
        elif command == CanvasCommand.UNDO:
            self.cancel()
            return self.history.undo(doc)
        elif command == CanvasCommand.REDO:
            self.cancel()
            return self.history.redo(doc)
        elif command == CanvasCommand.DELETE:
            self.cancel()
            var before = doc
            if len(self.selected) > 0:
                doc.remove(self.selected)
            elif self.selected_edge >= 0:
                var edges = List[GraphEdge]()
                for edge in doc.edges:
                    if edge.id != self.selected_edge:
                        edges.append(edge)
                doc.edges = edges^
                doc.revision += 1
            self.history.record(before, doc, "Delete")
            self.selected.clear()
            self.selected_edge = -1
        elif command == CanvasCommand.TOGGLE_SNAP:
            self.snap = not self.snap
            self.status = "Grid snapping enabled (10 world units)" if self.snap else "Grid snapping disabled"
        elif command == CanvasCommand.TOGGLE_ASPECT:
            self.aspect = not self.aspect
            self.status = "Aspect constraint enabled" if self.aspect else "Aspect constraint disabled"
        elif command == CanvasCommand.NEXT_EDGE:
            if len(doc.edges) > 0:
                var index = -1
                for i in range(len(doc.edges)):
                    if doc.edges[i].id == self.selected_edge:
                        index = i
                var edge = doc.edges[(index + 1) % len(doc.edges)]
                self.selected.clear()
                self.selected_edge = edge.id
                self.camera.reveal(doc.world_bounds(doc.ports[doc.port_index.get(edge.source, -1)].object))
                self.status = String("Edge ", edge.id, " · E reconnect · Delete removes")
        elif command == CanvasCommand.NEXT_SOURCE:
            if self.session == SessionKind.CONNECT and self.replacing < 0:
                var ports = List[Int]()
                for port in doc.ports:
                    if port.direction == PortDirection.OUTPUT and doc.visible(port.object):
                        ports.append(port.id)
                if len(ports) > 0:
                    var index = -1
                    for i in range(len(ports)):
                        if ports[i] == self.source:
                            index = i
                    self.source = ports[(index + 1) % len(ports)]
                    self.camera.reveal(doc.world_bounds(doc.ports[doc.port_index.get(self.source, -1)].object))
        elif command == CanvasCommand.PAN_LEFT or command == CanvasCommand.PAN_RIGHT or command == CanvasCommand.PAN_UP or command == CanvasCommand.PAN_DOWN:
            if self.session != SessionKind.IDLE:
                self.status = "Finish or cancel the preview before panning"
                return False
            self.camera.pan(Float32(80 if command == CanvasCommand.PAN_LEFT else (-80 if command == CanvasCommand.PAN_RIGHT else 0)), Float32(80 if command == CanvasCommand.PAN_UP else (-80 if command == CanvasCommand.PAN_DOWN else 0)))
        elif command == CanvasCommand.CONNECT:
            for port in doc.ports:
                if port.object == self.focus and port.direction == PortDirection.OUTPUT:
                    self.start_connection(doc, port.id)
                    self.choose_target(doc, 1)
                    break
        elif command == CanvasCommand.RECONNECT:
            for edge in doc.edges:
                if edge.id == self.selected_edge:
                    self.start_connection(doc, edge.source, edge.id)
                    self.target = edge.target
                    break
        elif command == CanvasCommand.FIT_ALL or command == CanvasCommand.FIT_SELECTION:
            var extent = Rect(0, 0, 0, 0)
            var first = True
            for object in doc.objects:
                if doc.visible(object.id) and (command == CanvasCommand.FIT_ALL or self.is_selected(object.id)):
                    var bounds = doc.world_bounds(object.id)
                    extent = bounds if first else union(extent, bounds)
                    first = False
            self.camera.fit(extent)
        elif command == CanvasCommand.ZOOM_IN or command == CanvasCommand.ZOOM_OUT or command == CanvasCommand.RESET_ZOOM:
            if self.session != SessionKind.IDLE:
                self.status = "Finish or cancel the preview before zooming"
                return False
            var anchor = Point(self.camera.viewport.x + self.camera.viewport.width / 2, self.camera.viewport.y + self.camera.viewport.height / 2)
            if self.focus in doc.object_index:
                var bounds = self.camera.rect(doc.world_bounds(self.focus))
                anchor = Point(bounds.x + bounds.width / 2, bounds.y + bounds.height / 2)
            var scale = 1.0
            if command != CanvasCommand.RESET_ZOOM:
                scale = self.camera.zoom * (1.25 if command == CanvasCommand.ZOOM_IN else 0.8)
            self.camera.zoom_at(scale, anchor)
        elif command == CanvasCommand.NEIGHBORS:
            self.selected.clear()
            for edge in doc.edges:
                var a = doc.ports[doc.port_index.get(edge.source, -1)].object
                var b = doc.ports[doc.port_index.get(edge.target, -1)].object
                if a == self.focus and not self.is_selected(b):
                    self.selected.append(b)
                if b == self.focus and not self.is_selected(a):
                    self.selected.append(a)
        else:
            return False
        return True
