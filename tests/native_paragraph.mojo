"""Native paragraph geometry, pixel handoff and custom Mojo policy acceptance."""
from std.ffi import external_call
from moxi.box_layout import BoxLayoutContext, GeometrySnapshot
from moxi.native_paragraph import NativeParagraph, draw_box_snapshot
from moxi.geometry import Rect, Size
from moxi.macos import MacOSRenderer
from moxi.testing import test_check
from moxi.retained_layout import RetainedLayout, RetainedStyle, COLUMN, LEAF, FIXED
from moxi.retained_leaf import declare_leaf, RetainedPresentation
from moxi.recipes import badge
from moxi.view_node import ViewNode, LABEL_KIND
from moxi.frame import SurfaceMetrics
from moxi.native_frame import NativeFrameRenderer
from moxi.backend import BACKEND_MACOS_APPKIT
from paragraph_layout_policy import ParagraphFormLayout


def detached_snapshot() raises -> GeometrySnapshot[NativeParagraph]:
    # No context, measurement token, or placement plan survives this call.
    var context = BoxLayoutContext[NativeParagraph]()
    context.set_paragraph(1, "Snapshot owns this paragraph after its context is gone.", 18)
    var measured = context.measure(1, 230)
    var plan = context.plan(Size(800, 700))
    plan.place(measured, Rect(24, 24, 230, measured.metrics.size.height))
    context.commit(plan)
    return context.snapshot()


def retained_badge_presentation() raises:
    var tree = RetainedLayout()
    tree.set_region(1, RetainedStyle(COLUMN, padding=24, align=1))
    var tag = badge(2, "Theme: Light", 24, True)
    var allocation = RetainedStyle(LEAF, width_kind=FIXED, width=120,
        height_kind=FIXED, height=24)
    var renderer = MacOSRenderer()
    var frame_renderer = NativeFrameRenderer[BACKEND_MACOS_APPKIT]()
    for fixture in range(2):
        if fixture == 0:
            declare_leaf(tree, tag, allocation)
        else:
            # A badge supplied to an existing paragraph snapshot must also
            # keep its centered control text instead of binding the paragraph.
            tree.set_paragraph(2, tag.text, tag.style.font_size, allocation)
        tree.children(1, [2])
        var snapshot = tree.layout(1, Size(320,160))
        var presentation = RetainedPresentation(snapshot, [tag])
        test_check(presentation.commands[0].badge_label)
        var packet = presentation.packet(SurfaceMetrics(Size(320,160)))
        test_check(packet.commands[0].badge_label)
        test_check(len(packet.resources) == 0)
        renderer.begin_frame()
        presentation.draw_commands(renderer)
        renderer.update_accessibility(presentation.accessibility())
        renderer.end_frame()
        test_check(external_call["moxi_test_retained_badge_pixels", Int32](Int32(0), Int32(fixture)) == 1)
        frame_renderer.bind_resources(snapshot)
        frame_renderer.render(packet)
        test_check(external_call["moxi_test_retained_badge_pixels", Int32](Int32(0), Int32(fixture)) == 1)

    # Replacing the badge with an ordinary wrapping label restores the exact
    # measured paragraph payload, and the canvas still matches its reference.
    var label = ViewNode(LABEL_KIND, 2,
        "Ordinary retained labels draw their measured paragraph. 日本語.", 80)
    declare_leaf(tree, label, RetainedStyle(LEAF, width_kind=FIXED, width=230,
        height_kind=FIXED, height=80))
    var ordinary_snapshot = tree.layout(1, Size(320,160))
    var ordinary = RetainedPresentation(ordinary_snapshot, [label])
    test_check(not ordinary.commands[0].badge_label)
    var ordinary_packet = ordinary.packet(SurfaceMetrics(Size(320,160)))
    test_check(len(ordinary_packet.resources) == 1)
    renderer.begin_frame()
    ordinary.draw_commands(renderer)
    renderer.update_accessibility(ordinary.accessibility())
    renderer.end_frame()
    var output = ordinary_snapshot.output(2)
    test_check(external_call["moxi_test_paragraph_geometry", Int32](Int32(0), Int32(2),
        output.rect.x, output.rect.y, output.rect.width, output.rect.height,
        output.paragraph._storage[].handle) == 1)
    test_check(external_call["moxi_test_paragraph_pixels", Int32](Int32(0)) == 1)
    frame_renderer.bind_resources(ordinary_snapshot)
    frame_renderer.render(ordinary_packet)
    test_check(external_call["moxi_test_paragraph_pixels", Int32](Int32(0)) == 1)


