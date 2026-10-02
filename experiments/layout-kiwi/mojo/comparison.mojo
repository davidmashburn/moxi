"""Same CSV column workload through LayoutTree and the experimental Kiwi C ABI.

No production adapter: publication is copying rectangles into a Mojo List.
All timings include status checks. Construction includes initial constraints.
"""
from std.collections import List
from std.ffi import external_call
from std.memory import Pointer
from std.collections import Optional
from moxi import Rect
from moxi.content_layout import AxisSize, LayoutStyle, LayoutNode, LayoutTree

comptime Handle = Pointer[UInt8, MutAnyOrigin]


def now() -> Int64:
    return external_call["moxi_benchmark_time_ns", Int64]()


def check(ok: Bool, message: String) raises:
    if not ok:
        raise Error(message)


def declarations(summary: Bool) -> List[LayoutNode]:
    var nodes = List[LayoutNode]()
    nodes.append(LayoutNode(0, -1, LayoutStyle(AxisSize.fill(), AxisSize.fill(), padding=10, gap=8), True))
    nodes.append(LayoutNode(1, 0, LayoutStyle(AxisSize.fill(), AxisSize.fixed(40))))
    if summary:
        nodes.append(LayoutNode(3, 0, LayoutStyle(AxisSize.fill(), AxisSize.fixed(40))))
    nodes.append(LayoutNode(2, 0, LayoutStyle(AxisSize.fill(), AxisSize.fill(), min_height=160)))
    return nodes^


def verify(rects: List[Rect], height: Float64, summary: Bool, width: Float64) raises:
    var chart_y: Float64 = 58
    if summary:
        chart_y = 106
    var expected_h = max(Float64(160), height - 10 - chart_y)
    check(len(rects) == 2 + Int(summary), "publication count")
    check(abs(Float64(rects[0].y) - 10) < 0.01 and abs(Float64(rects[0].height) - 40) < 0.01, "header")
    if summary:
        check(abs(Float64(rects[1].y) - 58) < 0.01 and abs(Float64(rects[1].height) - 40) < 0.01, "summary")
    var chart = rects[len(rects)-1]
    check(abs(Float64(chart.y) - chart_y) < 0.01 and abs(Float64(chart.height) - expected_h) < 0.01, "chart resize/insertion/overflow")
    for rect in rects:
        check(abs(Float64(rect.x) - 10) < 0.01 and abs(Float64(rect.width) - (width - 20)) < 0.01, "horizontal allocation")


def report(engine: String, sample: Int, phase: String, mutation: Int64, layout: Int64, publication: Int64, total: Int64, rects: List[Rect]):
    var checksum: Float64 = 0
    for rect in rects:
        checksum += Float64(rect.x + rect.y + rect.width + rect.height)
    print(engine, sample, phase, mutation, layout, publication, total, checksum)


def tree_run(sample: Int) raises:
    var start = now()
    var tree = LayoutTree()
    tree.sync(declarations(False))
    var created = now() - start
    print("creation", "mojo", sample, created)
    for step in range(5):
        var height: Float64 = 600
        var width: Float64 = 800
        var summary = step >= 2
        var phase: String = "cold"
        if step == 1:
            height = 800
            width = 1000
            phase = "resize"
        elif step == 2:
            phase = "insert"
        elif step == 3:
            phase = "overflow"
            height = 150
        elif step == 4:
            phase = "unchanged"
            height = 150
        var total_start = now()
        start = now()
        if step == 2:
            tree.sync(declarations(True))
        var mutation = now() - start
        start = now()
        tree.layout(Rect(0, 0, Float32(width), Float32(height)))
        var layout = now() - start
        start = now()
        var rects = List[Rect]()
        for i in range(1, tree.count()):
            rects.append(tree.bounds(i))
        var publication = now() - start
        var total = now() - total_start
        verify(rects, height, summary, width)
        report("mojo", sample, phase, mutation, layout, publication, total, rects)


def status(code: Int32) raises:
    check(code == 0, String("Kiwi ABI status ", code))


def constraint(handle: Handle, id: Int, ids: List[Int32], coefficients: List[Float64], constant: Float64, op: Int = 0, strength: Float64 = 1001001000) raises:
    status(external_call["layout_kiwi_add_constraint", Int32](handle, Int32(id), ids.unsafe_ptr(), coefficients.unsafe_ptr(), UInt(len(ids)), constant, Int32(op), strength))


def fixed(handle: Handle, id: Int, value: Float64) raises:
    constraint(handle, id, [Int32(id)], [Float64(1)], -value)


