"""Host adapter protocol shared by desktop, mobile, and browser targets."""

from .backend import (
    BACKEND_ANDROID,
    BACKEND_HEADLESS,
    BACKEND_IOS,
    BACKEND_WEB,
)
from .platform import PlatformSurface, PlatformTarget, SurfaceConfig


trait PlatformAdapter:
    """Lifecycle seam for a host-owned native or browser surface."""

    def kind(self) -> Int:
        ...

    def is_available(self) -> Bool:
        ...

    def open(mut self, config: SurfaceConfig) -> Bool:
        ...

    def resize(mut self, width: Float32, height: Float32) -> Bool:
        ...

    def begin_frame(mut self) -> Bool:
        ...

    def present(mut self) -> Bool:
        ...

    def close(mut self) -> Bool:
        ...


struct ContractBackend(PlatformAdapter):
    """A real lifecycle implementation backed by the portable surface state.

    For unavailable targets, calls fail closed. This makes it safe to share
    application code while a UIKit, Android, or browser host is being built.
    """

    var target: PlatformTarget
    var surface: PlatformSurface
    var open_attempts: Int

    def __init__(out self, kind: Int):
        self.target = PlatformTarget(kind)
        self.surface = PlatformSurface()
        self.open_attempts = 0

    def kind(self) -> Int:
        return self.target.kind()

    def is_available(self) -> Bool:
        return self.target.capabilities.available

    def open(mut self, config: SurfaceConfig) -> Bool:
        self.open_attempts += 1
        if not self.is_available():
            return False
        self.surface = PlatformSurface(config)
        return self.surface.attach()

    def resize(mut self, width: Float32, height: Float32) -> Bool:
        return self.surface.resize(width, height)

    def begin_frame(mut self) -> Bool:
        return self.surface.begin_frame()

    def present(mut self) -> Bool:
        return self.surface.end_frame()

    def close(mut self) -> Bool:
        return self.surface.close()


def headless_backend() -> ContractBackend:
    return ContractBackend(BACKEND_HEADLESS)


def ios_backend() -> ContractBackend:
    return ContractBackend(BACKEND_IOS)


def android_backend() -> ContractBackend:
    return ContractBackend(BACKEND_ANDROID)


def web_backend() -> ContractBackend:
    return ContractBackend(BACKEND_WEB)
