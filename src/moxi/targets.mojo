"""Named target adapters for iOS, Android, and Web.

These adapters are the portable host boundary: they normalize host input and
provide a deterministic fallback renderer while native SDK shims are still
capability-gated. Keeping this layer useful before the platform FFI lands lets
application code and tests share one event/lifecycle contract.
"""

from .event import (
    CompositionEvent,
    Event,
    KeyEvent,
    PointerEvent,
    ResizeEvent,
    TextInputEvent,
    TouchEvent,
)
from .geometry import Point, Size
from .platform import SurfaceConfig
from .platform_adapters import (
    ContractBackend,
    PlatformAdapter,
    android_backend,
    ios_backend,
    web_backend,
)
from .scene import Scene
from .software import SoftwareSceneRenderer
from .svg import SvgSceneRenderer


def _software_checksum(scene: Scene, width: Int, height: Int) raises -> Int:
    var renderer = SoftwareSceneRenderer(width, height)
    renderer.render_scene(scene)
    return renderer.checksum()


struct IOSBackend(PlatformAdapter):
    """UIKit/Metal host bridge with a deterministic software fallback."""

    var base: ContractBackend

    def __init__(out self):
        self.base = ios_backend()

    def kind(self) -> Int:
        return self.base.kind()

    def is_available(self) -> Bool:
        return self.base.is_available()

    def open(mut self, config: SurfaceConfig) -> Bool:
        return self.base.open(config)

    def resize(mut self, width: Float32, height: Float32) -> Bool:
        return self.base.resize(width, height)

    def set_scale_factor(mut self, scale: Float32) -> Bool:
        return self.base.set_scale_factor(scale)

    def begin_frame(mut self) -> Bool:
        return self.base.begin_frame()

    def present(mut self) -> Bool:
        return self.base.present()

    def close(mut self) -> Bool:
        return self.base.close()

    def touch(
        self,
        kind: Int,
        pointer_id: Int,
        position: Point,
        modifiers: Int = 0,
    ) -> Event:
        """Normalize a UIKit touch phase into the Moxi touch envelope."""
        var result = Event(TouchEvent(kind, pointer_id, position))
        result.modifiers = modifiers
        return result

    def resize_event(self, width: Float32, height: Float32) -> Event:
        """Normalize a UIKit safe-area/content resize notification."""
        return Event(ResizeEvent(Size(width, height)))

    def key_event(self, key: Int, modifiers: Int = 0) -> Event:
        """Normalize hardware-key input when a UIKit host provides it."""
        return Event(KeyEvent(key, modifiers))

    def text_event(
        self,
        text: String,
        replacement_start: Int = -1,
        replacement_end: Int = -1,
    ) -> Event:
        """Normalize committed text and native replacement ranges."""
        return Event(TextInputEvent(text, replacement_start, replacement_end))

    def composition_event(
        self,
        text: String,
        selection_start: Int = 0,
        selection_end: Int = 0,
    ) -> Event:
        """Normalize marked-text updates from an iOS input method."""
        return Event(CompositionEvent(text, selection_start, selection_end))

    def software_checksum(self, scene: Scene, width: Int, height: Int) raises -> Int:
        """Render through the portable fallback while native Metal is absent."""
        return _software_checksum(scene, width, height)


