"""Publish Moxi widget declarations to the browser's DOM adapter."""
from std.ffi import external_call
from moxi.column_view import ColumnView
from moxi.style import Color


def rgba(color: Color) -> UInt32:
    return (
        (UInt32(color.red * 255 + 0.5) << 24)
        | (UInt32(color.green * 255 + 0.5) << 16)
        | (UInt32(color.blue * 255 + 0.5) << 8)
        | UInt32(color.alpha * 255 + 0.5)
    )


def publish_widgets(ref view: ColumnView):
    for i in range(view.child_count()):
        var node = view.child(i)
        var text = node.text.as_c_string_span()
        var label = node.semantics.label.as_c_string_span()
        var hint = node.semantics.hint.as_c_string_span()
        external_call["moxi_widget", NoneType](
            Int32(node.id), Int32(node.parent_id), Int32(node.kind),
            text.ptr(), Int64(node.text.byte_length()),
            label.ptr(), Int64(node.semantics.label.byte_length()),
            hint.ptr(), Int64(node.semantics.hint.byte_length()),
            Int32(node.enabled), Int32(node.checked), Int32(node.container_axis),
            Int32(node.container_main_alignment), Int32(node.container_cross_alignment),
            Int32(node.container_layout_kind), Int32(node.container_grid_columns),
            node.container_spacing, node.container_padding,
            node.preferred_width, node.preferred_height,
            rgba(node.style.fill), rgba(node.style.text), rgba(node.style.border),
            node.style.border_width, node.style.corner_radius, node.style.font_size,
        )
