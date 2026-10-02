"""Independent authoring exercise, compiled against the precompiled package."""
from std.testing import assert_equal, assert_true
from moxi.retained_layout import RetainedLayout, RetainedStyle, RetainedPlacement, COLUMN, LEAF, FIXED
from moxi.retained_leaf import declare_leaf, RetainedPresentation
from moxi.constraint_layout import ConstraintRegion, LinearConstraint, coordinate, PARENT_WIDTH
from moxi.collection_layout import CollectionViewport
from moxi.overlay_layout import place_overlay
from moxi.view_node import ViewNode, LABEL_KIND
from moxi.geometry import Size, Rect, Point


def main() raises:
    var tree = RetainedLayout()
    tree.set_region(1,RetainedStyle(COLUMN,padding=10))
    var label = ViewNode(LABEL_KIND,2,"An independently authored 日本語 consumer wraps this paragraph.",40)
    declare_leaf(tree,label,RetainedStyle(LEAF,width_kind=FIXED,width=180))
    tree.children(1,[2])
    var first = tree.layout(1,Size(200,200))
    assert_true(first.output(2).paragraph.metrics().size.height>label.style.font_size)
    var region = ConstraintRegion()
    region.model([2],[LinearConstraint([coordinate(2,0)],[Float64(1)],-10),
                      LinearConstraint([coordinate(2,1)],[Float64(1)],-20),
                      LinearConstraint([coordinate(2,2),PARENT_WIDTH],[Float64(1),-1],20),
                      LinearConstraint([coordinate(2,3)],[Float64(1)],-80)])
    var form = region.stage(Size(200,200))
    tree.place([RetainedPlacement(2,form.rectangles[2])])
    var staged = tree.stage(1,Size(200,200))
    var presentation = RetainedPresentation(staged.snapshot,[label])
    assert_equal(presentation.hit_test(Point(24,34)),2)
    _ = tree.commit(staged)
    region.commit(form)
    var viewport = CollectionViewport()
    viewport.sync_rows([7,9,12],[Float64(20),40,30])
    viewport.columns.sync([1,2],[Float64(80),120])
    var anchor = viewport.anchor(25)
    viewport.sync_rows([5,7,9,12],[Float64(15),20,40,30])
    assert_equal(viewport.restore(anchor,25,30),Float64(40))
    var proposal = viewport.stage(Rect(0,0,160,30),offset_y=40)
    assert_true(len(proposal.cells)>0)
    viewport.commit(proposal^)
    var popup = place_overlay(Rect(180,160,20,20),Size(90,60),Rect(0,0,200,200))
    assert_true(popup.present)
    assert_true(popup.bounds.x+popup.bounds.width<=200)
    print("Independent precompiled layout consumer passed")
