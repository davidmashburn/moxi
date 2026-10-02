"""Native integration contracts for the optional retained layout adapter."""
from moxi.retained_layout import RetainedLayout, RetainedStyle, RetainedTrack, RetainedSnapshot, COLUMN, ROW, WRAP, GRID, STACK, LEAF, CONTENT, FIXED
from moxi.geometry import Point, Size
from std.testing import assert_true, assert_equal, assert_almost_equal


def detached() raises -> RetainedSnapshot:
    var tree = RetainedLayout()
    tree.set_region(1, RetainedStyle(gap=8, padding=12))
    tree.set_paragraph(2, "A retained paragraph survives its entire native tree", 18)
    tree.children(1, [2])
    return tree.layout(1, Size(240, 160))


def main() raises:
    var tree = RetainedLayout()
    tree.set_region(1, RetainedStyle(padding=12, gap=8))
    tree.set_region(2, RetainedStyle(ROW, align=4, gap=8))
    tree.set_paragraph(3, "Dataset", 15)
    tree.set_paragraph(4, "Annual observations — rainfall across regions", 24,
                       RetainedStyle(LEAF, grow=1, shrink=1))
    tree.set_paragraph(5, "Summary with Japanese 日本語 and Arabic العربية", 16)
    tree.set_box(6, RetainedStyle(LEAF, grow=1, min_height=80), "Chart")
    tree.children(1, [2,5,6])
    tree.children(2, [3,4])
    var wide = tree.layout(1, Size(700, 400))
    var small = wide.output(3)
    var large = wide.output(4)
    assert_almost_equal(small.rect.y + small.paragraph.metrics().first_baseline,
                        large.rect.y + large.paragraph.metrics().first_baseline)
    assert_almost_equal(large.rect.width, large.paragraph.metrics().size.width)
    var measured = tree.measurements()
    var changed = tree.mutations()
    var same = tree.layout(1, Size(700, 400))
    assert_equal(tree.measurements(), measured)
    assert_equal(tree.mutations(), changed)
    assert_equal(same.generation, wide.generation)
    # Identical declarations stay inert even though the root's computed style
    # carries its parent's exact allocation.
    tree.set_region(1, RetainedStyle(padding=12, gap=8))
    tree.set_paragraph(4, "Annual observations — rainfall across regions", 24,
                       RetainedStyle(LEAF, grow=1, shrink=1))
    _ = tree.layout(1, Size(700,400))
    assert_equal(tree.measurements(), measured)
    assert_equal(tree.mutations(), changed)
    var narrow = tree.layout(1, Size(330, 400))
    assert_true(narrow.output(4).paragraph.line_count() > wide.output(4).paragraph.line_count())
    assert_true(narrow.bounds(6).height < wide.bounds(6).height)
    var point = Point(narrow.bounds(6).x + 1, narrow.bounds(6).y + 1)
    assert_equal(narrow.hit_test(point), 6)
    var ax = narrow.accessibility()
    assert_equal(len(ax.nodes), narrow.count())
    tree.remove(5)
    try:
        _ = tree.layout(1, Size(-1, 400))
        assert_true(False)
    except:
        pass
    assert_equal(tree.snapshot().count(), narrow.count() - 1)
    assert_equal(narrow.output(5).key, 5)
    var after = tree.layout(1, Size(330,400))
    assert_true(after.bounds(6).height > narrow.bounds(6).height)
    tree.invalidate_environment()
    measured = tree.measurements()
    _ = tree.layout(1, Size(330,400))
    assert_true(tree.measurements() > measured)
    var retained = detached()
    assert_true(retained.output(2).paragraph.line_count() > 1)
    assert_true(retained.output(2).paragraph.metrics().size.height > 0)
    var grid = RetainedLayout()
    grid.set_region(1, RetainedStyle(GRID, gap=10))
    grid.tracks(1, [RetainedTrack.fraction(1), RetainedTrack.fraction(2)])
    grid.set_paragraph(2, "First", 16, RetainedStyle(LEAF, column=1, row=1))
    grid.set_paragraph(3, "Second", 16, RetainedStyle(LEAF, column=2, row=1))
    grid.set_box(4, RetainedStyle(LEAF, column=1, column_span=2, row=2, height_kind=FIXED, height=30))
    grid.children(1,[2,3,4])
    var g = grid.layout(1,Size(310,120))
    assert_almost_equal(g.bounds(2).width, Float32(100))
    assert_almost_equal(g.bounds(3).width, Float32(200))
    assert_almost_equal(g.bounds(4).width, Float32(310))
    print("Retained layout native contracts passed")
