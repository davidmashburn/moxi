"""Exercise owned bindings independently of application state and native widgets."""
from std.memory import ArcPointer
from std.collections import List
from bindings import Action, _Raw
from runtime import Declaration, RetainedUI
from application import Application
from document import Document
from moxi import test_check, BUTTON_KIND


struct Ledger(ImplicitlyCopyable):
    var live: Int
    var drops: Int
    def __init__(out self):
        self.live = 0
        self.drops = 0


struct Tracked(ImplicitlyCopyable):
    var ledger: ArcPointer[Ledger]
    var message: String
    def __init__(out self, ledger: ArcPointer[Ledger]):
        self.ledger = ledger
        self.message = "owned descriptor survives temporary values and container copies"
        self.ledger[].live += 1
    def __init__(out self, *, copy: Self):
        self.ledger = copy.ledger
        self.message = copy.message
        self.ledger[].live += 1
    def __deinit__(deinit self):
        self.ledger[].live -= 1
        self.ledger[].drops += 1


def invoke(raw: _Raw, mut state: Application, mut context: NoneType, text: String, checked: Bool):
    test_check(raw.unsafe_bitcast[Tracked]()[] .message == "owned descriptor survives temporary values and container copies")
    state.next_key += 1


def main():
    var ledger = ArcPointer(Ledger())
    var retained = RetainedUI[Application]()
    var declarations = List[Declaration[Application, NoneType]]()
    declarations.append(Declaration[Application, NoneType]("/p0", BUTTON_KIND, "Tracked", action=Action[Application](payload=Tracked(ledger), invoke=invoke)))
    retained.rebuild(declarations)
    declarations.clear()
    test_check(ledger[].live == 1)
    var copied = retained
    var context: NoneType = None
    var first = Application()
    var second = first
    retained.controls[0].action(first, context)
    test_check(first.next_key == 4)
    test_check(second.next_key == 3)
    retained.rebuild(declarations)
    test_check(not retained.controls[0].action._storage)
    test_check(ledger[].live == 1)
    copied.controls[0].action(second, context)
    test_check(second.next_key == 4)
    copied.rebuild(declarations)
    test_check(ledger[].live == 0)
    var drops = ledger[].drops
    for _ in range(100):
        declarations.append(Declaration[Application, NoneType]("/p0", BUTTON_KIND, "Tracked", action=Action[Application](payload=Tracked(ledger), invoke=invoke)))
        retained.rebuild(declarations)
        declarations.clear()
        retained.controls[retained.index(retained.next_id - 1)].action(first, context)
        retained.rebuild(declarations)
        test_check(ledger[].live == 0)
    test_check(first.next_key == 104)
    test_check(ledger[].drops > drops)
    print("PASS binding copies share only immutable descriptors; current roots remain independent; retirement and 100 remounts release payloads")
