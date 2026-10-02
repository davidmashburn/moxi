"""Explicit legacy leaf presentation on retained geometry; no legacy layout pass."""
from std.collections import List, Dict
from std.ffi import external_call
from .retained_layout import RetainedLayout, RetainedStyle, RetainedSnapshot
from .view_node import ViewNode, LABEL_KIND, BUTTON_KIND, TEXT_INPUT_VIEW_KIND, CANVAS_KIND
from .paint import PaintCommand
from .accessibility import ROLE_CONTAINER, ROLE_LABEL
from .geometry import Point
from .macos import MacOSRenderer


def declare_leaf(mut layout: RetainedLayout, node: ViewNode, style: RetainedStyle) raises:
    """Supported modes are label, button, single-line editor and canvas.

    Reject other legacy modes until they have an explicit adapter. Controls own
    their state; the retained tree supplies all geometry. Labels use the identical
    CoreText payload for measurement and drawing. Fixed-allocation controls use
    their existing native rendering and text-editing implementation.
    """
    if node.kind == LABEL_KIND:
        layout.set_paragraph(node.id,node.text,node.style.font_size,style)
    elif node.kind == BUTTON_KIND or node.kind == TEXT_INPUT_VIEW_KIND or node.kind == CANVAS_KIND:
        layout.set_box(node.id,style,node.text)
    else:
        raise Error("Unsupported legacy leaf mode in retained adapter")
    layout.set_semantics(node.id,node.semantics)


struct RetainedPresentation:
    var snapshot: RetainedSnapshot
    var commands: List[PaintCommand]
    var focused: Int
    def __init__(out self, snapshot: RetainedSnapshot, leaves: List[ViewNode], focused: Int = -1) raises:
        self.snapshot = snapshot
        self.focused = focused
        self.commands = List[PaintCommand]()
        var nodes = Dict[Int,ViewNode]()
        if len(snapshot._outputs[])>1024:
            raise Error("Retained native host capacity exceeded (1024 nodes)")
        for leaf in leaves:
            if leaf.id in nodes:
                raise Error("Duplicate presentation leaf")
            if leaf.kind!=LABEL_KIND and leaf.kind!=BUTTON_KIND and leaf.kind!=TEXT_INPUT_VIEW_KIND and leaf.kind!=CANVAS_KIND:
                raise Error("Unsupported retained native presentation mode")
            _ = snapshot.output(leaf.id)
            nodes[leaf.id] = leaf
        for output in snapshot._outputs[]:
            if output.hidden or output.semantics.role == ROLE_CONTAINER:
                continue
            var command = PaintCommand(output.semantics.label,output.rect)
            command.kind = LABEL_KIND if output.has_paragraph else CANVAS_KIND
            command.id = output.key
            command.style.font_size = output.font
            command.wrap_text = output.has_paragraph
            if output.key in nodes:
                var node = nodes[output.key]
                command.kind = node.kind
                command.text = node.text
                command.style = node.style
                command.cursor = node.cursor
                command.set_selection(node.selection_anchor,node.cursor)
                command.set_composition(node.composition,node.composition_selection_start,node.composition_selection_end)
                command.enabled = node.enabled
                command.action_id = node.action_id
            command.slot = len(self.commands)
            command.focused = output.key == focused
            command.semantics = output.semantics
            command.semantics.focused = command.focused
            command.set_clip(output.clip)
            self.commands.append(command)

    def hit_test(self, point: Point) -> Int:
        for i in range(len(self.commands)-1,-1,-1):
            if self.commands[i].bounds.contains(point) and self.commands[i].clip_bounds.contains(point) and self.commands[i].enabled:
                return self.commands[i].id
        return -1

    def draw_commands(self, mut renderer: MacOSRenderer, custom_layer: Int = -1) raises:
        external_call["moxi_window_ordered_paint_begin", NoneType]()
        for command in self.commands:
            if command.kind == CANVAS_KIND:
                renderer.draw_panel(command)
            else:
                renderer.draw(command)
            external_call["moxi_window_ordered_paint", NoneType](Int32(3 if command.kind == CANVAS_KIND else command.kind),Int32(command.slot))
            if command.id==custom_layer:
                external_call["moxi_window_ordered_paint", NoneType](Int32(100),Int32(command.slot))
            var output = self.snapshot.output(command.id)
            if output.has_paragraph and command.kind == LABEL_KIND:
                external_call["moxi_window_set_paragraph_at", NoneType](Int32(command.slot),output.paragraph._storage[].handle)

    def draw_accessibility(self, mut renderer: MacOSRenderer) raises:
        var accessibility = self.snapshot.accessibility()
        for i in range(len(accessibility.nodes)):
            accessibility.nodes[i].focused = accessibility.nodes[i].id == self.focused
            if accessibility.nodes[i].role == ROLE_LABEL and accessibility.nodes[i].value == "":
                accessibility.nodes[i].value = accessibility.nodes[i].label
        renderer.update_accessibility(accessibility)

    def draw(self, mut renderer: MacOSRenderer, custom_layer: Int = -1) raises:
        self.draw_commands(renderer,custom_layer)
        self.draw_accessibility(renderer)
