"""Exercise the real interaction model and export its native Metal frames."""

from std.ffi import external_call
from std.math import abs
from moxi import MacOSMetalRenderer, Point, Rect, test_check
from signal_playground_model import SignalPlayground


def capture(mut renderer: MacOSMetalRenderer, model: SignalPlayground, name: String) raises:
    var scene = model.scene(Rect(0.0, 0.0, 1080.0, 760.0))
    renderer.render_scene(scene)
    test_check(renderer.fallback_command_count() == 0)
    test_check(renderer.write_ppm(String("artifacts/signal-playground/", name, ".ppm")))
    var mean: Float32 = 0.0
    for index in range(128):
        test_check(abs(model.samples[index]) <= 1.00001)
        mean += model.samples[index] / 128.0
        external_call["signal_audio_set_sample", NoneType](Int32(index), model.samples[index])
    test_check(abs(mean) < 0.00001)
    external_call["signal_audio_commit", NoneType]()
    var path = String("artifacts/signal-playground/", name, ".wav")
    test_check(external_call["signal_audio_write_wav", Int32](path.as_c_string_span().ptr()) != 0)
    print(name, " fundamental=", model.harmonics[0], " second=", model.harmonics[1], " third=", model.harmonics[2])


def main() raises:
    var renderer = MacOSMetalRenderer(1080, 760)
    test_check(renderer.is_ready())
    var model = SignalPlayground()
    var bounds = Rect(0.0, 0.0, 1080.0, 760.0)
    test_check(model.harmonics[0] > 0.78)
    test_check(model.harmonics[1] < 0.0001)
    capture(renderer, model, "01-sine")
    var wave = model.wave_bounds(bounds)
    var point = Point(wave.x + wave.width * 0.25, wave.y + wave.height * 0.1)
    _ = model.pointer(bounds, point, True)
    point.y = wave.y + wave.height * 0.8
    test_check(model.pointer(bounds, point, True))
    test_check(model.selected == 4)
    test_check(model.harmonics[1] > 0.1)
    capture(renderer, model, "02-drag")
    _ = model.pointer(bounds, point, False)
    test_check(model.selected == -1)
    var button = model.preset_bounds(1)
    _ = model.pointer(bounds, Point(button.x + 20.0, button.y + 15.0), True)
    _ = model.pointer(bounds, point, False)
    test_check(model.preset == 1)
    test_check(model.harmonics[1] < 0.0001)
    test_check(model.harmonics[2] > 0.06)
    capture(renderer, model, "03-triangle")
    button = model.preset_bounds(2)
    _ = model.pointer(bounds, Point(button.x + 20.0, button.y + 15.0), True)
    _ = model.pointer(bounds, point, False)
    test_check(model.preset == 2)
    test_check(model.harmonics[1] > 0.25)
    capture(renderer, model, "04-pulse")
    renderer.shutdown()
    print("Signal playground: pointer editing, presets, centered/bounded audio and native frames passed.")
