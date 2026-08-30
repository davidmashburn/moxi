"""Portable platform-target and surface lifecycle contracts.

The target adapters are intentionally separate from the view/runtime. This
module lets iOS, Android, Web, and desktop hosts share the same lifecycle and
scale-factor rules before each platform has a native implementation.
"""

from .backend import (
    BACKEND_ANDROID,
    BACKEND_IOS,
    BACKEND_MACOS_APPKIT,
    BACKEND_WEB,
    BackendCapabilities,
    backend_capabilities,
)


struct PlatformTarget(ImplicitlyCopyable):
    """Extended target facts needed by a surface/input adapter."""

    var capabilities: BackendCapabilities
    var touch_input: Bool
    var keyboard_input: Bool
    var ime: Bool
    var device_pixels: Bool
    var browser_host: Bool
    var renderer_name: String

    def __init__(out self, kind: Int):
        self.capabilities = backend_capabilities(kind)
        self.touch_input = False
        self.keyboard_input = True
        self.ime = False
        self.device_pixels = False
        self.browser_host = False
        self.renderer_name = "software"
        if kind == BACKEND_MACOS_APPKIT:
            self.ime = True
            self.device_pixels = True
            self.renderer_name = "appkit"
        elif kind == BACKEND_IOS:
            self.touch_input = True
            self.ime = True
            self.device_pixels = True
            self.renderer_name = "metal"
        elif kind == BACKEND_ANDROID:
            self.touch_input = True
            self.ime = True
            self.device_pixels = True
            self.renderer_name = "gpu-surface"
        elif kind == BACKEND_WEB:
            self.touch_input = True
            self.ime = True
            self.browser_host = True
            self.renderer_name = "canvas/webgpu"

    def kind(self) -> Int:
        return self.capabilities.kind

    def is_planned_only(self) -> Bool:
        return not self.capabilities.available


struct SurfaceConfig(ImplicitlyCopyable):
    """Logical surface configuration shared by native and browser hosts."""

    var width: Float32
    var height: Float32
    var scale_factor: Float32
    var title: String
    var resizable: Bool

    def __init__(
        out self,
        width: Float32 = 640.0,
        height: Float32 = 480.0,
        title: String = "Moxi",
    ):
        self.width = width if width > 0.0 else 1.0
        self.height = height if height > 0.0 else 1.0
        self.scale_factor = 1.0
        self.title = title
        self.resizable = True

    def set_scale_factor(mut self, scale: Float32):
        self.scale_factor = scale if scale > 0.0 else 1.0

    def pixel_width(self) -> Int:
        var result = Int(self.width * self.scale_factor)
        return result if result > 0 else 1

    def pixel_height(self) -> Int:
        var result = Int(self.height * self.scale_factor)
        return result if result > 0 else 1


struct PlatformSurface:
    """Small lifecycle state machine for a host-owned surface."""

    var config: SurfaceConfig
    var attached: Bool
    var frame_open: Bool
    var frame_count: Int
    var resize_count: Int

    def __init__(out self, config: SurfaceConfig = SurfaceConfig()):
        self.config = config
        self.attached = False
        self.frame_open = False
        self.frame_count = 0
        self.resize_count = 0

    def attach(mut self) -> Bool:
        if self.attached:
            return False
        self.attached = True
        return True

    def resize(mut self, width: Float32, height: Float32) -> Bool:
        if not self.attached:
            return False
        var next_width = width if width > 0.0 else 1.0
        var next_height = height if height > 0.0 else 1.0
        if self.config.width == next_width and self.config.height == next_height:
            return False
        self.config.width = next_width
        self.config.height = next_height
        self.resize_count += 1
        return True

    def set_scale_factor(mut self, scale: Float32) -> Bool:
        if not self.attached:
            return False
        var next_scale = scale if scale > 0.0 else 1.0
        if self.config.scale_factor == next_scale:
            return False
        self.config.scale_factor = next_scale
        self.resize_count += 1
        return True

    def begin_frame(mut self) -> Bool:
        if not self.attached or self.frame_open:
            return False
        self.frame_open = True
        return True

    def end_frame(mut self) -> Bool:
        if not self.frame_open:
            return False
        self.frame_open = False
        self.frame_count += 1
        return True

    def close(mut self) -> Bool:
        if not self.attached:
            return False
        self.frame_open = False
        self.attached = False
        return True

    def is_ready(self) -> Bool:
        return self.attached and not self.frame_open
