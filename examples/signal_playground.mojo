"""Native Metal waveform editor with a measured spectrum and live audio."""

from std.ffi import external_call
from moxi import MacOSMetalRenderer, MacOSMetalWindow, Rect, WindowConfig
from signal_playground_model import SignalPlayground


def publish_audio(model: SignalPlayground):
    for index in range(128):
        external_call["signal_audio_set_sample", NoneType](Int32(index), model.samples[index])
    external_call["signal_audio_commit", NoneType]()


def main() raises:
    var model = SignalPlayground()
    var renderer = MacOSMetalRenderer(1080, 760)
    var window = MacOSMetalWindow()
    window.open(WindowConfig("Moxi Signal Playground", 1080.0, 760.0))
    if not renderer.is_ready() or not window.is_open():
        renderer.shutdown()
        raise Error("Moxi Metal window unavailable")
    var audio_started = False
    var previous_playing = False
    var previous_revision = -1
    var previous_width: Float32 = 0.0
    var previous_height: Float32 = 0.0
    while window.is_open():
        window.pump()
        var bounds = Rect(0.0, 0.0, window.config.width, window.config.height)
        var changed = model.pointer(bounds, window.pointer_position(), window.left_mouse_down())
        if model.revision != previous_revision:
            publish_audio(model)
            previous_revision = model.revision
            changed = True
        if model.playing != previous_playing:
            if model.playing and not audio_started:
                audio_started = external_call["signal_audio_start", Int32]() != 0
                if not audio_started:
                    model.playing = False
                    model.message = "Audio device unavailable. Waveform editing still works."
            var enabled = external_call["signal_audio_enable", Int32](Int32(1 if model.playing else 0))
            if model.playing and enabled == 0:
                model.playing = False
                model.message = "Audio output could not start. Try Play again."
            previous_playing = model.playing
            changed = True
        if changed or previous_width != bounds.width or previous_height != bounds.height:
            var scene = model.scene(bounds)
            renderer.render_scene(scene)
            previous_width = bounds.width
            previous_height = bounds.height
        _ = external_call["usleep", Int32](UInt32(16000))
    external_call["signal_audio_stop", NoneType]()
    renderer.shutdown()
