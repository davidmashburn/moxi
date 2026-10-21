"""One waveform model shared by the interactive window and native captures."""

from std.math import sin, cos, sqrt, abs
from moxi import Color, Point, Rect, Scene


def label(mut scene: Scene, id: Int, text: String, x: Float32, y: Float32, width: Float32, size: Float32 = 14.0, bright: Bool = False):
    # Metal's compact ASCII glyphs use box height as their cell size.
    scene.append_text(id, text, Rect(x, y, width, size * 0.7), Color(0.91, 0.95, 1.0, 1.0) if bright else Color(0.54, 0.65, 0.78, 1.0))


struct SignalPlayground:
    var knots: SIMD[DType.float32, 16]
    var samples: SIMD[DType.float32, 128]
    var harmonics: SIMD[DType.float32, 16]
    var selected: Int
    var last_edit_y: Float32
    var was_down: Bool
    var playing: Bool
    var preset: Int
    var revision: Int
    var message: String

    def __init__(out self):
        self.knots = SIMD[DType.float32, 16](0.0)
        self.samples = SIMD[DType.float32, 128](0.0)
        self.harmonics = SIMD[DType.float32, 16](0.0)
        self.selected = -1
        self.last_edit_y = -100000.0
        self.was_down = False
        self.playing = False
        self.preset = 0
        self.revision = 0
        self.message = "Start with a sine. Press Play, then drag a dot."
        self.set_preset(0)

    def wave_bounds(self, bounds: Rect) -> Rect:
        return Rect(64.0, 214.0, bounds.width - 128.0, (bounds.height - 370.0) * 0.55)

    def play_bounds(self, bounds: Rect) -> Rect:
        return Rect(bounds.width - 212.0, 40.0, 180.0, 44.0)

    def preset_bounds(self, index: Int) -> Rect:
        return Rect(32.0 + Float32(index) * 116.0, 108.0, 104.0, 34.0)

    def set_preset(mut self, preset: Int):
        self.preset = preset
        for index in range(16):
            var phase = Float32(index) / 16.0
            if preset == 0:
                self.knots[index] = 0.8 * sin(phase * 6.2831853)
            elif preset == 1:
                self.knots[index] = 0.8 * (1.0 - 4.0 * abs(phase - 0.5))
            else:
                self.knots[index] = 0.75 if index < 4 else -0.25
        self.message = "Sine: one dominant harmonic, a soft tone."
        if preset == 1:
            self.message = "Triangle: mostly odd harmonics, a rounder buzz."
        elif preset == 2:
            self.message = "Pulse: a richer harmonic stack, a brighter tone."
        self.rebuild()

    def rebuild(mut self):
        # Center and bound the editable points so the audio has no DC offset.
        var mean: Float32 = 0.0
        for index in range(16):
            mean += self.knots[index] / 16.0
        var peak: Float32 = 1.0
        for index in range(16):
            self.knots[index] -= mean
            peak = max(peak, abs(self.knots[index]))
        for index in range(16):
            self.knots[index] /= peak
        for index in range(128):
            var left = index // 8
            var mix = Float32(index % 8) / 8.0
            self.samples[index] = self.knots[left] * (1.0 - mix) + self.knots[(left + 1) % 16] * mix
        # Measure the actual table sent to audio, rather than preset labels.
        for harmonic in range(16):
            var real: Float32 = 0.0
            var imaginary: Float32 = 0.0
            for index in range(128):
                var angle = 6.2831853 * Float32((harmonic + 1) * index) / 128.0
                real += self.samples[index] * cos(angle)
                imaginary += self.samples[index] * sin(angle)
            self.harmonics[harmonic] = sqrt(real * real + imaginary * imaginary) / 64.0
        self.revision += 1

    def pointer(mut self, bounds: Rect, point: Point, down: Bool) -> Bool:
        var changed = False
        var wave = self.wave_bounds(bounds)
        if down and not self.was_down:
            if self.play_bounds(bounds).contains(point):
                self.playing = not self.playing
                changed = True
            for index in range(3):
                if self.preset_bounds(index).contains(point):
                    self.set_preset(index)
                    changed = True
            if wave.contains(point):
                self.selected = min(15, max(0, Int((point.x - wave.x) / wave.width * 16.0 + 0.5)))
                self.last_edit_y = -100000.0
                changed = True
        if down and self.selected >= 0 and abs(point.y - self.last_edit_y) > 0.1:
            self.last_edit_y = point.y
            var value = min(Float32(1.0), max(Float32(-1.0), 1.0 - (point.y - wave.y) / wave.height * 2.0))
            if abs(value - self.knots[self.selected]) > 0.002:
                var delta = value - self.knots[self.selected]
                for index in range(16):
                    if index != self.selected:
                        self.knots[index] -= delta / 15.0
                self.knots[self.selected] = value
                self.preset = -1
                self.rebuild()
                self.message = "Your shape: new harmonics, same 220 Hz pitch."
                changed = True
        if not down and self.selected >= 0:
            self.selected = -1
            changed = True
        self.was_down = down
        return changed

    def scene(self, bounds: Rect) -> Scene:
        var scene = Scene()
        scene.append_rect(1, bounds, Color(0.035, 0.055, 0.09, 1.0))
        label(scene, 2, "Draw a sound.", 32.0, 30.0, 650.0, 32.0, True)
        label(scene, 3, "Reshape the waveform. See its harmonics. Hear the difference.", 34.0, 74.0, 740.0)
        var play = self.play_bounds(bounds)
        scene.append_rounded_rect(4, play, Color(0.15, 0.48, 0.39, 1.0) if self.playing else Color(0.13, 0.27, 0.36, 1.0), 10.0)
        label(scene, 5, "Stop audio" if self.playing else "Play 220 Hz", play.x + 26.0, play.y + 11.0, 150.0, 17.0, True)
        for index in range(3):
            var button = self.preset_bounds(index)
            scene.append_rounded_rect(10 + index, button, Color(0.14, 0.29, 0.39, 1.0) if self.preset == index else Color(0.08, 0.12, 0.18, 1.0), 7.0)
            label(scene, 20 + index, "Sine" if index == 0 else ("Triangle" if index == 1 else "Pulse"), button.x + 18.0, button.y + 7.0, 90.0, 14.0, self.preset == index)
        label(scene, 25, "M O X I   /   S I G N A L   P L A Y G R O U N D", bounds.width - 430.0, 117.0, 410.0, 12.0)

        var wave = self.wave_bounds(bounds)
        scene.append_rounded_rect(30, Rect(32.0, 166.0, bounds.width - 64.0, wave.height + 94.0), Color(0.055, 0.09, 0.14, 1.0), 14.0)
        label(scene, 31, "01   WAVEFORM", 52.0, 180.0, 300.0, 14.0, True)
        label(scene, 32, "Drag a dot up or down", bounds.width - 245.0, 180.0, 220.0, 13.0)
        for index in range(9):
            var x = wave.x + wave.width * Float32(index) / 8.0
            scene.append_line(40 + index, Point(x, wave.y), Point(x, wave.y + wave.height), Color(0.13, 0.20, 0.28, 1.0), 1.0)
        for index in range(5):
            var y = wave.y + wave.height * Float32(index) / 4.0
            scene.append_line(60 + index, Point(wave.x, y), Point(wave.x + wave.width, y), Color(0.20, 0.30, 0.39, 1.0) if index == 2 else Color(0.13, 0.20, 0.28, 1.0), 1.0)
        for index in range(128):
            var a = Point(wave.x + Float32(index) / 128.0 * wave.width, wave.y + (1.0 - self.samples[index]) * wave.height * 0.5)
            var b = Point(wave.x + Float32(index + 1) / 128.0 * wave.width, wave.y + (1.0 - self.samples[(index + 1) % 128]) * wave.height * 0.5)
            scene.append_line(100 + index, a, b, Color(0.15, 0.70, 0.95, 0.13), 9.0)
            scene.append_line(300 + index, a, b, Color(0.35, 0.84, 1.0, 1.0), 2.5)
        for index in range(16):
            var x = wave.x + Float32(index) / 16.0 * wave.width
            var y = wave.y + (1.0 - self.knots[index]) * wave.height * 0.5
            scene.append_rounded_rect(500 + index, Rect(x - 5.0, y - 5.0, 10.0, 10.0), Color(1.0, 0.73, 0.36, 1.0) if self.selected == index else Color(0.70, 0.94, 1.0, 1.0), 5.0)
        label(scene, 520, "0", wave.x, wave.y + wave.height + 9.0, 60.0, 11.0)
        label(scene, 521, "one repeating cycle", wave.x + wave.width - 150.0, wave.y + wave.height + 9.0, 155.0, 11.0)

        var spectrum_y = wave.y + wave.height + 62.0
        var spectrum_height = bounds.height - spectrum_y - 70.0
        scene.append_rounded_rect(600, Rect(32.0, spectrum_y, bounds.width - 64.0, spectrum_height), Color(0.055, 0.09, 0.14, 1.0), 14.0)
        label(scene, 601, "02   HARMONICS", 52.0, spectrum_y + 14.0, 300.0, 14.0, True)
        label(scene, 602, "Measured from your waveform", bounds.width - 284.0, spectrum_y + 14.0, 260.0, 13.0)
        var chart_bottom = spectrum_y + spectrum_height - 34.0
        var chart_height = spectrum_height - 80.0
        var cell = wave.width / 16.0
        for index in range(16):
            var x = wave.x + Float32(index) * cell
            var height = max(Float32(1.0), self.harmonics[index] * chart_height)
            scene.append_rounded_rect(620 + index, Rect(x + 5.0, chart_bottom - height, cell - 10.0, height), Color(1.0, 0.66, 0.29, 1.0), 3.0)
            label(scene, 650 + index, String(index + 1), x + 10.0, chart_bottom + 9.0, cell, 11.0)
        label(scene, 690, "1 = 220 Hz", wave.x, spectrum_y + 40.0, 170.0, 11.0)
        label(scene, 700, self.message, 34.0, bounds.height - 48.0, bounds.width - 230.0, 14.0, True)
        label(scene, 701, "Low-volume output" if self.playing else "Audio is muted", bounds.width - 185.0, bounds.height - 46.0, 170.0, 12.0)
        return scene^
