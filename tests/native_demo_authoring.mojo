"""Embedded page resets at the native input-batch boundary."""
from std.ffi import external_call
from moxi import (App, Rect, Event, FocusEvent, TEXT_INPUT_VIEW_KIND,
    BUTTON_KIND, TASK_COMPLETED, test_check)
from moxi.event import (ACTION_KIND, TEXT_INPUT_KIND, COMPOSITION_UPDATE_KIND,
    POINTER_DOWN_KIND, POINTER_UP_KIND, WINDOW_RESIZED_KIND)
from moxi.macos import MacOSWindow, MacOSRenderer
from moxi_demo import (DemoBrowserState, DEMO_FORM_ID, DEMO_COUNTER_ID,
    DEMO_ENTRY_VIEW_BASE, DEMO_RESET_BUTTON_ID)
from demo_authoring import select, target
from native_authoring import enqueue


def require(condition: Bool, message: String):
    if not condition:
        print("FAIL:", message)
    test_check(condition)


def main() raises:
    external_call["moxi_probe_init", NoneType]()
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    var app = App(DemoBrowserState(), Rect(0, 0, 1180, 760))
    select(app, DEMO_FORM_ID)
    var input = target(app, TEXT_INPUT_VIEW_KIND, "Name")
    var submit = target(app, BUTTON_KIND, "Submit")
    _ = app.dispatch(Event(FocusEvent(input)))
    app.render(renderer)
    external_call["moxi_probe_capture_ax", NoneType](Int32(submit), Int32(input))
    app.render(renderer)
    var sibling = app.schedule_request(99, "unrelated launcher work", 60.0)
    require(app.complete_request(sibling, TASK_COMPLETED), "app.complete_request(sibling, TASK_COMPLETED)")
    app.component.begin_input_batch()
    enqueue(ACTION_KIND, target=DEMO_RESET_BUTTON_ID)
    enqueue(TEXT_INPUT_KIND)
    enqueue(COMPOSITION_UPDATE_KIND)
    enqueue(ACTION_KIND, target=submit)
    # Navigation and resize behind Reset remain in order and are not dropped.
    enqueue(ACTION_KIND, target=DEMO_ENTRY_VIEW_BASE + DEMO_COUNTER_ID)
    enqueue(WINDOW_RESIZED_KIND, x=1180, y=760)
    var delivered = 0
    while window.event_queue_depth() > 0:
        _ = app.dispatch(window.poll_event())
        delivered += 1
    require(delivered == 6, "delivered == 6")
    require(app.component.form.component.root.name == "queued", "app.component.form.component.root.name == \"queued\"")
    require(app.component.form.component.root.submissions == 1, "app.component.form.component.root.submissions == 1")
    require(app.component.finish_input_batch(), "app.component.finish_input_batch()")
    app.rebuild()
    app.render(renderer)
    require(app.component.form.component.root.name == "", "app.component.form.component.root.name == \"\"")
    require(app.component.form.component.root.submissions == 0, "app.component.form.component.root.submissions == 0")
    require(app.component.selected_id == DEMO_COUNTER_ID, "app.component.selected_id == DEMO_COUNTER_ID")
    require(app.requests.ready_count() == 1, "app.requests.ready_count() == 1")
    var result = app.requests.pop_ready()
    require(result.key == 99 and app.requests.should_deliver(result), "result.key == 99 and app.requests.should_deliver(result)")
    # Both queued pointer clicks still belong to the old Counter lifetime.
    select(app, DEMO_COUNTER_ID)
    var button = target(app, BUTTON_KIND, "Increment")
    var bounds = app.view.bounds_for(button)
    require(button > 0 and bounds.width > 0, "Counter must be mounted before pointer input")
    app.component.begin_input_batch()
    enqueue(ACTION_KIND, target=DEMO_RESET_BUTTON_ID)
    enqueue(POINTER_DOWN_KIND, x=bounds.x + 8, y=bounds.y + 8)
    enqueue(POINTER_UP_KIND, x=bounds.x + 8, y=bounds.y + 8)
    enqueue(ACTION_KIND, target=button)
    while window.event_queue_depth() > 0:
        _ = app.dispatch(window.poll_event())
    require(app.component.counter.component.root.count == 2, "app.component.counter.component.root.count == 2")
    require(app.component.finish_input_batch(), "app.component.finish_input_batch()")
    app.rebuild()
    app.render(renderer)
    require(app.component.counter.component.root.count == 0, "app.component.counter.component.root.count == 0")
    enqueue(ACTION_KIND, target=button)
    _ = app.dispatch(window.poll_event())
    require(app.component.counter.component.root.count == 0, "app.component.counter.component.root.count == 0")
    # A delayed pointer-up from the retired lifetime cannot click the new page.
    app.component.begin_input_batch()
    enqueue(POINTER_DOWN_KIND, x=bounds.x + 8, y=bounds.y + 8)
    enqueue(ACTION_KIND, target=DEMO_RESET_BUTTON_ID)
    while window.event_queue_depth() > 0:
        _ = app.dispatch(window.poll_event())
    require(app.component.finish_input_batch(), "app.component.finish_input_batch()")
    app.rebuild()
    enqueue(POINTER_UP_KIND, x=bounds.x + 8, y=bounds.y + 8)
    _ = app.dispatch(window.poll_event())
    require(app.component.counter.component.root.count == 0, "app.component.counter.component.root.count == 0")
    # Objects captured before Reset retain retired targets, not new controls.
    select(app, DEMO_FORM_ID)
    app.render(renderer)
    external_call["moxi_probe_late_ax_callbacks", NoneType]()
    while window.event_queue_depth() > 0:
        _ = app.dispatch(window.poll_event())
    require(app.component.form.component.root.name == "", "app.component.form.component.root.name == \"\"")
    require(app.component.form.component.root.submissions == 0, "app.component.form.component.root.submissions == 0")
    input = target(app, TEXT_INPUT_VIEW_KIND, "Name")
    _ = app.dispatch(Event(FocusEvent(input)))
    app.render(renderer)
    enqueue(TEXT_INPUT_KIND)
    require(app.dispatch(window.poll_event()), "app.dispatch(window.poll_event())")
    require(app.component.form.component.root.name == "queued", "app.component.form.component.root.name == \"queued\"")
    print("PASS native embedded page reset, queue order, and late callbacks")
