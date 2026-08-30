"""Named target adapters for the iOS, Android, and Web roadmap."""

from .platform import SurfaceConfig
from .platform_adapters import (
    ContractBackend,
    PlatformAdapter,
    android_backend,
    ios_backend,
    web_backend,
)


struct IOSBackend(PlatformAdapter):
    """UIKit/Metal adapter shell; fails closed until the native host lands."""

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

    def begin_frame(mut self) -> Bool:
        return self.base.begin_frame()

    def present(mut self) -> Bool:
        return self.base.present()

    def close(mut self) -> Bool:
        return self.base.close()


struct AndroidBackend(PlatformAdapter):
    """Android surface/GPU adapter shell; fails closed before native support."""

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

    def begin_frame(mut self) -> Bool:
        return self.base.begin_frame()

    def present(mut self) -> Bool:
        return self.base.present()

    def close(mut self) -> Bool:
        return self.base.close()


struct WebBackend(PlatformAdapter):
    """Canvas/WebGPU adapter shell; fails closed before a browser host exists."""

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

    def begin_frame(mut self) -> Bool:
        return self.base.begin_frame()

    def present(mut self) -> Bool:
        return self.base.present()

    def close(mut self) -> Bool:
        return self.base.close()
