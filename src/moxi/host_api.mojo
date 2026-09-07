"""Focused host/adapter import path.

This module groups portable host contracts with the native macOS adapters.
Availability remains capability-dependent; importing the path does not claim a
linked runtime on every target.
"""

from .host_contract import (
    HOST_NATIVE,
    HOST_PORTABLE_BRIDGE,
    HostContract,
    host_contract,
)
from .macos import (
    MacOSCanvasPainter,
    MacOSCanvasSceneRenderer,
    MacOSClipboard,
    MacOSFileWatcher,
    MacOSLiveScript,
    MacOSRenderer,
    MacOSWindow,
)
from .platform import PlatformSurface, PlatformTarget, SurfaceConfig
from .platform_adapters import (
    ContractBackend,
    PlatformAdapter,
    android_backend,
    headless_backend,
    ios_backend,
    web_backend,
)
from .targets import AndroidBackend, IOSBackend, WebBackend
