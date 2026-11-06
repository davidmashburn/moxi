"""Bounded FDG browser ABI. Addresses never cross the exported API.

The per-instance host registry resolves opaque, never-reused handles. Imports
are synchronous and trusted; input validation precedes application mutation.
"""
from std.ffi import external_call
from std.memory import Pointer
from std.memory.alloc import alloc, dealloc, Allocation, Layout as MemoryLayout
from std.math import isfinite
from moxi import App, Rect, Point, Event, Scene, SvgSceneRenderer
from moxi.event import (
    POINTER_DOWN_KIND, POINTER_UP_KIND, POINTER_MOVE_KIND, POINTER_CANCEL_KIND,
    SCROLL_KIND, KEY_DOWN_KIND, TEXT_INPUT_KIND, FRAME_TICK_KIND, ACTION_KIND,
)
from moxi.paint import scene_from_paint
from graph_app import GraphApp, CANVAS, EXPORT, dispatch_graph_event
from layout import Layout, sample_graph, MAX_NODES, MAX_LINKS

comptime OK = 0
comptime INVALID_HANDLE = -1
comptime INVALID_INPUT = -2
comptime EXPORT_UNSUPPORTED = -3
comptime MAX_TEXT_BYTES = 512
comptime MAX_DIMENSION = 4096

struct BrowserState:
    var app: App[GraphApp]
    var svg: String

    def __init__(out self, var graph: Layout, width: Float32, height: Float32):
        self.app = App[GraphApp](GraphApp(graph^), Rect(0, 0, width, height))
        self.app.component.fit(self.app.view.bounds_for(CANVAS))
        self.svg = ""

comptime StatePointer = Pointer[BrowserState, MutUntrackedOrigin]

def resolve(handle: Int64) -> Int64:
    return external_call["moxi_resolve", Int64](handle)

def valid_size(width: Float32, height: Float32) -> Bool:
    return isfinite(width) and isfinite(height) and width >= 320 and height >= 320 and width <= MAX_DIMENSION and height <= MAX_DIMENSION

def input_text() raises -> String:
    var count = Int(external_call["moxi_text_size", Int32]())
    var data = List[UInt8]()
    for i in range(count):
        data.append(UInt8(external_call["moxi_text_byte", Int32](Int32(i))))
    return String(from_utf8=data)

@export
def moxi_create(width: Float32, height: Float32, sample: Int32) abi("C") -> Int64:
    if not valid_size(width, height) or (sample != 0 and sample != 1):
        return 0
    if external_call["moxi_can_create", Int32]() == 0:
        return 0
    try:
        var graph = Layout()
        if sample == 1:
            graph = sample_graph()
        else:
            var nodes = Int(external_call["moxi_graph_size", Int32](Int32(0)))
            var links = Int(external_call["moxi_graph_size", Int32](Int32(1)))
            if nodes < 0 or nodes > MAX_NODES or links < 0 or links > MAX_LINKS:
                return 0
            for i in range(nodes):
                # IDs are deliberately index-based in the bounded graph input ABI.
                graph.add_node(String("node-", i), Int(external_call["moxi_graph_group", Int32](Int32(i))))
            for i in range(links):
                var a = Int(external_call["moxi_graph_edge", Float64](Int32(i), Int32(0)))
                var b = Int(external_call["moxi_graph_edge", Float64](Int32(i), Int32(1)))
                var weight = external_call["moxi_graph_edge", Float64](Int32(i), Int32(2))
                if a < 0 or a >= nodes or b < 0 or b >= nodes or not isfinite(weight) or weight < 0 or weight > 1000000:
                    return 0
                graph.add_link(String("node-", a), String("node-", b), weight)
        var state = BrowserState(graph^, width, height)
        var allocation = alloc(MemoryLayout[BrowserState].single())
        var ptr = allocation^.unsafe_leak()
        ptr.unsafe_write(state^)
        return external_call["moxi_register", Int64](Int64(Int(ptr)))
    except:
        return 0

@export
def moxi_destroy(handle: Int64) abi("C") -> Int32:
    var address = resolve(handle)
    if address == 0:
        return INVALID_HANDLE
    var ptr = StatePointer(unsafe_from_address=Int(address))
    external_call["moxi_forget", NoneType](handle)
    ptr.unsafe_deinit_pointee()
    dealloc(Allocation(unsafe_owned_ptr=ptr, layout=MemoryLayout[BrowserState].single()))
    return OK

@export
def moxi_resize(handle: Int64, width: Float32, height: Float32) abi("C") -> Int32:
    var address = resolve(handle)
    if address == 0:
        return INVALID_HANDLE
    var ptr = StatePointer(unsafe_from_address=Int(address))
    if not valid_size(width, height):
        return INVALID_INPUT
    _ = ptr[].app.resize(Rect(0, 0, width, height))
    return OK

