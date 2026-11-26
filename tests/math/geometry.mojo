from moxi_math import parse_math, MathLayout, MathFont, MathPosition, MathKind, open_math_font, close_math_font
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
    assert_equal(layout.snapshot.width,plain_width+32*.16)
    assert_equal(layout.snapshot.height,plain_height)
    assert_equal(layout.snapshot.baseline,plain_baseline)
    var script=parse_math("scripts(x, ?, 2, ?, ?)")
    var absent=script.nodes[script.root].children[1]
    layout.publish(script,32,script.nodes[absent].id)
    assert_equal(len(layout.snapshot.regions),3)
    var compact_height=layout.snapshot.height
    var focus_generation=layout.snapshot.generation
    layout.publish(script,32,script.nodes[script.root].id)
    assert_equal(layout.snapshot.generation,focus_generation)
    assert_equal(len(layout.snapshot.regions),3)
    assert_equal(layout.snapshot.height,compact_height)
    assert_equal(layout.snapshot.measured_nodes,0)
    for stop in layout.snapshot.carets:
        assert_true(stop.position.id!=script.nodes[absent].id)
    _=script.create_optional_slot(script.root,1)
    layout.publish(script)
    assert_equal(len(layout.snapshot.regions),4)
    assert_true(layout.snapshot.height>compact_height)
    var authored_bounds=layout.snapshot.bounds(script.nodes[absent].id)
    layout.publish(script,32,script.nodes[script.nodes[script.root].children[0]].id)
    assert_equal(layout.snapshot.measured_nodes,0)
    assert_equal(layout.snapshot.bounds(script.nodes[absent].id).height,authored_bounds.height)
    var restored=parse_math(script.text())
    layout.publish(restored)
    assert_equal(len(layout.snapshot.regions),4)
    # Repeated notation shares measurements while presence remains per subtree.
    var repeated=parse_math("row(scripts(x, ?, ?, ?, ?), scripts(x, ?, ?, ?, ?))")
    var repeated_children=repeated.nodes[repeated.root].children.copy()
    _=repeated.create_optional_slot(repeated_children[1],1)
    layout.publish(repeated)
    assert_equal(len(layout.snapshot.regions),6)
    var radical=parse_math("root(?, x)")
    var index=radical.nodes[radical.root].children[0]
    layout.publish(radical,32,radical.nodes[index].id)
    assert_equal(len(layout.snapshot.regions),2)
    var radical_width=layout.snapshot.width
    _=radical.create_optional_slot(radical.root,0)
    layout.publish(radical)
    assert_equal(len(layout.snapshot.regions),3)
    assert_true(layout.snapshot.width>radical_width)
    var index_position=MathPosition(radical.nodes[index].id,0)
    var index_caret=layout.snapshot.caret(index_position)
    assert_true(index_caret.height>9)
    assert_equal(layout.snapshot.hit(Point(index_caret.x,index_caret.y+index_caret.height/2)).id,index_position.id)
    # A hole has one inside stop and separate before/after positions.
    var hole=parse_math("?")
    layout.publish(hole)
    assert_equal(len(layout.snapshot.carets),3)
    var hole_id=hole.nodes[hole.root].id
    var hole_offsets: List[Int]=[-1,0,-2]
    var previous_x: Float32=-1
    for offset in hole_offsets:
        var position=MathPosition(hole_id,offset)
        var bounds=layout.snapshot.caret(position)
        assert_true(bounds.x>previous_x)
        previous_x=bounds.x
        var hit=layout.snapshot.hit(Point(bounds.x,bounds.y+bounds.height/2))
        assert_equal(hit.id,position.id)
        assert_equal(hit.offset,position.offset)
    # Every structural node, including the document root and matrix rows, has edges.
    var structural: List[String]=["row()", "frac(row(a), row(b))", "root(?, x)", "scripts(x, ?, 2, ?, ?)", 'group("(", ")", x)', 'fn("sin", x)', "matrix(row(a, b), row(c, d))", "sum(i, 0, n, x)", "integral(x, 0, 1, x)"]
    for source in structural:
        var expression=parse_math(source)
        layout.publish(expression)
        for region in layout.snapshot.regions:
            var node=expression.nodes[expression.find_id(region.id)]
            if node.kind==MathKind.TOKEN or node.kind==MathKind.ERROR or node.kind==MathKind.HOLE:
                continue
            var before=layout.snapshot.caret(MathPosition(region.id,0))
            var after=layout.snapshot.caret(MathPosition(region.id,1))
            assert_equal(before.x,region.bounds.x)
            assert_equal(after.x,region.bounds.x+region.bounds.width)
            assert_true(after.x>before.x)
            for offset in range(2):
                var edge=layout.snapshot.caret(MathPosition(region.id,offset))
                var hit=layout.snapshot.hit(Point(edge.x,edge.y+edge.height/2))
                assert_equal(hit.id,region.id)
                assert_equal(hit.offset,offset)
    var matrix=parse_math("matrix(row(a, b), row(c, d))")
    layout.publish(matrix)
    var first_row=matrix.nodes[matrix.nodes[matrix.root].children[0]].id
    var second_row=matrix.nodes[matrix.nodes[matrix.root].children[1]].id
    for offset in range(2):
        var down=layout.snapshot.vertical(MathPosition(first_row,offset),1)
        assert_equal(down.id,second_row)
        assert_equal(down.offset,offset)
        var up=layout.snapshot.vertical(MathPosition(second_row,offset),-1)
        assert_equal(up.id,first_row)
        assert_equal(up.offset,offset)
    var fraction=parse_math("frac(row(a), row(b))")
    layout.publish(fraction)
    var numerator=fraction.nodes[fraction.nodes[fraction.root].children[0]].id
    var denominator=fraction.nodes[fraction.nodes[fraction.root].children[1]].id
    for offset in range(2):
        var down=layout.snapshot.vertical(MathPosition(numerator,offset),1)
        assert_equal(down.id,denominator)
        assert_equal(down.offset,offset)
        var up=layout.snapshot.vertical(MathPosition(denominator,offset),-1)
        assert_equal(up.id,numerator)
        assert_equal(up.offset,offset)
    var graphemes=parse_math('"é👩‍🔬"')
    layout.publish(graphemes)
    assert_equal(len(layout.snapshot.carets),3)
    assert_equal(layout.snapshot.carets[0].position.offset,0)
    assert_equal(layout.snapshot.carets[1].position.offset,2)
    assert_equal(layout.snapshot.carets[2].position.offset,5)
    close_math_font()
    print("PASS native MATH geometry, caret hits, bounds, cache, font sizes")
