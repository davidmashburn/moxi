"""Canvas document transactions. IDs are stable; previews never mutate the store."""
from std.collections import List, Dict
from std.math import isfinite
from moxi.geometry import Point, Rect


@fieldwise_init
struct ObjectKind(Equatable, ImplicitlyCopyable):
    var value: Int
    comptime NODE = Self(0)
    comptime GROUP = Self(1)


@fieldwise_init
struct PortDirection(Equatable, ImplicitlyCopyable):
    var value: Int
    comptime INPUT = Self(0)
    comptime OUTPUT = Self(1)


@fieldwise_init
struct PathKind(Equatable, ImplicitlyCopyable):
    var value: Int
    comptime STRAIGHT = Self(0)
    comptime CUBIC = Self(1)


@fieldwise_init
struct SessionKind(Equatable, ImplicitlyCopyable):
    var value: Int
    comptime IDLE = Self(0)
    comptime MOVE = Self(1)
    comptime RESIZE = Self(2)
    comptime MARQUEE = Self(3)
    comptime PAN = Self(4)
    comptime CONNECT = Self(5)


struct CanvasObject(ImplicitlyCopyable):
    var id: Int
    var bounds: Rect
    var title: String
    var parent: Int
    var kind: ObjectKind
    var hidden: Bool

    def __init__(out self, id: Int, bounds: Rect, title: String, parent: Int = -1, kind: ObjectKind = ObjectKind.NODE, hidden: Bool = False):
        self.id = id
        self.bounds = bounds
        self.title = title
        self.parent = parent
        self.kind = kind
        self.hidden = hidden



struct Port(ImplicitlyCopyable):
    var id: Int
    var object: Int
    var direction: PortDirection
    # Fractional layout anchor, derived from the published node dimensions.
    var x: Float32
    var y: Float32
    var type_id: Int
    var capacity: Int

    def __init__(out self, id: Int, object: Int, direction: PortDirection, x: Float32, y: Float32, type_id: Int = 0, capacity: Int = 0):
        self.id = id
        self.object = object
        self.direction = direction
        self.x = x
        self.y = y
        self.type_id = type_id
        self.capacity = capacity


struct GraphEdge(ImplicitlyCopyable):
    var id: Int
    var source: Int
    var target: Int
    var label: String
    var path: PathKind

    def __init__(out self, id: Int, source: Int, target: Int, label: String = "", path: PathKind = PathKind.CUBIC):
        self.id = id
        self.source = source
        self.target = target
        self.label = label
        self.path = path



struct ConnectionPolicy(ImplicitlyCopyable):
    var allow_self: Bool
    var allow_duplicates: Bool
    var allow_cycles: Bool

    def __init__(out self, allow_self: Bool = False, allow_duplicates: Bool = False, allow_cycles: Bool = True):
        self.allow_self = allow_self
        self.allow_duplicates = allow_duplicates
        self.allow_cycles = allow_cycles

    def rejection(self, doc: CanvasDocument, source: Int, target: Int, replacing: Int = -1) -> String:
        var a = doc.port_index.get(source, -1)
        var b = doc.port_index.get(target, -1)
        if a < 0 or b < 0:
            return "Port was removed"
        var src = doc.ports[a]
        var dst = doc.ports[b]
        if src.direction != PortDirection.OUTPUT or dst.direction != PortDirection.INPUT:
            return "Choose an output and an input"
        if src.type_id != dst.type_id:
            return "Port types differ"
        if not self.allow_self and src.object == dst.object:
            return "Self connections are disabled"
        var source_count = 0
        var target_count = 0
        for edge in doc.edges:
            if edge.id == replacing:
                continue
            if not self.allow_duplicates and edge.source == source and edge.target == target:
                return "Connection already exists"
            if edge.source == source:
                source_count += 1
            if edge.target == target:
                target_count += 1
        if (src.capacity > 0 and source_count >= src.capacity) or (dst.capacity > 0 and target_count >= dst.capacity):
            return "Port capacity reached"
        if not self.allow_cycles:
            var pending = List[Int]([dst.object])
            var visited = Dict[Int, Bool]()
            while len(pending) > 0:
                var current = pending.pop()
                if current == src.object:
                    return "Cycle is disabled by this application"
                if current in visited:
                    continue
                visited[current] = True
                for edge in doc.edges:
                    if edge.id == replacing:
                        continue
                    if doc.ports[doc.port_index.get(edge.source, -1)].object == current:
                        pending.append(doc.ports[doc.port_index.get(edge.target, -1)].object)
        return ""


