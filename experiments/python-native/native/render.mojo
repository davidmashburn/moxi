"""Private, synchronous C ABI; all Mojo allocations die before return."""
from std.memory import Pointer
from moxi.geometry import Rect
from moxi.style import Color
from moxi.svg import SvgSceneRenderer
from moxi.software import SoftwareSceneRenderer
from moxi_plot.plot_data import PlotDataTable
from moxi_plot.plot_spec import plot_spec_from_json, plot_from_spec

# Named ABI states, mirrored by the C boundary contract tests.
struct Status:
    comptime OK: Int32 = 0
    comptime INVALID_SPEC: Int32 = 1
    comptime INVALID_COLUMNS: Int32 = 2
    comptime OUTPUT_LIMIT: Int32 = 3
    comptime RENDER_FAILED: Int32 = 4

struct Output:
    comptime RGBA: Int32 = 0
    comptime SVG: Int32 = 1

comptime Bytes = Pointer[UInt8, MutUntrackedOrigin]
comptime Addresses = Pointer[Int64, MutUntrackedOrigin]
comptime Numbers = Pointer[Float64, MutUntrackedOrigin]

def text_from(address: Int64, length: Int64) raises -> String:
    var source = Bytes(unsafe_from_address=Int(address))
    var data = List[UInt8]()
    for i in range(Int(length)):
        data.append(source[unsafe_offset=i])
    return String(from_utf8=data)

@export
def moxi_e04_abi_version() abi("C") -> Int32:
    return 1

@export
def moxi_e04_render(
    spec_address: Int64, spec_length: Int64,
    names_address: Int64, lengths_address: Int64,
    values_address: Int64, validity_address: Int64,
    columns: Int64, rows: Int64, width: Int32, height: Int32,
    output_kind: Int32, output_address: Int64, capacity: Int64,
    written_address: Int64,
) abi("C") -> Int32:
    # The private C shim validates lengths, pointer provenance and finite values.
    # These pointers only refer to C-owned buffers held for this call.
    var written = Addresses(unsafe_from_address=Int(written_address))
    written[unsafe_offset=0] = 0
    try:
        var spec = plot_spec_from_json(text_from(spec_address, spec_length))
        if not spec.is_valid() or not spec.validate():
            return Status.INVALID_SPEC
        var table = PlotDataTable()
        var names = Addresses(unsafe_from_address=Int(names_address))
        var lengths = Addresses(unsafe_from_address=Int(lengths_address))
        var values = Addresses(unsafe_from_address=Int(values_address))
        var validity = Addresses(unsafe_from_address=Int(validity_address))
        var fields = List[String]()
        for c in range(Int(columns)):
            var field = text_from(names[unsafe_offset=c], lengths[unsafe_offset=c])
            if field != "x" and field != "y":
                if not table.add_float64_column(field):
                    return Status.INVALID_COLUMNS
            fields.append(field)
        for r in range(Int(rows)):
            _ = table.append(0, 0)
            for c in range(Int(columns)):
                var numbers = Numbers(unsafe_from_address=Int(values[unsafe_offset=c]))
                var valid = Bytes(unsafe_from_address=Int(validity[unsafe_offset=c]))
                if fields[c] == "x" or fields[c] == "y":
                    if not table.set_float_field(fields[c], r, Float32(numbers[unsafe_offset=r]), valid[unsafe_offset=r] != 0):
                        return Status.INVALID_COLUMNS
                elif not table.set_float64_field(fields[c], r, numbers[unsafe_offset=r], valid[unsafe_offset=r] != 0):
                    return Status.INVALID_COLUMNS
        var plot = plot_from_spec(spec, table, Rect(0, 0, Float32(width), Float32(height)))
        var scene = plot.build_scene()
        var output = Bytes(unsafe_from_address=Int(output_address))
        if output_kind == Output.SVG:
            var renderer = SvgSceneRenderer(Int(width), Int(height))
            renderer.render_scene(scene)
            var encoded = renderer.output.as_bytes()
            if Int64(len(encoded)) > capacity:
                return Status.OUTPUT_LIMIT
            for i in range(len(encoded)):
                output[unsafe_offset=i] = encoded[i]
            written[unsafe_offset=0] = Int64(len(encoded))
        elif output_kind == Output.RGBA:
            if Int64(width) * Int64(height) * 4 > capacity:
                return Status.OUTPUT_LIMIT
            var renderer = SoftwareSceneRenderer(Int(width), Int(height), Color(1, 1, 1, 1))
            renderer.render_scene(scene)
            for i in range(len(renderer.pixels)):
                var pixel = renderer.pixels[i]
                output[unsafe_offset=i * 4] = UInt8(max(0, min(255, Int(pixel.red * 255))))
                output[unsafe_offset=i * 4 + 1] = UInt8(max(0, min(255, Int(pixel.green * 255))))
                output[unsafe_offset=i * 4 + 2] = UInt8(max(0, min(255, Int(pixel.blue * 255))))
                output[unsafe_offset=i * 4 + 3] = UInt8(max(0, min(255, Int(pixel.alpha * 255))))
            written[unsafe_offset=0] = Int64(width) * Int64(height) * 4
        else:
            return Status.RENDER_FAILED
        return Status.OK
    except:
        return Status.RENDER_FAILED
