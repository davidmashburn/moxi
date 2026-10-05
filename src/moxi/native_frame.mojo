"""Native resource adapter for the portable frame contract.

The canonical frame path has no retained-tree access during rendering. Bindings
pin measured paragraphs before submission; the host publishes AX and presents.
"""

from std.collections import Dict
from std.ffi import external_call
from .backend import RendererCapabilities
from .frame import FramePacket, FrameRenderer
from .native_window import NativeRenderer, NativeCanvasSceneRenderer
from .native_paragraph import NativeParagraph
from .retained_layout import RetainedSnapshot
from .view_node import CANVAS_KIND, LABEL_KIND, TEXT_INPUT_VIEW_KIND


struct NativeFrameRenderer[backend_kind: Int](FrameRenderer):
    var paint: NativeRenderer[Self.backend_kind]
    var scene: NativeCanvasSceneRenderer[Self.backend_kind]
    var paragraphs: Dict[Int, NativeParagraph]
    var mounts: Dict[Int, UInt64]
    var generation: UInt64

    def __init__(out self):
        self.paint = NativeRenderer[Self.backend_kind]()
        self.scene = NativeCanvasSceneRenderer[Self.backend_kind]()
        self.paragraphs = Dict[Int, NativeParagraph]()
        self.mounts = Dict[Int, UInt64]()
        self.generation = 0

    def capabilities(self) -> RendererCapabilities:
        return RendererCapabilities(Self.backend_kind)

    def bind_resources(mut self, snapshot: RetainedSnapshot):
        """Replace a frame lease with exact measured payloads, retaining ownership."""
        self.paragraphs = Dict[Int, NativeParagraph]()
        self.mounts = Dict[Int, UInt64]()
        for output in snapshot._outputs[]:
            if output.has_paragraph and not output.hidden:
                self.paragraphs[output.key] = output.paragraph
                self.mounts[output.key] = output.mount
        self.generation = snapshot.generation

    def release_resources(mut self) raises:
        self.paragraphs = Dict[Int, NativeParagraph]()
        self.mounts = Dict[Int, UInt64]()
        self.generation = 0

    def render(mut self, packet: FramePacket) raises:
        if packet.generation != self.generation and len(packet.resources) > 0:
            raise Error("Frame paragraph lease belongs to another generation")
        var bound_commands = Dict[Int, Bool]()
        for resource in packet.resources:
            if resource.command_index in bound_commands:
                raise Error("Duplicate frame resource command")
            bound_commands[resource.command_index] = True
            if resource.id not in self.paragraphs or self.mounts[resource.id] != resource.mount:
                raise Error("Unbound or retired frame paragraph")
            if resource.command_index < 0 or resource.command_index >= len(packet.commands):
                raise Error("Invalid frame resource command")
            if packet.commands[resource.command_index].id != resource.id or packet.commands[resource.command_index].resource_id != resource.id or packet.commands[resource.command_index].kind != LABEL_KIND:
                raise Error("Frame resource does not identify its command")
        for index in range(len(packet.commands)):
            if packet.commands[index].resource_id >= 0 and index not in bound_commands:
                raise Error("Frame command is missing its resource binding")
        self.paint.begin_frame()
        external_call["moxi_window_ordered_paint_begin", NoneType]()
        var resources = Dict[Int, Int]()
        for resource in packet.resources:
            resources[resource.command_index] = resource.id
        var scene_submitted = False
        for index in range(len(packet.commands)):
            var command = packet.commands[index]
            if command.kind == TEXT_INPUT_VIEW_KIND and command.focused:
                external_call["moxi_window_text_editor_key", NoneType](Int32(command.id))
            if command.kind == CANVAS_KIND:
                self.paint.draw_panel(command)
            else:
                self.paint.draw(command)
            external_call["moxi_window_ordered_paint", NoneType](
                Int32(3 if command.kind == CANVAS_KIND else command.kind), Int32(command.slot))
            if index in resources:
                external_call["moxi_window_set_paragraph_at", NoneType](
                    Int32(command.slot), self.paragraphs[resources[index]]._storage[].handle)
            if command.id == packet.custom_layer:
                self.scene.set_clip(packet.scene_clip)
                self.scene.render_scene(packet.scene)
                external_call["moxi_window_ordered_paint", NoneType](Int32(100), Int32(command.slot))
                scene_submitted = True
        if not scene_submitted and packet.scene.count() > 0:
            self.scene.set_clip(packet.scene_clip)
            self.scene.render_scene(packet.scene)
            external_call["moxi_window_ordered_paint", NoneType](Int32(100), Int32(0))
