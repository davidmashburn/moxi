from moxi_math import MathEditorState, MathPosition, MathCommand, MathKind
from std.collections import List
from std.testing import assert_equal, assert_true

def check_directed_ranges() raises:
    var editor = MathEditorState("row(abcdef, frac(gh, ij), klmnop)")
    var children = editor.document.nodes[editor.document.root].children.copy()
    var first = MathPosition(editor.document.nodes[children[0]].id, 2)
    var last = MathPosition(editor.document.nodes[children[2]].id, 3)
    editor.set_caret(first)
    editor.set_caret(last, True)
    assert_true(editor.has_range_selection())
    assert_true(not editor.has_text_selection())
    assert_equal(editor.selected, -1)
    assert_equal(editor.copy_text(), "row(cdef, frac(gh, ij), klm)")
    assert_equal(len(editor.range_spans()), 3)
    editor.set_caret(first, True)
    assert_true(not editor.has_range_selection())
    editor.set_caret(last)
    editor.set_caret(first, True)
    assert_equal(editor.selection_anchor.id, last.id)
    assert_equal(editor.caret.id, first.id)
    assert_equal(editor.copy_fragment_text(), "row(cdef, frac(gh, ij), klm)")
    editor.delete()
    assert_equal(editor.document.text(), "row(ab, nop)")
    assert_equal(editor.caret.id, first.id)
    assert_equal(editor.caret.offset, 2)
    editor.command(MathCommand.UNDO)
    assert_equal(editor.copy_text(), "row(cdef, frac(gh, ij), klm)")
    assert_equal(editor.selection_anchor.id, last.id)
    editor.horizontal(1)
    assert_equal(editor.caret.id, last.id)
    assert_equal(editor.caret.offset, last.offset)
    assert_true(not editor.has_range_selection())

def check_fraction_ranges() raises:
    var editor = MathEditorState("frac(abcdef, ghijkl)")
    var children = editor.document.nodes[editor.document.root].children.copy()
    var first = MathPosition(editor.document.nodes[children[0]].id, 3)
    var last = MathPosition(editor.document.nodes[children[1]].id, 2)
    editor.set_caret(last)
    editor.set_caret(first, True)
    assert_equal(editor.copy_text(), "frac(def, gh)")
    editor.delete()
    assert_equal(editor.document.text(), "frac(abc, ijkl)")
    editor.insert("X")
    assert_equal(editor.document.text(), "frac(abcX, ijkl)")

    editor = MathEditorState("frac(abcdef, ghijkl)")
    children = editor.document.nodes[editor.document.root].children.copy()
    editor.set_caret(MathPosition(editor.document.nodes[children[0]].id, 3))
    editor.set_caret(MathPosition(editor.document.nodes[children[1]].id, 2), True)
    editor.command(MathCommand.GROUP)
    assert_equal(editor.document.text(), 'frac(row(abc, group("(", ")", frac(def, gh))), ijkl)')

def check_matrix_ranges() raises:
    var editor = MathEditorState("matrix(row(ab, cd), row(ef, gh))")
    var rows = editor.document.nodes[editor.document.root].children.copy()
    var first = editor.document.nodes[rows[0]].children[0]
    var last = editor.document.nodes[rows[1]].children[1]
    editor.set_caret(MathPosition(editor.document.nodes[first].id, 1))
    editor.set_caret(MathPosition(editor.document.nodes[last].id, 1), True)
    assert_equal(editor.copy_text(), "matrix(row(b, cd), row(ef, g))")
    editor.delete()
    assert_equal(editor.document.text(), "matrix(row(a, ?), row(?, h))")
    editor.document.validate()

def check_structural_navigation() raises:
    var editor = MathEditorState("row(a, frac(b, c))")
    var root = editor.document.root
    var children = editor.document.nodes[root].children.copy()
    var fraction = children[1]
    var slots = editor.document.nodes[fraction].children.copy()
    var stops = List[MathPosition]()
    stops.append(MathPosition(editor.document.nodes[root].id, 0))
    stops.append(MathPosition(editor.document.nodes[children[0]].id, 0))
    stops.append(MathPosition(editor.document.nodes[children[0]].id, 1))
    stops.append(MathPosition(editor.document.nodes[fraction].id, 0))
    stops.append(MathPosition(editor.document.nodes[slots[0]].id, 0))
    stops.append(MathPosition(editor.document.nodes[slots[0]].id, 1))
    stops.append(MathPosition(editor.document.nodes[slots[1]].id, 0))
    stops.append(MathPosition(editor.document.nodes[slots[1]].id, 1))
    stops.append(MathPosition(editor.document.nodes[fraction].id, 1))
    stops.append(MathPosition(editor.document.nodes[root].id, 1))
    editor.set_caret(stops[0])
    for i in range(1, len(stops)):
        editor.horizontal(1)
        assert_equal(editor.caret.id, stops[i].id)
        assert_equal(editor.caret.offset, stops[i].offset)
    for i in range(len(stops)-1):
        editor.horizontal(-1)
        var expected = stops[len(stops)-i-2]
        assert_equal(editor.caret.id, expected.id)
        assert_equal(editor.caret.offset, expected.offset)
    editor.set_caret(MathPosition(editor.document.nodes[fraction].id, 0))
    editor.set_caret(MathPosition(editor.document.nodes[fraction].id, 1), True)
    assert_equal(editor.selected, editor.document.nodes[fraction].id)
    editor.horizontal(-1, True)
    assert_equal(editor.selected, -1)
    assert_equal(editor.selection_anchor.id, editor.document.nodes[fraction].id)
    assert_equal(editor.selection_anchor.offset, 0)
    assert_equal(editor.caret.id, editor.document.nodes[slots[1]].id)
    assert_equal(editor.caret.offset, 1)

