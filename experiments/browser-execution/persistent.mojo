"""Probe-only C ABI. Raw addresses are private to the checked JS owner wrapper."""
from layout import Layout, sample_graph
from std.memory import Pointer
from std.memory.alloc import alloc, dealloc, Allocation, Layout as MemoryLayout
from std.math import isfinite

comptime GraphPointer = Pointer[Layout, MutUntrackedOrigin]

@export
def fdg_create() abi("C") -> Int64:
    try:
        # Finish raising work before acquiring the manually owned allocation.
        var graph = sample_graph()
        var allocation = alloc(MemoryLayout[Layout].single())
        var ptr = allocation^.unsafe_leak()
        ptr.unsafe_write(graph^)
        return Int64(Int(ptr))
    except:
        return 0

@export
def fdg_destroy(address: Int64) abi("C"):
    var ptr = GraphPointer(unsafe_from_address=Int(address))
    ptr.unsafe_deinit_pointee()
    dealloc(Allocation(unsafe_owned_ptr=ptr, layout=MemoryLayout[Layout].single()))

@export
def fdg_step(address: Int64, steps: Int32) abi("C") -> Int32:
    if steps < 0 or steps > 1000:
        return -1
    var ptr = GraphPointer(unsafe_from_address=Int(address))
    for _ in range(Int(steps)):
        _ = ptr[].step()
    return 0

@export
def fdg_pin(address: Int64, index: Int32, x: Float64, y: Float64) abi("C") -> Int32:
    var ptr = GraphPointer(unsafe_from_address=Int(address))
    if index < 0 or Int(index) >= len(ptr[].nodes):
        return -1
    if not isfinite(x) or not isfinite(y) or abs(x) > 1000000 or abs(y) > 1000000:
        return -1
    ptr[].pin(Int(index), x, y)
    return 0

@export
def fdg_release(address: Int64, index: Int32) abi("C") -> Int32:
    var ptr = GraphPointer(unsafe_from_address=Int(address))
    if index < 0 or Int(index) >= len(ptr[].nodes):
        return -1
    ptr[].release(Int(index))
    return 0

@export
def fdg_coordinate(address: Int64, index: Int32, field: Int32) abi("C") -> Float64:
    var ptr = GraphPointer(unsafe_from_address=Int(address))
    if index < 0 or Int(index) >= len(ptr[].nodes) or field < 0 or field > 4:
        return -999999.0
    var node = ptr[].nodes[Int(index)]
    if field == 0:
        return node.x
    if field == 1:
        return node.y
    if field == 2:
        return node.vx
    if field == 3:
        return node.vy
    return Float64(Int(node.pinned))

def snapshot(graph: Layout):
    for node in graph.nodes:
        print(node.x, node.y, node.vx, node.vy, Int(node.pinned))

def main() raises:
    # Independent oracle invokes Layout directly, not the exported wrappers.
    var graph = sample_graph()
    snapshot(graph)
    for _ in range(10):
        _ = graph.step()
    snapshot(graph)
    graph.pin(3, 120.0, -80.0)
    for _ in range(5):
        _ = graph.step()
    snapshot(graph)
    graph.release(3)
    for _ in range(20):
        _ = graph.step()
    snapshot(graph)