struct CanvasDocument(ImplicitlyCopyable):
    """Single authoritative record store. One-level groups use relative positions."""
    var objects: List[CanvasObject]
    var ports: List[Port]
    var edges: List[GraphEdge]
    var object_index: Dict[Int, Int]
    var port_index: Dict[Int, Int]
    var revision: Int

    def __init__(out self, *, copy: Self):
        self.objects = copy.objects.copy()
        self.ports = copy.ports.copy()
        self.edges = copy.edges.copy()
        self.object_index = copy.object_index.copy()
        self.port_index = copy.port_index.copy()
        self.revision = copy.revision


    def __init__(out self):
        self.objects = List[CanvasObject]()
        self.ports = List[Port]()
        self.edges = List[GraphEdge]()
        self.object_index = Dict[Int, Int]()
        self.port_index = Dict[Int, Int]()
        self.revision = 0

    def reindex(mut self):
        self.object_index = Dict[Int, Int]()
        self.port_index = Dict[Int, Int]()
        for i in range(len(self.objects)):
            self.object_index[self.objects[i].id] = i
        for i in range(len(self.ports)):
            self.port_index[self.ports[i].id] = i

    def add(mut self, object: CanvasObject) raises:
        if len(self.objects) >= 10000:
            raise Error("Canvas object limit is 10000 (stress ceiling, not native capacity)")
        if object.id < 0 or object.id in self.object_index:
            raise Error("Object ID must be nonnegative and unique")
        if not valid_bounds(object.bounds):
            raise Error("Object bounds exceed the finite canvas contract")
        if object.parent >= 0:
            var parent = self.object_index.get(object.parent, -1)
            if parent < 0 or self.objects[parent].kind != ObjectKind.GROUP or object.kind == ObjectKind.GROUP:
                raise Error("Only one level of group membership is supported")
        self.object_index[object.id] = len(self.objects)
        self.objects.append(object)
        self.revision += 1

    def add_port(mut self, port: Port) raises:
        if len(self.ports) >= 40000:
            raise Error("Canvas port limit is 40000")
        if port.id < 0 or port.id in self.port_index or port.object not in self.object_index:
            raise Error("Port identity or owner is invalid")
        if not isfinite(port.x) or not isfinite(port.y) or port.x < 0 or port.x > 1 or port.y < 0 or port.y > 1:
            raise Error("Port anchor must lie inside the published layout")
        self.port_index[port.id] = len(self.ports)
        self.ports.append(port)
        self.revision += 1

    def connect(mut self, edge: GraphEdge, policy: ConnectionPolicy) -> String:
        if edge.id < 0:
            return "Edge ID must be nonnegative"
        if len(self.edges) >= 20000:
            return "Canvas edge limit is 20000"
        for prior in self.edges:
            if prior.id == edge.id:
                return "Edge ID already exists"
        var reason = policy.rejection(self, edge.source, edge.target)
        if reason != "":
            return reason
        self.edges.append(edge)
        self.revision += 1
        return ""

    def world_bounds(self, id: Int) -> Rect:
        var i = self.object_index.get(id, -1)
        if i < 0:
            return Rect(0, 0, 0, 0)
        var result = self.objects[i].bounds
        var parent = self.object_index.get(self.objects[i].parent, -1)
        if parent >= 0:
            result.x += self.objects[parent].bounds.x
            result.y += self.objects[parent].bounds.y
        return result

    def visible(self, id: Int) -> Bool:
        var i = self.object_index.get(id, -1)
        if i < 0 or self.objects[i].hidden:
            return False
        var parent = self.object_index.get(self.objects[i].parent, -1)
        return parent < 0 or not self.objects[parent].hidden

    def anchor(self, port_id: Int) -> Point:
        var i = self.port_index.get(port_id, -1)
        if i < 0:
            return Point(0, 0)
        var port = self.ports[i]
        var bounds = self.world_bounds(port.object)
        return Point(bounds.x + port.x * bounds.width, bounds.y + port.y * bounds.height)

    def remove(mut self, ids: List[Int]):
        var removed = Dict[Int, Bool]()
        for id in ids:
            removed[id] = True
        for object in self.objects:
            if object.parent in removed:
                removed[object.id] = True
        var objects = List[CanvasObject]()
        var ports = List[Port]()
        var port_removed = Dict[Int, Bool]()
        var edges = List[GraphEdge]()
        for object in self.objects:
            if object.id not in removed:
                objects.append(object)
        for port in self.ports:
            if port.object in removed:
                port_removed[port.id] = True
            else:
                ports.append(port)
        for edge in self.edges:
            if edge.source not in port_removed and edge.target not in port_removed:
                edges.append(edge)
        self.objects = objects^
        self.ports = ports^
        self.edges = edges^
        self.reindex()
        self.revision += 1

    def remove_port(mut self, id: Int):
        var ports = List[Port]()
        var edges = List[GraphEdge]()
        for port in self.ports:
            if port.id != id:
                ports.append(port)
        for edge in self.edges:
            if edge.source != id and edge.target != id:
                edges.append(edge)
        self.ports = ports^
        self.edges = edges^
        self.reindex()
        self.revision += 1


