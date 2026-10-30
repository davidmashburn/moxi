"""Headless ownership transport comparison; no widget/reactivity implementation.

One policy engine prevents policy differences from prejudicing the comparison.
Projection uses a temporary borrow, shared ownership uses copied Arc handles,
and controlled ownership queues intents until the parent can mutate its value.
"""
from std.collections import List
from std.memory import ArcPointer
from moxi.testing import test_check


struct Values(ImplicitlyCopyable):
    var name: String
    var start: Int
    var end: Int

    def __init__(out self, name: String = "Ada", start: Int = 10, end: Int = 20):
        self.name = name
        self.start = start
        self.end = end

    def same(self, other: Self) -> Bool:
        return self.name == other.name and self.start == other.start and self.end == other.end


struct Edit(ImplicitlyCopyable):
    # 0 name, 1 interval, 2 undo, 3 redo, 4 save current owner state.
    var kind: Int
    var name: String
    var start: Int
    var end: Int

    def __init__(out self, kind: Int, name: String = "", start: Int = 0, end: Int = 0):
        self.kind = kind
        self.name = name
        self.start = start
        self.end = end


struct Token(ImplicitlyCopyable):
    var identity: Int
    var revision: Int
    var request: Int

    def __init__(out self, identity: Int, revision: Int, request: Int):
        self.identity = identity
        self.revision = revision
        self.request = request


struct Document(Movable):
    var value: Values
    var past: List[Values]
    var future: List[Values]
    var revision: Int
    var identity: Int
    var request: Int
    var saved: Values
    var saves: Int

    def __init__(out self, identity: Int = 1):
        self.value = Values()
        self.past = List[Values]()
        self.future = List[Values]()
        self.revision = 0
        self.identity = identity
        self.request = 0
        self.saved = Values()
        self.saves = 0

    def commit(mut self, proposed: Values) -> Bool:
        var next = proposed
        var normalized = String(next.name.strip())
        next.name = normalized
        if next.name == "" or next.start >= next.end or next.same(self.value):
            return False
        self.past.append(self.value)
        self.future = List[Values]()
        self.value = next
        self.revision += 1
        return True

    def apply(mut self, edit: Edit) -> Bool:
        if edit.kind == 0:
            var next = self.value
            next.name = edit.name
            return self.commit(next)
        if edit.kind == 1:
            var next = self.value
            next.start = edit.start
            next.end = edit.end
            return self.commit(next)
        if edit.kind == 2:
            if len(self.past) == 0:
                return False
            self.future.append(self.value)
            self.value = self.past.pop()
            self.revision += 1
            return True
        if edit.kind == 3:
            if len(self.future) == 0:
                return False
            self.past.append(self.value)
            self.value = self.future.pop()
            self.revision += 1
            return True
        if edit.kind == 4:
            self.saved = self.value
            self.saves += 1
            return True
        return False

    def begin_request(mut self) -> Token:
        self.request += 1
        return Token(self.identity, self.revision, self.request)

    def complete(mut self, token: Token, name: String) -> Bool:
        if token.identity != self.identity or token.revision != self.revision or token.request != self.request:
            return False
        self.request += 1  # Consume even a rejected/no-op completion.
        return self.apply(Edit(0, name))


trait Transport(Movable):
    def current(self) -> Values: ...
    def send(mut self, edit: Edit): ...
    def settle(mut self): ...
    def revision(self) -> Int: ...
    def saved(self) -> Values: ...
    def saves(self) -> Int: ...


struct Projection(Transport):
    var document: Document

    def __init__(out self):
        self.document = Document()

    def project(mut self) -> ref[self.document] Document:
        return self.document

    def send(mut self, edit: Edit):
        # A current-state borrow exists only during this callback.
        ref document = self.project()
        _ = document.apply(edit)

    def settle(mut self):
        pass

    def current(self) -> Values:
        return self.document.value
    def revision(self) -> Int:
        return self.document.revision
    def saved(self) -> Values:
        return self.document.saved
    def saves(self) -> Int:
        return self.document.saves


struct Shared(Transport):
    var owner: ArcPointer[Document]
    var first: ArcPointer[Document]
    var second: ArcPointer[Document]

    def __init__(out self):
        self.owner = ArcPointer(Document())
        self.first = self.owner
        self.second = self.owner

    def send(mut self, edit: Edit):
        # B's strongest policy-preserving variant: share an owner, not raw fields.
        _ = self.first[].apply(edit)

    def settle(mut self):
        pass

    def current(self) -> Values:
        return self.second[].value
    def revision(self) -> Int:
        return self.owner[].revision
    def saved(self) -> Values:
        return self.owner[].saved
    def saves(self) -> Int:
        return self.owner[].saves


struct Controlled(Transport):
    var document: Document
    var pending: List[Edit]

    def __init__(out self):
        self.document = Document()
        self.pending = List[Edit]()

    def send(mut self, edit: Edit):
        # C's callback records intent; the parent applies it after child dispatch.
        self.pending.append(edit)

    def settle(mut self):
        for edit in self.pending:
            _ = self.document.apply(edit)
        self.pending = List[Edit]()

    def current(self) -> Values:
        return self.document.value
    def revision(self) -> Int:
        return self.document.revision
    def saved(self) -> Values:
        return self.document.saved
    def saves(self) -> Int:
        return self.document.saves


