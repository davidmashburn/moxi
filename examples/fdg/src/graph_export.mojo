"""FDG exports the existing Scene through Moxi's SVG backend in every format."""
from std.ffi import external_call
from moxi import Rect, Scene, SvgSceneRenderer
from moxi.scene import SCENE_RECT, SCENE_ROUNDED_RECT, SCENE_LINE, SCENE_TEXT, SCENE_CLIP, SCENE_POP_CLIP
from graph_app import GraphApp

struct ExportFormat:
    var value: String

    def __init__(out self, path: String) raises:
        if path.endswith(".svg"):
            self.value = "svg"
        elif path.endswith(".png"):
            self.value = "png"
        elif path.endswith(".pdf"):
            self.value = "pdf"
        else:
            raise Error("Unsupported export format: use .svg, .png or .pdf")

comptime EXPORT_OK = 0
comptime EXPORT_IO = 1
comptime EXPORT_DEPENDENCY = 2

def scene_svg(scene: Scene, bounds: Rect) raises -> String:
    # Explicit FDG subset: reject newly introduced primitives until their SVG
    # fidelity is verified. Shared SVG image/gradient fallbacks are not exports.
    for i in range(scene.count()):
        var kind = scene.command(i).kind
        if kind != SCENE_RECT and kind != SCENE_ROUNDED_RECT and kind != SCENE_LINE and kind != SCENE_TEXT and kind != SCENE_CLIP and kind != SCENE_POP_CLIP:
            raise Error(String("Unsupported FDG export scene command: ", kind))
    var renderer = SvgSceneRenderer(Int(bounds.width), Int(bounds.height))
    renderer.render_scene(scene)
    return renderer.markup()

def export_graph(state: GraphApp, bounds: Rect, var path: String) raises:
    var format = ExportFormat(path)
    # Change origin only: preserve viewport scale/pan, selection, labels,
    # neighborhood filtering and the current simulation positions.
    var local = Rect(0, 0, bounds.width, bounds.height)
    var svg = scene_svg(state.scene(local), local)
    var c_svg = svg.as_c_string_span()
    var c_path = path.as_c_string_span()
    var c_format = format.value.as_c_string_span()
    var result = external_call["fdg_write_export", Int32](c_svg.ptr(), c_path.ptr(), c_format.ptr())
    if result == EXPORT_DEPENDENCY:
        raise Error("PNG/PDF export requires rsvg-convert on PATH or MOXI_FDG_RSVG pointing to it; SVG remains available")
    if result == EXPORT_IO:
        raise Error("Cannot write export path; existing destination preserved")
    if result != EXPORT_OK:
        raise Error("rsvg-convert failed; existing destination preserved")
    print("Exported ", path)
