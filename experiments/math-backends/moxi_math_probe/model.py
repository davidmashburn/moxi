"""Lossless probe notation and a deliberately closed semantic vocabulary.

The text representation is versioned JSON, including node IDs and unresolved
edits. It is NOT SymPy/SymEngine source. D02 can adapt its own notation to Node.
"""
from dataclasses import dataclass, replace
from enum import StrEnum
from fractions import Fraction
import json
import re

VERSION = 1
MAX_NODES = 4096
MAX_DEPTH = 64
MAX_DIGITS = 1024
IDENTIFIER = re.compile(r"[A-Za-z][A-Za-z0-9_]{0,63}\Z")
INTEGER = re.compile(r"-?(0|[1-9][0-9]*)\Z")
DECIMAL = re.compile(r"-?[0-9]+(?:\.[0-9]+)?\Z")

class Kind(StrEnum):
    INTEGER = "integer"
    RATIONAL = "rational"
    SYMBOL = "symbol"
    ADD = "add"
    MUL = "mul"
    POW = "pow"
    SIN = "sin"
    COS = "cos"
    FUNCTION = "function"
    MATRIX = "matrix"
    MATMUL = "matmul"
    HOLE = "hole"
    MALFORMED = "malformed"
    ROW = "row"
    INTEGRAL = "integral"

class Domain(StrEnum):
    COMPLEX = "complex"
    REAL = "real"
    POSITIVE = "positive"

class Operation(StrEnum):
    EVALUATE = "evaluate"
    EXPAND = "expand"
    DIFFERENTIATE = "differentiate"
    SUBSTITUTE = "substitute"

class Status(StrEnum):
    OK = "ok"
    UNSUPPORTED = "unsupported"
    INVALID = "invalid"
    ERROR = "error"
    CANCELLED = "cancelled"
    STALE = "stale"
    CLOSED = "closed"
    TIMEOUT = "timeout"

class Backend(StrEnum):
    SYMPY = "sympy"
    SYMENGINE = "symengine"

class BoundaryError(ValueError):
    def __init__(self, message, node_id="", status=Status.INVALID):
        super().__init__(message)
        self.node_id, self.status = node_id, status

@dataclass(frozen=True)
class Node:
    kind: Kind
    values: tuple[str, ...] = ()
    children: tuple["Node", ...] = ()
    id: str = "source"

    def wire(self):
        return {"kind": self.kind.value, "values": list(self.values),
                "children": [n.wire() for n in self.children], "id": self.id}

    @classmethod
    def read(cls, value, depth=0, budget=None):
        budget = [MAX_NODES] if budget is None else budget
        budget[0] -= 1
        if depth > MAX_DEPTH or budget[0] < 0:
            raise BoundaryError("Expression exceeds depth/node budget")
        if not isinstance(value, dict) or set(value) != {"kind", "values", "children", "id"}:
            raise BoundaryError("Malformed node")
        if not isinstance(value["id"], str) or len(value["id"]) > 256:
            raise BoundaryError("Invalid node identity")
        if not isinstance(value["values"], list) or any(not isinstance(v, str) or len(v) > 4096 for v in value["values"]):
            raise BoundaryError("Invalid node payload", value["id"])
        if not isinstance(value["children"], list):
            raise BoundaryError("Invalid children", value["id"])
        try:
            kind = Kind(value["kind"])
        except (ValueError, TypeError) as exc:
            raise BoundaryError("Unknown notation kind", value["id"]) from exc
        return cls(kind, tuple(value["values"]), tuple(cls.read(c, depth + 1, budget) for c in value["children"]), value["id"])

    def validate(self, symbols=None, depth=0, budget=None):
        budget = [MAX_NODES] if budget is None else budget
        budget[0] -= 1
        if depth > MAX_DEPTH or budget[0] < 0:
            raise BoundaryError("Expression exceeds depth/node budget", self.id)
        symbols = {} if symbols is None else symbols
        k, v, c = self.kind, self.values, self.children
        def require(ok, message):
            if not ok:
                raise BoundaryError(message, self.id)
        def integer(s):
            return len(s) <= MAX_DIGITS and INTEGER.fullmatch(s)
        if k in (Kind.HOLE, Kind.MALFORMED, Kind.ROW):
            raise BoundaryError("Incomplete or ambiguous notation", self.id)
        if k == Kind.INTEGRAL:
            raise BoundaryError("Bound-variable substitution/evaluation is unsupported", self.id, Status.UNSUPPORTED)
        if k == Kind.INTEGER:
            require(len(v) == 1 and not c and integer(v[0]), "Invalid exact integer")
        elif k == Kind.RATIONAL:
            require(len(v) == 2 and not c and all(integer(x) for x in v) and int(v[1]) > 0, "Invalid exact rational")
        elif k == Kind.SYMBOL:
            require(len(v) == 3 and not c and IDENTIFIER.fullmatch(v[0]) and len(v[1]) <= 128, "Invalid symbol identity/label")
            try:
                Domain(v[2])
            except ValueError:
                raise BoundaryError("Unsupported symbol domain", self.id)
            require(v[0] not in symbols or symbols[v[0]] == v, "Conflicting symbol metadata")
            symbols[v[0]] = v
        elif k in (Kind.ADD, Kind.MUL):
            require(not v and len(c) >= 2, "Scalar operation needs at least two operands")
            require(all(x.kind not in (Kind.MATRIX, Kind.MATMUL) for x in c), "Scalar/matrix multiplication must be distinguished")
        elif k == Kind.POW:
            require(not v and len(c) == 2 and all(x.kind not in (Kind.MATRIX, Kind.MATMUL) for x in c), "Invalid scalar power")
        elif k in (Kind.SIN, Kind.COS):
            require(not v and len(c) == 1 and c[0].kind not in (Kind.MATRIX, Kind.MATMUL), "Invalid scalar function")
        elif k == Kind.FUNCTION:
            require(len(v) == 1 and IDENTIFIER.fullmatch(v[0]) and len(c) >= 1, "Invalid function")
        elif k == Kind.MATRIX:
            require(len(v) == 2 and all(x.isdigit() and len(x) <= 3 for x in v), "Invalid matrix dimensions")
            require(0 < int(v[0]) <= 16 and 0 < int(v[1]) <= 16 and int(v[0]) * int(v[1]) == len(c), "Invalid matrix shape")
            require(all(x.kind not in (Kind.MATRIX, Kind.MATMUL) for x in c), "Nested matrix element")
        elif k == Kind.MATMUL:
            require(not v and len(c) == 2 and all(x.kind == Kind.MATRIX for x in c), "Only explicit matrix products supported")
            require(c[0].values[1] == c[1].values[0], "Matrix dimensions do not agree")
        for child in c:
            child.validate(symbols, depth + 1, budget)
        return symbols

    def at(self, path):
        result = self
        for index in path:
            if type(index) is not int or not 0 <= index < len(result.children):
                raise BoundaryError("Invalid selection", result.id)
            result = result.children[index]
        return result

    def replace_at(self, path, result):
        if not path:
            return result
        self.at(path)  # Validate before mutation.
        children = list(self.children)
        children[path[0]] = children[path[0]].replace_at(path[1:], result)
        return replace(self, children=tuple(children))