def check_boundary_only_and_hole_ranges() raises:
    var editor = MathEditorState("frac(a, b)")
    var root = editor.document.root
    var numerator = editor.document.nodes[root].children[0]
    editor.set_caret(MathPosition(editor.document.nodes[root].id, 0))
    editor.set_caret(MathPosition(editor.document.nodes[numerator].id, 0), True)
    var revision = editor.document.revision
    var history = len(editor.undo_stack)
    assert_equal(len(editor.range_spans()), 0)
    editor.delete()
    assert_equal(editor.document.text(), "frac(a, b)")
    assert_equal(editor.document.revision, revision)
    assert_equal(len(editor.undo_stack), history)
    assert_true(not editor.has_range_selection())

    var row = MathEditorState("row(a, ?, b)")
    var hole = row.document.nodes[row.document.root].children[1]
    var id = row.document.nodes[hole].id
    row.set_caret(MathPosition(id, -1))
    row.set_caret(MathPosition(id, 0), True)
    assert_equal(row.selected, id)
    assert_equal(len(row.range_spans()), 1)
    assert_equal(row.copy_text(), "?")
    row.horizontal(-1, True)
    assert_equal(row.selected, -1)
    assert_true(not row.has_range_selection())
    row.horizontal(1, True)
    assert_equal(row.selected, id)
    row.delete()
    assert_equal(row.document.text(), "row(a, b)")
    row.command(MathCommand.UNDO)
    assert_equal(row.selected, id)
    assert_equal(row.selection_anchor.offset, -1)
    assert_equal(row.caret.offset, 0)

    var optional = MathEditorState("scripts(a, ?, empty(), ?, ?)")
    hole = optional.document.nodes[optional.document.root].children[2]
    id = optional.document.nodes[hole].id
    optional.set_caret(MathPosition(id, -2))
    optional.set_caret(MathPosition(id, 0), True)
    optional.delete()
    assert_equal(optional.document.text(), "scripts(a, ?, ?, ?, ?)")

    var required = MathEditorState("frac(?, b)")
    hole = required.document.nodes[required.document.root].children[0]
    id = required.document.nodes[hole].id
    required.set_caret(MathPosition(id, -1))
    required.set_caret(MathPosition(id, 0), True)
    revision = required.document.revision
    required.delete()
    assert_equal(required.document.text(), "frac(?, b)")
    assert_equal(required.document.revision, revision)
    required.set_caret(MathPosition(id, -1))
    required.set_caret(MathPosition(id, 0), True)
    required.insert("x")
    assert_equal(required.document.text(), "frac(x, b)")

def check_optional_start_replacement() raises:
    var editor = MathEditorState("scripts(a, empty(), bc, ?, ?)")
    var slots = editor.document.nodes[editor.document.root].children.copy()
    editor.set_caret(MathPosition(editor.document.nodes[slots[1]].id, 0))
    editor.set_caret(MathPosition(editor.document.nodes[slots[2]].id, 1), True)
    editor.insert("X")
    assert_equal(editor.document.text(), "scripts(a, X, c, ?, ?)")

    editor = MathEditorState("scripts(a, empty(), bc, ?, ?)")
    slots = editor.document.nodes[editor.document.root].children.copy()
    editor.set_caret(MathPosition(editor.document.nodes[slots[1]].id, 0))
    editor.set_caret(MathPosition(editor.document.nodes[slots[2]].id, 1), True)
    editor.paste("frac(x, y)")
    assert_equal(editor.document.text(), "scripts(a, frac(x, y), c, ?, ?)")

    editor = MathEditorState("scripts(a, empty(), bc, ?, ?)")
    slots = editor.document.nodes[editor.document.root].children.copy()
    editor.set_caret(MathPosition(editor.document.nodes[slots[1]].id, 0))
    editor.set_caret(MathPosition(editor.document.nodes[slots[2]].id, 1), True)
    editor.command(MathCommand.GROUP)
    assert_equal(editor.document.text(), 'scripts(a, group("(", ")", scripts(?, empty(), b, ?, ?)), c, ?, ?)')

    editor = MathEditorState("scripts(a, row(x, y), bc, ?, ?)")
    slots = editor.document.nodes[editor.document.root].children.copy()
    var first = editor.document.nodes[slots[1]].children[0]
    editor.set_caret(MathPosition(editor.document.nodes[first].id, 0))
    editor.set_caret(MathPosition(editor.document.nodes[slots[2]].id, 1), True)
    editor.insert("X")
    assert_equal(editor.document.text(), "scripts(a, X, c, ?, ?)")

def main() raises:
    check_directed_ranges()
    check_fraction_ranges()
    check_matrix_ranges()
    check_structural_navigation()
    check_boundary_only_and_hole_ranges()
    check_optional_start_replacement()
    print("PASS directed structural ranges, exact cross-slot operations, fragments, and exterior navigation")
