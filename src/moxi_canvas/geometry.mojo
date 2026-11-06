"""The one projection and geometry publication used by paint, input and semantics."""
from std.collections import List, Dict
from std.math import isfinite, sqrt
from moxi.geometry import Point, Rect
from .model import CanvasDocument, GraphEdge, PathKind
from .index import SpatialIndex


@fieldwise_init
struct WorldPoint(ImplicitlyCopyable):
    var x: Float64
    var y: Float64


@fieldwise_init
struct WindowPoint(ImplicitlyCopyable):
    var x: Float32
    var y: Float32


struct Camera(ImplicitlyCopyable):
    var x: Float64
    var y: Float64
    var zoom: Float64
    var viewport: Rect

    def __init__(out self, viewport: Rect = Rect(0, 0, 1000, 700)):
        self.x = 0
        self.y = 0
        self.zoom = 1
        self.viewport = viewport

    def project(self, point: WorldPoint) -> WindowPoint:
        return WindowPoint(Float32((point.x - self.x) * self.zoom) + self.viewport.x,
                           Float32((point.y - self.y) * self.zoom) + self.viewport.y)

    def unproject(self, point: WindowPoint) -> WorldPoint:
        return WorldPoint(self.x + Float64(point.x - self.viewport.x) / self.zoom,
                          self.y + Float64(point.y - self.viewport.y) / self.zoom)

    def point(self, point: Point) -> Point:
        var result = self.project(WorldPoint(Float64(point.x), Float64(point.y)))
        return Point(result.x, result.y)

    def rect(self, bounds: Rect) -> Rect:
        var origin = self.point(Point(bounds.x, bounds.y))
        return Rect(origin.x, origin.y, bounds.width * Float32(self.zoom), bounds.height * Float32(self.zoom))

    def zoom_at(mut self, scale: Float64, anchor: Point):
        if not isfinite(scale) or scale <= 0:
            return
        var world = self.unproject(WindowPoint(anchor.x, anchor.y))
        self.zoom = max(0.1, min(4.0, scale))
        self.x = world.x - Float64(anchor.x - self.viewport.x) / self.zoom
        self.y = world.y - Float64(anchor.y - self.viewport.y) / self.zoom
        self.clamp()

    def pan(mut self, dx: Float32, dy: Float32):
        if not isfinite(dx) or not isfinite(dy):
            return
        self.x -= Float64(dx) / self.zoom
        self.y -= Float64(dy) / self.zoom
        self.clamp()

    def clamp(mut self):
        self.x = max(-1000000.0, min(1000000.0, self.x))
        self.y = max(-1000000.0, min(1000000.0, self.y))

    def fit(mut self, bounds: Rect):
        if bounds.width <= 0 or bounds.height <= 0:
            return
        self.zoom = max(0.1, min(4.0, min(Float64(self.viewport.width - 64) / Float64(bounds.width), Float64(self.viewport.height - 64) / Float64(bounds.height))))
        self.x = Float64(bounds.x + bounds.width / 2) - Float64(self.viewport.width) / (2 * self.zoom)
        self.y = Float64(bounds.y + bounds.height / 2) - Float64(self.viewport.height) / (2 * self.zoom)
        self.clamp()

    def reveal(mut self, bounds: Rect):
        var projected = self.rect(bounds)
        var dx: Float32 = 0
        var dy: Float32 = 0
        if projected.x < self.viewport.x + 16:
            dx = self.viewport.x + 16 - projected.x
        elif projected.x + projected.width > self.viewport.x + self.viewport.width - 16:
            dx = self.viewport.x + self.viewport.width - 16 - projected.x - projected.width
        if projected.y < self.viewport.y + 16:
            dy = self.viewport.y + 16 - projected.y
        elif projected.y + projected.height > self.viewport.y + self.viewport.height - 16:
            dy = self.viewport.y + self.viewport.height - 16 - projected.y - projected.height
        self.pan(dx, dy)


def overlaps(a: Rect, b: Rect) -> Bool:
    return a.x <= b.x + b.width and b.x <= a.x + a.width and a.y <= b.y + b.height and b.y <= a.y + a.height


def union(a: Rect, b: Rect) -> Rect:
    var x = min(a.x, b.x)
    var y = min(a.y, b.y)
    return Rect(x, y, max(a.x + a.width, b.x + b.width) - x, max(a.y + a.height, b.y + b.height) - y)


def distance(a: Point, b: Point) -> Float32:
    return sqrt((a.x - b.x) ** 2 + (a.y - b.y) ** 2)


