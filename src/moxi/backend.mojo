"""Backend capability declarations shared by renderers and tooling."""


comptime BACKEND_HEADLESS = 1
comptime BACKEND_MACOS_APPKIT = 2
comptime BACKEND_GPU = 3
comptime BACKEND_WINDOWS = 4
comptime BACKEND_LINUX = 5


struct BackendCapabilities(ImplicitlyCopyable):
    """What a renderer can actually provide at runtime."""

    var kind: Int
    var name: String
    var available: Bool
    var native_window: Bool
    var gpu_acceleration: Bool
    var text_shaping: Bool
    var bidi: Bool
    var rich_text: Bool
    var accessibility: Bool
    var clipping: Bool
    var incremental: Bool
    var note: String

    def __init__(
        out self,
        kind: Int,
        name: String,
        available: Bool,
        native_window: Bool,
        gpu_acceleration: Bool,
        text_shaping: Bool,
        bidi: Bool,
        rich_text: Bool,
        accessibility: Bool,
        clipping: Bool,
        incremental: Bool,
        note: String,
    ):
        self.kind = kind
        self.name = name
        self.available = available
        self.native_window = native_window
        self.gpu_acceleration = gpu_acceleration
        self.text_shaping = text_shaping
        self.bidi = bidi
        self.rich_text = rich_text
        self.accessibility = accessibility
        self.clipping = clipping
        self.incremental = incremental
        self.note = note


def backend_capabilities(kind: Int) -> BackendCapabilities:
    """Return the honest capability matrix for a known backend target."""
    if kind == BACKEND_MACOS_APPKIT:
        return BackendCapabilities(
            BACKEND_MACOS_APPKIT,
            "macOS AppKit",
            True,
            True,
            False,
            True,
            True,
            False,
            True,
            True,
            False,
            "AppKit supplies native windowing, text shaping, bidi, and AX.",
        )
    if kind == BACKEND_GPU:
        return BackendCapabilities(
            BACKEND_GPU,
            "GPU command backend",
            False,
            False,
            True,
            False,
            False,
            False,
            False,
            True,
            True,
            "Command contract reserved; no GPU implementation is shipped yet.",
        )
    if kind == BACKEND_WINDOWS:
        return BackendCapabilities(
            BACKEND_WINDOWS,
            "Windows backend",
            False,
            False,
            False,
            False,
            False,
            False,
            False,
            True,
            False,
            "Backend contract reserved; native bridge is not shipped yet.",
        )
    if kind == BACKEND_LINUX:
        return BackendCapabilities(
            BACKEND_LINUX,
            "Linux backend",
            False,
            False,
            False,
            False,
            False,
            False,
            False,
            True,
            False,
            "Backend contract reserved; native bridge is not shipped yet.",
        )
    return BackendCapabilities(
        BACKEND_HEADLESS,
        "headless test renderer",
        True,
        False,
        False,
        False,
        False,
        False,
        True,
        True,
        True,
        "Deterministic commands and semantics; text uses the estimate backend.",
    )
