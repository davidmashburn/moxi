"""Portable frame transaction. Hosts own publication; renderers own pixels."""

from std.collections import List
from .accessibility import AccessibilitySnapshot
from .backend import HostCapabilities, RendererCapabilities, BACKEND_HEADLESS
from .geometry import Size, Rect
from .invalidation import Invalidation, INVALIDATE_CONTENT, INVALIDATE_LAYOUT, INVALIDATE_STRUCTURE
from .paint import PaintCommand
from .scene import Scene


struct SurfaceMetrics(ImplicitlyCopyable):
    """Logical content size and its device-pixel scale, without native handles."""

    var size: Size
    var scale_factor: Float32

    def __init__(out self, size: Size = Size(640, 480), scale_factor: Float32 = 1):
        self.size = size
        self.scale_factor = scale_factor if scale_factor > 0 else 1

    def bounds(self) -> Rect:
        return Rect(0, 0, self.size.width, self.size.height)

    def pixel_width(self) -> Int:
        return max(1, Int(self.size.width * self.scale_factor))

    def pixel_height(self) -> Int:
        return max(1, Int(self.size.height * self.scale_factor))


struct FrameResource(ImplicitlyCopyable):
    """A paragraph binding identified by retained key and mount, never a pointer.

    A native renderer pins the exact measured payload before submission. The
    packet generation prevents a stale packet from using a newer binding.
    """

    var id: Int
    var mount: UInt64
    var command_index: Int

    def __init__(out self, id: Int, mount: UInt64, command_index: Int):
        self.id = id
        self.mount = mount
        self.command_index = command_index


struct FramePacket:
    """One publication supplies paint, semantics, metrics and resource identities.

    Scene is a canvas projection placed after custom_layer in the paint order.
    Native text payloads stay in the renderer's resource cache, outside this IR.
    """

    var generation: UInt64
    var metrics: SurfaceMetrics
    var invalidation: Invalidation
    var commands: List[PaintCommand]
    var semantics: AccessibilitySnapshot
    var scene: Scene
    var scene_clip: Rect
    var custom_layer: Int
    var resources: List[FrameResource]

    def __init__(out self, metrics: SurfaceMetrics = SurfaceMetrics(), generation: UInt64 = 0):
        self.generation = generation
        self.metrics = metrics
        self.invalidation = Invalidation()
        self.commands = List[PaintCommand]()
        self.semantics = AccessibilitySnapshot()
        self.scene = Scene()
        self.scene_clip = metrics.bounds()
        self.custom_layer = -1
        self.resources = List[FrameResource]()

    def needs_paint(self) -> Bool:
        return self.invalidation.has(INVALIDATE_CONTENT | INVALIDATE_LAYOUT | INVALIDATE_STRUCTURE)


trait FrameRenderer:
    """Consumes a portable publication without a host or application reference."""

    def capabilities(self) -> RendererCapabilities:
        return RendererCapabilities(BACKEND_HEADLESS)

    def render(mut self, packet: FramePacket) raises:
        ...

    def release_resources(mut self) raises:
        pass


trait FrameHost:
    """Publication facet of WindowBackend; deliberately independent of pixels."""

    def host_capabilities(self) -> HostCapabilities:
        return HostCapabilities(BACKEND_HEADLESS)

    def publish_accessibility(mut self, snapshot: AccessibilitySnapshot) raises:
        pass

    def present(mut self) raises:
        pass

    def metrics(self) raises -> SurfaceMetrics:
        ...


def submit_frame[HostType: FrameHost, RendererType: FrameRenderer](
    mut host: HostType, mut renderer: RendererType, packet: FramePacket
) raises:
    """Publish semantics independently; present only when paint is invalidated."""
    if packet.invalidation.is_empty():
        return
    if packet.needs_paint():
        renderer.render(packet)
    host.publish_accessibility(packet.semantics)
    if packet.needs_paint():
        host.present()