def variable(handle: Handle, id: Int) raises:
    status(external_call["layout_kiwi_add_variable", Int32](handle, Int32(id)))


def value(handle: Handle, id: Int) raises -> Float32:
    var result: Float64 = 0
    status(external_call["layout_kiwi_get_value", Int32](handle, Int32(id), Pointer(to=result)))
    return Float32(result)


def kiwi_rect(handle: Handle, base: Int) raises -> Rect:
    return Rect(value(handle, base), value(handle, base+1), value(handle, base+2), value(handle, base+3))


def kiwi_run(sample: Int) raises:
    var start = now()
    var maybe_handle = external_call["layout_kiwi_create", Optional[Handle]]()
    check(Bool(maybe_handle), "Kiwi create")
    var handle = maybe_handle.value()
    try:
        # IDs 10..13 header, 20..23 chart, 30..33 summary; 100 viewport height, 101 viewport width.
        variable(handle, 101)
        status(external_call["layout_kiwi_add_edit_variable", Int32](handle, Int32(101), Float64(1000000)))
        status(external_call["layout_kiwi_suggest_value", Int32](handle, Int32(101), Float64(800)))
        for base in range(10, 30, 10):
            for offset in range(4):
                variable(handle, base+offset)
            fixed(handle, base, 10)
            constraint(handle, base+2, [Int32(base+2), Int32(101)], [Float64(1), Float64(-1)], 20)
        variable(handle, 100)
        status(external_call["layout_kiwi_add_edit_variable", Int32](handle, Int32(100), Float64(1000000)))
        status(external_call["layout_kiwi_suggest_value", Int32](handle, Int32(100), Float64(600)))
        fixed(handle, 11, 10)
        fixed(handle, 13, 40)
        # Chart top uses replaceable constraint IDs; variable IDs remain stable.
        constraint(handle, 200, [Int32(21), Int32(11), Int32(13)], [Float64(1), Float64(-1), Float64(-1)], -8)
        constraint(handle, 201, [Int32(23)], [Float64(1)], -160, 2)
        # Parent size dominates a medium fill preference, so shortage overflows.
        constraint(handle, 202, [Int32(21), Int32(23), Int32(100)], [Float64(1), Float64(1), Float64(-1)], 10, 0, 1000)
        var created = now() - start
        print("creation", "kiwi", sample, created)
        for step in range(5):
            var height: Float64 = 600
            var width: Float64 = 800
            var summary = step >= 2
            var phase: String = "cold"
            if step == 1:
                height = 800
                width = 1000
                phase = "resize"
            elif step == 2:
                phase = "insert"
            elif step == 3:
                phase = "overflow"
                height = 150
            elif step == 4:
                phase = "unchanged"
                height = 150
            var total_start = now()
            start = now()
            if step > 0 and step < 4:
                status(external_call["layout_kiwi_suggest_value", Int32](handle, Int32(100), height))
                status(external_call["layout_kiwi_suggest_value", Int32](handle, Int32(101), width))
            if step == 2:
                for offset in range(4):
                    variable(handle, 30+offset)
                fixed(handle, 30, 10)
                constraint(handle, 31, [Int32(31), Int32(11), Int32(13)], [Float64(1), Float64(-1), Float64(-1)], -8)
                constraint(handle, 32, [Int32(32), Int32(101)], [Float64(1), Float64(-1)], 20)
                fixed(handle, 33, 40)
                status(external_call["layout_kiwi_remove_constraint", Int32](handle, Int32(200)))
                constraint(handle, 203, [Int32(21), Int32(31), Int32(33)], [Float64(1), Float64(-1), Float64(-1)], -8)
            var mutation = now() - start
            start = now()
            status(external_call["layout_kiwi_update", Int32](handle))
            var layout = now() - start
            start = now()
            var rects = List[Rect]()
            rects.append(kiwi_rect(handle, 10))
            if summary:
                rects.append(kiwi_rect(handle, 30))
            rects.append(kiwi_rect(handle, 20))
            var publication = now() - start
            var total = now() - total_start
            verify(rects, height, summary, width)
            check(abs(Float64(value(handle, 100)) - height) < .01, "parent height changed")
            check(abs(Float64(value(handle, 101)) - width) < .01, "parent width changed")
            report("kiwi", sample, phase, mutation, layout, publication, total, rects)
    except e:
        external_call["layout_kiwi_destroy", NoneType](handle)
        raise e
    external_call["layout_kiwi_destroy", NoneType](handle)


def main() raises:
    for sample in range(7):
        if sample % 2 == 0:
            tree_run(sample)
            kiwi_run(sample)
        else:
            kiwi_run(sample)
            tree_run(sample)
