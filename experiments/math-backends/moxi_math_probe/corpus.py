"""Hand-checkable fixtures shared by tests, measurements and the native demo."""
from dataclasses import dataclass
from .model import (Node, Kind as K, Operation as O, Domain, Request, Status, Backend,
                    integer as I, rational as Q, symbol as S, node as N, decimal_exact)

X, Y = S("x"), S("y")
SUM = N(K.ADD, X, Y)
SQUARE = N(K.POW, SUM, I(2))

@dataclass(frozen=True)
class Fixture:
    name: str
    request: Request
    expected: Node | None
    native_status: Status = Status.OK
    sympy_status: Status = Status.OK

    def status(self, backend):
        return self.native_status if backend == Backend.SYMENGINE else self.sympy_status


def fixtures():
    poly = N(K.ADD, N(K.POW, X, I(3)), N(K.MUL, I(2), X), I(5))
    expansion = N(K.ADD, N(K.POW, X, I(2)), N(K.MUL, I(2), X, Y), N(K.POW, Y, I(2)))
    fraction = N(K.MUL, SQUARE, N(K.POW, N(K.ADD, X, I(1)), I(-1)))
    matrix = N(K.MATRIX, I(1), Q(1, 2), X, I(3), values=("2", "2"))
    identity = N(K.MATRIX, I(1), I(0), I(0), I(1), values=("2", "2"))
    real = S("r", domain=Domain.REAL)
    positive = S("p", domain=Domain.POSITIVE)
    huge = 10**90 + 7
    return [
        Fixture("exact-half", Request(N(K.ADD, Q(1, 3), Q(1, 6))), Q(1, 2)),
        Fixture("large-rational", Request(Q(huge, 10**80 + 9)), Q(huge, 10**80 + 9)),
        Fixture("exact-decimal", Request(N(K.ADD, decimal_exact("0.1"), decimal_exact("0.2"))), Q(3, 10)),
        Fixture("expand-square", Request(SQUARE, O.EXPAND), expansion),
        Fixture("selected-numerator", Request(fraction, O.EXPAND, (0,)), expansion),
        Fixture("differentiate-polynomial", Request(poly, O.DIFFERENTIATE, variable=X), N(K.ADD, N(K.MUL, I(3), N(K.POW, X, I(2))), I(2))),
        Fixture("differentiate-sine-product", Request(N(K.MUL, X, N(K.SIN, X)), O.DIFFERENTIATE, variable=X), N(K.ADD, N(K.SIN, X), N(K.MUL, X, N(K.COS, X)))),
        Fixture("substitute-compound", Request(N(K.POW, X, I(2)), O.SUBSTITUTE, variable=X, replacement=N(K.ADD, Y, I(1))), N(K.POW, N(K.ADD, Y, I(1)), I(2))),
        Fixture("complex-root-square", Request(N(K.POW, N(K.POW, X, I(2)), Q(1, 2))), N(K.POW, N(K.POW, X, I(2)), Q(1, 2))),
        Fixture("positive-root-square", Request(N(K.POW, N(K.POW, positive, I(2)), Q(1, 2))), positive, Status.UNSUPPORTED),
        Fixture("real-root-unsupported-abs", Request(N(K.POW, N(K.POW, real, I(2)), Q(1, 2))), None, Status.UNSUPPORTED, Status.UNSUPPORTED),
        Fixture("matrix", Request(matrix), matrix, Status.UNSUPPORTED),
        Fixture("matrix-multiplication", Request(N(K.MATMUL, matrix, identity)), matrix, Status.UNSUPPORTED),
        Fixture("unknown-function", Request(N(K.FUNCTION, X, values=("f",))), N(K.FUNCTION, X, values=("f",)), Status.UNSUPPORTED),
        Fixture("unsupported-derivative", Request(N(K.FUNCTION, X, values=("f",)), O.DIFFERENTIATE, variable=X), None, Status.UNSUPPORTED, Status.UNSUPPORTED),
        Fixture("unsupported-infinity", Request(N(K.POW, I(0), I(-1))), None, Status.UNSUPPORTED, Status.UNSUPPORTED),
    ]


def canonical(n):
    """Structural oracle only: flatten associative operations and ignore order/IDs.

    It cannot prove arbitrary equivalence, simplify, or call either engine.
    """
    children = []
    for child in n.children:
        if n.kind in (K.ADD, K.MUL) and child.kind == n.kind:
            children.extend(canonical(c) for c in child.children)
        else:
            children.append(canonical(child))
    if n.kind in (K.ADD, K.MUL):
        children.sort(key=repr)
    return (n.kind.value, n.values, tuple(children))


def slow_request(power=1200):
    # Real combinatorial expansion, no sleeps/fake worker latency.
    return Request(N(K.POW, N(K.ADD, X, Y, S("z")), I(power)), O.EXPAND)
