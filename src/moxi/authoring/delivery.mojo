"""Host delivery identity; contains no pointer to application state."""
from std.memory import ArcPointer, Pointer
from .actions import Action
from ..event import Event


struct _Marker(ImplicitlyCopyable):
    var reserved: Int
    def __init__(out self):
        self.reserved = 0


struct DeliveryScope(ImplicitlyCopyable):
    # Envelopes keep this allocation alive, preventing address reuse while stale
    # work exists. Compare identity only; never dereference application state.
    var _marker: ArcPointer[_Marker]
    def __init__(out self):
        self._marker = ArcPointer(_Marker())
    def matches(self, other: Self) -> Bool:
        return Pointer(to=self._marker[]) == Pointer(to=other._marker[])


struct QueuedEvent(ImplicitlyCopyable):
    var scope: DeliveryScope
    var event: Event
    def __init__(out self, scope: DeliveryScope, event: Event):
        self.scope = scope
        self.event = event


struct CapturedAction[S: ImplicitlyCopyable](ImplicitlyCopyable):
    var scope: DeliveryScope
    var target: Int
    var action: Action[Self.S]
    def __init__(out self, scope: DeliveryScope, target: Int, action: Action[Self.S]):
        self.scope = scope
        self.target = target
        self.action = action
