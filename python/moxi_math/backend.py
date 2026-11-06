"""Project D02's selected notation into D01's bounded persistent SymPy worker.

No UI model lives here. Mojo passes the actual selected tree and ancestor kinds;
only explicit scalar operators are projected. Unsupported syntax is never eval'd.
"""
from dataclasses import dataclass
from enum import IntEnum, StrEnum
import os
import sys

from moxi_math_probe.model import (
    Backend, BoundaryError, Kind, Operation, Request, Status, Node,
    integer, rational, decimal_exact, symbol, node,
)
from moxi_math_probe.controller import Controller

class Notation(IntEnum):
    TOKEN=0; HOLE=1; ERROR=2; ROW=3; FRACTION=4; ROOT=5; SCRIPTS=6
    GROUP=7; FUNCTION=8; MATRIX=9; SUM=10; INTEGRAL=11

class State(StrEnum):
    IDLE='idle'; PENDING='pending'; READY='ready'; STALE='stale'; UNSUPPORTED='unsupported'
    ERROR='error'; CANCELLED='cancelled'; CLOSED='closed'

@dataclass(frozen=True)
class Source:
    kind: Notation
    text: str
    extra: str
    children: tuple
    identity: int

def source(kind, text, extra, children, identity):
    return Source(Notation(kind), str(text), str(extra), tuple(children), int(identity))

def project(n):
    k=n.kind; c=n.children; identity=str(n.identity)
    if k == Notation.TOKEN:
        s=n.text
        if s.isascii() and (s.isdigit() or (s.startswith('-') and s[1:].isdigit())):
            return integer(s, identity)
        if s.isascii() and s.count('.') == 1 and s.replace('.', '', 1).isdigit():
            return decimal_exact(s)
        if s.isidentifier() and s.isascii():
            return symbol(s)
        raise BoundaryError('Token has no supported unambiguous scalar projection', identity, Status.UNSUPPORTED)
    if k in (Notation.HOLE, Notation.ERROR):
        raise BoundaryError('Incomplete or malformed selected notation', identity)
    if k in (Notation.SUM, Notation.INTEGRAL):
        raise BoundaryError('Binder scope is not supported by the initial adapter', identity, Status.UNSUPPORTED)
    if k == Notation.FRACTION:
        return node(Kind.MUL, project(c[0]), node(Kind.POW,project(c[1]),integer(-1)),id=identity)
    if k == Notation.ROOT:
        degree=integer(2) if c[0].kind == Notation.HOLE else project(c[0])
        if degree.kind != Kind.INTEGER or int(degree.values[0])<=0:
            raise BoundaryError('Root degree must be a positive exact integer',identity,Status.UNSUPPORTED)
        return node(Kind.POW,project(c[1]),rational(1,int(degree.values[0])),id=identity)
    if k == Notation.SCRIPTS:
        if any(c[i].kind != Notation.HOLE for i in (1,3,4)):
            raise BoundaryError('Subscripts and above/below placements have no scalar projection',identity,Status.UNSUPPORTED)
        return project(c[0]) if c[2].kind == Notation.HOLE else node(Kind.POW,project(c[0]),project(c[2]),id=identity)
    if k == Notation.GROUP:
        if (n.text,n.extra) != ('(',')'):
            raise BoundaryError('Only explicit parentheses project as scalar grouping',identity,Status.UNSUPPORTED)
        return project(c[0])
    if k == Notation.FUNCTION:
        kind={'sin':Kind.SIN,'cos':Kind.COS}.get(n.text,Kind.FUNCTION)
        return node(kind,project(c[0]),values=(n.text,) if kind==Kind.FUNCTION else (),id=identity)
    if k == Notation.MATRIX:
        return node(Kind.MATRIX,*(project(cell) for row in c for cell in row.children),values=(str(len(c)),str(len(c[0].children))),id=identity)
    if k == Notation.ROW:
        if len(c)==1:
            return project(c[0])
        # Explicit binary operators only; equal precedence is folded in written order.
        if not c or len(c)%2!=1 or any(c[i].kind!=Notation.TOKEN for i in range(1,len(c),2)):
            raise BoundaryError('Ambiguous row: use explicit +, -, *, × or named function',identity,Status.UNSUPPORTED)
        ops=[c[i].text for i in range(1,len(c),2)]
        if any(op not in ('+','-','−','*','×') for op in ops):
            raise BoundaryError('Unsupported row operator',identity,Status.UNSUPPORTED)
        values=[project(c[i]) for i in range(0,len(c),2)]
        # Multiplication binds before addition; no implicit adjacency/application.
        terms=[values[0]]; signs=[]
        for op,value in zip(ops,values[1:]):
            if op in ('*','×'):
                left=terms.pop()
                if left.kind==Kind.MATRIX and value.kind==Kind.MATRIX:
                    terms.append(node(Kind.MATMUL,left,value))
                else:
                    terms.append(node(Kind.MUL,left,value))
            else:
                signs.append(op); terms.append(value)
        result=terms[0]
        for op,value in zip(signs,terms[1:]):
            if op!='+': value=node(Kind.MUL,integer(-1),value)
            result=node(Kind.ADD,result,value,id=identity)
        return result
    raise BoundaryError('Unsupported notation',identity,Status.UNSUPPORTED)

