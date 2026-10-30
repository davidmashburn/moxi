"""Specialized field projection and keyed collection over the existing runtime.

No application-state pointer or borrow is retained. Reflection resolves the
field at compile time; the action receives the current parent's field.
"""
from std.collections import List
from runtime import UI, Pane
from bindings import Action


def _field_route[name: StringLiteral, S: ImplicitlyCopyable, C: ImplicitlyCopyable, Child: Pane](mut parent: S, mut context: C, key: Int, action: Action[Child, C]):
    comptime index = reflect[S].field_index[name]()
    action(rebind[Child](reflect[S].field_ref[index](parent)), context)


def field[name: StringLiteral, S: ImplicitlyCopyable, C: ImplicitlyCopyable](mut ui: UI[S, C], parent: S, context: C, *, key: Int):
    comptime index = reflect[S].field_index[name]()
    comptime Child = reflect[S].field_types()[index]
    comptime if conforms_to(Child, Pane):
        ui.child[Child](reflect[S].field_ref[index](parent), rebind[Child.Context](context), rebind[def(mut S, mut C, Int, Action[Child, Child.Context]) thin -> None](_field_route[name, S, C, Child]), key=key)
    else:
        comptime assert False, "field must conform to Pane"


struct Entry[T: Pane & Deinitable](ImplicitlyCopyable):
    var key: Int
    var value: Self.T
    def __init__(out self, key: Int, value: Self.T):
        self.key = key
        self.value = value


struct Keyed[T: Pane & Deinitable](Pane):
    comptime Context = Self.T.Context
    var entries: List[Entry[Self.T]]
    var next_key: Int
    def __init__(out self):
        self.entries = List[Entry[Self.T]]()
        self.next_key = 1

    def __init__(out self, *, copy: Self):
        self.entries = copy.entries.copy()
        self.next_key = copy.next_key

    def append(mut self, value: Self.T) -> Int:
        var key = self.next_key
        self.next_key += 1
        self.entries.append(Entry[Self.T](key, value))
        return key

    def remove(mut self, key: Int):
        var retained = List[Entry[Self.T]]()
        for entry in self.entries:
            if entry.key != key:
                retained.append(entry)
        self.entries = retained^

    def route(mut self, mut context: Self.Context, key: Int, action: Action[Self.T, Self.Context]):
        for i in range(len(self.entries)):
            if self.entries[i].key == key:
                action(self.entries[i].value, context)
                return

    def render(self, mut ui: UI[Self, Self.Context], context: Self.Context):
        for entry in self.entries:
            ui.child(entry.value, context, Self.route, key=entry.key)