def valid_bounds(bounds: Rect) -> Bool:
    return (isfinite(bounds.x) and isfinite(bounds.y) and isfinite(bounds.width) and isfinite(bounds.height)
            and abs(bounds.x) <= 1000000 and abs(bounds.y) <= 1000000
            and bounds.width >= 80 and bounds.height >= 64 and bounds.width <= 100000 and bounds.height <= 100000)


struct CanvasHistory(ImplicitlyCopyable):
    """Bounded document transactions; camera and selection never enter history."""
    var before: List[CanvasDocument]
    var after: List[CanvasDocument]
    var titles: List[String]
    var cursor: Int
    var limit: Int

    def __init__(out self, *, copy: Self):
        self.before = copy.before.copy()
        self.after = copy.after.copy()
        self.titles = copy.titles.copy()
        self.cursor = copy.cursor
        self.limit = copy.limit


    def __init__(out self, limit: Int = 100):
        self.before = List[CanvasDocument]()
        self.after = List[CanvasDocument]()
        self.titles = List[String]()
        self.cursor = 0
        self.limit = limit

    def record(mut self, before: CanvasDocument, after: CanvasDocument, title: String):
        while len(self.before) > self.cursor:
            _ = self.before.pop()
            _ = self.after.pop()
            _ = self.titles.pop()
        self.before.append(before)
        self.after.append(after)
        self.titles.append(title)
        if len(self.before) > self.limit:
            _ = self.before.pop(0)
            _ = self.after.pop(0)
            _ = self.titles.pop(0)
        self.cursor = len(self.before)

    def undo(mut self, mut doc: CanvasDocument) -> Bool:
        if self.cursor == 0:
            return False
        var revision = doc.revision + 1
        self.cursor -= 1
        doc = self.before[self.cursor]
        doc.revision = revision
        return True

    def redo(mut self, mut doc: CanvasDocument) -> Bool:
        if self.cursor >= len(self.after):
            return False
        var revision = doc.revision + 1
        doc = self.after[self.cursor]
        doc.revision = revision
        self.cursor += 1
        return True