def segment_distance(p: Point, a: Point, b: Point) -> Float32:
    var dx = b.x - a.x
    var dy = b.y - a.y
    var length = dx * dx + dy * dy
    if length == 0:
        return distance(p, a)
    var t = max(Float32(0), min(Float32(1), ((p.x - a.x) * dx + (p.y - a.y) * dy) / length))
    return distance(p, Point(a.x + t * dx, a.y + t * dy))


struct EdgeGeometry(ImplicitlyCopyable):
    var id: Int
    var points: List[Point]
    var bounds: Rect
    var label: Rect
    var text: String

    def __init__(out self, *, copy: Self):
        self.id = copy.id
        self.points = copy.points.copy()
        self.bounds = copy.bounds
        self.label = copy.label
        self.text = copy.text


    def __init__(out self, edge: GraphEdge, a: Point, b: Point):
        self.id = edge.id
        self.text = edge.label
        self.points = List[Point]()
        self.points.append(a)
        if edge.path == PathKind.CUBIC:
            var bend = max(Float32(40), abs(b.x - a.x) / 2)
            flatten_cubic(self.points, a, Point(a.x + bend, a.y), Point(b.x - bend, b.y), b, 0)
        else:
            self.points.append(b)
        self.bounds = Rect(a.x, a.y, 0, 0)
        for point in self.points:
            self.bounds = union(self.bounds, Rect(point.x, point.y, 0, 0))
        var mid = self.points[len(self.points) // 2]
        self.label = Rect(mid.x - 60, mid.y - 22, 120, 22)
        self.bounds = union(self.bounds, self.label)

    def hit(self, point: Point, tolerance: Float32 = 7) -> Bool:
        for i in range(1, len(self.points)):
            if segment_distance(point, self.points[i - 1], self.points[i]) <= tolerance:
                return True
        return False


def flatten_cubic(mut points: List[Point], a: Point, b: Point, c: Point, d: Point, depth: Int):
    # At most 1024 segments, <= 0.5 screen point deviation before depth cap.
    if depth >= 10 or max(segment_distance(b, a, d), segment_distance(c, a, d)) <= 0.5:
        points.append(d)
        return
    var ab = Point((a.x + b.x) / 2, (a.y + b.y) / 2)
    var bc = Point((b.x + c.x) / 2, (b.y + c.y) / 2)
    var cd = Point((c.x + d.x) / 2, (c.y + d.y) / 2)
    var abc = Point((ab.x + bc.x) / 2, (ab.y + bc.y) / 2)
    var bcd = Point((bc.x + cd.x) / 2, (bc.y + cd.y) / 2)
    var mid = Point((abc.x + bcd.x) / 2, (abc.y + bcd.y) / 2)
    flatten_cubic(points, a, ab, abc, mid, depth + 1)
    flatten_cubic(points, mid, bcd, cd, d, depth + 1)


struct CanvasSnapshot(ImplicitlyCopyable):
    """Immutable-by-convention publication. Linear bounded broad phase, indexed IDs.

    Rebuilt projection does no component measurement. Edge paths share screen-space
    flattening for hits and rendering, so tolerances do not shrink with zoom.
    """
    var revision: Int
    var ids: List[Int]
    var bounds: List[Rect]
    var ports: Dict[Int, Point]
    var edges: List[EdgeGeometry]
    var visible: Dict[Int, Bool]
    var extent: Rect
    var objects_examined: Int
    var object_hits: SpatialIndex
    var port_hits: SpatialIndex
    var edge_hits: SpatialIndex

    def __init__(out self, *, copy: Self):
        self.revision = copy.revision
        self.ids = copy.ids.copy()
        self.bounds = copy.bounds.copy()
        self.ports = copy.ports.copy()
        self.edges = copy.edges.copy()
        self.visible = copy.visible.copy()
        self.extent = copy.extent
        self.objects_examined = copy.objects_examined
        self.object_hits = copy.object_hits
        self.port_hits = copy.port_hits
        self.edge_hits = copy.edge_hits


    def __init__(out self, doc: CanvasDocument, camera: Camera, pinned: Int = -1):
        var cache = GeometryCache()
        self = Self(doc, camera, pinned, cache)

    def __init__(out self, doc: CanvasDocument, camera: Camera, pinned: Int, mut cache: GeometryCache):
        self.revision = doc.revision
        self.ids = List[Int]()
        self.bounds = List[Rect]()
        self.ports = Dict[Int, Point]()
        self.edges = List[EdgeGeometry]()
        self.visible = Dict[Int, Bool]()
        self.extent = Rect(0, 0, 0, 0)
        self.objects_examined = len(doc.objects)
        self.object_hits = cache.object_hits
        self.port_hits = cache.port_hits
        self.edge_hits = cache.edge_hits
        var first = True
        for object in doc.objects:
            if not doc.visible(object.id):
                continue
            var world = doc.world_bounds(object.id)
            self.extent = world if first else union(self.extent, world)
            first = False
            var bounds = camera.rect(world)
            self.object_hits.update(len(self.ids), bounds)
            self.ids.append(object.id)
            self.bounds.append(bounds)
            if overlaps(bounds, camera.viewport) or object.id == pinned:
                self.visible[object.id] = True
        for port in doc.ports:
            if doc.visible(port.object):
                var anchor = camera.point(doc.anchor(port.id))
                self.ports[port.id] = anchor
                self.port_hits.update(port.id, Rect(anchor.x - 16, anchor.y - 16, 32, 32))
        for edge in doc.edges:
            if edge.source in self.ports and edge.target in self.ports:
                var geometry = cache.edge(edge, self.ports.get(edge.source, Point(0, 0)), self.ports.get(edge.target, Point(0, 0)))
                if overlaps(geometry.bounds, camera.viewport):
                    self.edge_hits.update(len(self.edges), Rect(geometry.bounds.x - 7, geometry.bounds.y - 7, geometry.bounds.width + 14, geometry.bounds.height + 14))
                    self.edges.append(geometry)

        self.object_hits.retain_prefix(len(self.ids))
        self.edge_hits.retain_prefix(len(self.edges))
        self.port_hits.retain_ids(self.ports)
        cache.object_hits = self.object_hits
        cache.port_hits = self.port_hits
        cache.edge_hits = self.edge_hits

    def hit_object(self, point: Point) -> Int:
        var best = -1
        for i in self.object_hits.query(point):
            if self.bounds[i].contains(point):
                best = max(best, i)
        return self.ids[best] if best >= 0 else -1

    def hit_port(self, point: Point, prior: Int = -1) -> Int:
        if prior in self.ports and distance(point, self.ports.get(prior, Point(0, 0))) <= 16:
            return prior
        var best = -1
        var best_distance: Float32 = 11
        for id in self.port_hits.query(point):
            var delta = distance(point, self.ports.get(id, Point(0, 0)))
            if delta < best_distance or (delta == best_distance and id < best):
                best = id
                best_distance = delta
        return best

    def hit_edge(self, point: Point) -> Int:
        var best = -1
        for i in self.edge_hits.query(point):
            if self.edges[i].hit(point):
                best = max(best, i)
        return self.edges[best].id if best >= 0 else -1


struct CachedEdge(ImplicitlyCopyable):
    var source: Point
    var target: Point
    var kind: PathKind
    var geometry: EdgeGeometry
    def __init__(out self, edge: GraphEdge, a: Point, b: Point):
        self.source = a
        self.target = b
        self.kind = edge.path
        self.geometry = EdgeGeometry(edge, a, b)
    def __init__(out self, *, copy: Self):
        self.source = copy.source
        self.target = copy.target
        self.kind = copy.kind
        self.geometry = copy.geometry


struct GeometryCache(ImplicitlyCopyable):
    var edges: Dict[Int, CachedEdge]
    var object_hits: SpatialIndex
    var port_hits: SpatialIndex
    var edge_hits: SpatialIndex
    var routes: Int
    var hits: Int
    def __init__(out self):
        self.edges = Dict[Int, CachedEdge]()
        self.object_hits = SpatialIndex()
        self.port_hits = SpatialIndex()
        self.edge_hits = SpatialIndex()
        self.routes = 0
        self.hits = 0
    def __init__(out self, *, copy: Self):
        self.edges = copy.edges.copy()
        self.object_hits = copy.object_hits
        self.port_hits = copy.port_hits
        self.edge_hits = copy.edge_hits
        self.routes = copy.routes
        self.hits = copy.hits
    def edge(mut self, edge: GraphEdge, a: Point, b: Point) -> EdgeGeometry:
        if edge.id in self.edges:
            try:
                var prior = self.edges[edge.id]
                if prior.source.x == a.x and prior.source.y == a.y and prior.target.x == b.x and prior.target.y == b.y and prior.kind == edge.path and prior.geometry.text == edge.label:
                    self.hits += 1
                    return prior.geometry
            except:
                pass
        var next = CachedEdge(edge, a, b)
        if len(self.edges) >= 20000 and edge.id not in self.edges:
            self.edges.clear()
        self.edges[edge.id] = next
        self.routes += 1
        return next.geometry
    def prune(mut self, doc: CanvasDocument):
        var live = Dict[Int, Bool]()
        for edge in doc.edges:
            live[edge.id] = True
        var dead = List[Int]()
        for id in self.edges.keys():
            if id not in live:
                dead.append(id)
        for id in dead:
            try:
                _ = self.edges.pop(id)
            except:
                pass