struct AndroidBackend(PlatformAdapter):
    """Android surface/GPU host bridge with a deterministic software fallback."""

    var base: ContractBackend

    def __init__(out self):
        self.base = android_backend()

    def kind(self) -> Int:
        return self.base.kind()

    def is_available(self) -> Bool:
        return self.base.is_available()

    def open(mut self, config: SurfaceConfig) -> Bool:
        return self.base.open(config)

    def resize(mut self, width: Float32, height: Float32) -> Bool:
        return self.base.resize(width, height)

    def set_scale_factor(mut self, scale: Float32) -> Bool:
        return self.base.set_scale_factor(scale)

    def begin_frame(mut self) -> Bool:
        return self.base.begin_frame()

    def present(mut self) -> Bool:
        return self.base.present()

    def close(mut self) -> Bool:
        return self.base.close()

    def touch(
        self,
        kind: Int,
        pointer_id: Int,
        position: Point,
        modifiers: Int = 0,
    ) -> Event:
        """Normalize an Android MotionEvent phase into Moxi."""
        var result = Event(TouchEvent(kind, pointer_id, position))
        result.modifiers = modifiers
        return result

    def resize_event(self, width: Float32, height: Float32) -> Event:
        """Normalize a surface/density-aware content resize."""
        return Event(ResizeEvent(Size(width, height)))

    def key_event(self, key: Int, modifiers: Int = 0) -> Event:
        """Normalize Android hardware-key input."""
        return Event(KeyEvent(key, modifiers))

    def text_event(
        self,
        text: String,
        replacement_start: Int = -1,
        replacement_end: Int = -1,
    ) -> Event:
        """Normalize committed text from the Android IME."""
        return Event(TextInputEvent(text, replacement_start, replacement_end))

    def composition_event(
        self,
        text: String,
        selection_start: Int = 0,
        selection_end: Int = 0,
    ) -> Event:
        """Normalize composing text from the Android IME."""
        return Event(CompositionEvent(text, selection_start, selection_end))

    def software_checksum(self, scene: Scene, width: Int, height: Int) raises -> Int:
        """Render through the portable fallback while native surface support is absent."""
        return _software_checksum(scene, width, height)


struct WebBackend(PlatformAdapter):
    """Browser host bridge with pointer input and SVG fallback output."""

    var base: ContractBackend

    def __init__(out self):
        self.base = web_backend()

    def kind(self) -> Int:
        return self.base.kind()

    def is_available(self) -> Bool:
        return self.base.is_available()

    def open(mut self, config: SurfaceConfig) -> Bool:
        return self.base.open(config)

    def resize(mut self, width: Float32, height: Float32) -> Bool:
        return self.base.resize(width, height)

    def set_scale_factor(mut self, scale: Float32) -> Bool:
        return self.base.set_scale_factor(scale)

    def begin_frame(mut self) -> Bool:
        return self.base.begin_frame()

    def present(mut self) -> Bool:
        return self.base.present()

    def close(mut self) -> Bool:
        return self.base.close()

    def pointer(
        self,
        kind: Int,
        position: Point,
        pointer_id: Int = 0,
        buttons: Int = 0,
        modifiers: Int = 0,
    ) -> Event:
        """Normalize a DOM PointerEvent into the Moxi pointer envelope."""
        var result = Event(PointerEvent(kind, position, pointer_id, buttons))
        result.modifiers = modifiers
        return result

    def touch(
        self,
        kind: Int,
        pointer_id: Int,
        position: Point,
        modifiers: Int = 0,
    ) -> Event:
        """Normalize a DOM touch fallback into the shared touch envelope."""
        var result = Event(TouchEvent(kind, pointer_id, position))
        result.modifiers = modifiers
        return result

    def resize_event(self, width: Float32, height: Float32) -> Event:
        """Normalize a ResizeObserver or canvas resize notification."""
        return Event(ResizeEvent(Size(width, height)))

    def key_event(self, key: Int, modifiers: Int = 0) -> Event:
        """Normalize a DOM KeyboardEvent's logical key."""
        return Event(KeyEvent(key, modifiers))

    def text_event(
        self,
        text: String,
        replacement_start: Int = -1,
        replacement_end: Int = -1,
    ) -> Event:
        """Normalize committed browser text input."""
        return Event(TextInputEvent(text, replacement_start, replacement_end))

    def composition_event(
        self,
        text: String,
        selection_start: Int = 0,
        selection_end: Int = 0,
    ) -> Event:
        """Normalize a DOM composition update."""
        return Event(CompositionEvent(text, selection_start, selection_end))

    def software_checksum(self, scene: Scene, width: Int, height: Int) raises -> Int:
        """Render through the portable fallback while Canvas/WebGPU is absent."""
        return _software_checksum(scene, width, height)

    def svg_frame(self, scene: Scene, width: Int, height: Int) raises -> String:
        """Serialize one frame for a browser host using SVG as the fallback."""
        var renderer = SvgSceneRenderer(width, height)
        renderer.render_scene(scene)
        return renderer.markup()
