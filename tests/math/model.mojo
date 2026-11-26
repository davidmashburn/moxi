from moxi_math import MathDocument, MathKind, parse_math

def main() raises:
    var sources: List[String] = ["frac(2, 4)", "root(?, frac(x, ?))", "scripts(α, i, 2, ?, ?)", 'group("(", ")", row(x, +, y))', 'matrix(row(a, b), row(c, d))', 'sum(i, 0, n, fn("sin", x))', 'integral(x, 0, 1, x)', 'error("frac(x,\\n")', '"a\\\"b"', 'row(x, +, ?)', "root(empty(), x)", "scripts(x, empty(), ?, ?, empty())"]
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
    var optional=parse_math("scripts(x, ?, 2, ?, ?)")
    assert_true(optional.is_optional_slot(optional.root,1))
    assert_true(not optional.is_optional_slot(optional.root,0))
    assert_true(not optional.is_optional_slot(-1,0))
    assert_true(not optional.is_optional_slot(optional.root,5))
    assert_true(optional.slot_exists(optional.root,0))
    assert_true(not optional.slot_exists(optional.root,1))
    assert_true(optional.slot_exists(optional.root,2))
    var optional_id=optional.nodes[optional.nodes[optional.root].children[1]].id
    var empty=optional.create_optional_slot(optional.root,1)
    assert_equal(optional.nodes[empty].id,optional_id)
    assert_true(optional.nodes[empty].kind==MathKind.HOLE)
    assert_true(optional.nodes[empty].authored_empty)
    assert_true(optional.slot_exists(optional.root,1))
    assert_equal(optional.create_optional_slot(optional.root,1),empty)
    assert_equal(optional.text(),"scripts(x, empty(), 2, ?, ?)")
    var restored=parse_math(optional.text())
    assert_true(restored.nodes[restored.nodes[restored.root].children[1]].authored_empty)
    assert_true(restored.slot_exists(restored.root,1))
    assert_true(not restored.slot_exists(restored.root,3))
    var cloned=MathDocument()
    cloned.root=cloned.clone_from(optional,optional.root)
    cloned.compact()
    assert_equal(cloned.text(),optional.text())
    assert_true(cloned.slot_exists(cloned.root,1))
    var rejected_slot=False
    try:
        _=optional.create_optional_slot(optional.root,0)
    except:
        rejected_slot=True
    assert_true(rejected_slot)
    rejected_slot=False
    try:
        _=optional.create_optional_slot(optional.root,2)
    except:
        rejected_slot=True
    assert_true(rejected_slot)
    optional.nodes[empty].authored_empty=False
    assert_true(not optional.slot_exists(optional.root,1))
    var radical=parse_math("root(?, ?)")
    assert_true(not radical.slot_exists(radical.root,0))
    assert_true(radical.slot_exists(radical.root,1))
    _=radical.create_optional_slot(radical.root,0)
    assert_equal(radical.text(),"root(empty(), ?)")
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
