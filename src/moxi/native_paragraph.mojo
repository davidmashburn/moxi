"""Optional macOS paragraph provider and committed-snapshot presenter.

Link macos_text.o + CoreText; presentation also needs macos_window.o + Cocoa.
"""
from std.ffi import external_call
from std.memory import ArcPointer
from .box_layout import BoxMetrics, ParagraphPayload, GeometrySnapshot
from .geometry import Size
from .macos import MacOSRenderer


struct _NativeParagraphStorage:
    var handle: UInt

    def __init__(out self, handle: UInt = 0):
        self.handle = handle

    def __deinit__(deinit self):
        if self.handle != 0:
            external_call["moxi_paragraph_release", NoneType](self.handle)


struct NativeParagraph(ParagraphPayload):
    """Shared ownership prevents cache eviction from retiring a live draw payload."""
    var _storage: ArcPointer[_NativeParagraphStorage]

    def __init__(out self):
        self._storage = ArcPointer(_NativeParagraphStorage())

    @staticmethod
    def create(text: String, font_size: Float32, width: Float32, direction: Int) raises -> Self:
        if "\x00" in text:
            raise Error("Native paragraph text cannot contain a NUL character")
        var source = text
        var c_source = source.as_c_string_slice()
        var handle = external_call["moxi_paragraph_create", UInt](
            c_source.ptr(), font_size, width, Int32(direction))
        if handle == 0:
            raise Error("Native paragraph creation failed")
        var result = Self()
        result._storage = ArcPointer(_NativeParagraphStorage(handle))
        return result^

    def _metric(self, index: Int32) -> Float32:
        return external_call["moxi_paragraph_metric", Float32](self._storage[].handle, index)

    def metrics(self) -> BoxMetrics:
        return BoxMetrics(Size(self._metric(0), self._metric(1)), self._metric(2), self._metric(3))

    def line_count(self) -> Int:
        return Int(self._metric(4))


def draw_box_snapshot(mut renderer: MacOSRenderer, snapshot: GeometrySnapshot[NativeParagraph]) raises:
    """Submit the committed geometry and exact retained paragraphs to AppKit.

    Call begin_frame first; submit any chart scene before update_accessibility.
    """
    var commands = snapshot.paint_commands()
    for i in range(len(commands)):
        renderer.draw(commands[i])
        if snapshot._outputs[][i].paragraph:
            external_call["moxi_window_set_paragraph_at", NoneType](
                Int32(i), snapshot._outputs[][i].measured._payload._storage[].handle)
