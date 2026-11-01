"""Production authoring reset through real macOS queue, renderer and App delivery."""
from std.ffi import external_call
from moxi import App, Rect, WindowConfig, KEY_ENTER, KEY_TAB, TEXT_INPUT_VIEW_KIND, BUTTON_KIND
from moxi.event import (KEY_DOWN_KIND, POINTER_DOWN_KIND, POINTER_UP_KIND, TEXT_INPUT_KIND,
                        COMPOSITION_UPDATE_KIND, ACTION_KIND, WINDOW_RESIZED_KIND)
from moxi.macos import MacOSWindow, MacOSRenderer
from moxi.authoring import Screen, UI, HandlerHost, reset, reset_headless, schedule_action, complete_action
from moxi import test_check


def require(condition: Bool, message: String):
    if not condition:
        print("FAIL:", message)
    test_check(condition)


struct Page(Screen):
    var text: String
    var clicks: Int
    var extra: String
    def __init__(out self):
        self.text = "fresh"
        self.clicks = 0
        self.extra = "second"
    def change(mut self, text: String):
        self.text = text
    def click(mut self):
        self.clicks += 1
    def change_extra(mut self, text: String):
        self.extra = text
    def render(self, mut ui: UI[Self]):
        ui.text_input("Draft", self.text, Self.change)
        ui.button("Act", Self.click)
        ui.text_input("Second", self.extra, Self.change_extra)


def target(app: App[HandlerHost[Page]], kind: Int) -> Int:
    for item in app.component.ui.controls:
        if item.kind == kind:
            return item.id
    return -1


def enqueue(kind: Int, key: Int = 0, target: Int = -1, x: Float32 = 0, y: Float32 = 0):
    external_call["moxi_probe_enqueue", NoneType](Int32(kind), Int32(key), Int32(target), x, y)


def drain(mut app: App[HandlerHost[Page]], mut window: MacOSWindow) raises -> Int:
    var accepted = 0
    while window.event_queue_depth() > 0:
        var event = window.poll_event()
        _ = app.update(event)
        accepted += 1
    return accepted


