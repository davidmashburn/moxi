from moxi_math import parse_math, MathLayout, MathFont, MathEditorState, MathCommand, open_math_font, close_math_font
from moxi.geometry import Point
from std.testing import assert_true, assert_equal

def main() raises:
    open_math_font("assets/math/STIXTwoMath-Regular.otf")
    var layout=MathLayout()
    var doc=parse_math('frac(root(?, scripts(x, i, 2, ?, ?)), matrix(row(1, 22), row(333, 4)))')
    layout.publish(doc)
    var snapshot=layout.snapshot
    assert_true(snapshot.width>50 and snapshot.height>80)
    # Empty radical indices and unused over/under slots do not occupy geometry.
    assert_equal(len(snapshot.regions),len(doc.nodes)-3)
    assert_true(len(snapshot.glyphs)>10)
    for stop in snapshot.carets:
        var hit=snapshot.hit(Point(stop.bounds.x,stop.bounds.y+stop.bounds.height/2))
        assert_equal(hit.id,stop.position.id)
        assert_equal(hit.offset,stop.position.offset)
        assert_true(stop.bounds.x>=0 and stop.bounds.y>=0)
        assert_true(stop.bounds.x<=snapshot.width+1)
        assert_true(stop.bounds.y+stop.bounds.height<=snapshot.height+1)
    layout.publish(doc)
    assert_equal(layout.snapshot.measured_nodes,0)
    var generation=layout.snapshot.generation
    doc.edit_text('frac(root(?, scripts(y, i, 2, ?, ?)), matrix(row(1, 22), row(333, 4)))')
    layout.publish(doc)
    assert_true(layout.snapshot.measured_nodes>0 and layout.snapshot.measured_nodes<len(doc.nodes))
    assert_equal(layout.snapshot.generation,generation+1)
    for size in range(16,65,8):
        layout.publish(doc,Float32(size))
        assert_true(layout.snapshot.width>0)
    var fixtures: List[String]=['root(?, frac(frac(x, y), root(3, z)))','scripts(frac(a, b), i, 2, n, k)','group("(", ")", matrix(row(frac(x, y), root(?, z)), row(a, b)))','sum(i, 0, n, scripts(x, ?, 2, ?, ?))','integral(x, 0, 1, frac(1, x))']
    var font=MathFont()
    for fixture in fixtures:
        var d=parse_math(fixture)
        for size in range(16,65,8):
            layout.publish(d,Float32(size))
            for region in layout.snapshot.regions:
                assert_true(region.bounds.x>=-1 and region.bounds.y>=-1)
                assert_true(region.bounds.x+region.bounds.width<=layout.snapshot.width+1)
                assert_true(region.bounds.y+region.bounds.height<=layout.snapshot.height+1)
            for glyph in layout.snapshot.glyphs:
                assert_true(glyph.x+font.metric(glyph.id,glyph.size,3)>=-1)
                assert_true(glyph.y-font.metric(glyph.id,glyph.size,1)>=-1)
                assert_true(glyph.x+font.metric(glyph.id,glyph.size,3)+font.metric(glyph.id,glyph.size,4)<=layout.snapshot.width+1)
                assert_true(glyph.y+font.metric(glyph.id,glyph.size,2)<=layout.snapshot.height+1)
    var plain=parse_math("x")
    layout.publish(plain)
    var plain_width=layout.snapshot.width
    var plain_height=layout.snapshot.height
    var plain_baseline=layout.snapshot.baseline
    var empty_scripts=parse_math("scripts(x, ?, ?, ?, ?)")
    layout.publish(empty_scripts)
    assert_equal(len(layout.snapshot.regions),2)
    assert_equal(layout.snapshot.width,plain_width)
    assert_equal(layout.snapshot.height,plain_height)
    assert_equal(layout.snapshot.baseline,plain_baseline)
    var script=MathEditorState("scripts(x, ?, 2, ?, ?)")
    layout.publish(script.document,32,script.caret.id)
    assert_equal(len(layout.snapshot.regions),3)
    var compact_height=layout.snapshot.height
    # The model still visits every hole, revealing just the current optional slot.
    var script_slots: List[Int]=[1,3,4]
    for slot in script_slots:
        script.command(MathCommand.NEXT_HOLE)
        assert_equal(script.caret.id,script.document.nodes[script.document.nodes[script.document.root].children[slot]].id)
        var generation=layout.snapshot.generation
        layout.publish(script.document,32,script.caret.id)
        assert_equal(layout.snapshot.generation,generation+1)
        assert_equal(len(layout.snapshot.regions),4)
        var focused=layout.snapshot.caret(script.caret)
        assert_true(focused.width>0 and focused.height>9)
        var hit=layout.snapshot.hit(Point(focused.x,focused.y+focused.height/2))
        assert_equal(hit.id,script.caret.id)
        layout.publish(script.document,32,script.caret.id)
        assert_equal(layout.snapshot.measured_nodes,0)
    script.focus(script.document.nodes[script.document.root].children[0])
    layout.publish(script.document,32,script.caret.id)
    assert_equal(len(layout.snapshot.regions),3)
    assert_equal(layout.snapshot.height,compact_height)
    assert_equal(layout.snapshot.measured_nodes,0)
    # Identical notation shares cached measurements until only one subtree is focused.
    var repeated=MathEditorState("row(scripts(x, ?, ?, ?, ?), scripts(x, ?, ?, ?, ?))")
    layout.publish(repeated.document,32,repeated.caret.id)
    assert_equal(len(layout.snapshot.regions),5)
    var repeated_children=repeated.document.nodes[repeated.document.root].children.copy()
    for child in repeated_children:
        repeated.focus(repeated.document.nodes[child].children[1])
        layout.publish(repeated.document,32,repeated.caret.id)
        assert_equal(len(layout.snapshot.regions),6)
        var holes=0
        for region in layout.snapshot.regions:
            if region.label=="empty slot":
                holes+=1
                assert_equal(region.id,repeated.caret.id)
        assert_equal(holes,1)
    var radical=MathEditorState("root(?, x)")
    radical.focus(radical.document.nodes[radical.document.root].children[1])
    layout.publish(radical.document,32,radical.caret.id)
    assert_equal(len(layout.snapshot.regions),2)
    var radical_width=layout.snapshot.width
    radical.command(MathCommand.NEXT_HOLE)
    layout.publish(radical.document,32,radical.caret.id)
    assert_equal(len(layout.snapshot.regions),3)
    assert_true(layout.snapshot.width>radical_width)
    var index_caret=layout.snapshot.caret(radical.caret)
    assert_true(index_caret.height>9)
    assert_equal(layout.snapshot.hit(Point(index_caret.x,index_caret.y+index_caret.height/2)).id,radical.caret.id)
    close_math_font()
    print("PASS native MATH geometry, caret hits, bounds, cache, font sizes")
