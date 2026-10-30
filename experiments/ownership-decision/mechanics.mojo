"""Compiler probes, not a public ownership or observed-cell implementation."""
from std.memory import ArcPointer
from moxi import App, Rect
from moxi.testing import test_check
from examples import TwoForms
from runtime import HandlerHost, Screen, UI


struct State(ImplicitlyCopyable):
    var value: Int
    def __init__(out self):
        self.value = 0


struct Shared(ImplicitlyCopyable):
    var storage: ArcPointer[State]
    def __init__(out self, storage: ArcPointer[State]):
        self.storage = storage

    def read_only_receiver(self):
        # Intentionally tests whether `self` prevents alias-mediated writes.
        self.storage[].value += 1


struct SharedScreen(Screen):
    var storage: ArcPointer[State]
    def __init__(out self, storage: ArcPointer[State]):
        self.storage = storage

    def render(self, mut ui: UI[Self]):
        self.storage[].value += 1
        ui.label(String(self.storage[].value))


def main() raises:
    var owner = ArcPointer(State())
    var shared = Shared(owner)
    shared.read_only_receiver()
    test_check(owner[].value == 1)
    print("PASS immutable receiver can mutate ArcPointer pointee")
    var before_handle = owner
    var before_value = owner[]
    shared.read_only_receiver()
    test_check(before_handle[].value == 2)
    test_check(before_value.value == 1)
    print("PASS copied handle aliases; copied value is an independent snapshot")
    var screen_state = ArcPointer(State())
    var host = HandlerHost(SharedScreen(screen_state))
    host.refresh()
    test_check(screen_state[].value == 2)
    print("PASS actual Screen.render(self, ui) permits alias-mediated mutation")
    var app = App(HandlerHost(TwoForms()), Rect(0, 0, 520, 900))
    test_check(app.component.renders == 1)
    print("PASS App(HandlerHost(TwoForms()), bounds) infers both type arguments")