def main() raises:
    external_call["moxi_probe_init", NoneType]()
    external_call["moxi_probe_queue_wrap", NoneType]()
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    var real_window = external_call["moxi_probe_open_requested", Int32]() != 0
    if real_window:
        window.open(WindowConfig("Authoring reset smoke", 600, 900))
    var app = App(HandlerHost(Page()), Rect(0, 0, 600, 900))
    app.render(renderer)
    var input = target(app, TEXT_INPUT_VIEW_KIND)
    var button = target(app, BUTTON_KIND)
    var pending = schedule_action(app, button, 1, "pending", 60.0)
    var background = app.schedule_request(99, "app-owned background", 60.0)
    var bounds = app.view.bounds_for(button)
    enqueue(TEXT_INPUT_KIND)
    enqueue(TEXT_INPUT_KIND, target=input)
    enqueue(COMPOSITION_UPDATE_KIND)
    enqueue(KEY_DOWN_KIND, KEY_ENTER)
    enqueue(POINTER_DOWN_KIND, x=bounds.x + 8, y=bounds.y + 8)
    enqueue(POINTER_UP_KIND, x=bounds.x + 8, y=bounds.y + 8)
    enqueue(ACTION_KIND, target=button)
    enqueue(WINDOW_RESIZED_KIND)
    external_call["moxi_probe_seed_gesture", NoneType]()
    # Supported host transaction: invalidate native ingress and state, then reset.
    reset(app, Page(), window, renderer)
    require(external_call["moxi_probe_gesture_clear", Int32]() != 0, "native IME and pointer gesture cleared")
    require(drain(app, window) == 1, "reject seven old input packets; preserve resize")
    require(app.component.root.text == "fresh" and app.component.root.clicks == 0, "old queue cannot alter fresh root")
    require(not complete_action(app, pending), "same transaction rejects old asynchronous completion")
    require(app.request_is_current(background), "same transaction preserves unrelated App work")
    enqueue(TEXT_INPUT_KIND)
    require(drain(app, window) == 1 and app.component.root.text == "queued", "fresh native text works")
    button = target(app, BUTTON_KIND)
    enqueue(ACTION_KIND, target=button)
    require(drain(app, window) == 1 and app.component.root.clicks == 1, "fresh native semantic action works")
    var fresh = schedule_action(app, button, 1, "fresh", 60.0)
    require(complete_action(app, fresh), "enqueue fresh request completion")
    _ = app.advance_tasks(0.0)
    require(app.component.root.clicks == 2, "App delivers fresh request after native reset")
    _ = app.advance_tasks(0.0)
    require(app.component.root.clicks == 2, "request delivered exactly once")
    # Isolate target validation by deliberately bypassing native queue cleanup.
    # Application code must use integrated reset for a native window.
    input = target(app, TEXT_INPUT_VIEW_KIND)
    enqueue(TEXT_INPUT_KIND, target=input)
    reset_headless(app, Page())
    var addressed = window.poll_event()
    require(addressed.target == input and not app.update(addressed), "targeted native input rejects old monotonic ID")
    # Normal input remains an ordered stream inside a root lifetime. All four
    # packets arrive before dispatch/render, but follow intervening focus changes.
    enqueue(KEY_DOWN_KIND, KEY_TAB)
    enqueue(KEY_DOWN_KIND, KEY_ENTER)
    enqueue(KEY_DOWN_KIND, KEY_TAB)
    enqueue(TEXT_INPUT_KIND)
    require(drain(app, window) == 4, "drain complete Tab/activate/Tab/type batch")
    require(app.component.root.clicks == 1 and app.component.root.text == "fresh" and app.component.root.extra == "queued", "batch follows dispatch-time focus")
    bounds = app.view.bounds_for(target(app, TEXT_INPUT_VIEW_KIND))
    enqueue(POINTER_DOWN_KIND, x=bounds.x + 8, y=bounds.y + 8)
    enqueue(POINTER_UP_KIND, x=bounds.x + 8, y=bounds.y + 8)
    enqueue(TEXT_INPUT_KIND)
    require(drain(app, window) == 3 and app.component.root.text == "queued", "click then type follows new focus without intermediate render")
    # Already-dispatched pointer capture must also retire, not just queued input.
    button = target(app, BUTTON_KIND)
    input = target(app, TEXT_INPUT_VIEW_KIND)
    bounds = app.view.bounds_for(button)
    enqueue(POINTER_DOWN_KIND, x=bounds.x + 8, y=bounds.y + 8)
    require(drain(app, window) == 1 and app.runtime.pressed_view_id() == button, "seed active App pointer capture")
    external_call["moxi_probe_capture_ax", NoneType](Int32(button), Int32(input))
    reset(app, Page(), window, renderer)
    require(external_call["moxi_probe_published", Int32](Int32(target(app, BUTTON_KIND))) != 0, "reset publishes replacement accessibility snapshot")
    require(app.runtime.pressed_view_id() == -1 and app.runtime.hover_id() == -1, "reset retires App pointer captures")
    require(app.runtime.focus_id() == target(app, TEXT_INPUT_VIEW_KIND), "reset focuses fresh first control")
    enqueue(POINTER_UP_KIND, x=bounds.x + 8, y=bounds.y + 8)
    require(drain(app, window) == 1 and app.component.root.clicks == 0, "fresh release cannot finish old press")
    # Late callbacks retain old IDs even after native queue cleanup.
    external_call["moxi_probe_late_ax_callbacks", NoneType]()
    _ = drain(app, window)
    # The native snapshot may reject callbacks before they enqueue. Explicit
    # addressed packets must also be harmless if an adapter forwards them.
    enqueue(ACTION_KIND, target=button)
    enqueue(TEXT_INPUT_KIND, target=input)
    _ = drain(app, window)
    require(app.component.root.clicks == 0 and app.component.root.text == "fresh", "retired AX targets cannot mutate new root after reset")
    if real_window:
        window.close()
        require(not window.is_open(), "close real smoke window")
    print("PASS production native queue reset, gesture reset, resize preservation, fresh delivery, targeted stale IDs, sequential Tab/click/type batches, App pointer capture, late AX callbacks")
