from moxi_math import parse_math, MathLayout, MathFont, open_math_font, close_math_font
from moxi.geometry import Point
from std.testing import assert_true, assert_equal

def main() raises:
    open_math_font("assets/math/STIXTwoMath-Regular.otf")
    var layout=MathLayout()
    var doc=parse_math('frac(root(?, scripts(x, i, 2, ?, ?)), matrix(row(1, 22), row(333, 4)))')
    layout.publish(doc)
    var snapshot=layout.snapshot
    assert_true(snapshot.width>50 and snapshot.height>80)
    assert_equal(len(snapshot.regions),len(doc.nodes))
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
            for glyph in layout.snapshot.glyphs:
                assert_true(glyph.x+font.metric(glyph.id,glyph.size,3)>=-1)
                assert_true(glyph.y-font.metric(glyph.id,glyph.size,1)>=-1)
                assert_true(glyph.x+font.metric(glyph.id,glyph.size,3)+font.metric(glyph.id,glyph.size,4)<=layout.snapshot.width+1)
                assert_true(glyph.y+font.metric(glyph.id,glyph.size,2)<=layout.snapshot.height+1)
    close_math_font()
    print("PASS native MATH geometry, caret hits, bounds, cache, font sizes")
