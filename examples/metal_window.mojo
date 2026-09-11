"""Interactive Metal water-table demo with reflected pointer ripples."""

from moxi import (
    Color,
    ColumnView,
    Component,
    MacOSMetalRenderer,
    MacOSMetalWindow,
    Point,
    Rect,
    Scene,
    WindowConfig,
)
from std.ffi import external_call
from std.math import cos, sin


comptime RIPPLE_CAPACITY = 32
comptime RIPPLE_SEGMENTS = 64
comptime CIRCLE_SAMPLES = RIPPLE_SEGMENTS
comptime RIPPLE_LIFETIME = Float32(1.6)
comptime RIPPLE_SPEED = Float32(246.0)
comptime RIPPLE_FADE_IN_DISTANCE = Float32(28.0)
comptime HOLD_EMISSION_SECONDS = Float32(1.0 / 15.0)
comptime HOVER_EMISSION_SECONDS = Float32(0.30)


struct MetalWindowDemo(Component):
    """Emit bounded ripple fronts from the real window pointer."""

    var ripple_cursor: Int
    var emission_elapsed: Float32
    var seeded: Bool
    var was_pointer_down: Bool
    var ripple_x: SIMD[DType.float32, RIPPLE_CAPACITY]
    var ripple_y: SIMD[DType.float32, RIPPLE_CAPACITY]
    var ripple_age: SIMD[DType.float32, RIPPLE_CAPACITY]
    var ripple_strength: SIMD[DType.float32, RIPPLE_CAPACITY]
    var circle_x: SIMD[DType.float32, CIRCLE_SAMPLES]
    var circle_y: SIMD[DType.float32, CIRCLE_SAMPLES]

    def __init__(out self):
        self.ripple_cursor = 0
        self.emission_elapsed = 0.0
        self.seeded = False
        self.was_pointer_down = False
        self.ripple_x = SIMD[DType.float32, RIPPLE_CAPACITY](0.0)
        self.ripple_y = SIMD[DType.float32, RIPPLE_CAPACITY](0.0)
        self.ripple_age = SIMD[DType.float32, RIPPLE_CAPACITY](0.0)
        self.ripple_strength = SIMD[DType.float32, RIPPLE_CAPACITY](0.0)
        self.circle_x = SIMD[DType.float32, CIRCLE_SAMPLES](0.0)
        self.circle_y = SIMD[DType.float32, CIRCLE_SAMPLES](0.0)
        for index in range(CIRCLE_SAMPLES):
            var angle = (
                Float32(index) * Float32(6.2831853)
                / Float32(CIRCLE_SAMPLES)
            )
            self.circle_x[index] = cos(angle)
            self.circle_y[index] = sin(angle)

    def emit(
        mut self,
        point: Point,
        strength: Float32,
        initial_age: Float32 = 0.0,
    ):
        self.ripple_x[self.ripple_cursor] = point.x
        self.ripple_y[self.ripple_cursor] = point.y
        self.ripple_age[self.ripple_cursor] = initial_age
        self.ripple_strength[self.ripple_cursor] = strength
        self.ripple_cursor = (self.ripple_cursor + 1) % RIPPLE_CAPACITY

    def advance(
        mut self,
        bounds: Rect,
        pointer: Point,
        pointer_down: Bool,
        delta_seconds: Float32 = Float32(1.0 / 60.0),
    ):
        var delta = delta_seconds
        if delta < 0.0:
            delta = 0.0
        elif delta > 0.05:
            delta = 0.05
        self.emission_elapsed += delta
        for index in range(RIPPLE_CAPACITY):
            if self.ripple_strength[index] > 0.0:
                self.ripple_age[index] += delta
                if self.ripple_age[index] >= RIPPLE_LIFETIME:
                    self.ripple_strength[index] = 0.0

        var basin = Rect(
            bounds.x + 24.0,
            bounds.y + 78.0,
            bounds.width - 48.0,
            bounds.height - 102.0,
        )
        var pointer_inside = basin.contains(pointer)
        if not self.seeded:
            self.seeded = True
            if not pointer_inside or not pointer_down:
                self.emit(
                    Point(
                        basin.x + basin.width * 0.5,
                        basin.y + basin.height * 0.5,
                    ),
                    Float32(0.52),
                )
        if pointer_inside and pointer_down:
            if not self.was_pointer_down:
                self.emit(pointer, Float32(1.0))
                self.emission_elapsed = 0.0
            elif self.emission_elapsed >= HOLD_EMISSION_SECONDS:
                self.emission_elapsed -= HOLD_EMISSION_SECONDS
                self.emit(pointer, Float32(1.0), self.emission_elapsed)
        elif pointer_inside:
            if self.was_pointer_down:
                self.emission_elapsed = 0.0
            elif self.emission_elapsed >= HOVER_EMISSION_SECONDS:
                self.emission_elapsed -= HOVER_EMISSION_SECONDS
                self.emit(pointer, Float32(0.46), self.emission_elapsed)
        else:
            self.emission_elapsed = 0.0
        self.was_pointer_down = pointer_down

    def fold_coordinate(
        self,
        value: Float32,
        minimum: Float32,
        maximum: Float32,
    ) -> Float32:
        var folded = value
        while folded < minimum or folded > maximum:
            if folded < minimum:
                folded = minimum + (minimum - folded)
            if folded > maximum:
                folded = maximum - (folded - maximum)
        return folded

    def append_reflected_ring(
        self,
        mut scene: Scene,
        id_base: Int,
        basin: Rect,
        origin: Point,
        radius: Float32,
        color: Color,
        width: Float32,
    ):
        if radius <= 1.0 or color.alpha <= 0.01:
            return
        var right = basin.x + basin.width
        var bottom = basin.y + basin.height
        for segment in range(RIPPLE_SEGMENTS):
            var next = (segment + 1) % RIPPLE_SEGMENTS
            var start = Point(
                self.fold_coordinate(
                    origin.x + self.circle_x[segment] * radius,
                    basin.x,
                    right,
                ),
                self.fold_coordinate(
                    origin.y + self.circle_y[segment] * radius,
                    basin.y,
                    bottom,
                ),
            )
            var end = Point(
                self.fold_coordinate(
                    origin.x + self.circle_x[next] * radius,
                    basin.x,
                    right,
                ),
                self.fold_coordinate(
                    origin.y + self.circle_y[next] * radius,
                    basin.y,
                    bottom,
                ),
            )
            scene.append_line(
                id_base + segment,
                start,
                end,
                color,
                width,
            )

    def build(self, bounds: Rect) -> ColumnView:
        var root = ColumnView(bounds, 20.0, 10.0)
        root.add_label(1, "Metal water table", 32.0)
        root.add_canvas(2, "Ripple tank", bounds.height - 80.0)
        root.layout()
        return root^

    def scene(self, bounds: Rect) -> Scene:
        var scene = Scene()
        scene.append_rounded_rect(
            1,
            bounds,
            Color(0.025, 0.065, 0.105, 1.0),
            16.0,
        )
        scene.append_text(
            2,
            "RIPPLE TANK",
            Rect(bounds.x + 22.0, bounds.y + 18.0, bounds.width - 44.0, 28.0),
            Color(0.78, 0.94, 1.0, 1.0),
        )
        scene.append_text(
            3,
            "HOVER: SLOW WAVES   HOLD/DRAG: DENSE",
            Rect(bounds.x + 22.0, bounds.y + 50.0, bounds.width - 44.0, 14.0),
            Color(0.38, 0.68, 0.78, 1.0),
        )

        var basin = Rect(
            bounds.x + 24.0,
            bounds.y + 78.0,
            bounds.width - 48.0,
            bounds.height - 102.0,
        )
        scene.append_linear_gradient(
            10,
            basin,
            Point(basin.x, basin.y),
            Point(basin.x, basin.y + basin.height),
            Color(0.025, 0.16, 0.20, 1.0),
            Color(0.018, 0.055, 0.12, 1.0),
        )
        for index in range(7):
            var x = basin.x + Float32(index + 1) * basin.width / Float32(8.0)
            scene.append_line(
                20 + index,
                Point(x, basin.y),
                Point(x, basin.y + basin.height),
                Color(0.18, 0.48, 0.52, 0.13),
                1.0,
            )
        for index in range(4):
            var y = basin.y + Float32(index + 1) * basin.height / Float32(5.0)
            scene.append_line(
                30 + index,
                Point(basin.x, y),
                Point(basin.x + basin.width, y),
                Color(0.18, 0.48, 0.52, 0.13),
                1.0,
            )

        scene.push_clip(40, basin)
        for ripple in range(RIPPLE_CAPACITY):
            var strength = self.ripple_strength[ripple]
            if strength <= 0.0:
                continue
            var age = self.ripple_age[ripple]
            var life = Float32(1.0) - age / RIPPLE_LIFETIME
            var radius = age * RIPPLE_SPEED
            if radius < 16.0:
                continue
            var origin = Point(self.ripple_x[ripple], self.ripple_y[ripple])
            var fade_in = (radius - Float32(16.0)) / RIPPLE_FADE_IN_DISTANCE
            if fade_in > 1.0:
                fade_in = 1.0
            # Smoothly introduce complete rings so dense emission does not
            # create a brightness pulse at each ring's first visible frame.
            fade_in = fade_in * fade_in * (Float32(3.0) - Float32(2.0) * fade_in)
            var alpha = strength * fade_in * life * life * Float32(0.82)
            self.append_reflected_ring(
                scene,
                1000 + ripple * 400,
                basin,
                origin,
                radius,
                Color(0.42, 0.90, 1.0, alpha),
                Float32(2.0) + strength * Float32(0.35),
            )
        scene.pop_clip(15000)

        scene.append_line(
            15100,
            Point(basin.x, basin.y),
            Point(basin.x + basin.width, basin.y),
            Color(0.32, 0.72, 0.78, 0.75),
            2.0,
        )
        scene.append_line(
            15101,
            Point(basin.x + basin.width, basin.y),
            Point(basin.x + basin.width, basin.y + basin.height),
            Color(0.32, 0.72, 0.78, 0.75),
            2.0,
        )
        scene.append_line(
            15102,
            Point(basin.x + basin.width, basin.y + basin.height),
            Point(basin.x, basin.y + basin.height),
            Color(0.32, 0.72, 0.78, 0.75),
            2.0,
        )
        scene.append_line(
            15103,
            Point(basin.x, basin.y + basin.height),
            Point(basin.x, basin.y),
            Color(0.32, 0.72, 0.78, 0.75),
            2.0,
        )

        return scene^


def main() raises:
    var component = MetalWindowDemo()
    var renderer = MacOSMetalRenderer(640, 420)
    var window = MacOSMetalWindow()
    window.open(WindowConfig("Moxi Metal ripple tank", 640.0, 420.0))
    if not renderer.is_ready() or not window.is_open():
        print("Moxi Metal window unavailable")
        renderer.shutdown()
        return
    var previous_time = external_call["moxi_metal_time_seconds", Float64]()
    while window.is_open():
        window.pump()
        var current_time = external_call["moxi_metal_time_seconds", Float64]()
        var delta_seconds = Float32(current_time - previous_time)
        previous_time = current_time
        var bounds = Rect(0.0, 0.0, window.config.width, window.config.height)
        component.advance(
            bounds,
            window.pointer_position(),
            window.left_mouse_down(),
            delta_seconds,
        )
        var scene = component.scene(bounds)
        renderer.render_scene(scene)
    renderer.shutdown()
