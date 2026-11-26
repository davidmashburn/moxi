"""Native UI replay of the normal entry point. No direct model mutations."""
from std.ffi import external_call
from std.testing import assert_equal, assert_true
from moxi import Point
from moxi.macos import MacOSWindow, MacOSRenderer, MacOSCanvasSceneRenderer
from host import MotionApp, drain, render, tick
from editor import CANVAS, Command, knot_point
from model import SketchKind, SolveState, MotionPhase


def control(app: MotionApp, command: Command, enabled: Bool = True) raises:
    var snapshot = app.accessibility()
    for node in snapshot.nodes:
        if node.id == command.value:
            assert_equal(node.enabled, enabled)
            return
    raise Error("Missing native control " + String(command.value))


def settle(mut app: MotionApp, mut window: MacOSWindow, mut paint: MacOSRenderer, mut graph: MacOSCanvasSceneRenderer) raises:
    _ = drain(app, window)
    render(app, window, paint, graph)


def press(mut app: MotionApp, mut window: MacOSWindow, mut paint: MacOSRenderer, mut graph: MacOSCanvasSceneRenderer, command: Command) raises:
    control(app, command)
    external_call["motion_press", NoneType](Int32(command.value))
    settle(app, window, paint, graph)


def pointer(mut app: MotionApp, mut window: MacOSWindow, mut paint: MacOSRenderer, mut graph: MacOSCanvasSceneRenderer, phase: Int, point: Point) raises:
    external_call["motion_pointer", NoneType](Int32(phase), point.x, point.y)
    settle(app, window, paint, graph)


def key(mut app: MotionApp, mut window: MacOSWindow, mut paint: MacOSRenderer, mut graph: MacOSCanvasSceneRenderer, code: Int, modifiers: Int = 0) raises:
    external_call["motion_key", NoneType](Int32(code), Int32(modifiers))
    settle(app, window, paint, graph)


def click(mut app: MotionApp, mut window: MacOSWindow, mut paint: MacOSRenderer, mut graph: MacOSCanvasSceneRenderer, command: Command) raises:
    control(app, command)
    var bounds = app.view.bounds_for(command.value)
    var point = Point(bounds.x + bounds.width / 2, bounds.y + bounds.height / 2)
    pointer(app, window, paint, graph, 0, point)
    pointer(app, window, paint, graph, 2, point)


def finish(mut app: MotionApp, mut window: MacOSWindow, mut paint: MacOSRenderer, mut graph: MacOSCanvasSceneRenderer) raises:
    for _ in range(40):
        _ = tick(app)
    settle(app, window, paint, graph)


def activate_keyboard(mut app: MotionApp, mut window: MacOSWindow, mut paint: MacOSRenderer, mut graph: MacOSCanvasSceneRenderer, command: Command) raises:
    control(app, command)
    var count = 0
    while app.runtime.focus_id() != command.value and count < 40:
        key(app, window, paint, graph, 9)
        count += 1
    assert_equal(app.runtime.focus_id(), command.value)
    key(app, window, paint, graph, 32)


def capture(mut app: MotionApp, mut window: MacOSWindow, mut paint: MacOSRenderer, mut graph: MacOSCanvasSceneRenderer, directory: String, name: String) raises:
    settle(app, window, paint, graph)
    var path = directory + "/" + name + ".png"
    assert_equal(external_call["motion_capture", Int32](path.as_c_string_span().ptr()), Int32(1))
    external_call["motion_assert_host", NoneType]()