@export
def moxi_event(handle: Int64, kind: Int32, x: Float32, y: Float32, value: Float32, key: Int32, modifiers: Int32) abi("C") -> Int32:
    var address = resolve(handle)
    if address == 0:
        return INVALID_HANDLE
    var ptr = StatePointer(unsafe_from_address=Int(address))
    if not isfinite(x) or not isfinite(y) or not isfinite(value) or abs(x) > 1000000 or abs(y) > 1000000 or abs(value) > 1000 or modifiers < 0 or modifiers > 15:
        return INVALID_INPUT
    var event = Event()
    event.kind = Int(kind)
    event.position = Point(x, y)
    event.modifiers = Int(modifiers)
    if kind == POINTER_DOWN_KIND or kind == POINTER_UP_KIND or kind == POINTER_MOVE_KIND or kind == POINTER_CANCEL_KIND:
        pass
    elif kind == SCROLL_KIND:
        event.scroll_delta = Point(0, value)
    elif kind == KEY_DOWN_KIND:
        event.key = Int(key)
    elif kind == FRAME_TICK_KIND:
        event.delta_seconds = 1.0 / 60.0
    elif kind == ACTION_KIND:
        event.target = Int(key)
        event.action_id = Int(value)
        if key == EXPORT:
            return EXPORT_UNSUPPORTED
    elif kind == TEXT_INPUT_KIND:
        var count = external_call["moxi_text_size", Int32]()
        if count < 0 or count > MAX_TEXT_BYTES:
            return INVALID_INPUT
        try:
            event.text = input_text()
        except:
            return INVALID_INPUT
        # Bound retained query size as well as each individual message.
        if ptr[].app.component.query.text.byte_length() + event.text.byte_length() > MAX_TEXT_BYTES:
            return INVALID_INPUT
    else:
        return INVALID_INPUT
    _ = dispatch_graph_event(ptr[].app, event)
    if ptr[].app.component.export_requested:
        ptr[].app.component.export_requested = False
        ptr[].app.component.message = "Browser SVG file export is outside this experimental subset"
        ptr[].app.rebuild()
    return OK

@export
def moxi_render(handle: Int64) abi("C") -> Int32:
    var address = resolve(handle)
    if address == 0:
        return INVALID_HANDLE
    var ptr = StatePointer(unsafe_from_address=Int(address))
    try:
        var controls = scene_from_paint(ptr[].app.paint())
        var graph = ptr[].app.component.scene(ptr[].app.view.bounds_for(CANVAS))
        for command in graph.commands:
            controls.append(command)
        var renderer = SvgSceneRenderer(Int(ptr[].app.root_bounds.width), Int(ptr[].app.root_bounds.height))
        renderer.render_scene(controls)
        ptr[].svg = renderer.markup()
        var markup = ptr[].svg.as_c_string_span()
        external_call["moxi_svg", NoneType](handle, markup.ptr(), Int64(ptr[].svg.byte_length()))
        var snapshot = ptr[].app.accessibility()
        for i in range(snapshot.count()):
            var node = snapshot.node(i)
            var label = node.label.as_c_string_span()
            var value = node.value.as_c_string_span()
            external_call["moxi_semantic", NoneType](handle, Int32(node.id), Int32(node.parent_id), Int32(node.role), label.ptr(), Int64(node.label.byte_length()), value.ptr(), Int64(node.value.byte_length()), node.bounds.x, node.bounds.y, node.bounds.width, node.bounds.height, Int32(node.enabled), Int32(node.focused), Int32(node.selected), Int32(node.actions))
        ptr[].app.clear_invalidation()
        return OK
    except:
        return INVALID_INPUT

# Read-only scalar inspection for parity fixtures and reproducible demo gestures.
# Node fields: x/y/vx/vy/pinned/screen-x/screen-y. App fields use index -1.
@export
def moxi_inspect(handle: Int64, index: Int32, field: Int32) abi("C") -> Float64:
    var address = resolve(handle)
    if address == 0:
        return -999999
    var ptr = StatePointer(unsafe_from_address=Int(address))
    if index == -1:
        if field == 0:
            return Float64(ptr[].app.component.selected)
        if field == 1:
            return Float64(ptr[].app.component.zoom)
        if field == 2:
            return Float64(ptr[].app.component.pan.x)
        if field == 3:
            return Float64(ptr[].app.component.pan.y)
        if field == 4:
            return Float64(Int(ptr[].app.component.graph.paused))
        if field == 5:
            return ptr[].app.component.graph.alpha
        if field == 6:
            return Float64(len(ptr[].app.component.graph.nodes))
        if field == 7:
            return Float64(len(ptr[].app.component.graph.links))
    if index < 0 or Int(index) >= len(ptr[].app.component.graph.nodes):
        return -999999
    var node = ptr[].app.component.graph.nodes[Int(index)]
    if field == 0:
        return node.x
    if field == 1:
        return node.y
    if field == 2:
        return node.vx
    if field == 3:
        return node.vy
    if field == 4:
        return Float64(Int(node.pinned))
    var screen = ptr[].app.component.screen(Int(index), ptr[].app.view.bounds_for(CANVAS))
    if field == 5:
        return Float64(screen.x)
    if field == 6:
        return Float64(screen.y)
    return -999999