def text(n):
    """Editable notation import, with no normalization of the source document."""
    k=n.kind; c=n.children; v=n.values
    if k==Kind.INTEGER: return v[0]
    if k==Kind.RATIONAL: return f'frac({v[0]}, {v[1]})'
    if k==Kind.SYMBOL:
        # D01 validates identity/assumption preservation before this call.
        return v[1]
    if k in (Kind.ADD,Kind.MUL,Kind.MATMUL):
        op=' + ' if k==Kind.ADD else ' * '
        parts=[text(x) for x in c]
        if k in (Kind.MUL,Kind.MATMUL):
            parts=[f'group("(", ")", {value})' if child.kind==Kind.ADD else value for child,value in zip(c,parts)]
        return 'row('+(', '+op.strip()+', ').join(parts)+')'
    if k==Kind.POW:
        base=text(c[0])
        if c[0].kind in (Kind.ADD,Kind.MUL,Kind.MATMUL): base=f'group("(", ")", {base})'
        return f'scripts({base}, ?, {text(c[1])}, ?, ?)'
    if k in (Kind.SIN,Kind.COS,Kind.FUNCTION):
        name={Kind.SIN:'sin',Kind.COS:'cos'}.get(k,v[0] if v else '')
        if len(c)!=1: raise BoundaryError('Only unary named functions import',n.id,Status.UNSUPPORTED)
        return 'fn("'+name+'", '+text(c[0])+')'
    if k==Kind.MATRIX:
        columns=int(v[1]); rows=[]
        for i in range(0,len(c),columns): rows.append('row('+', '.join(text(x) for x in c[i:i+columns])+')')
        return 'matrix('+', '.join(rows)+')'
    raise BoundaryError('Unsupported result notation',n.id,Status.UNSUPPORTED)

class Computation:
    def __init__(self, python=None):
        self.controller=Controller(Backend.SYMPY, command=[python or os.environ.get('MOXI_SYMPY_PYTHON',sys.executable), '-m', 'moxi_math_probe.sympy_worker'])
        self.state=State.IDLE; self.message='Optional persistent SymPy · explicit selected subtree only'
        self.result=''; self.revision=-1; self.target=-1; self.generation=0; self.closed=False
        self.new_result=False
    def submit(self, selected, ancestors, operation, revision, replacement=None):
        if self.closed: return False
        self.result=''
        try:
            if any(Notation(k) in (Notation.SUM,Notation.INTEGRAL) for k in ancestors):
                raise BoundaryError('Selection is inside an unsupported ancestor binder',str(selected.identity),Status.UNSUPPORTED)
            operation=Operation(operation)
            if operation==Operation.SUBSTITUTE and replacement is None:
                raise BoundaryError('Substitute requires an editable replacement expression',str(selected.identity))
            request=Request(project(selected),operation,
                variable=symbol('x') if operation in (Operation.DIFFERENTIATE,Operation.SUBSTITUTE) else None,
                replacement=project(replacement) if operation==Operation.SUBSTITUTE else None)
            request.validate()
            self.generation=self.controller.submit(request,int(revision))
            self.revision=int(revision); self.target=selected.identity
            self.state=State.PENDING; self.message='Pending · keep editing; Apply checks revision and identity'
            return True
        except (BoundaryError,ValueError) as e:
            # A rejected new selection also supersedes any in-flight request.
            self.generation=self.controller.cancel(terminate=True)
            self.state=State.UNSUPPORTED; self.message=str(e); return False
    def tick(self, revision):
        self.new_result=False
        if self.state==State.READY and int(revision)!=self.revision:
            self.state=State.STALE; self.message='Source changed after result arrived · Apply is stale; Result edits are retained'
            return True
        done=self.controller.poll()
        if done is None: return False
        if done.generation!=self.generation or self.closed or self.state!=State.PENDING: return False
        if int(revision)!=self.revision:
            self.state=State.STALE; self.message='Stale result retained for inspection; Apply cannot overwrite edits'
        elif done.status==Status.OK:
            self.state=State.READY; self.message='Result ready · editable; Apply is one undoable transaction'
        else:
            self.state=State.ERROR; self.message=f'{done.status}: {done.message}'
        if done.status==Status.OK:
            try:
                self.result=text(done.result)
                self.new_result=True
            except BoundaryError as e: self.state=State.UNSUPPORTED; self.message=str(e)
        return True
    def eligible(self, revision):
        return self.state==State.READY and int(revision)==self.revision and bool(self.result) and not self.closed
    def cancel(self):
        self.generation=self.controller.cancel(terminate=True); self.state=State.CANCELLED
        self.result=''; self.message='Cancelled · worker terminated; next request restarts it'
    def close(self):
        self.closed=True; self.state=State.CLOSED; self.controller.close()
