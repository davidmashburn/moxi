"""Backend-neutral resource handles for images, fonts, and application assets."""

from std.collections import List


comptime RESOURCE_NONE = -1
comptime RESOURCE_IMAGE = 1
comptime RESOURCE_FONT = 2
comptime RESOURCE_DATA = 3


struct ResourceHandle(ImplicitlyCopyable):
    """A stable resource identity that can cross a renderer boundary."""

    var id: Int
    var kind: Int
    var label: String

    def __init__(out self, id: Int, kind: Int, label: String):
        self.id = id
        self.kind = kind
        self.label = label


struct ImageResource(ImplicitlyCopyable):
    """Metadata for an image owned by the application resource store."""

    var id: Int
    var source: String
    var alt_text: String
    var width: Int
    var height: Int

    def __init__(
        out self,
        id: Int,
        source: String,
        alt_text: String,
        width: Int,
        height: Int,
    ):
        self.id = id
        self.source = source
        self.alt_text = alt_text
        self.width = width if width > 0 else 0
        self.height = height if height > 0 else 0


struct FontResource(ImplicitlyCopyable):
    """Metadata for a font source resolved by a platform text adapter."""

    var id: Int
    var source: String
    var family: String
    var weight: Int

    def __init__(
        out self,
        id: Int,
        source: String,
        family: String,
        weight: Int = 400,
    ):
        self.id = id
        self.source = source
        self.family = family
        self.weight = weight if weight > 0 else 400


struct ResourceStore:
    """Deterministic application-owned image registry.

    The store intentionally keeps bytes out of the UI core. A platform adapter
    resolves `source` into a native or GPU resource, while views carry only a
    stable integer handle.
    """

    var images: List[ImageResource]
    var fonts: List[FontResource]
    var next_id: Int

    def __init__(out self):
        self.images = List[ImageResource]()
        self.fonts = List[FontResource]()
        self.next_id = 1

    def register_image(
        mut self,
        source: String,
        alt_text: String,
        width: Int,
        height: Int,
    ) -> ResourceHandle:
        """Register image metadata and return a stable handle."""
        for index in range(len(self.images)):
            if self.images[index].source == source:
                return ResourceHandle(self.images[index].id, RESOURCE_IMAGE, source)
        var id = self.next_id
        self.next_id += 1
        self.images.append(ImageResource(id, source, alt_text, width, height))
        return ResourceHandle(id, RESOURCE_IMAGE, source)

    def image_count(self) -> Int:
        return len(self.images)

    def has_image(self, id: Int) -> Bool:
        for index in range(len(self.images)):
            if self.images[index].id == id:
                return True
        return False

    def image(self, id: Int) -> ImageResource:
        for index in range(len(self.images)):
            if self.images[index].id == id:
                return self.images[index]
        return ImageResource(RESOURCE_NONE, "", "", 0, 0)

    def register_font(
        mut self,
        source: String,
        family: String,
        weight: Int = 400,
    ) -> ResourceHandle:
        """Register a font source and return a stable font handle."""
        for index in range(len(self.fonts)):
            if self.fonts[index].source == source:
                return ResourceHandle(self.fonts[index].id, RESOURCE_FONT, source)
        var id = self.next_id
        self.next_id += 1
        self.fonts.append(FontResource(id, source, family, weight))
        return ResourceHandle(id, RESOURCE_FONT, source)

    def font_count(self) -> Int:
        return len(self.fonts)

    def has_font(self, id: Int) -> Bool:
        for index in range(len(self.fonts)):
            if self.fonts[index].id == id:
                return True
        return False

    def font(self, id: Int) -> FontResource:
        for index in range(len(self.fonts)):
            if self.fonts[index].id == id:
                return self.fonts[index]
        return FontResource(RESOURCE_NONE, "", "")


trait ResourceResolver:
    """Platform hook for turning a portable handle into a native resource."""

    def resolve_image(mut self, image: ImageResource) raises -> Bool:
        """Return whether the platform can resolve one image resource."""
        return False

    def resolve_font(mut self, font: FontResource) raises -> Bool:
        """Return whether the platform can resolve one font resource."""
        return False

    def release_image(mut self, id: Int) raises:
        """Release a platform-side image resource by stable id."""
        pass
