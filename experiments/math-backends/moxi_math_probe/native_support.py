"""Framing only for the Mojo process: no SymPy/SymEngine Python binding."""
import sys
import time
from .model import Node, Kind, Domain, Backend, Request, Status, VERSION, BoundaryError
from .protocol import read, write

def ready(version):
    write(sys.stdout.buffer, {"version": VERSION, "ready": True, "engine": Backend.SYMENGINE.value, "engine_version": version})

def next_request():
    try:
        return read(sys.stdin.buffer)
    except EOFError:
        return None

def prepare(envelope):
    request = Request.read(envelope["request"])
    # Native subset uses complex scalar symbols. Refuse unsupported semantics
    # before C calls rather than erasing an assumption, matrix or function.
    def check(n):
        if n.kind in (Kind.FUNCTION, Kind.MATRIX, Kind.MATMUL):
            raise BoundaryError("SymEngine probe does not import " + n.kind.value, n.id, Status.UNSUPPORTED)
        if n.kind == Kind.SYMBOL and n.values[2] != Domain.COMPLEX:
            raise BoundaryError("SymEngine probe supports complex symbols only", n.id, Status.UNSUPPORTED)
        for child in n.children:
            check(child)
    for n in (request.root, request.variable, request.replacement):
        if n:
            check(n)
    return request.wire()

def make_node(kind, values, children):
    return Node(Kind(kind), tuple(values), tuple(Node.read(c) for c in children), "result").wire()

def symbol_result(identity, envelope):
    request = Request.read(envelope["request"])
    symbols = request.validate()
    if identity not in symbols:
        raise BoundaryError("Unknown returned symbol", status=Status.UNSUPPORTED)
    return Node(Kind.SYMBOL, symbols[identity], id=identity).wire()

def finish(envelope, result, started, constructed, computed, finished, handles, peak):
    n = Node.read(result)
    n.validate()
    write(sys.stdout.buffer, {"version": VERSION, "generation": envelope["generation"], "revision": envelope["revision"],
          "status": Status.OK.value, "result": result, "worker_ns": time.perf_counter_ns() - started,
          "handles": {"live": handles, "peak": peak},
          "timings": {"construct_ns": constructed-started, "compute_ns": computed-constructed, "convert_ns": finished-computed}})

def failure(envelope, message, handles):
    # Unsupported output never becomes a symbol. C errors remain backend errors.
    status = Status.UNSUPPORTED if "unsupported" in message.lower() or "import" in message.lower() or "complex symbols" in message.lower() else Status.ERROR
    write(sys.stdout.buffer, {"version": VERSION, "generation": envelope["generation"], "revision": envelope["revision"],
          "status": status.value, "message": message, "handles": {"live": handles}})
