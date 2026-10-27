"""Application-owned deterministic force layout; no UI, host, or clock imports."""
from std.collections import List
from std.math import cos, sin, sqrt, isfinite

comptime MAX_NODES = 256
comptime MAX_LINKS = 1024

struct Node(ImplicitlyCopyable):
    var id: String
    var group: Int
    var x: Float64
    var y: Float64
    var vx: Float64
    var vy: Float64
    var pinned: Bool

    def __init__(out self, id: String, group: Int, index: Int):
        self.id = id
        self.group = group
        var radius = 12.0 * sqrt(Float64(index) + 0.5)
        var angle = Float64(index) * 2.399963229728653
        self.x = radius * cos(angle)
        self.y = radius * sin(angle)
        self.vx = 0
        self.vy = 0
        self.pinned = False

struct Link(ImplicitlyCopyable):
    var source: Int
    var target: Int
    var weight: Float64

    def __init__(out self, source: Int, target: Int, weight: Float64 = 1):
        self.source = source
        self.target = target
        self.weight = weight

struct Layout(ImplicitlyCopyable):
    var nodes: List[Node]
    var links: List[Link]
    var degrees: List[Int]
    var alpha: Float64
    var charge: Float64
    var distance: Float64
    var paused: Bool

    def __init__(out self):
        self.nodes = List[Node]()
        self.links = List[Link]()
        self.degrees = List[Int]()
        self.alpha = 1
        self.charge = 180
        self.distance = 55
        self.paused = False

    def __init__(out self, *, copy: Self):
        self.nodes = copy.nodes.copy()
        self.links = copy.links.copy()
        self.degrees = copy.degrees.copy()
        self.alpha = copy.alpha
        self.charge = copy.charge
        self.distance = copy.distance
        self.paused = copy.paused

    def find(self, id: String) -> Int:
        for i in range(len(self.nodes)):
            if self.nodes[i].id == id:
                return i
        return -1

    def add_node(mut self, id: String, group: Int = 0) raises:
        if self.find(id) >= 0:
            raise Error(String("Duplicate node ID: ", id))
        if len(self.nodes) >= MAX_NODES:
            raise Error("This first version supports at most 256 nodes")
        self.nodes.append(Node(id, group, len(self.nodes)))
        self.degrees.append(0)

    def add_link(mut self, source: String, target: String, weight: Float64 = 1) raises:
        var a = self.find(source)
        var b = self.find(target)
        if a < 0 or b < 0:
            raise Error(String("Unknown link endpoint: ", source, " -> ", target))
        if not isfinite(weight) or weight < 0 or weight > 1000000:
            raise Error("Link value must be finite and in [0, 1000000]")
        if len(self.links) >= MAX_LINKS:
            raise Error("This first version supports at most 1024 links")
        self.links.append(Link(a, b, weight))
        self.degrees[a] += 1
        self.degrees[b] += 1

    def adjacent(self, a: Int, b: Int) -> Bool:
        if a == b:
            return True
        for edge in self.links:
            if (edge.source == a and edge.target == b) or (edge.source == b and edge.target == a):
                return True
        return False

    def active(self) -> Bool:
        return not self.paused and self.alpha >= 0.001 and len(self.nodes) > 0

    def restart(mut self):
        self.alpha = 1

    def pin(mut self, index: Int, x: Float64, y: Float64):
        self.nodes[index].pinned = True
        self.nodes[index].x = x
        self.nodes[index].y = y
        self.nodes[index].vx = 0
        self.nodes[index].vy = 0
        self.restart()

    def release(mut self, index: Int):
        self.nodes[index].pinned = False
        self.restart()

    def step(mut self) -> Bool:
        if not self.active():
            return False
        self.alpha *= 0.98
        # Exact pairwise repulsion is intentionally bounded; no timing/randomness.
        for i in range(len(self.nodes)):
            for j in range(i + 1, len(self.nodes)):
                var dx = self.nodes[j].x - self.nodes[i].x
                var dy = self.nodes[j].y - self.nodes[i].y
                if dx * dx + dy * dy < 0.000001:
                    var angle = Float64(i * 131 + j * 17) * 2.399963229728653
                    dx = cos(angle) * 0.1
                    dy = sin(angle) * 0.1
                var d2 = max(dx * dx + dy * dy, 4.0)
                var strength = self.charge * self.alpha / d2
                self.nodes[i].vx -= dx * strength
                self.nodes[i].vy -= dy * strength
                self.nodes[j].vx += dx * strength
                self.nodes[j].vy += dy * strength
        for edge in self.links:
            var a = edge.source
            var b = edge.target
            if a == b:
                continue
            var dx = self.nodes[b].x - self.nodes[a].x
            var dy = self.nodes[b].y - self.nodes[a].y
            var length = max(sqrt(dx * dx + dy * dy), 0.01)
            var degree = max(1, min(self.degrees[a], self.degrees[b]))
            var force = 0.12 * self.alpha * (length - self.distance) / length / Float64(degree)
            self.nodes[a].vx += dx * force
            self.nodes[a].vy += dy * force
            self.nodes[b].vx -= dx * force
            self.nodes[b].vy -= dy * force
        for i in range(len(self.nodes)):
            if self.nodes[i].pinned:
                self.nodes[i].vx = 0
                self.nodes[i].vy = 0
                continue
            self.nodes[i].vx = max(-20.0, min(20.0, (self.nodes[i].vx - self.nodes[i].x * 0.002 * self.alpha) * 0.6))
            self.nodes[i].vy = max(-20.0, min(20.0, (self.nodes[i].vy - self.nodes[i].y * 0.002 * self.alpha) * 0.6))
            self.nodes[i].x += self.nodes[i].vx
            self.nodes[i].y += self.nodes[i].vy
        return True

def sample_graph() raises -> Layout:
    var graph = Layout()
    for i in range(36):
        graph.add_node(String("node-", i), i // 9)
    for i in range(36):
        graph.add_link(String("node-", i), String("node-", (i // 9) * 9), Float64(1 + i % 4))
        if i % 9 != 8:
            graph.add_link(String("node-", i), String("node-", i + 1))
    for i in range(3):
        graph.add_link(String("node-", i * 9), String("node-", (i + 1) * 9), 3)
    return graph^
