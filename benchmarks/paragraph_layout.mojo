"""Four-leaf native screen: declaration updates, layout, publication and consumers.

Compilation and native drawing are excluded. Each unchanged sample averages 100
complete passes; resize samples average 100 alternating exact-width passes.
"""
from std.ffi import external_call
from moxi.box_layout import BoxLayoutContext
from moxi.native_paragraph import NativeParagraph
from moxi.geometry import Size
from paragraph_layout_policy import ParagraphFormLayout


def frame(mut context: BoxLayoutContext[NativeParagraph], width: Float32) raises -> Float32:
    context.set_paragraph(1, "Dataset", 15)
    context.set_paragraph(2, "Annual observations — temperature and rainfall across regions", 24)
    context.set_paragraph(3, "A native paragraph measured and drawn from the same retained CoreText lines.", 16)
    context.set_box(4, "Chart", 160)
    var policy = ParagraphFormLayout()
    var plan = policy.arrange(context, Size(width, 560))
    context.commit(plan)
    var snapshot = context.snapshot()
    var paints = snapshot.paint_commands()
    var ax = snapshot.accessibility()
    return snapshot.bounds(4).height + paints[0].bounds.y + ax.node(0).bounds.width


def main() raises:
    for sample in range(7):
        var context = BoxLayoutContext[NativeParagraph]()
        var start = external_call["moxi_benchmark_time_ns", Int64]()
        var checksum = frame(context, 760)
        var cold = external_call["moxi_benchmark_time_ns", Int64]() - start
        var before = context.leaf_measurements
        start = external_call["moxi_benchmark_time_ns", Int64]()
        for _ in range(100):
            checksum += frame(context, 760)
        var unchanged = external_call["moxi_benchmark_time_ns", Int64]() - start
        var unchanged_measurements = context.leaf_measurements - before
        before = context.leaf_measurements
        start = external_call["moxi_benchmark_time_ns", Int64]()
        for step in range(100):
            checksum += frame(context, Float32(380 if step % 2 == 0 else 760))
        var resize = external_call["moxi_benchmark_time_ns", Int64]() - start
        print("sample=", sample, " cold_ns=", cold, " unchanged_mean_ns=", unchanged // 100,
              " alternating_resize_mean_ns=", resize // 100,
              " unchanged_measures=", unchanged_measurements,
              " resize_measures=", context.leaf_measurements - before, " checksum=", checksum)
