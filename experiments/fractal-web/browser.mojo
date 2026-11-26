"""Experimental memory64 ABI over the actual native FractalState renderer."""
from std.collections import List
from std.ffi import external_call
from std.math import isfinite
from std.memory import Pointer
from std.memory.alloc import alloc, dealloc, Allocation, Layout as MemoryLayout
from moxi import FractalState, Point, Rect, Event
from moxi.column_view import ColumnView
from moxi.natural import Natural
from moxi.fractal import (
    FRACTAL_CANVAS_ID, FRACTAL_PRESET_COUNT, fractal_preset_name,
)
from moxi.event import POINTER_DOWN_KIND, POINTER_UP_KIND, POINTER_MOVE_KIND, POINTER_CANCEL_KIND, FRAME_TICK_KIND
from fractal_fixtures import set_fixture
from moxi.accessibility import ACTION_PRESS
from moxi.event import ACTION_KIND, TEXT_INPUT_KIND, KEY_DOWN_KIND, KEY_ENTER
from moxi.view_node import BUTTON_KIND, CHECKBOX_KIND, TEXT_INPUT_VIEW_KIND
from web_view import publish_widgets
from web_painter import WebCanvasPainter

comptime OK = 0
comptime INVALID_HANDLE = -1
comptime INVALID_INPUT = -2

struct BrowserState:
    var fractal: FractalState
    var view: ColumnView

    def __init__(out self):
        self.fractal = FractalState()
        self.view = self.fractal.build(Rect(0, 0, 1180, 900))

comptime StatePointer = Pointer[BrowserState, MutUntrackedOrigin]

def resolve(handle: Int64) -> Int64:
    return external_call["moxi_resolve", Int64](handle)

def input_text() raises -> String:
    var count = Int(external_call["moxi_text_size", Int32]())
    if count < 0:
        raise Error("Invalid text length")
    var data = List[UInt8]()
    for i in range(count):
        data.append(UInt8(external_call["moxi_text_byte", Int32](Int32(i))))
    return String(from_utf8=data)

@export
def moxi_create() abi("C") -> Int64:
    if external_call["moxi_can_create", Int32]() == 0:
        return 0
    var state = BrowserState()
    var allocation = alloc(MemoryLayout[BrowserState].single())
    var ptr = allocation^.unsafe_leak()
    ptr.unsafe_write(state^)
    return external_call["moxi_register", Int64](Int64(Int(ptr)))

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
def moxi_preset_count() abi("C") -> Int32:
    return Int32(FRACTAL_PRESET_COUNT)

@export
def moxi_preset_name(index: Int32) abi("C") -> Int32:
    if index < 0 or Int(index) >= FRACTAL_PRESET_COUNT:
        return INVALID_INPUT
    var name = fractal_preset_name(Int(index))
    var bytes = name.as_c_string_span()
    external_call["moxi_text_out", NoneType](bytes.ptr(), Int64(name.byte_length()))
    return OK

@export
def moxi_preset(handle: Int64, index: Int32) abi("C") -> Int32:
    var address = resolve(handle)
    if address == 0:
        return INVALID_HANDLE
    if index < 0 or Int(index) >= FRACTAL_PRESET_COUNT:
        return INVALID_INPUT
    var ptr = StatePointer(unsafe_from_address=Int(address))
    ptr[].fractal.preset_id = Int(index)
    ptr[].fractal.dragging = False
    ptr[].fractal.reset_current_preset()
    return OK

@export
def moxi_fixture(handle: Int64, index: Int32) abi("C") -> Int32:
    var address = resolve(handle)
    if address == 0:
        return INVALID_HANDLE
    var ptr = StatePointer(unsafe_from_address=Int(address))
    return OK if set_fixture(ptr[].fractal, Int(index)) else INVALID_INPUT

@export
def moxi_depth(handle: Int64) abi("C") -> Int32:
    var address = resolve(handle)
    if address == 0:
        return INVALID_HANDLE
    try:
        var depth = Natural()
        if not depth.parse(input_text()):
            return INVALID_INPUT
        var ptr = StatePointer(unsafe_from_address=Int(address))
        _ = ptr[].fractal.set_depth(depth)
        return OK
    except:
        return INVALID_INPUT

