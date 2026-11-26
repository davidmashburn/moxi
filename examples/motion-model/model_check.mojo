"""Independent numerical invariants and transactional recovery checks."""
from std.testing import assert_true, assert_equal
from model import *


def finish(mut studio: Studio):
    for _ in range(40):
        _ = studio.tick(0)


def main() raises:
    # Every admissible curve honors the pins, amplitude bound, continuity and
    # state transition. The midpoint values have an independent 45-degree oracle.
    var checked = 0
    for peak in range(20, 81, 5):
        for turn in range(4, 13):
            var p = Parameters(peak, turn)
            var t = Float64(turn) / 8
            assert_true(p.valid())
            assert_equal(p.angle(0), Float64(0))
            assert_equal(p.angle(2), Float64(0))
            assert_true(abs(p.angle(t) - Float64(peak)) < 1e-10)
            assert_true(abs(p.angle(t / 2) - Float64(peak) * sqrt(0.5)) < 1e-10)
            assert_true(abs(p.angle(t + (2 - t) / 2) - Float64(peak) * sqrt(0.5)) < 1e-10)
            assert_true(p.phase(t - 1e-6) == MotionPhase.TRACK)
            assert_true(p.phase(t) == MotionPhase.RETURN)
            assert_true(abs(p.angle(t - 1e-6) - p.angle(t + 1e-6)) < 1e-8)
            for i in range(201):
                assert_true(p.angle(Float64(i) / 100) >= 0)
                assert_true(p.angle(Float64(i) / 100) <= Float64(peak) + 1e-10)
            checked += 1
    assert_equal(checked, SEARCH_SIZE)

    var bounded = Studio()
    bounded.formalize()
    bounded.edit_parameters(1000, 1000)
    assert_true(bounded.doc.parameters == Parameters(80, 12))
    var bound_revision = bounded.revision
    bounded.edit_parameters(5, 1)
    assert_equal(bounded.revision, bound_revision)
    bounded.edit_parameters(-1000, -1000)
    assert_true(bounded.doc.parameters == Parameters(20, 4))
    bounded.edit_length(1000)
    assert_equal(bounded.doc.length, 160)
    bounded.edit_length(-1000)
    assert_equal(bounded.doc.length, 80)

    var s = Studio()
    var original = s.doc
    s.formalize()
    s.begin_drag(3)
    s.draft[3] = 95
    s.undo()
    assert_true(not s.dragging)
    assert_true(s.doc.kind == SketchKind.ARM)
    assert_equal(s.doc.target, original.target)
    assert_equal(len(s.undo_stack), 1)
    s.edit_length(10)
    assert_equal(s.doc.length, 130)
    s.undo()
    s.undo()
    assert_true(s.doc.kind == SketchKind.INFORMAL)
    assert_equal(s.doc.note, original.note)
    assert_equal(s.doc.note_x, original.note_x)
    assert_equal(s.doc.note_y, original.note_y)
    s.redo()
    assert_true(s.doc.kind == SketchKind.ARM)
    assert_equal(s.doc.length, 120)

    s.edit_parameters(5, 0)
    for i in range(KNOTS):
        assert_equal(s.doc.target[i], original.target[i])
    s.knot = 3
    var parameters = s.doc.parameters
    s.edit_target(65)
    assert_true(s.doc.parameters == parameters)
    s.undo()
    s.knot = 8
    var revision = s.revision
    s.edit_target(20)
    assert_equal(s.revision, revision)
    assert_equal(s.doc.target[8], Float64(0))

    s.begin_drag(3)
    s.draft[3] = 110
    s.cancel()
    assert_equal(s.revision, revision)
    assert_equal(s.doc.target[3], original.target[3])
    s.request()
    _ = s.tick(0)
    assert_true(s.search.state == SolveState.RUNNING)
    s.cancel()
    finish(s)
    assert_true(s.search.state == SolveState.CANCELLED)
    assert_true(s.doc.parameters == parameters)
    s.request()
    finish(s)
    assert_true(s.search.state == SolveState.READY)
    assert_equal(len(s.search.choices), 3)
    assert_true(s.search.choices[0].parameters == Parameters(60, 6))
    assert_true(s.search.choices[0].error < 1e-10)
    for i in range(1, 3):
        assert_true(s.search.choices[i].error >= s.search.choices[i - 1].error)
        assert_true(s.search.choices[i].error <= FIT_TOLERANCE)
    s.search.selected = 1
    var chosen = s.visible_parameters()
    assert_true(chosen != s.doc.parameters)
    s.apply()
    assert_true(s.doc.parameters == chosen)
    s.undo()
    assert_true(s.doc.parameters == parameters)
    s.redo()
    assert_true(s.doc.parameters == chosen)

    s.request()
    s.edit_parameters(5, 0)
    finish(s)
    assert_true(s.search.state == SolveState.STALE)
    var edited = s.doc.parameters
    s.apply()
    assert_true(s.doc.parameters == edited)
    s.request()
    finish(s)
    s.undo()
    s.apply()
    assert_true(s.search.state == SolveState.STALE)

    s.knot = 3
    s.edit_target(120)
    s.request()
    finish(s)
    assert_true(s.search.state == SolveState.FAILED)
    assert_equal(len(s.search.choices), 0)
    assert_equal(s.doc.target[3], Float64(120))
    assert_true(s.search.best_error > FIT_TOLERANCE)
    s.undo()
    assert_equal(s.doc.target[3], original.target[3])
    assert_true(s.search.state == SolveState.STALE)
    print("PASS: 117 curves / 23517 sample bounds, response laws, pins, states, ownership, sketch undo, three fits, failed/cancelled/stale solve, apply/undo/redo")
