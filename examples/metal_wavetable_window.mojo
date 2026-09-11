"""Visible Metal scene window demo with an explicit scene component."""

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
from std.math import sin


struct MetalWindowDemo(Component):
    """Keep the component scene independent from the Metal window host."""

    var wave_index: Int
    var wave_table: SIMD[DType.float32, 128]
    var pointer: Point
    var pointer_down: Bool

    def __init__(out self):
        self.wave_index = 0
        self.wave_table = SIMD[DType.float32, 128](0.0)
        for index in range(128):
            var angle = Float32(index) * Float32(6.2831853) / Float32(128.0)
            self.wave_table[index] = sin(angle)
        self.pointer = Point(-1.0, -1.0)
        self.pointer_down = False

    def advance(mut self, bounds: Rect, pointer: Point, pointer_down: Bool):
        self.wave_index = (self.wave_index + 1) % 128
        self.pointer = pointer
        self.pointer_down = pointer_down

    def wave(self, index: Int) -> Float32:
        var slot = index % 128
        if slot < 0:
            slot += 128
        return self.wave_table[slot]

    def build(self, bounds: Rect) -> ColumnView:
        var root = ColumnView(bounds, 20.0, 10.0)
        root.add_label(1, "Metal window component", 32.0)
        root.add_canvas(2, "Metal scene", bounds.height - 80.0)
        root.layout()
        return root^

    def scene(self, bounds: Rect) -> Scene:
        var scene = Scene()
        scene.append_rounded_rect(
            1,
            bounds,
            Color(0.055, 0.085, 0.15, 1.0),
            16.0,
        )
        scene.append_text(
            2,
            "WAVETABLE LAB",
            Rect(bounds.x + 22.0, bounds.y + 18.0, bounds.width - 44.0, 28.0),
            Color(0.82, 0.92, 1.0, 1.0),
        )
        scene.append_text(
            3,
            "X FRAME   Y HARMONICS   HOLD DRIVE",
            Rect(bounds.x + 22.0, bounds.y + 50.0, bounds.width - 44.0, 14.0),
            Color(0.45, 0.62, 0.76, 1.0),
        )

        var field = Rect(
            bounds.x + 24.0,
            bounds.y + 76.0,
            bounds.width - 48.0,
            bounds.height - 100.0,
        )
        var pointer_inside = field.contains(self.pointer)
        var frame_phase = self.wave_index
        var harmonic_mix = (
            Float32(0.50)
            + self.wave(self.wave_index / 2) * Float32(0.28)
        )
        if pointer_inside:
            var pointer_x = (self.pointer.x - field.x) / field.width
            var pointer_y = (self.pointer.y - field.y) / field.height
            if pointer_x < 0.0:
                pointer_x = 0.0
            if pointer_x > 1.0:
                pointer_x = 1.0
            if pointer_y < 0.0:
                pointer_y = 0.0
            if pointer_y > 1.0:
                pointer_y = 1.0
            frame_phase = Int(pointer_x * Float32(127.0))
            harmonic_mix = pointer_y
        var drive: Float32 = (
            Float32(0.16)
            if self.pointer_down and pointer_inside
            else Float32(0.0)
        )

        var scope = Rect(
            field.x,
            field.y,
            field.width,
            field.height * Float32(0.66),
        )
        scene.append_rounded_rect(
            10,
            scope,
            Color(0.025, 0.052, 0.092, 1.0),
            12.0,
        )
        for index in range(7):
            var x = scope.x + Float32(index + 1) * scope.width / Float32(8.0)
            scene.append_line(
                20 + index,
                Point(x, scope.y + 10.0),
                Point(x, scope.y + scope.height - 10.0),
                Color(0.12, 0.24, 0.34, 0.42),
                1.0,
            )
        for index in range(3):
            var y = scope.y + Float32(index + 1) * scope.height / Float32(4.0)
            scene.append_line(
                30 + index,
                Point(scope.x + 10.0, y),
                Point(scope.x + scope.width - 10.0, y),
                Color(0.12, 0.24, 0.34, 0.42),
                1.0,
            )

        var center_y = scope.y + scope.height * Float32(0.50)
        var amplitude = scope.height * Float32(0.29)
        for segment in range(64):
            var left_sample_index = segment * 2
            var right_sample_index = (segment + 1) * 2
            var left_fundamental = self.wave(
                self.wave_index + left_sample_index
            )
            var right_fundamental = self.wave(
                self.wave_index + right_sample_index
            )
            var left_second = self.wave(
                self.wave_index * 2 + left_sample_index * 2 + frame_phase
            )
            var right_second = self.wave(
                self.wave_index * 2 + right_sample_index * 2 + frame_phase
            )
            var left_third = self.wave(
                self.wave_index * 3 + left_sample_index * 3 - frame_phase
            )
            var right_third = self.wave(
                self.wave_index * 3 + right_sample_index * 3 - frame_phase
            )
            var fundamental_gain = Float32(0.78) - harmonic_mix * Float32(0.24)
            var second_gain = Float32(0.10) + harmonic_mix * Float32(0.32)
            var third_gain = Float32(0.06) + drive
            var left_value = (
                left_fundamental * fundamental_gain
                + left_second * second_gain
                + left_third * third_gain
            )
            var right_value = (
                right_fundamental * fundamental_gain
                + right_second * second_gain
                + right_third * third_gain
            )
            var left_x = scope.x + Float32(segment) * scope.width / Float32(64.0)
            var right_x = scope.x + Float32(segment + 1) * scope.width / Float32(64.0)
            var start = Point(left_x, center_y + left_value * amplitude)
            var end = Point(right_x, center_y + right_value * amplitude)
            scene.append_line(
                100 + segment,
                start,
                end,
                Color(0.15, 0.58, 0.88, 0.20),
                7.0,
            )
            scene.append_line(
                200 + segment,
                start,
                end,
                Color(0.42, 0.88, 1.0, 0.96),
                Float32(2.2) + drive * Float32(2.0),
            )

        if pointer_inside:
            scene.append_line(
                280,
                Point(self.pointer.x, scope.y + 10.0),
                Point(self.pointer.x, scope.y + scope.height - 10.0),
                Color(1.0, 0.72, 0.28, 0.55),
                1.0,
            )

        var strip_y = scope.y + scope.height + 14.0
        var strip_height = field.y + field.height - strip_y
        var cell_gap = Float32(6.0)
        var cell_width = (
            field.width - cell_gap * Float32(7.0)
        ) / Float32(8.0)
        var active_cell = frame_phase * 8 / 128
        for cell in range(8):
            var cell_x = field.x + Float32(cell) * (cell_width + cell_gap)
            var selected = cell == active_cell
            scene.append_rounded_rect(
                300 + cell,
                Rect(cell_x, strip_y, cell_width, strip_height),
                (
                    Color(0.12, 0.30, 0.42, 0.96)
                    if selected
                    else Color(0.035, 0.075, 0.12, 0.92)
                ),
                7.0,
            )
            var mini_center = strip_y + strip_height * Float32(0.50)
            var mini_amplitude = strip_height * Float32(0.28)
            for segment in range(12):
                var left_index = segment * 10
                var right_index = (segment + 1) * 10
                var cell_phase = cell * 16
                var left_value = (
                    self.wave(left_index) * Float32(0.68)
                    + self.wave(left_index * 2 + cell_phase) * Float32(0.25)
                )
                var right_value = (
                    self.wave(right_index) * Float32(0.68)
                    + self.wave(right_index * 2 + cell_phase) * Float32(0.25)
                )
                scene.append_line(
                    400 + cell * 12 + segment,
                    Point(
                        cell_x + Float32(segment) * cell_width / Float32(12.0),
                        mini_center + left_value * mini_amplitude,
                    ),
                    Point(
                        cell_x + Float32(segment + 1) * cell_width / Float32(12.0),
                        mini_center + right_value * mini_amplitude,
                    ),
                    (
                        Color(1.0, 0.78, 0.34, 0.96)
                        if selected
                        else Color(0.32, 0.64, 0.78, 0.76)
                    ),
                    1.4,
                )
        return scene^


def main() raises:
    var component = MetalWindowDemo()
    var renderer = MacOSMetalRenderer(640, 420)
    var window = MacOSMetalWindow()
    window.open(WindowConfig("Moxi Metal wavetable", 640.0, 420.0))
    if not renderer.is_ready() or not window.is_open():
        print("Moxi Metal window unavailable")
        renderer.shutdown()
        return
    while window.is_open():
        window.pump()
        var bounds = Rect(0.0, 0.0, window.config.width, window.config.height)
        component.advance(
            bounds,
            window.pointer_position(),
            window.left_mouse_down(),
        )
        var scene = component.scene(bounds)
        renderer.render_scene(scene)
    renderer.shutdown()
