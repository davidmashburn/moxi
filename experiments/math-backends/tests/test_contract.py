import os
import sys
import time
import pytest
from moxi_math_probe.model import *
from moxi_math_probe.corpus import fixtures, canonical, slow_request
from moxi_math_probe.controller import Controller, Document, Completion

BACKENDS = list(Backend) if os.environ.get("MOXI_SYMENGINE_WORKER") else [Backend.SYMPY]

def wait(controller, timeout=10):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        value = controller.poll()
        if value is not None:
            return value
        time.sleep(0.002)
    raise AssertionError("No completion")

@pytest.mark.parametrize("backend", BACKENDS)
def test_shared_corpus(backend):
    with Controller(backend) as controller:
        for fixture in fixtures():
            request = fixture.request
            source = to_text(request.root)
            assert from_text(source) == request.root
            controller.submit(request, 17)
            result = wait(controller)
            assert result.status == fixture.status(backend), (fixture.name, result)
            assert to_text(request.root) == source
            if result.status == Status.OK:
                assert canonical(result.result) == canonical(fixture.expected), (fixture.name, result.result)
                assert from_text(to_text(result.result)) == result.result
                # Result is computable again, not a flattened backend string.
                controller.submit(Request(from_text(to_text(result.result))), 18)
                second = wait(controller)
                assert second.status == Status.OK
                assert canonical(second.result) == canonical(result.result)
            if backend == Backend.SYMENGINE:
                assert result.timings["handles"]["live"] == 0
        assert len(controller.startups) == 1

@pytest.mark.parametrize("kind", [Kind.HOLE, Kind.MALFORMED, Kind.ROW, Kind.INTEGRAL])
def test_unresolved_editable_but_never_submitted(kind):
    root = Node(kind, ("unfinished λ",), id="affected-node")
    assert from_text(to_text(root)) == root
    with Controller(command=["does-not-exist"]) as controller:
        with pytest.raises(BoundaryError) as exc:
            controller.submit(Request(root), 0)
        assert exc.value.node_id == "affected-node"
        assert controller.process is None
        assert controller.generation == 0

def test_selected_result_and_independent_guards():
    fixture = next(x for x in fixtures() if x.name == "selected-numerator")
    doc = Document(fixture.request.root, revision=7, generation=3, selection=(0,))
    original_denominator = doc.root.children[1]
    ready = Completion(3, 7, Status.OK, fixture.expected)
    assert doc.apply(Completion(2, 7, Status.OK, fixture.expected)) == Status.STALE
    assert doc.apply(Completion(3, 6, Status.OK, fixture.expected)) == Status.STALE
    assert doc.apply(ready) == Status.OK
    assert doc.root.children[1] == original_denominator
    assert doc.apply(ready) == Status.STALE  # applying is a revision change
    doc.closed = True
    assert doc.apply(ready) == Status.CLOSED

@pytest.mark.parametrize("selection", [(0,), (0, 0)])
def test_selected_subtree_cannot_escape_bound_variable_scope(selection):
    body = node(Kind.ADD, symbol("x"), integer(1))
    root = node(Kind.INTEGRAL, body, symbol("x"), id="binder")
    with Controller(command=["does-not-exist"]) as controller:
        with pytest.raises(BoundaryError) as exc:
            controller.submit(Request(root, Operation.SUBSTITUTE, selection,
                                      variable=symbol("x"), replacement=symbol("y")), 0)
        assert exc.value.status is Status.UNSUPPORTED
        assert exc.value.node_id == "binder"
        assert controller.process is None
        assert controller.generation == 0

@pytest.mark.parametrize("backend", BACKENDS)
def test_edit_while_running_and_supersede(backend):
    with Controller(backend, timeout=3) as controller:
        doc = Document(slow_request().root)
        doc.submit(controller, slow_request())
        time.sleep(0.4)  # let real engine work begin
        assert controller.active is not None
        doc.edit(integer(99))
        doc.submit(controller, Request(doc.root))
        done = wait(controller)
        assert doc.apply(done) == Status.OK
        assert doc.root.values == ("99",)
        assert controller.pending is None
        assert controller.active is None

@pytest.mark.parametrize("backend", BACKENDS)
def test_deadline_restart_and_logical_cancel(backend):
    with Controller(backend, timeout=2) as controller:
        controller.submit(Request(integer(1)), 0)
        assert wait(controller).status == Status.OK
        controller.timeout = 0.05
        controller.submit(slow_request(), 1)
        assert wait(controller).status == Status.TIMEOUT
        controller.timeout = 3
        controller.submit(Request(integer(2)), 2)
        assert wait(controller).status == Status.OK
        controller.submit(slow_request(), 3)
        time.sleep(0.03)
        controller.cancel()  # logical discard; active work still exists
        assert controller.active is not None
        assert controller.poll() is None
        controller.cancel(terminate=True)
        controller.submit(Request(integer(3)), 4)
        assert wait(controller).status == Status.OK
        assert len(controller.startups) >= 2

@pytest.mark.parametrize("backend", BACKENDS)
def test_close_reaps_active_and_queue_bound(backend):
    controller = Controller(backend, timeout=3)
    controller.submit(slow_request(), 0)
    time.sleep(0.3)
    for i in range(50):
        controller.submit(Request(integer(i)), i, replace_active=False)
    with controller.lock:
        assert controller.pending.request.root == integer(49)
        process = controller.process
    controller.close()
    assert not controller.thread.is_alive()
    assert process is None or process.poll() is not None
    assert controller.poll() is None
    with pytest.raises(BoundaryError):
        controller.submit(Request(integer(1)), 1)

