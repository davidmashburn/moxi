"""Persistent isolated SymPy worker. Only explicit constructors are reachable."""
import sys
import time
from .model import (Node, Kind, Domain, Backend, Request, Operation, Status, VERSION, BoundaryError)
from .protocol import read, write

class Adapter:
    def __init__(self):
        import sympy
        self.s = sympy
        self.symbols = {}

    def encode(self, n):
        s, k, v = self.s, n.kind, n.values
        c = [self.encode(x) for x in n.children]
        if k == Kind.INTEGER:
            return s.Integer(v[0])
        if k == Kind.RATIONAL:
            return s.Rational(v[0], v[1])
        if k == Kind.SYMBOL:
            domain = Domain(v[2])
            assumptions = {} if domain == Domain.COMPLEX else {domain.value: True}
            result = s.Symbol(v[0], **assumptions)
            self.symbols[result] = n
            return result
        if k == Kind.ADD:
            return s.Add(*c)
        if k == Kind.MUL:
            return s.Mul(*c)
        if k == Kind.POW:
            return s.Pow(*c)
        if k == Kind.SIN:
            return s.sin(*c)
        if k == Kind.COS:
            return s.cos(*c)
        if k == Kind.FUNCTION:
            return s.Function(v[0])(*c)
        if k == Kind.MATRIX:
            return s.ImmutableMatrix(int(v[0]), int(v[1]), c)
        if k == Kind.MATMUL:
            return c[0] * c[1]
        raise BoundaryError("Unsupported input", n.id, Status.UNSUPPORTED)

    def decode(self, value, depth=0, budget=None):
        from sympy.core.function import AppliedUndef
        s = self.s
        budget = [4096] if budget is None else budget
        budget[0] -= 1
        if depth > 64 or budget[0] < 0:
            raise BoundaryError("Result exceeds import budget", status=Status.UNSUPPORTED)
        identity = "result-" + str(4096 - budget[0])
        if value in self.symbols:
            return self.symbols[value]
        if isinstance(value, s.Integer):
            return Node(Kind.INTEGER, (str(value),), id=identity)
        if isinstance(value, s.Rational):
            return Node(Kind.RATIONAL, (str(value.p), str(value.q)), id=identity)
        if isinstance(value, s.MatrixBase):
            return Node(Kind.MATRIX, (str(value.rows), str(value.cols)),
                        tuple(self.decode(v, depth + 1, budget) for v in value), identity)
        constructors = {s.Add: Kind.ADD, s.Mul: Kind.MUL, s.Pow: Kind.POW, s.sin: Kind.SIN, s.cos: Kind.COS}
        if value.func in constructors:
            return Node(constructors[value.func], (), tuple(self.decode(x, depth + 1, budget) for x in value.args), identity)
        if isinstance(value, AppliedUndef):
            return Node(Kind.FUNCTION, (value.func.__name__,), tuple(self.decode(x, depth + 1, budget) for x in value.args), identity)
        raise BoundaryError("Cannot import result type " + type(value).__name__, status=Status.UNSUPPORTED)

    def execute(self, request):
        self.symbols = {}
        start = time.perf_counter_ns()
        expr = self.encode(request.root)
        variable = self.encode(request.variable) if request.variable else None
        replacement = self.encode(request.replacement) if request.replacement else None
        exported = time.perf_counter_ns()
        match request.operation:
            case Operation.EVALUATE:
                result = expr
            case Operation.EXPAND:
                result = self.s.expand(expr)
            case Operation.DIFFERENTIATE:
                result = self.s.diff(expr, variable)
            case Operation.SUBSTITUTE:
                result = expr.subs(variable, replacement)
        computed = time.perf_counter_ns()
        output = self.decode(result)
        output.validate()
        finished = time.perf_counter_ns()
        return output, {"construct_ns": exported - start, "compute_ns": computed - exported,
                        "convert_ns": finished - computed}


def main():
    adapter = Adapter()
    write(sys.stdout.buffer, {"version": VERSION, "ready": True, "engine": Backend.SYMPY.value, "engine_version": adapter.s.__version__})
    while True:
        try:
            envelope = read(sys.stdin.buffer)
        except EOFError:
            return
        start = time.perf_counter_ns()
        response = {"version": VERSION, "generation": envelope["generation"], "revision": envelope["revision"]}
        try:
            request = Request.read(envelope["request"])
            result, timings = adapter.execute(request)
            response.update(status=Status.OK.value, result=result.wire(), timings=timings)
        except BoundaryError as exc:
            response.update(status=exc.status.value, message=str(exc), node_id=exc.node_id)
        except Exception as exc:
            response.update(status=Status.ERROR.value, message=type(exc).__name__ + ": " + str(exc))
        response["worker_ns"] = time.perf_counter_ns() - start
        write(sys.stdout.buffer, response)

if __name__ == "__main__":
    main()