@export
def moxi_flags(handle: Int64, guides: Int32, colors: Int32) abi("C") -> Int32:
    var address = resolve(handle)
    if address == 0:
        return INVALID_HANDLE
    if (guides != 0 and guides != 1) or (colors != 0 and colors != 1):
        return INVALID_INPUT
    var ptr = StatePointer(unsafe_from_address=Int(address))
    ptr[].fractal.show_guides = guides == 1
    if ptr[].fractal.random_colors != (colors == 1):
        ptr[].fractal.random_colors = colors == 1
        ptr[].fractal.reset_render_progress()
    return OK

@export
def moxi_reset(handle: Int64) abi("C") -> Int32:
    var address = resolve(handle)
    if address == 0:
        return INVALID_HANDLE
    var ptr = StatePointer(unsafe_from_address=Int(address))
    ptr[].fractal.dragging = False
    ptr[].fractal.reset_current_preset()
    return OK

@export
def moxi_advance(handle: Int64, budget: Int32) abi("C") -> Int32:
    var address = resolve(handle)
    if address == 0:
        return INVALID_HANDLE
    if budget < 1:
        return INVALID_INPUT
    var ptr = StatePointer(unsafe_from_address=Int(address))
    return Int32(ptr[].fractal.advance_render(Int(budget)))

@export
def moxi_event(handle: Int64, kind: Int32, x: Float32, y: Float32, delta: Float32) abi("C") -> Int32:
    var address = resolve(handle)
    if address == 0:
        return INVALID_HANDLE
    if not isfinite(x) or not isfinite(y) or not isfinite(delta) or delta < 0:
        return INVALID_INPUT
    var ptr = StatePointer(unsafe_from_address=Int(address))
    var event = Event()
    event.kind = Int(kind)
    var canvas = ptr[].view.bounds_for(FRACTAL_CANVAS_ID)
    event.position = Point(canvas.x + x, canvas.y + y)
    event.target = FRACTAL_CANVAS_ID
    event.delta_seconds = delta
    if kind == FRAME_TICK_KIND:
        return Int32(ptr[].fractal.update(event, ptr[].view))
    elif kind == POINTER_DOWN_KIND or kind == POINTER_UP_KIND or kind == POINTER_MOVE_KIND or kind == POINTER_CANCEL_KIND:
        return Int32(ptr[].fractal.update_canvas(event, ptr[].view))
    else:
        return INVALID_INPUT

# Scalar metadata: 0 preset, 1 complete, 2 overflow, 3 branches, 4 guides,
# 5 colors, 6 point count, 7 preview count, 8 width, 9 height, 10 dragging,
# 11/12 endpoint docked, 13/14 inner endpoint revealed; 20/21 point x/y,
# 22/23 baseline x/y, 24..27 preview x0/y0/x1/y1.
@export
def moxi_inspect(handle: Int64, field: Int32, index: Int32) abi("C") -> Float64:
    var address = resolve(handle)
    if address == 0:
        return -999999
    var ptr = StatePointer(unsafe_from_address=Int(address))
    if field == 0:
        return Float64(ptr[].fractal.preset_id)
    if field == 1:
        return Float64(Int(ptr[].fractal.render_complete()))
    if field == 2:
        return Float64(Int(ptr[].fractal.coordinate_overflow))
    if field == 3:
        return Float64(ptr[].fractal.branch_factor())
    if field == 4:
        return Float64(Int(ptr[].fractal.show_guides))
    if field == 5:
        return Float64(Int(ptr[].fractal.random_colors))
    if field == 6:
        return Float64(len(ptr[].fractal.geometry.generator_points))
    if field == 7:
        return Float64(len(ptr[].fractal.rendered_segments))
    if field == 8:
        return Float64(ptr[].fractal.raster.width)
    if field == 9:
        return Float64(ptr[].fractal.raster.height)
    if field == 10:
        return Float64(Int(ptr[].fractal.dragging))
    if field == 11:
        return Float64(Int(ptr[].fractal.geometry.endpoint0_docked))
    if field == 12:
        return Float64(Int(ptr[].fractal.geometry.endpoint1_docked))
    if field == 13:
        return Float64(Int(ptr[].fractal.endpoint0_revealed))
    if field == 14:
        return Float64(Int(ptr[].fractal.endpoint1_revealed))
    if field >= 20 and field <= 21 and index >= 0 and Int(index) < len(ptr[].fractal.geometry.generator_points):
        var point = ptr[].fractal.geometry.generator_points[Int(index)]
        return Float64(point.x if field == 20 else point.y)
    if field >= 22 and field <= 23 and index >= 0 and index < 2:
        var point = ptr[].fractal.geometry.baseline_start if index == 0 else ptr[].fractal.geometry.baseline_end
        return Float64(point.x if field == 22 else point.y)
    if field >= 24 and field <= 27 and index >= 0 and Int(index) < len(ptr[].fractal.rendered_segments):
        var segment = ptr[].fractal.rendered_segments[Int(index)]
        if field == 24:
            return Float64(segment.start.x)
        if field == 25:
            return Float64(segment.start.y)
        if field == 26:
            return Float64(segment.end.x)
        return Float64(segment.end.y)
    return -999999

