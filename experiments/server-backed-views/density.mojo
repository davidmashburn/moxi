"""Example-local ABI for the actual Moxi density component."""
from std.math import isfinite
from std.ffi import external_call
from std.memory import Pointer
from std.memory.alloc import alloc, dealloc, Allocation, Layout as MemoryLayout
from moxi import App, Component, ColumnView, Event, Point, Rect, Scene, Color, SvgSceneRenderer
from moxi.paint import scene_from_paint
from moxi.event import POINTER_DOWN_KIND, POINTER_MOVE_KIND, POINTER_UP_KIND, POINTER_CANCEL_KIND, DRAG_UPDATE_KIND, DROP_KIND, CLICK_KIND, SCROLL_KIND

from app import Density, CANVAS, CELLS, MAX_EXACT, READY, PENDING, FAILED

struct BrowserState:
    var app: App[Density]
    var svg: String
    def __init__(out self, width: Float32, height: Float32):
        self.app = App[Density](Density(), Rect(0, 0, width, height))
        self.svg = ""

comptime StatePointer = Pointer[BrowserState, MutUntrackedOrigin]

def resolve(handle: Int64) -> Int64:
    return external_call["moxi_resolve", Int64](handle)

@export
def moxi_create(width: Float32, height: Float32, sample: Int32) abi("C") -> Int64:
    if not isfinite(width) or not isfinite(height) or width < 320 or height < 320 or width > 4096 or height > 4096 or external_call["moxi_can_create", Int32]() == 0:
        return 0
    var state = BrowserState(width, height)
    var allocation = alloc(MemoryLayout[BrowserState].single())
    var ptr = allocation^.unsafe_leak()
    ptr.unsafe_write(state^)
    return external_call["moxi_register", Int64](Int64(Int(ptr)))

@export
def moxi_destroy(handle: Int64) abi("C") -> Int32:
    var address = resolve(handle)
    if address == 0:
        return -1
    var ptr = StatePointer(unsafe_from_address=Int(address))
    external_call["moxi_forget", NoneType](handle)
    ptr.unsafe_deinit_pointee()
    dealloc(Allocation(unsafe_owned_ptr=ptr, layout=MemoryLayout[BrowserState].single()))
    return 0

@export
def moxi_resize(handle: Int64, width: Float32, height: Float32) abi("C") -> Int32:
    if resolve(handle) == 0:
        return -1
    if not isfinite(width) or not isfinite(height) or width < 320 or height < 320 or width > 4096 or height > 4096:
        return -2
    var ptr = StatePointer(unsafe_from_address=Int(resolve(handle)))
    _ = ptr[].app.resize(Rect(0, 0, width, height))
    return 0

@export
def moxi_event(handle: Int64, kind: Int32, x: Float32, y: Float32, value: Float32, key: Int32, modifiers: Int32) abi("C") -> Int32:
    if resolve(handle) == 0:
        return -1
    if not isfinite(x) or not isfinite(y) or not isfinite(value) or abs(x) > 100000 or abs(y) > 100000 or abs(value) > 1000:
        return -2
    if kind != POINTER_DOWN_KIND and kind != POINTER_MOVE_KIND and kind != POINTER_UP_KIND and kind != POINTER_CANCEL_KIND and kind != SCROLL_KIND:
        return -2
    var ptr = StatePointer(unsafe_from_address=Int(resolve(handle)))
    var event = Event()
    event.kind = Int(kind)
    event.position = Point(x, y)
    event.scroll_delta = Point(0, value)
    event.modifiers = Int(modifiers)
    _ = ptr[].app.dispatch(event)
    return 0

# All data crosses a bounded example-local ABI, after transport validation.
@export
def moxi_grid(handle: Int64, x: Float32, y: Float32, width: Float32, height: Float32) abi("C") -> Int32:
    if resolve(handle) == 0:
        return -1
    if not isfinite(x) or not isfinite(y) or not isfinite(width) or not isfinite(height) or width < 0.009 or height < 0.009 or width > 4.01 or height > 4.01:
        return -2
    var ptr = StatePointer(unsafe_from_address=Int(resolve(handle)))
    ptr[].app.component.data_bounds = Rect(x, y, width, height)
    ptr[].app.component.counts.clear()
    return 0

@export
def moxi_count(handle: Int64, value: Int32) abi("C") -> Int32:
    if resolve(handle) == 0:
        return -1
    var ptr = StatePointer(unsafe_from_address=Int(resolve(handle)))
    if value < 0 or value > 1000000 or len(ptr[].app.component.counts) >= CELLS:
        return -2
    ptr[].app.component.counts.append(Int(value))
    return 0

@export
def moxi_status(handle: Int64, value: Int32) abi("C") -> Int32:
    if resolve(handle) == 0:
        return -1
    if value < READY or value > FAILED:
        return -2
    var ptr = StatePointer(unsafe_from_address=Int(resolve(handle)))
    ptr[].app.component.status = Int(value)
    ptr[].app.rebuild()
    return 0

@export
def moxi_exact(handle: Int64, id: Int32) abi("C") -> Int32:
    if resolve(handle) == 0:
        return -1
    var ptr = StatePointer(unsafe_from_address=Int(resolve(handle)))
    if id == 0:
        ptr[].app.component.exact.clear()
    elif id > 0 and id <= 1000000 and len(ptr[].app.component.exact) < MAX_EXACT:
        ptr[].app.component.exact.append(Int(id))
    else:
        return -2
    ptr[].app.rebuild()
    return 0

@export
def moxi_inspect(handle: Int64, index: Int32, field: Int32) abi("C") -> Float64:
    if resolve(handle) == 0:
        return -999999
    var ptr = StatePointer(unsafe_from_address=Int(resolve(handle)))
    var box = ptr[].app.component.camera
    if index == 1:
        box = ptr[].app.component.selection
    elif index == 2:
        box = ptr[].app.view.bounds_for(CANVAS)
    if field == 0:
        return Float64(box.x)
    if field == 1:
        return Float64(box.y)
    if field == 2:
        return Float64(box.width)
    if field == 3:
        return Float64(box.height)
    if field == 4:
        return Float64(ptr[].app.component.generation)
    if field == 5:
        return Float64(ptr[].app.component.selected_count)
    if field == 6:
        return Float64(len(ptr[].app.component.counts))
    if field == 9:
        return Float64(ptr[].app.component.selected_cell)
    if field == 8:
        return Float64(ptr[].app.component.selection_generation)
    return Float64(len(ptr[].app.component.exact))

@export
def moxi_render(handle: Int64) abi("C") -> Int32:
    if resolve(handle) == 0:
        return -1
    var ptr = StatePointer(unsafe_from_address=Int(resolve(handle)))
    try:
        var scene = scene_from_paint(ptr[].app.paint())
        var data = ptr[].app.component.scene(ptr[].app.view.bounds_for(CANVAS))
        for command in data.commands:
            scene.append(command)
        var renderer = SvgSceneRenderer(Int(ptr[].app.root_bounds.width), Int(ptr[].app.root_bounds.height))
        renderer.render_scene(scene)
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
        return 0
    except:
        return -2
