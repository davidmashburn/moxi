from moxi_math import MathDocument, MathKind, parse_math

def main() raises:
    var sources: List[String] = ["frac(2, 4)", "root(?, frac(x, ?))", "scripts(α, i, 2, ?, ?)", 'group("(", ")", row(x, +, y))', 'matrix(row(a, b), row(c, d))', 'sum(i, 0, n, fn("sin", x))', 'integral(x, 0, 1, x)', 'error("frac(x,\\n")', '"a\\\"b"', 'row(x, +, ?)']
    for source in sources:
        var doc = parse_math(source)
        doc.validate()
        assert_true(doc.nodes[doc.root].kind != MathKind.ERROR or source.startswith("error"))
        assert_equal(doc.text(), source)
        assert_equal(parse_math(doc.text()).text(), source)
    var malformed = parse_math("frac(x,")
    assert_equal(malformed.nodes[malformed.root].kind.value, MathKind.ERROR.value)
    assert_equal(parse_math(malformed.text()).text(), malformed.text())
    var doc = parse_math("frac(x, y)")
    var id = doc.nodes[doc.nodes[doc.root].children[0]].id
    doc.edit_text("frac(x, z)")
    assert_equal(doc.nodes[doc.nodes[doc.root].children[0]].id, id)
    var row=parse_math("row(a, b, c)")
    var b=row.nodes[row.nodes[row.root].children[1]].id
    var c=row.nodes[row.nodes[row.root].children[2]].id
    row.edit_text("row(a, x, b, c)")
    assert_equal(row.nodes[row.nodes[row.root].children[2]].id,b)
    assert_equal(row.nodes[row.nodes[row.root].children[3]].id,c)
    row.validate()
    var huge=String("")
    for _ in range(4097):
        huge+="x"
    var bounded=parse_math(huge)
    assert_equal(bounded.nodes[bounded.root].kind.value,MathKind.ERROR.value)
    assert_equal(bounded.nodes[bounded.root].text,huge)
    var rejected=False
    try:
        _ = parse_math("a\x00b")
    except:
        rejected=True
    assert_true(rejected)
    print("PASS notation roundtrips, literal errors, identity")

from std.testing import assert_equal, assert_true
