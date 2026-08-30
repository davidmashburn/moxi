"""Explicit native-host status and requirements for platform adapters.

The Mojo package is built for the host it is running on, so it cannot safely
pretend that an iOS SDK, Android NDK, or browser runtime is linked merely
because a target enum exists. This contract describes package-side native
availability; the separately built host artifacts under ``native/`` are
validated by their platform build scripts.
"""

from .backend import (
    BACKEND_ANDROID,
    BACKEND_HEADLESS,
    BACKEND_IOS,
    BACKEND_MACOS_APPKIT,
    BACKEND_WEB,
)


comptime HOST_PORTABLE_BRIDGE = 1
comptime HOST_NATIVE = 2


struct HostContract(ImplicitlyCopyable):
    """What a target host provides independently of the renderer API."""

    var target: Int
    var name: String
    var status: Int
    var lifecycle: Bool
    var input: Bool
    var gpu_surface: Bool
    var accessibility: Bool
    var requirement: String

    def __init__(
        out self,
        target: Int,
        name: String,
        status: Int,
        lifecycle: Bool,
        input: Bool,
        gpu_surface: Bool,
        accessibility: Bool,
        requirement: String,
    ):
        self.target = target
        self.name = name
        self.status = status
        self.lifecycle = lifecycle
        self.input = input
        self.gpu_surface = gpu_surface
        self.accessibility = accessibility
        self.requirement = requirement

    def native_available(self) -> Bool:
        return self.status == HOST_NATIVE

    def portable_fallback(self) -> Bool:
        return self.status == HOST_PORTABLE_BRIDGE


def host_contract(target: Int) -> HostContract:
    """Return a truthful host status for the current package build."""
    if target == BACKEND_MACOS_APPKIT:
        return HostContract(
            BACKEND_MACOS_APPKIT,
            "macOS AppKit/Metal",
            HOST_NATIVE,
            True,
            True,
            True,
            True,
            "Xcode Command Line Tools plus AppKit/Metal frameworks",
        )
    if target == BACKEND_IOS:
        return HostContract(
            BACKEND_IOS,
            "iOS UIKit/Metal",
            HOST_PORTABLE_BRIDGE,
            True,
            True,
            True,
            False,
            "Moxi iOS host artifact plus a Mojo-capable target runtime",
        )
    if target == BACKEND_ANDROID:
        return HostContract(
            BACKEND_ANDROID,
            "Android NDK surface/GPU",
            HOST_PORTABLE_BRIDGE,
            True,
            True,
            True,
            False,
            "Moxi Android APK host plus a Mojo-capable target runtime",
        )
    if target == BACKEND_WEB:
        return HostContract(
            BACKEND_WEB,
            "Browser Canvas/WebGPU",
            HOST_PORTABLE_BRIDGE,
            True,
            True,
            True,
            False,
            "Moxi browser host plus a Mojo-capable WebAssembly/runtime target",
        )
    return HostContract(
        BACKEND_HEADLESS,
        "headless host",
        HOST_PORTABLE_BRIDGE,
        True,
        False,
        False,
        True,
        "no native surface; deterministic test renderer",
    )
