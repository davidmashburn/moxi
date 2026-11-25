"""Private, synchronous C ABI; all Mojo allocations die before return."""
from std.memory import Pointer
from std.ffi import external_call
from moxi.geometry import Rect
from moxi.svg import SvgSceneRenderer
from moxi.scene import (
    Scene, SceneCommand, SceneRenderer, SCENE_RECT, SCENE_ROUNDED_RECT,
    SCENE_LINE, SCENE_TEXT, SCENE_CLIP, SCENE_POP_CLIP,
)
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
    comptime PDF: Int32 = 2

comptime Bytes = Pointer[UInt8, MutUntrackedOrigin]
comptime Addresses = Pointer[Int64, MutUntrackedOrigin]
comptime Numbers = Pointer[Float64, MutUntrackedOrigin]

struct HostSceneRenderer(SceneRenderer):
    """Submit only the declared line/scatter scene slice to the owned host sink."""
    var context: Int64

    def __init__(out self, context: Int64):
        self.context = context

    def draw_scene_command(mut self, command: SceneCommand) raises:
        if command.kind == SCENE_RECT or command.kind == SCENE_ROUNDED_RECT:
            external_call["moxi_e04_rect", NoneType](
                self.context, Float64(command.bounds.x), Float64(command.bounds.y),
                Float64(command.bounds.width), Float64(command.bounds.height),
                Float64(command.corner_radius), Float64(command.fill.red),
                Float64(command.fill.green), Float64(command.fill.blue),
                Float64(command.fill.alpha * command.opacity))
        elif command.kind == SCENE_LINE:
            external_call["moxi_e04_line", NoneType](
                self.context, Float64(command.point_start.x), Float64(command.point_start.y),
                Float64(command.point_end.x), Float64(command.point_end.y),
                Float64(command.stroke_width), Float64(command.stroke.red),
                Float64(command.stroke.green), Float64(command.stroke.blue),
                Float64(command.stroke.alpha * command.opacity))
        elif command.kind == SCENE_TEXT:
            # Plot chrome currently carries unstyled text. Reject future style
            # extensions until family/weight/alignment semantics are implemented.
            if command.has_text_style:
                raise Error("Styled text is outside the experimental rendering slice")
            var text = command.text
            var source = text.as_c_string_span()
            var ok = external_call["moxi_e04_text", Int32](
                self.context, source.ptr(), Float64(command.bounds.x),
                Float64(command.bounds.y + command.bounds.height), Float64(14.0),
                Float64(command.fill.red), Float64(command.fill.green),
                Float64(command.fill.blue), Float64(command.fill.alpha * command.opacity))
            if ok == 0:
                raise Error("Host text rendering failed")
        elif command.kind == SCENE_CLIP:
            external_call["moxi_e04_clip", NoneType](self.context,
                Float64(command.bounds.x), Float64(command.bounds.y),
                Float64(command.bounds.width), Float64(command.bounds.height))
        elif command.kind == SCENE_POP_CLIP:
            if external_call["moxi_e04_pop_clip", Int32](self.context) == 0:
                raise Error("Unbalanced host clip")
        else:
            raise Error("Scene command outside the experimental rendering slice")

    def render_scene(mut self, scene: Scene) raises:
        for index in range(scene.count()):
            self.draw_scene_command(scene.command(index))

def text_from(address: Int64, length: Int64) raises -> String:
    var source = Bytes(unsafe_from_address=Int(address))
    var data = List[UInt8]()
    for i in range(Int(length)):
        data.append(source[unsafe_offset=i])
    return String(from_utf8=data)

@export
def moxi_e04_abi_version() abi("C") -> Int32:
    return 2

@export
def moxi_e04_render(
    spec_address: Int64, spec_length: Int64,
    names_address: Int64, lengths_address: Int64,
    values_address: Int64, validity_address: Int64,
    columns: Int64, rows: Int64, width: Int32, height: Int32,
    output_kind: Int32, output_address: Int64, capacity: Int64,
    written_address: Int64, context_address: Int64,
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
        elif output_kind == Output.RGBA or output_kind == Output.PDF:
            if context_address == 0:
                return Status.RENDER_FAILED
            var renderer = HostSceneRenderer(context_address)
            renderer.render_scene(scene)
        else:
            return Status.RENDER_FAILED
        return Status.OK
    except:
        return Status.RENDER_FAILED
