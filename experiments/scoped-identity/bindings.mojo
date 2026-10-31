"""Owned callback descriptors. No pointer to application state is retained."""
from std.collections import Optional
from std.memory import Pointer, ArcPointer
from std.memory.alloc import alloc, dealloc, Layout, Allocation

comptime _Raw = Pointer[UInt8, MutUntrackedOrigin]


def _destroy[T: ImplicitlyCopyable & Deinitable](raw: _Raw):
    var ptr = raw.unsafe_bitcast[T]()
    ptr.unsafe_deinit_pointee()
    dealloc(Allocation(unsafe_owned_ptr=ptr, layout=Layout[T](count=1)))


struct _Storage(Movable):
    """Private erasure boundary: allocation, invoker and destructor agree on T."""
    var raw: _Raw
    var drop: def(_Raw) thin -> None

    def __init__[T: ImplicitlyCopyable & Deinitable](out self, value: T):
        var allocation = alloc(Layout[T](count=1))
        allocation.unsafe_ptr().unsafe_write(copy=value)
        self.raw = allocation^.unsafe_leak().unsafe_bitcast[UInt8]()
        self.drop = _destroy[T]

    def __deinit__(deinit self):
        self.drop(self.raw)


def _noop[S: ImplicitlyCopyable, C: ImplicitlyCopyable](raw: _Raw, mut state: S, mut context: C, text: String, checked: Bool):
    pass


def _local[S: ImplicitlyCopyable, C: ImplicitlyCopyable](raw: _Raw, mut state: S, mut context: C, text: String, checked: Bool):
    raw.unsafe_bitcast[def(mut S) thin -> None]()[](state)


def _text[S: ImplicitlyCopyable, C: ImplicitlyCopyable](raw: _Raw, mut state: S, mut context: C, text: String, checked: Bool):
    raw.unsafe_bitcast[def(mut S, String) thin -> None]()[](state, text)


def _toggle[S: ImplicitlyCopyable, C: ImplicitlyCopyable](raw: _Raw, mut state: S, mut context: C, text: String, checked: Bool):
    raw.unsafe_bitcast[def(mut S, Bool) thin -> None]()[](state, checked)


def _write_context[S: ImplicitlyCopyable, C: ImplicitlyCopyable](raw: _Raw, mut state: S, mut context: C, text: String, checked: Bool):
    raw.unsafe_bitcast[def(mut S, mut C) thin -> None]()[](state, context)


struct Action[S: ImplicitlyCopyable, C: ImplicitlyCopyable = NoneType](ImplicitlyCopyable):
    var _storage: Optional[ArcPointer[_Storage]]
    var _invoke: def(_Raw, mut Self.S, mut Self.C, String, Bool) thin -> None
    var _text: String
    var _checked: Bool

    def __init__(out self):
        self._storage = Optional[ArcPointer[_Storage]]()
        self._invoke = _noop[Self.S, Self.C]
        self._text = ""
        self._checked = False

    def __init__[T: ImplicitlyCopyable & Deinitable](out self, *, payload: T, invoke: def(_Raw, mut Self.S, mut Self.C, String, Bool) thin -> None):
        self._storage = Optional(ArcPointer(_Storage(payload)))
        self._invoke = invoke
        self._text = ""
        self._checked = False

    def __call__(self, mut state: Self.S, mut context: Self.C):
        if self._storage:
            self._invoke(self._storage.value()[].raw, state, context, self._text, self._checked)
        # Raw has erased its origin. Keep the owner alive through the invocation.
        _ = self

    def with_input(self, text: String, checked: Bool) -> Self:
        var result = self
        result._text = text
        result._checked = checked
        return result^


struct _ChildBinding[R: ImplicitlyCopyable, RC: ImplicitlyCopyable, S: ImplicitlyCopyable, C: ImplicitlyCopyable, K: ImplicitlyCopyable & Deinitable = Int](ImplicitlyCopyable):
    var key: Self.K
    var route: def(mut Self.R, Self.K, Action[Self.S, Self.C]) thin -> None
    var action: Action[Self.S, Self.C]

    def __init__(out self, key: Self.K, route: def(mut Self.R, Self.K, Action[Self.S, Self.C]) thin -> None, action: Action[Self.S, Self.C]):
        self.key = key
        self.route = route
        self.action = action


def _route[R: ImplicitlyCopyable, RC: ImplicitlyCopyable, S: ImplicitlyCopyable, C: ImplicitlyCopyable, K: ImplicitlyCopyable & Deinitable = Int](raw: _Raw, mut state: R, mut context: RC, text: String, checked: Bool):
    var binding = raw.unsafe_bitcast[_ChildBinding[R, RC, S, C, K]]()[]
    binding.route(state, binding.key, binding.action.with_input(text, checked))


def child_action[R: ImplicitlyCopyable, RC: ImplicitlyCopyable, S: ImplicitlyCopyable, C: ImplicitlyCopyable, K: ImplicitlyCopyable & Deinitable = Int](key: K, route: def(mut R, K, Action[S, C]) thin -> None, action: Action[S, C]) -> Action[R, RC]:
    return Action[R, RC](payload=_ChildBinding[R, RC, S, C, K](key, route, action), invoke=_route[R, RC, S, C, K])


struct _ContextChildBinding[R: ImplicitlyCopyable, RC: ImplicitlyCopyable, S: ImplicitlyCopyable, C: ImplicitlyCopyable, K: ImplicitlyCopyable & Deinitable = Int](ImplicitlyCopyable):
    var key: Self.K
    var route: def(mut Self.R, mut Self.RC, Self.K, Action[Self.S, Self.C]) thin -> None
    var action: Action[Self.S, Self.C]

    def __init__(out self, key: Self.K, route: def(mut Self.R, mut Self.RC, Self.K, Action[Self.S, Self.C]) thin -> None, action: Action[Self.S, Self.C]):
        self.key = key
        self.route = route
        self.action = action


def _context_route[R: ImplicitlyCopyable, RC: ImplicitlyCopyable, S: ImplicitlyCopyable, C: ImplicitlyCopyable, K: ImplicitlyCopyable & Deinitable = Int](raw: _Raw, mut state: R, mut context: RC, text: String, checked: Bool):
    var binding = raw.unsafe_bitcast[_ContextChildBinding[R, RC, S, C, K]]()[]
    binding.route(state, context, binding.key, binding.action.with_input(text, checked))


def child_action[R: ImplicitlyCopyable, RC: ImplicitlyCopyable, S: ImplicitlyCopyable, C: ImplicitlyCopyable, K: ImplicitlyCopyable & Deinitable = Int](key: K, route: def(mut R, mut RC, K, Action[S, C]) thin -> None, action: Action[S, C]) -> Action[R, RC]:
    return Action[R, RC](payload=_ContextChildBinding[R, RC, S, C, K](key, route, action), invoke=_context_route[R, RC, S, C, K])