def main() raises:
    external_call["moxi_test_paragraph_host", NoneType]()
    retained_badge_presentation()
    var text = String("Measured and drawn with the same CoreText paragraph. Café, 日本語, العربية.")
    var source = text.as_c_string_span()
    var paragraph = NativeParagraph.create(text, 18, 230, 0)
    test_check(paragraph.line_count() > 1)
    test_check(external_call["moxi_test_paragraph_reference", Int32](paragraph._storage[].handle, source.ptr(), Float32(18), Float32(230)) == 1)
    test_check(NativeParagraph.create("", 18, 100, 0).line_count() == 1)
    test_check(NativeParagraph.create("a\n", 18, 100, 0).line_count() == 2)
    test_check(NativeParagraph.create("a\n\nb", 18, 100, 0).line_count() == 3)
    test_check(NativeParagraph.create("a\r\nb", 18, 100, 0).line_count() == 2)
    test_check(NativeParagraph.create("🙂", 18, 0, 0).line_count() == 1)
    var rejected = False
    try:
        _ = NativeParagraph.create("a\x00b", 18, 100, 0)
    except:
        rejected = True
    test_check(rejected)
    # A real native wrapping threshold, keeping fractional proposals distinct.
    var transition = False
    var previous = NativeParagraph.create("MMMM MMMM", 18, 1, 0).line_count()
    for step in range(5, 600):
        var width = Float32(step) / 4
        var lines = NativeParagraph.create("MMMM MMMM", 18, width, 0).line_count()
        if lines != previous:
            transition = True
            test_check(NativeParagraph.create("MMMM MMMM", 18, width - 0.25, 0).line_count() != lines)
            break
        previous = lines
    test_check(transition)
    var context = BoxLayoutContext[NativeParagraph]()
    context.set_paragraph(1, text, 18)
    var measured = context.measure(1, 230)
    var plan = context.plan(Size(800, 700))
    plan.place(measured, Rect(24, 24, 230, measured.metrics.size.height))
    context.commit(plan)
    var saved = context.snapshot()
    var renderer = MacOSRenderer()
    renderer.begin_frame()
    draw_box_snapshot(renderer, saved)
    renderer.update_accessibility(saved.accessibility())
    renderer.end_frame()
    test_check(external_call["moxi_test_paragraph_geometry", Int32](Int32(0), Int32(1), Float32(24), Float32(24), Float32(230), measured.metrics.size.height, measured._payload._storage[].handle) == 1)
    test_check(external_call["moxi_test_paragraph_pixels", Int32](Int32(0)) == 1)
    # Evict every cached width, replace content and retire the context's child.
    # The older snapshot must still draw its original paragraph correctly.
    for width in range(100, 108):
        _ = context.measure(1, Float32(width))
    context.set_paragraph(1, "Replacement", 24)
    context.remove(1)
    var empty = context.plan(Size(800, 700))
    context.commit(empty)
    renderer.begin_frame()
    draw_box_snapshot(renderer, saved)
    renderer.update_accessibility(saved.accessibility())
    renderer.end_frame()
    test_check(external_call["moxi_test_paragraph_pixels", Int32](Int32(0)) == 1)
    test_check(external_call["moxi_test_paragraph_slot_lifetime", Int32]() == 1)
    var detached = detached_snapshot()
    renderer.begin_frame()
    draw_box_snapshot(renderer, detached)
    renderer.update_accessibility(detached.accessibility())
    renderer.end_frame()
    test_check(external_call["moxi_test_paragraph_pixels", Int32](Int32(0)) == 1)
    # Compile and exercise the same author policy used by the live example.
    context.set_paragraph(1, "Dataset", 14)
    context.set_paragraph(2, text, 23)
    context.set_paragraph(3, "Summary information wraps and changes the available chart height.", 16)
    context.set_box(4, "Chart", 160)
    var policy = ParagraphFormLayout()
    var wide = policy.arrange(context, Size(760, 600))
    var before_commit = context.leaf_measurements
    context.commit(wide)
    test_check(context.leaf_measurements == before_commit)
    var wide_snapshot = context.snapshot()
    var left = wide_snapshot.bounds(1)
    var right = wide_snapshot.bounds(2)
    var label = context.measure(1, left.width)
    var value = context.measure(2, right.width)
    test_check(abs(left.y + label.metrics.first_baseline - right.y - value.metrics.first_baseline) < 0.01)
    var repeated = policy.arrange(context, Size(760, 600))
    context.commit(repeated)
    test_check(context.leaf_measurements == before_commit)
    var narrow = policy.arrange(context, Size(380, 600))
    context.commit(narrow)
    test_check(context.snapshot().bounds(2).height > wide_snapshot.bounds(2).height)
    test_check(context.snapshot().bounds(4).height < wide_snapshot.bounds(4).height)
    var chart_before = context.snapshot().bounds(4).height
    context.remove(3)
    policy.summary = False
    var without_summary = policy.arrange(context, Size(380, 600))
    context.commit(without_summary)
    test_check(context.snapshot().bounds(4).height > chart_before)
    # Same geometry cannot make a replaced native drawing payload current.
    var old_payload = context.measure(1, left.width)._payload
    context.set_paragraph(1, "Changed", 14)
    var new_payload = context.measure(1, left.width)._payload
    test_check(old_payload._storage[].handle != new_payload._storage[].handle)
    print("Moxi native paragraph layout passed")