def mixed_input_drafts(mut app: MotionApp, mut window: MacOSWindow, mut paint: MacOSRenderer, mut graph: MacOSCanvasSceneRenderer, directory: String) raises:
    click(app, window, paint, graph, Command.FORMALIZE)
    while app.component.studio.knot > 0:
        activate_keyboard(app, window, paint, graph, Command.KNOT_PREVIOUS)
    activate_keyboard(app, window, paint, graph, Command.KNOT_NEXT)
    var bounds = app.view.bounds_for(CANVAS)
    var target = app.component.studio.doc.target.copy()
    var parameters = app.component.studio.doc.parameters
    for endpoint in [0, 8]:
        var start = knot_point(bounds, endpoint, 0)
        var end = knot_point(bounds, endpoint, 80)
        # Rect.contains excludes the right edge. Hit inside the last knot's
        # rounded selection region so this really tests endpoint 8 acceptance.
        if endpoint == 8:
            start.x -= 1
            end.x -= 1
        for terminal in [Command.APPLY, Command.CANCEL, Command.UNDO]:
            var revision = app.component.studio.revision
            var undo_count = len(app.component.studio.undo_stack)
            var redo_count = len(app.component.studio.redo_stack)
            activate_keyboard(app, window, paint, graph, Command.TARGET_UP)
            var draft = app.component.studio.draft.copy()
            assert_true(abs(draft[1] - target[1] - 5) < 0.001)
            for phase in range(3):
                pointer(app, window, paint, graph, phase, start if phase == 0 else end)
                print("CHECK mixed-input endpoint", endpoint, "terminal", terminal.value, "phase", phase,
                      "selected", app.component.studio.knot, "pointer owner", app.component.pointer_drag)
                assert_true(app.component.studio.dragging)
                assert_true(not app.component.pointer_drag)
                assert_equal(app.component.studio.knot, 1)
                assert_equal(app.component.studio.draft, draft)
                assert_equal(app.component.studio.doc.target, target)
                assert_true(app.component.studio.doc.parameters == parameters)
                assert_equal(app.component.studio.revision, revision)
                assert_equal(len(app.component.studio.undo_stack), undo_count)
                assert_equal(len(app.component.studio.redo_stack), redo_count)
                if phase == 1 and terminal == Command.APPLY:
                    capture(app, window, paint, graph, directory, String("mixed-pin-", endpoint, "-draft"))

            # The retained selection and draft must still accept keyboard edits.
            activate_keyboard(app, window, paint, graph, Command.TARGET_UP)
            assert_true(abs(app.component.studio.draft[1] - target[1] - 10) < 0.001)
            if terminal == Command.APPLY:
                click(app, window, paint, graph, Command.APPLY)
                var committed = target.copy()
                committed[1] += 10
                assert_equal(app.component.studio.doc.target, committed)
                assert_equal(app.component.studio.revision, revision + 1)
                assert_equal(len(app.component.studio.undo_stack), undo_count + 1)
                assert_equal(len(app.component.studio.redo_stack), 0)
                capture(app, window, paint, graph, directory, String("mixed-pin-", endpoint, "-committed"))
                key(app, window, paint, graph, 122, 2)
                assert_equal(app.component.studio.doc.target, target)
                key(app, window, paint, graph, 122, 3)
                assert_equal(app.component.studio.doc.target, committed)
                key(app, window, paint, graph, 122, 2)
                assert_equal(app.component.studio.revision, revision + 4)
                assert_equal(len(app.component.studio.undo_stack), undo_count)
                assert_equal(len(app.component.studio.redo_stack), 1)
            else:
                key(app, window, paint, graph, 27 if terminal == Command.CANCEL else 122,
                    0 if terminal == Command.CANCEL else 2)
                assert_equal(app.component.studio.revision, revision)
                assert_equal(len(app.component.studio.undo_stack), undo_count)
                assert_equal(len(app.component.studio.redo_stack), redo_count)
            assert_true(not app.component.studio.dragging)
            assert_true(not app.component.pointer_drag)
            assert_equal(len(app.component.studio.draft), 0)
            assert_equal(app.component.studio.doc.target, target)
            assert_true(app.component.studio.doc.parameters == parameters)
            print("PASS mixed-input endpoint", endpoint, "terminal", terminal.value,
                  ": pinned down/move/up preserves keyboard draft; commit/cancel/undo retains target ownership")
        var revision = app.component.studio.revision
        for phase in range(3):
            pointer(app, window, paint, graph, phase, start if phase == 0 else end)
        assert_true(not app.component.studio.dragging)
        assert_true(not app.component.pointer_drag)
        assert_equal(app.component.studio.knot, 1)
        assert_equal(app.component.studio.doc.target, target)
        assert_equal(app.component.studio.revision, revision)