def integer(value, id="integer"):
    return Node(Kind.INTEGER, (str(value),), id=id)


def rational(p, q, id="rational"):
    f = Fraction(p, q)
    return integer(f.numerator, id) if f.denominator == 1 else Node(Kind.RATIONAL, (str(f.numerator), str(f.denominator)), id=id)


def decimal_exact(text):
    if not isinstance(text, str) or not DECIMAL.fullmatch(text) or len(text) > MAX_DIGITS:
        raise BoundaryError("Exact decimals require bounded base-ten text; floats/exponents are not accepted")
    f = Fraction(text)
    return rational(f.numerator, f.denominator)


def symbol(identity="x", label=None, domain=Domain.COMPLEX):
    return Node(Kind.SYMBOL, (identity, label or identity, domain.value), id=identity)


def node(kind, *children, values=(), id="expression"):
    return Node(kind, values, children, id)


def to_text(n):
    return json.dumps({"notation": VERSION, "root": n.wire()}, ensure_ascii=False, separators=(",", ":"))


def from_text(text):
    if len(text.encode()) > 1024 * 1024:
        raise BoundaryError("Notation text exceeds budget")
    try:
        value = json.loads(text)
        if set(value) != {"notation", "root"} or value["notation"] != VERSION:
            raise ValueError("Unknown notation version")
        return Node.read(value["root"])
    except (ValueError, TypeError, RecursionError) as exc:
        raise BoundaryError("Malformed notation text") from exc


@dataclass(frozen=True)
class Request:
    root: Node
    operation: Operation = Operation.EVALUATE
    selection: tuple[int, ...] = ()
    variable: Node | None = None
    replacement: Node | None = None

    def validate(self):
        selected = self.root.at(self.selection)
        # Selecting only the body must not erase an enclosing binder's scope.
        # Until binders have an explicit semantic mapping, reject that context.
        ancestor = self.root
        for index in self.selection:
            if ancestor.kind == Kind.INTEGRAL:
                raise BoundaryError("Selected expression is inside an unsupported bound-variable scope",
                                    ancestor.id, Status.UNSUPPORTED)
            ancestor = ancestor.children[index]
        symbols = selected.validate()
        if self.operation in (Operation.DIFFERENTIATE, Operation.SUBSTITUTE):
            if self.variable is None or self.variable.kind != Kind.SYMBOL:
                raise BoundaryError("An explicit scalar symbol is required")
            self.variable.validate(symbols)
        if self.operation == Operation.SUBSTITUTE:
            if self.replacement is None:
                raise BoundaryError("A replacement expression is required")
            self.replacement.validate(symbols)
        return symbols

    def wire(self):
        self.validate()
        return {"expression": self.root.at(self.selection).wire(), "operation": self.operation.value,
                "variable": self.variable.wire() if self.variable else None,
                "replacement": self.replacement.wire() if self.replacement else None}

    @classmethod
    def read(cls, value):
        if not isinstance(value, dict) or set(value) != {"expression", "operation", "variable", "replacement"}:
            raise BoundaryError("Malformed operation")
        result = cls(Node.read(value["expression"]), Operation(value["operation"]),
                     variable=Node.read(value["variable"]) if value["variable"] is not None else None,
                     replacement=Node.read(value["replacement"]) if value["replacement"] is not None else None)
        result.validate()
        return result