@export
def moxi_pixels(handle: Int64) abi("C") -> Int64:
    var address = resolve(handle)
    if address == 0:
        return 0
    var ptr = StatePointer(unsafe_from_address=Int(address))
    return Int64(Int(ptr[].fractal.raster.pixels.unsafe_ptr()))

@export
def moxi_text(handle: Int64, field: Int32) abi("C") -> Int32:
    var address = resolve(handle)
    if address == 0:
        return INVALID_HANDLE
    var ptr = StatePointer(unsafe_from_address=Int(address))
    var text = ptr[].fractal.depth.text() if field == 0 else ptr[].fractal.cursor.emitted.text()
    var bytes = text.as_c_string_span()
    external_call["moxi_text_out", NoneType](bytes.ptr(), Int64(text.byte_length()))
    return OK

@export
def moxi_widgets(handle: Int64, width: Float32, height: Float32) abi("C") -> Int32:
    var address = resolve(handle)
    if address == 0:
        return INVALID_HANDLE
    if not isfinite(width) or not isfinite(height) or width <= 0 or height <= 0:
        return INVALID_INPUT
    var ptr = StatePointer(unsafe_from_address=Int(address))
    ptr[].view = ptr[].fractal.build(Rect(0, 0, width, height))
    publish_widgets(ptr[].view)
    return OK


@export
def moxi_widget_event(handle: Int64, id: Int32, kind: Int32) abi("C") -> Int32:
    var address = resolve(handle)
    if address == 0:
        return INVALID_HANDLE
    var ptr = StatePointer(unsafe_from_address=Int(address))
    var event = Event()
    event.target = Int(id)
    event.kind = Int(kind)
    for node in ptr[].view.children:
        if node.id != event.target or not node.enabled:
            continue
        if event.kind == ACTION_KIND and (node.kind == BUTTON_KIND or node.kind == CHECKBOX_KIND):
            event.action_id = ACTION_PRESS
        elif event.kind == TEXT_INPUT_KIND and node.kind == TEXT_INPUT_VIEW_KIND:
            try:
                event.text = input_text()
            except:
                return INVALID_INPUT
            event.replacement_start = 0
            event.replacement_end = node.text.count_codepoints()
        elif event.kind == KEY_DOWN_KIND and node.kind == TEXT_INPUT_VIEW_KIND:
            event.key = KEY_ENTER
        else:
            return INVALID_INPUT
        return Int32(ptr[].fractal.update(event, ptr[].view))
    return INVALID_INPUT


@export
def moxi_paint(handle: Int64) abi("C") -> Int32:
    var address = resolve(handle)
    if address == 0:
        return INVALID_HANDLE
    var ptr = StatePointer(unsafe_from_address=Int(address))
    var bounds = Rect(0, 0, Float32(ptr[].fractal.raster.width), Float32(ptr[].fractal.raster.height))
    var painter = WebCanvasPainter()
    try:
        ptr[].fractal.paint_canvas(painter, bounds, bounds)
        return OK
    except:
        return INVALID_INPUT