def replay(mut app: MotionApp, mut window: MacOSWindow, mut paint: MacOSRenderer, mut graph: MacOSCanvasSceneRenderer, directory: String) raises:
    settle(app, window, paint, graph)
    var original = app.component.studio.doc
    assert_true(original.kind == SketchKind.INFORMAL)
    control(app, Command.APPLY, False)
    control(app, Command.REQUEST, False)
    control(app, Command.PEAK_UP, False)
    capture(app, window, paint, graph, directory, "01-informal")

    click(app, window, paint, graph, Command.FORMALIZE)
    press(app, window, paint, graph, Command.LENGTH_UP)
    assert_true(app.component.studio.doc.kind == SketchKind.ARM)
    assert_equal(app.component.studio.doc.length, 130)
    assert_equal(app.component.studio.doc.note, original.note)
    assert_equal(app.component.studio.doc.note_x, original.note_x)
    assert_equal(app.component.studio.doc.note_y, original.note_y)
    control(app, Command.FORMALIZE, False)
    capture(app, window, paint, graph, directory, "02-formalized")
    print("PASS sketch: local formalization, length, unfinished note and position")

    press(app, window, paint, graph, Command.PEAK_UP)
    assert_equal(app.component.studio.doc.parameters.peak, 50)
    assert_equal(app.component.studio.doc.target, original.target)
    press(app, window, paint, graph, Command.SCRUB_FORWARD)
    assert_true(app.component.studio.doc.parameters.phase(app.component.studio.time) == MotionPhase.RETURN)
    capture(app, window, paint, graph, directory, "03-parameters")
    var before_target = app.component.studio.doc.parameters
    var bounds = app.view.bounds_for(CANVAS)
    var start = knot_point(bounds, 3, app.component.studio.doc.target[3])
    var end = knot_point(bounds, 3, 65)
    pointer(app, window, paint, graph, 0, start)
    assert_true(app.component.studio.dragging)
    pointer(app, window, paint, graph, 1, end)
    assert_equal(app.component.studio.doc.target, original.target)
    assert_true(app.component.studio.doc.parameters == before_target)
    capture(app, window, paint, graph, directory, "04-target-draft")
    pointer(app, window, paint, graph, 2, end)
    assert_true(not app.component.studio.dragging)
    assert_true(abs(app.component.studio.doc.target[3] - 65) < 0.001)
    assert_true(app.component.studio.doc.parameters == before_target)
    capture(app, window, paint, graph, directory, "05-target-committed")
    print("PASS ownership: parameters leave target; drag drafts until release and leaves parameters")

    press(app, window, paint, graph, Command.REQUEST)
    assert_true(app.component.studio.search.state == SolveState.RUNNING)
    control(app, Command.APPLY, False)
    finish(app, window, paint, graph)
    assert_true(app.component.studio.search.state == SolveState.READY)
    assert_equal(len(app.component.studio.search.choices), 3)
    activate_keyboard(app, window, paint, graph, Command.SECOND)
    assert_equal(app.component.studio.search.selected, 1)
    assert_true(app.component.studio.doc.parameters == before_target)
    var selected = app.component.studio.visible_parameters()
    var target = app.component.studio.doc.target.copy()
    capture(app, window, paint, graph, directory, "06-alternatives")
    key(app, window, paint, graph, 27)
    assert_true(app.component.studio.search.state == SolveState.CANCELLED)
    assert_true(app.component.studio.doc.parameters == before_target)
    press(app, window, paint, graph, Command.REQUEST)
    finish(app, window, paint, graph)
    activate_keyboard(app, window, paint, graph, Command.SECOND)
    click(app, window, paint, graph, Command.APPLY)
    assert_true(app.component.studio.doc.parameters == selected)
    assert_equal(app.component.studio.doc.target, target)
    assert_equal(app.component.studio.doc.length, 130)
    assert_equal(app.component.studio.doc.note, original.note)
    capture(app, window, paint, graph, directory, "07-applied")
    key(app, window, paint, graph, 122, 2)
    assert_true(app.component.studio.doc.parameters == before_target)
    key(app, window, paint, graph, 122, 3)
    assert_true(app.component.studio.doc.parameters == selected)
    print("PASS alternatives: three fits, separate preview, atomic apply, Cmd+Z / Cmd+Shift+Z")

    press(app, window, paint, graph, Command.REQUEST)
    _ = tick(app)
    assert_equal(app.component.studio.search.next, 3)
    capture(app, window, paint, graph, directory, "08-pending")
    press(app, window, paint, graph, Command.CANCEL)
    finish(app, window, paint, graph)
    assert_true(app.component.studio.search.state == SolveState.CANCELLED)
    assert_true(app.component.studio.doc.parameters == selected)
    assert_equal(app.component.studio.doc.target, target)
    capture(app, window, paint, graph, directory, "09-cancelled")

    start = knot_point(bounds, 3, app.component.studio.doc.target[3])
    end = knot_point(bounds, 3, 95)
    pointer(app, window, paint, graph, 0, start)
    pointer(app, window, paint, graph, 1, end)
    key(app, window, paint, graph, 27)
    assert_true(not app.component.studio.dragging)
    pointer(app, window, paint, graph, 2, end)
    assert_equal(app.component.studio.doc.target, target)
    assert_true(app.component.studio.doc.parameters == selected)
    capture(app, window, paint, graph, directory, "10-draft-cancelled")
    print("PASS cancellation: pending solve and Escape-drag survive later ticks / release")

    # Arrow keys belong to framework focus navigation. Tab/Space activates the
    # same visible knot controls without a special test-only event route.
    start = knot_point(bounds, 3, app.component.studio.doc.target[3])
    pointer(app, window, paint, graph, 0, start)
    pointer(app, window, paint, graph, 2, start)
    activate_keyboard(app, window, paint, graph, Command.TARGET_UP)
    assert_equal(app.component.studio.doc.target, target)
    assert_true(abs(app.component.studio.draft[3] - (target[3] + 5)) < 0.001)
    capture(app, window, paint, graph, directory, "11-keyboard-draft")
    var draft_revision = app.component.studio.revision
    key(app, window, paint, graph, 122, 2)
    assert_true(not app.component.studio.dragging)
    assert_equal(app.component.studio.revision, draft_revision)
    activate_keyboard(app, window, paint, graph, Command.TARGET_UP)
    activate_keyboard(app, window, paint, graph, Command.APPLY)
    assert_true(abs(app.component.studio.doc.target[3] - (target[3] + 5)) < 0.001)
    key(app, window, paint, graph, 122, 2)
    assert_equal(app.component.studio.doc.target, target)
    # A keyboard draft must also accept a mouse click on Commit target.
    activate_keyboard(app, window, paint, graph, Command.TARGET_UP)
    click(app, window, paint, graph, Command.APPLY)
    assert_true(abs(app.component.studio.doc.target[3] - (target[3] + 5)) < 0.001)
    key(app, window, paint, graph, 122, 2)
    assert_equal(app.component.studio.doc.target, target)
    for _ in range(3):
        activate_keyboard(app, window, paint, graph, Command.KNOT_PREVIOUS)
    assert_equal(app.component.studio.knot, 0)
    var revision = app.component.studio.revision
    activate_keyboard(app, window, paint, graph, Command.TARGET_UP)
    assert_equal(app.component.studio.doc.target[0], Float64(0))
    assert_equal(app.component.studio.revision, revision)
    capture(app, window, paint, graph, directory, "11-pinned")
    activate_keyboard(app, window, paint, graph, Command.PLAY)
    assert_true(app.component.studio.playing)
    var time = app.component.studio.time
    _ = tick(app, 0.025)
    assert_true(app.component.studio.time > time)
    activate_keyboard(app, window, paint, graph, Command.PLAY)
    assert_true(not app.component.studio.playing)
    print("PASS keyboard: Tab/Space preview, nudge, select and play; pinned start leaves revision unchanged")

    # A target beyond the angular cap cannot be fitted within six degrees RMS.
    start = knot_point(bounds, 3, app.component.studio.doc.target[3])
    end = knot_point(bounds, 3, 120)
    pointer(app, window, paint, graph, 0, start)
    pointer(app, window, paint, graph, 1, end)
    pointer(app, window, paint, graph, 2, end)
    press(app, window, paint, graph, Command.REQUEST)
    finish(app, window, paint, graph)
    assert_true(app.component.studio.search.state == SolveState.FAILED)
    assert_true(app.component.studio.doc.parameters == selected)
    assert_true(abs(app.component.studio.doc.target[3] - 120) < 0.001)
    control(app, Command.APPLY, False)
    capture(app, window, paint, graph, directory, "12-infeasible")
    press(app, window, paint, graph, Command.UNDO)
    assert_equal(app.component.studio.doc.target, target)
    capture(app, window, paint, graph, directory, "13-failure-undo")

    press(app, window, paint, graph, Command.REQUEST)
    press(app, window, paint, graph, Command.PEAK_UP)
    var changed = app.component.studio.doc.parameters
    finish(app, window, paint, graph)
    assert_true(app.component.studio.search.state == SolveState.STALE)
    assert_true(app.component.studio.doc.parameters == changed)
    control(app, Command.APPLY, False)
    capture(app, window, paint, graph, directory, "14-stale")
    print("PASS inverse recovery: infeasible request preserves implementation; undo; edited revision invalidates search")

    while len(app.component.studio.undo_stack) > 0:
        press(app, window, paint, graph, Command.UNDO)
    assert_true(app.component.studio.doc.kind == SketchKind.INFORMAL)
    assert_equal(app.component.studio.doc.length, original.length)
    assert_equal(app.component.studio.doc.note, original.note)
    assert_equal(app.component.studio.doc.note_x, original.note_x)
    assert_equal(app.component.studio.doc.note_y, original.note_y)
    capture(app, window, paint, graph, directory, "15-sketch-undo")
    control(app, Command.REQUEST, False)
    external_call["motion_resize", NoneType](Float32(960), Float32(760))
    settle(app, window, paint, graph)
    assert_equal(window.size().width, Float32(960))
    assert_equal(window.size().height, Float32(760))
    for node in app.view.children:
        assert_true(node.bounds.y + node.bounds.height <= 760)
    capture(app, window, paint, graph, directory, "16-minimum-window")
    print("PASS recovery / layout: undo formalization restores sketch and note; 960x760 controls stay in content")
    print("PASS native UI: 17 window captures; no queue drops or command overflows")
    mixed_input_drafts(app, window, paint, graph, directory)
