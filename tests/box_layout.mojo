"""Portable failure-path tests for the provisional box publication protocol."""
from moxi.box_layout import BoxLayoutContext, BoxMetrics, ParagraphPayload
from moxi.geometry import Point, Rect, Size
from moxi.testing import test_check


struct FixtureParagraph(ParagraphPayload):
    var _metrics: BoxMetrics

    def __init__(out self):
        self._metrics = BoxMetrics(Size(0, 0))

    @staticmethod
    def create(text: String, font_size: Float32, width: Float32, direction: Int) raises -> Self:
        var result = Self()
        var capacity = max(1, Int(width / 5))
        var lines = max(1, (text.count_codepoints() + capacity - 1) // capacity)
        result._metrics = BoxMetrics(Size(width, Float32(lines) * font_size), font_size * 0.75, (Float32(lines) - 0.25) * font_size)
        return result

    def metrics(self) -> BoxMetrics:
        return self._metrics


def main() raises:
    var context = BoxLayoutContext[FixtureParagraph]()
    context.set_paragraph(1, "abcdefgh", 10)
    var wide = context.measure(1, 40)
    var narrow = context.measure(1, 39.99)
    test_check(wide.metrics.size.height == 10)
    test_check(narrow.metrics.size.height == 20)
    _ = context.measure(1, 40)
    test_check(context.leaf_measurements == 2)
    var plan = context.plan(Size(100, 100))
    plan.place(wide, Rect(5, 6, 40, 10))
    context.commit(plan)
    var saved = context.snapshot()
    test_check(context.leaf_measurements == 2)
    test_check(saved.bounds(1).y == 6)
    test_check(saved.hit_test(Point(6, 7)) == 1)
    var paints = saved.paint_commands()
    var ax = saved.accessibility()
    test_check(paints[0].bounds.width == ax.node(0).bounds.width)
    test_check(paints[0].bounds.y == ax.node(0).bounds.y)
    # Re-publication of a superseded transaction must fail without a new generation.
    var rejected = False
    try:
        context.commit(plan)
    except:
        rejected = True
    test_check(rejected and context.snapshot().generation == 1)
    # Final width must match the exact measurement, not its rounded equivalent.
    var wrong = context.plan(Size(100, 100))
    wrong.place(wide, Rect(0, 0, 39.99, 10))
    rejected = False
    try:
        context.commit(wrong)
    except:
        rejected = True
    test_check(rejected and context.snapshot().generation == 1)
    # Same-sized replacement invalidates drawing content, not just geometry.
    context.set_paragraph(1, "ijklmnop", 10)
    var stale = context.plan(Size(100, 100))
    stale.place(wide, Rect(5, 6, 40, 10))
    rejected = False
    try:
        context.commit(stale)
    except:
        rejected = True
    test_check(rejected)
    var fresh = context.measure(1, 40)
    var next = context.plan(Size(100, 100))
    next.place(fresh, Rect(5, 6, 40, 10))
    context.commit(next)
    test_check(context.snapshot().paint_commands()[0].text == "ijklmnop")
    test_check(saved.paint_commands()[0].text == "abcdefgh")
    # Font, environment and remount invalidate even at an unchanged offered width.
    context.set_paragraph(1, "ijklmnop", 20)
    test_check(context.measure(1, 40).metrics.size.height == 20)
    var old_measurements = context.leaf_measurements
    context.invalidate_environment()
    _ = context.measure(1, 40)
    test_check(context.leaf_measurements == old_measurements + 1)
    context.remove(1)
    context.set_paragraph(1, "ijklmnop", 10)
    var remount = context.plan(Size(100, 100))
    remount.place(fresh, Rect(5, 6, 40, 10))
    rejected = False
    try:
        context.commit(remount)
    except:
        rejected = True
    test_check(rejected)
    # Identical keys and declaration counters in a different owner are foreign.
    var other = BoxLayoutContext[FixtureParagraph]()
    other.set_paragraph(1, "ijklmnop", 10)
    var foreign = other.plan(Size(100, 100))
    foreign.place(context.measure(1, 40), Rect(0, 0, 40, 10))
    rejected = False
    try:
        other.commit(foreign)
    except:
        rejected = True
    test_check(rejected and other.snapshot().generation == 0)
    # Duplicate and missing children fail atomically.
    context.set_box(2, "Chart", 30)
    var duplicate = context.plan(Size(100, 100))
    var measured = context.measure(1, 40)
    duplicate.place(measured, Rect(0, 0, 40, 10))
    duplicate.place(measured, Rect(0, 10, 40, 10))
    rejected = False
    try:
        context.commit(duplicate)
    except:
        rejected = True
    test_check(rejected)
    var missing = context.plan(Size(100, 100))
    rejected = False
    try:
        context.commit(missing)
    except:
        rejected = True
    test_check(rejected)
    # Cache eviction is bounded and does not retire saved snapshots.
    for width in range(100):
        _ = context.measure(1, Float32(width))
    test_check(len(context._leaves[0].cache) == 2)
    test_check(saved.paint_commands()[0].text == "abcdefgh")
    # Overflow uses one clipped geometry across paint, input and AX.
    var clipped = context.plan(Size(30, 15))
    clipped.place(context.measure(1, 40), Rect(5, 6, 40, 10))
    clipped.place(context.measure(2, 30), Rect(0, 20, 30, 30))
    context.commit(clipped)
    var snapshot = context.snapshot()
    test_check(snapshot.hit_test(Point(31, 7)) == -1)
    test_check(snapshot.accessibility().count() == 1)
    test_check(snapshot.accessibility().node(0).bounds.width == 25)
    test_check(snapshot.paint_commands()[0].clip_bounds.width == 25)
    # Real zero width is not the unbounded sentinel of legacy text APIs.
    test_check(context.measure(1, 0).metrics.size.width == 0)
    rejected = False
    try:
        _ = context.measure(1, -1)
    except:
        rejected = True
    test_check(rejected)
    print("Moxi box layout contracts passed")