def event[T: Transport](mut owner: T, edit: Edit):
    owner.send(edit)
    owner.settle()


def exercise[T: Transport](mut owner: T):
    # Both views start from the same owner, with separate uncommitted drafts.
    var first = owner.current()
    var second = owner.current()
    var draft = first
    draft.name = "Canceled draft"
    test_check(owner.current().name == "Ada")
    test_check(second.name == "Ada")

    event(owner, Edit(0, " Grace "))
    first = owner.current()
    second = owner.current()
    test_check(first.name == "Grace" and second.name == "Grace")
    test_check(owner.revision() == 1)

    event(owner, Edit(0, "  "))  # Rejected edits create no history entry.
    event(owner, Edit(0, "Grace"))  # Nor do no-ops.
    test_check(owner.revision() == 1)

    # Moving 10..20 to 30..40 must not commit an intermediate 30..20.
    event(owner, Edit(1, start=30, end=40))
    test_check(owner.current().start == 30 and owner.current().end == 40)
    test_check(owner.revision() == 2)
    event(owner, Edit(1, start=50, end=40))
    test_check(owner.revision() == 2)
    event(owner, Edit(2))
    test_check(owner.current().start == 10 and owner.current().end == 20)
    test_check(owner.current().name == "Grace")
    event(owner, Edit(3))
    test_check(owner.current().start == 30 and owner.revision() == 4)
    event(owner, Edit(2))
    event(owner, Edit(0, "Katherine"))
    var revision = owner.revision()
    event(owner, Edit(3))  # A new edit clears the redo branch.
    test_check(owner.current().name == "Katherine" and owner.revision() == revision)

    # Save is an owner command. It does not capture the old rendered `second`.
    test_check(second.name == "Grace")
    event(owner, Edit(4))
    test_check(owner.saved().name == "Katherine" and owner.saves() == 1)

    # Two commands before refresh retain intent and are processed in order.
    owner.send(Edit(0, "Dorothy"))
    owner.send(Edit(4))
    owner.settle()
    test_check(owner.saved().name == "Dorothy" and owner.saves() == 2)

    # A repeatable bounded stress trace: semantics must survive many edits/undos.
    for index in range(100):
        var before = owner.current()
        event(owner, Edit(1, start=index * 10, end=index * 10 + 5))
        var after = owner.current()
        event(owner, Edit(2))
        test_check(owner.current().same(before))
        event(owner, Edit(3))
        test_check(owner.current().same(after))
        event(owner, Edit(4))
        test_check(owner.saved().same(after))


def async_policy():
    var document = Document()
    var old = document.begin_request()
    var latest = document.begin_request()
    test_check(not document.complete(old, "Obsolete"))
    test_check(document.complete(latest, "Grace"))
    test_check(not document.complete(latest, "Duplicate"))

    var before_undo = document.begin_request()
    _ = document.apply(Edit(0, "Katherine"))
    _ = document.apply(Edit(2))
    test_check(document.value.name == "Grace")
    test_check(not document.complete(before_undo, "Stale after undo"))

    var before_replace = document.begin_request()
    document = Document(2)
    _ = document.begin_request()
    test_check(not document.complete(before_replace, "Wrong entity"))


def negative_controls():
    var shared = Shared()
    var fake_snapshot = shared.owner
    var real_snapshot = shared.owner[].value
    shared.send(Edit(0, "Grace"))
    test_check(fake_snapshot[].value.name == "Grace")
    test_check(real_snapshot.name == "Ada")

    # Raw shared mutation bypasses policy; a mutable projection can do the same.
    shared.first[].value.start = 30
    test_check(shared.second[].value.start >= shared.second[].value.end)
    test_check(shared.owner[].revision == 1)
    var projection = Projection()
    projection.document.value.start = 30
    test_check(projection.current().start >= projection.current().end)
    test_check(projection.revision() == 0)

    var controlled = Controlled()
    var old_props = controlled.current()
    controlled.send(Edit(0, "Grace"))
    test_check(controlled.current().name == "Ada")  # Intent is still queued.
    controlled.settle()
    test_check(controlled.current().name == "Grace" and old_props.name == "Ada")
    # Capturing old props for Save would be wrong for a 'save latest' contract.
    test_check(old_props.name != controlled.current().name)

    # All three can expose stale UI snapshots until their host refreshes them.
    var old_projection_view = projection.current()
    projection.send(Edit(0, "Katherine"))  # Rejected: interval already invalid.
    test_check(projection.current().same(old_projection_view))
    var fresh_projection = Projection()
    var old_view = fresh_projection.current()
    fresh_projection.send(Edit(0, "Katherine"))
    test_check(old_view.name != fresh_projection.current().name)


def main():
    var a = Projection()
    exercise(a)
    print("PASS A: current-state projection contract and 100 edit/undo/redo/save cycles")
    var b = Shared()
    exercise(b)
    print("PASS B: shared owner contract and 100 edit/undo/redo/save cycles")
    var c = Controlled()
    exercise(c)
    print("PASS C: controlled intent contract and 100 edit/undo/redo/save cycles")
    async_policy()
    print("PASS request supersession, duplicate completion, undo ABA, entity replacement")
    negative_controls()
    print("PASS negative controls expose alias snapshots, policy bypass, and stale props")
