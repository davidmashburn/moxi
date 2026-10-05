"""Linux specializations for the GTK native window and paragraph bridge.

Link the Linux native objects and their GTK/Pango/Cairo dependencies. Layout,
component state, hit testing, and the constraint model remain owned by Mojo.
"""

from .backend import BACKEND_LINUX
from .native_clipboard import NativeClipboard
from .native_window import (
    NativeCanvasPainter,
    NativeCanvasSceneRenderer,
    NativeRenderer,
    NativeWindow,
)


comptime LinuxRenderer = NativeRenderer[BACKEND_LINUX]
comptime LinuxCanvasSceneRenderer = NativeCanvasSceneRenderer[BACKEND_LINUX]
comptime LinuxCanvasPainter = NativeCanvasPainter[BACKEND_LINUX]
comptime LinuxWindow = NativeWindow[BACKEND_LINUX]

comptime LinuxClipboard = NativeClipboard
