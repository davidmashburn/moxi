"""Window lifecycle contract and portable configuration."""


struct WindowConfig:
    """The platform-independent inputs needed to create a window."""

    var title: String
    var width: Float32
    var height: Float32

    def __init__(out self, title: String, width: Float32, height: Float32):
        self.title = title
        self.width = width
        self.height = height


trait WindowBackend:
    """Owns a native window and its event-loop lifecycle."""

    def open(mut self, config: WindowConfig) raises:
        pass

    def run(self) raises:
        pass
