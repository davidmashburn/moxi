"""Native integration contracts for the optional retained layout adapter."""
from moxi.retained_layout import RetainedLayout, RetainedStyle, RetainedTrack, RetainedSnapshot, RetainedPlacement, COLUMN, ROW, WRAP, GRID, STACK, LEAF, CONTENT, FIXED
from moxi.geometry import Point, Size, Rect
from std.collections import List
from moxi.content_layout import AxisSize, LayoutStyle, LayoutNode, LayoutTree
from std.testing import assert_true, assert_equal, assert_almost_equal


def detached() raises -> RetainedSnapshot:
    var tree = RetainedLayout()
    tree.set_region(1, RetainedStyle(gap=8, padding=12))
    tree.set_paragraph(2, "A retained paragraph survives its entire native tree", 18)
    tree.children(1, [2])
    return tree.layout(1, Size(240, 160))


def compare_geometry(legacy: LayoutTree, retained: RetainedSnapshot) raises:
    for index in range(legacy.count()):
        var expected = legacy.bounds(index)
        var actual = retained.bounds(index+1)
        assert_almost_equal(actual.x,expected.x,atol=0.001)
        assert_almost_equal(actual.y,expected.y,atol=0.001)
        assert_almost_equal(actual.width,expected.width,atol=0.001)
        assert_almost_equal(actual.height,expected.height,atol=0.001)


def shared_geometry_profile() raises:
    # Only compare shared geometry: the legacy approximate text provider is not
    # a reference for CoreText paragraph metrics or the new grid/wrap profile.
    var nodes = List[LayoutNode]()
    nodes.append(LayoutNode(0,-1,LayoutStyle(AxisSize.fill(),AxisSize.fill(),axis=1,gap=10),True))
    nodes.append(LayoutNode(1,0,LayoutStyle(AxisSize.fill(1),AxisSize.fill(),max_width=60)))
    nodes.append(LayoutNode(2,0,LayoutStyle(AxisSize.fill(2),AxisSize.fill())))
    var legacy = LayoutTree()
    legacy.sync(nodes^)
    var retained = RetainedLayout()
    retained.set_region(1,RetainedStyle(ROW,gap=10))
    retained.set_box(2,RetainedStyle(LEAF,grow=1,max_width=60))
    retained.set_box(3,RetainedStyle(LEAF,grow=2))
    retained.children(1,[2,3])
    for width in range(100,501,7):
        legacy.layout(Rect(0,0,Float32(width),40))
        compare_geometry(legacy,retained.layout(1,Size(Float32(width),40)))
    nodes = List[LayoutNode]()
    nodes.append(LayoutNode(0,-1,LayoutStyle(AxisSize.fill(),AxisSize.fill(),padding=10,gap=5),True))
    nodes.append(LayoutNode(1,0,LayoutStyle(AxisSize.fill(),AxisSize.fixed(20))))
    nodes.append(LayoutNode(2,0,LayoutStyle(AxisSize.fill(),AxisSize.fill(),min_height=40)))
    legacy.sync(nodes^)
    retained = RetainedLayout()
    retained.set_region(1,RetainedStyle(COLUMN,padding=10,gap=5))
    retained.set_box(2,RetainedStyle(LEAF,height_kind=FIXED,height=20))
    retained.set_box(3,RetainedStyle(LEAF,grow=1,min_height=40))
    retained.children(1,[2,3])
    for height in range(100,501,7):
        legacy.layout(Rect(0,0,300,Float32(height)))
        compare_geometry(legacy,retained.layout(1,Size(300,Float32(height))))


def main() raises:
    shared_geometry_profile()
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
    assert_equal(narrow.hit_test(Point(-1,-1)),-1)
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
    var staged = grid.stage(1, Size(400,120))
    assert_equal(grid.snapshot().generation, g.generation)
    grid.place([RetainedPlacement(4, Rect(5,60,180,30))])
    var rejected = False
    try:
        _ = grid.commit(staged)
    except:
        rejected = True
    assert_true(rejected)
    assert_equal(grid.snapshot().generation, g.generation)
    staged = grid.stage(1, Size(400,120))
    var final = grid.commit(staged)
    assert_almost_equal(final.bounds(4).width, Float32(180))
    assert_almost_equal(final.bounds(4).x, Float32(5))
    print("Retained layout native contracts passed")
