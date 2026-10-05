"""Native clipboard service shared by AppKit and GTK hosts."""
from std.ffi import external_call
from .clipboard import ClipboardBackend


struct NativeClipboard(ClipboardBackend):
    def __init__(out self):
        pass

    def copy(mut self, text: String) raises:
        var copied = text
        var utf8 = copied.as_c_string_span()
        external_call["moxi_clipboard_set", NoneType](utf8.ptr())

    def paste(mut self) raises -> String:
        # One snapshot prevents cross-process changes between codepoint reads.
        var count = Int(external_call["moxi_clipboard_read_snapshot", Int32]())
        if count < 0:
            raise Error("Native clipboard read failed or timed out")
        var text = String("")
        for index in range(count):
            var codepoint = Int(external_call["moxi_clipboard_codepoint_at", Int32](Int32(index)))
            if codepoint < 0:
                raise Error("Native clipboard snapshot was truncated")
            text += chr(codepoint)
        return text
