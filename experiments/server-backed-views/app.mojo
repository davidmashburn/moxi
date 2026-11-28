"""Example-local density view: Moxi owns camera, gestures, selection and scene."""
from moxi.palette import light_tokens
from moxi.style import Theme
from moxi import Component, ColumnView, Event, Point, Rect, Scene, Color
from moxi.event import POINTER_DOWN_KIND, POINTER_MOVE_KIND, POINTER_UP_KIND, POINTER_CANCEL_KIND, DRAG_UPDATE_KIND, DROP_KIND, CLICK_KIND, SCROLL_KIND

comptime CANVAS = 100
comptime GRID = 32
comptime CELLS = GRID * GRID
comptime MAX_EXACT = 32
comptime READY = 0
comptime PENDING = 1
comptime FAILED = 2

struct Density(Component):
    var camera: Rect
    var data_bounds: Rect
    var counts: List[Int]
    var dragging: Bool
    var start: Point
    var origin: Point
    var moved: Bool
    var selection: Rect
    var selected_count: Int
    var exact: List[Int]
    var status: Int
    var generation: Int
    var selected_cell: Int
    var selection_generation: Int

    def __init__(out self):
        self.camera = Rect(0, 0, 1, 1)
        self.data_bounds = self.camera
        self.counts = List[Int]()
        self.dragging = False
        self.start = Point(0, 0)
        self.origin = Point(0, 0)
        self.moved = False
        self.selection = Rect(0, 0, 0, 0)
        self.selected_count = -1
        self.exact = List[Int]()
        self.status = PENDING
        self.generation = 0
        self.selected_cell = -1
        self.selection_generation = 0

    def __init__(out self, *, copy: Self):
        self.camera = copy.camera
        self.data_bounds = copy.data_bounds
        self.counts = copy.counts.copy()
        self.dragging = copy.dragging
        self.start = copy.start
        self.origin = copy.origin
        self.moved = copy.moved
        self.selection = copy.selection
        self.selected_count = copy.selected_count
        self.exact = copy.exact.copy()
        self.status = copy.status
        self.generation = copy.generation
        self.selected_cell = copy.selected_cell
        self.selection_generation = copy.selection_generation

    def count_range(self) -> Tuple[Int, Int]:
        if len(self.counts) == 0:
            return (0, 0)
        var low = self.counts[0]
        var high = low
        for count in self.counts:
            low = min(low, count)
            high = max(high, count)
        return (low, high)

    def build(self, bounds: Rect) -> ColumnView:
        var root = ColumnView(bounds, 12, 6)
        root.set_theme(Theme(light_tokens()))
        root.set_clip_to_bounds()
        var low, high = self.count_range()
        var state = String("Records per cell: ", low, "–", high)
        if self.status == PENDING:
            state = "Loading grid…" if len(self.counts) == 0 else "Updating · showing previous grid"
        elif self.status == FAILED:
            state = "Connection error · open connection controls"
        root.add_label(2, state, 24)
        root.add_canvas(CANVAS, "", max(Float32(100), bounds.height - 88))
        root.set_accessibility_label(CANVAS, "Density: drag to pan, wheel to zoom, click aggregate")
        if self.selected_count >= 0:
            root.add_label(3, String("Cell: ", self.selected_count, " records · ", len(self.exact), " exact IDs selected"), 24)
        root.layout()
        return root^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        var b = view.bounds_for(CANVAS)
        if event.kind == SCROLL_KIND and b.contains(event.position):
            var factor = max(Float32(0.5), min(Float32(2), 1 + event.scroll_delta.y * 0.03))
            var w = max(Float32(0.01), min(Float32(4), self.camera.width / factor))
            var h = max(Float32(0.01), min(Float32(4), self.camera.height / factor))
            var fx = (event.position.x - b.x) / b.width
            var fy = (event.position.y - b.y) / b.height
            self.camera.x += (self.camera.width - w) * fx
            self.camera.y += (self.camera.height - h) * fy
            self.camera.width = w
            self.camera.height = h
            self.generation += 1
            return True
        if self.dragging and (event.kind == POINTER_MOVE_KIND or event.kind == DRAG_UPDATE_KIND):
            var dx = event.position.x - self.start.x
            var dy = event.position.y - self.start.y
            if abs(dx) + abs(dy) > 2:
                self.moved = True
            self.camera.x = max(Float32(-4), min(Float32(4), self.origin.x - dx / b.width * self.camera.width))
            self.camera.y = max(Float32(-4), min(Float32(4), self.origin.y - dy / b.height * self.camera.height))
            self.generation += 1
            return True
        if self.dragging and (event.kind == POINTER_UP_KIND or event.kind == POINTER_CANCEL_KIND or event.kind == DROP_KIND or event.kind == CLICK_KIND):
            self.dragging = False
            if not self.moved and event.kind != POINTER_CANCEL_KIND and len(self.counts) == CELLS:
                var x = self.camera.x + (event.position.x - b.x) / b.width * self.camera.width
                var y = self.camera.y + (event.position.y - b.y) / b.height * self.camera.height
                if self.data_bounds.contains(Point(x, y)) and x < self.data_bounds.x + self.data_bounds.width and y < self.data_bounds.y + self.data_bounds.height:
                    var c = min(GRID - 1, Int((x - self.data_bounds.x) / self.data_bounds.width * GRID))
                    var r = min(GRID - 1, Int((y - self.data_bounds.y) / self.data_bounds.height * GRID))
                    self.selection = Rect(self.data_bounds.x + Float32(c) / GRID * self.data_bounds.width, self.data_bounds.y + Float32(r) / GRID * self.data_bounds.height, self.data_bounds.width / GRID, self.data_bounds.height / GRID)
                    self.selected_cell = r * GRID + c
                    self.selected_count = self.counts[self.selected_cell]
                    self.exact.clear()
                    self.selection_generation += 1
            return True
        if event.kind == POINTER_DOWN_KIND and event.target == CANVAS:
            self.dragging = True
            self.moved = False
            self.start = event.position
            self.origin = Point(self.camera.x, self.camera.y)
            return True
        return False

    def screen(self, box: Rect, b: Rect) -> Rect:
        return Rect(b.x + (box.x - self.camera.x) / self.camera.width * b.width, b.y + (box.y - self.camera.y) / self.camera.height * b.height, box.width / self.camera.width * b.width, box.height / self.camera.height * b.height)

    def scene(self, bounds: Rect) -> Scene:
        var scene = Scene()
        scene.append_rect(0, bounds, Color(0.97, 0.98, 0.97, 1))
        scene.push_clip(1, bounds)
        var low, high = self.count_range()
        for i in range(len(self.counts)):
            var cell = Rect(self.data_bounds.x + Float32(i % GRID) / GRID * self.data_bounds.width, self.data_bounds.y + Float32(i // GRID) / GRID * self.data_bounds.height, self.data_bounds.width / GRID, self.data_bounds.height / GRID)
            var level = Float32(self.counts[i] - low) / Float32(max(1, high - low))
            scene.append_rect(10 + i, self.screen(cell, bounds), Color(0.92 - level * 0.89, 0.96 - level * 0.62, 0.91 - level * 0.57, 1))
        if self.selected_count >= 0:
            var s = self.screen(self.selection, bounds)
            var ink = Color(1, 0.56, 0.15, 1)
            scene.append_rect(2000, Rect(s.x, s.y, s.width, 3), ink)
            scene.append_rect(2001, Rect(s.x, s.y + s.height - 3, s.width, 3), ink)
            scene.append_rect(2002, Rect(s.x, s.y, 3, s.height), ink)
            scene.append_rect(2003, Rect(s.x + s.width - 3, s.y, 3, s.height), ink)
        scene.pop_clip(1)
        return scene^