def test_exactness_and_symbol_identities():
    assert decimal_exact("0.125") == rational(1, 8)
    with pytest.raises(BoundaryError):
        decimal_exact(0.125)
    with pytest.raises(BoundaryError):
        node(Kind.ADD, symbol("x", "a"), symbol("x", "b")).validate()
    with pytest.raises(BoundaryError):
        Node.read({"kind": "future", "values": [], "children": [], "id": "x"})
    assert isinstance(Node.read(integer(1).wire()).kind, Kind)
    assert isinstance(Status("ok"), Status)

def test_missing_dependency_and_worker_error():
    with Controller(command=["/nonexistent/moxi-worker"]) as controller:
        controller.submit(Request(integer(1)), 0)
        assert wait(controller).status == Status.ERROR

@pytest.mark.parametrize("payload", [b"\x00\x10\x00\x01", b"\x00\x00\x00\x01{", b"\x00\x00\x00\x02{}", b"\x00\x00\x00\x10{}"])
def test_malformed_oversized_truncated_and_version_response(payload):
    # Fault worker used solely for transport failure paths, never measurements.
    command = [sys.executable, "-c", "import sys;sys.stdout.buffer.write(" + repr(payload) + ");sys.stdout.flush()"]
    with Controller(command=command, timeout=0.5) as controller:
        controller.submit(Request(integer(1)), 0)
        assert wait(controller).status == Status.ERROR

def test_text_and_structured_edit_same_semantic_request():
    original = node(Kind.ADD, integer(1), integer(2))
    structured = original.replace_at((1,), rational(1, 3, id="integer"))
    text_edited = from_text(to_text(original).replace('"values":["2"]', '"values":["1","3"]').replace('"kind":"integer","values":["1","3"]', '"kind":"rational","values":["1","3"]'))
    assert Request(structured).wire() == Request(text_edited).wire()

@pytest.mark.parametrize("response", [
    b"\x00\x10\x00\x01",  # oversized frame after valid handshake
    b"\x00\x00\x00\x01{",  # malformed JSON
    b"\x00\x00\x00\x10{}",  # truncated body
    {"version": 1, "generation": 999, "revision": 0, "status": "ok", "result": integer(1).wire()},
    {"version": 1, "generation": 1, "revision": 0, "status": "future"},
    {"version": 1, "generation": 1, "revision": 0, "status": "ok", "result": symbol("invented").wire()},
    {"version": 1, "generation": 1, "revision": 0, "status": "ok", "result": symbol("x", domain=Domain.POSITIVE).wire()},
])
def test_invalid_response_after_handshake_is_not_imported(response):
    from moxi_math_probe.protocol import pack
    body = response if isinstance(response, bytes) else pack(response)
    script = ("import sys;from moxi_math_probe.protocol import write,read;"
              "write(sys.stdout.buffer,{'version':1,'ready':True,'engine':'sympy'});"
              "read(sys.stdin.buffer);sys.stdout.buffer.write(" + repr(body) + ");sys.stdout.flush()")
    with Controller(command=[sys.executable, "-c", script], timeout=.5) as controller:
        doc = Document(symbol("x"))
        doc.submit(controller, Request(doc.root))
        completion = wait(controller)
        assert completion.status == Status.ERROR
        assert doc.apply(completion) == Status.ERROR
        assert doc.root == symbol("x")
        assert controller.process is None

@pytest.mark.parametrize("backend", BACKENDS)
def test_repeated_success_and_failed_import_release_ownership(backend):
    cases = [fixtures()[3], fixtures()[-1]]
    with Controller(backend) as controller:
        for i in range(100):
            case = cases[i % 2]
            controller.submit(case.request, i)
            result = wait(controller)
            assert result.status == case.status(backend)
            if backend == Backend.SYMENGINE:
                assert result.timings["handles"]["live"] == 0
        assert len(controller.startups) == 1

def test_node_and_frame_budgets():
    from moxi_math_probe.protocol import pack, MAX_FRAME
    deeply_nested = integer(1)
    for _ in range(66):
        deeply_nested = node(Kind.SIN, deeply_nested)
    with pytest.raises(BoundaryError):
        Request(deeply_nested).validate()
    with pytest.raises(BoundaryError):
        Request(node(Kind.ADD, *(integer(1) for _ in range(4097)))).validate()
    with pytest.raises(BoundaryError):
        pack({"payload": "x" * MAX_FRAME})

def test_scope_capture_rejected_locally_and_matrix_scalar_distinction():
    integral = node(Kind.INTEGRAL, symbol("x"), symbol("y"), id="bound-integral")
    with Controller(command=["not-a-worker"]) as controller:
        with pytest.raises(BoundaryError) as error:
            controller.submit(Request(integral, Operation.SUBSTITUTE, variable=symbol("y"), replacement=symbol("x")), 0)
        assert error.value.status == Status.UNSUPPORTED
        assert error.value.node_id == "bound-integral"
        assert controller.process is None
    matrix = node(Kind.MATRIX, integer(1), values=("1", "1"))
    with pytest.raises(BoundaryError):
        Request(node(Kind.MUL, matrix, matrix)).validate()

def test_embedded_python_overrides_do_not_replace_worker_virtualenv():
    env = dict(os.environ, PYTHONHOME="/not/a/python/home", PYTHONEXECUTABLE="/not/the/worker", __PYVENV_LAUNCHER__="/not/the/worker")
    with Controller(env=env) as controller:
        assert all(key not in controller.env for key in ("PYTHONHOME", "PYTHONEXECUTABLE", "__PYVENV_LAUNCHER__"))
        controller.submit(Request(integer(42)), 0)
        assert wait(controller).status == Status.OK
