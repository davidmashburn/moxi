"""Portable clipboard boundary for application-level text commands."""


trait ClipboardBackend:
    """A backend that can exchange UTF-8 text with the host environment."""

    def copy(mut self, text: String) raises:
        pass

    def paste(mut self) raises -> String:
        return ""


struct MemoryClipboard(ClipboardBackend):
    """Deterministic clipboard backend for tests and non-native applications."""

    var text: String

    def __init__(out self):
        self.text = ""

    def copy(mut self, text: String) raises:
        self.text = text

    def paste(mut self) raises -> String:
        return self.text
