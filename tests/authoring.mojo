"""Authoring lifetimes, request delivery, and integrated reset contracts."""

from moxi import (
    App,
    CompositionEvent,
    SemanticActionEvent,
    ACTION_PRESS,
    TEXT_INPUT_VIEW_KIND,
    BUTTON_KIND,
    Event,
    Point,
    PointerEvent,
    POINTER_DOWN_KIND,
    Rect,
    RequestScopeHandle,
    ResizeEvent,
    Size,
    TASK_CANCELLED,
    TASK_COMPLETED,
    TASK_FAILED,
    TestRenderer,
    TestWindow,
    WindowBackend,
    WindowConfig,
    test_check,
)
from moxi.authoring import (
    Action,
    HandlerHost,
    Keyed,
    Pane,
    Screen,
    UI,
    complete_action,
    field,
    reset,
    reset_headless,
    schedule_action,
    update_model,
)

struct Leaf(Pane):
    comptime Context = NoneType
    var marker: Int
    var hits: Int

    def __init__(out self, marker: Int = 0):
        self.marker = marker
        self.hits = 0

    def tap(mut self):
        self.hits += 1

    def render(self, mut ui: UI[Self, Self.Context], context: NoneType):
        ui.button("item-" + String(self.marker), Self.tap)

struct Root(Screen):
    var count: Int
    var draft: String
    var leaf: Leaf
    var children: Keyed[Leaf]

    def __init__(out self):
        self.count = 0
        self.draft = "draft"
        self.leaf = Leaf(9)
        self.children = Keyed[Leaf]()
        _ = self.children.append(Leaf(1))
        _ = self.children.append(Leaf(2))

    def edit_draft(mut self, value: String):
        self.draft = value

    def increment(mut self):
        self.count += 1

    def route(mut self, key: Int, action: Action[Keyed[Leaf]]):
        var context = NoneType()
        action(self.children, context)

    def replace_values(mut self):
        self = Root()

    def assign_children(mut self):
        self.children = Keyed[Leaf]()
        _ = self.children.append(Leaf(1))

    def reset_children(mut self):
        self.children.reset()
        _ = self.children.append(Leaf(3))

    def reorder_children(mut self):
        var first = self.children.entries[0]
        self.children.entries[0] = self.children.entries[1]
        self.children.entries[1] = first

    def render(self, mut ui: UI[Self]):
        ui.button("root", Self.increment)
        ui.text_input("Draft", self.draft, Self.edit_draft)
        field["leaf"](ui, self, NoneType(), key=1)
        ui.child(self.children, NoneType(), Self.route, key=2)

def path_button_id(app: App[HandlerHost[Root]], path: String) -> Int:
    for control in app.component.ui.controls:
        if control.active and control.kind == BUTTON_KIND and control.path == path:
            return control.id
    test_check(False)
    return -1

def root_button_id(app: App[HandlerHost[Root]]) -> Int:
    return path_button_id(app, "/p0")

def keyed_button_id(app: App[HandlerHost[Root]], key: Int) -> Int:
    return path_button_id(app, "/k1:2/k1:" + String(key) + "/p0")

def root_and_copy_lifetimes():
    var app = App(HandlerHost(Root()), Rect(0.0, 0.0, 520.0, 320.0))
    var target = root_button_id(app)
    var request = schedule_action(app, target, 10, "root", 60.0)
    test_check(request.handle.is_valid())

    update_model(app, Root.increment)
    test_check(app.component.root.count == 1)
    test_check(complete_action(app, request))
    test_check(app.requests.ready_count() == 1)
    test_check(app.component.root.count == 1)
    test_check(app.advance_tasks(0.0))
    test_check(app.component.root.count == 2)
    test_check(not complete_action(app, request))
    test_check(not app.advance_tasks(0.0))

    var assignment = schedule_action(app, target, 11, "assignment", 60.0)
    update_model(app, Root.replace_values)
    test_check(root_button_id(app) == target)
    test_check(app.component.root.count == 0)
    test_check(complete_action(app, assignment))
    test_check(app.advance_tasks(0.0))
    test_check(app.component.root.count == 1)

    var stale = schedule_action(app, root_button_id(app), 12, "stale", 60.0)
    reset_headless(app, Root())
    test_check(app.component.root.count == 0)
    test_check(root_button_id(app) != target)
    test_check(not complete_action(app, stale))
    test_check(not app.advance_tasks(0.0))
    test_check(app.pending_request_count() == 0)

    var source = App(HandlerHost(Root()), Rect(0.0, 0.0, 520.0, 320.0))
    var source_target = root_button_id(source)
    var source_request = schedule_action(source, source_target, 20, "source", 60.0)
    var copy = App(source.component, Rect(0.0, 0.0, 520.0, 320.0))
    test_check(not complete_action(copy, source_request))
    test_check(complete_action(source, source_request))
    test_check(source.advance_tasks(0.0))
    test_check(source.component.root.count == 1)
    test_check(copy.component.root.count == 0)
    var copy_request = schedule_action(copy, root_button_id(copy), 21, "copy", 60.0)
    test_check(complete_action(copy, copy_request))
    test_check(copy.advance_tasks(0.0))
    test_check(copy.component.root.count == 1)
    test_check(source.component.root.count == 1)

def collection_lifetimes_and_reorder():
    var assigned = App(HandlerHost(Root()), Rect(0.0, 0.0, 520.0, 320.0))
    var stable = keyed_button_id(assigned, 1)
    var assigned_request = schedule_action(assigned, stable, 30, "assigned", 60.0)
    update_model(assigned, Root.assign_children)
    test_check(keyed_button_id(assigned, 1) == stable)
    test_check(complete_action(assigned, assigned_request))
    test_check(assigned.advance_tasks(0.0))
    test_check(assigned.component.root.children.entries[0].value.hits == 1)

    var reset_app = App(HandlerHost(Root()), Rect(0.0, 0.0, 520.0, 320.0))
    var old_key = reset_app.component.root.children.entries[0].key
    var old_target = keyed_button_id(reset_app, 1)
    var old_request = schedule_action(reset_app, old_target, 31, "removed", 60.0)
    update_model(reset_app, Root.reset_children)
    test_check(reset_app.component.root.children.entries[0].key != old_key)
    test_check(keyed_button_id(reset_app, 3) != old_target)
    test_check(not complete_action(reset_app, old_request))
    test_check(not reset_app.advance_tasks(0.0))

    var reordered = App(HandlerHost(Root()), Rect(0.0, 0.0, 520.0, 320.0))
    var first = keyed_button_id(reordered, 1)
    var second = keyed_button_id(reordered, 2)
    var first_request = schedule_action(reordered, first, 40, "first", 60.0)
    var second_request = schedule_action(reordered, second, 41, "second", 60.0)
    update_model(reordered, Root.reorder_children)
    test_check(keyed_button_id(reordered, 2) == second)
    test_check(keyed_button_id(reordered, 1) == first)
    test_check(complete_action(reordered, first_request))
    test_check(complete_action(reordered, second_request))
    test_check(reordered.advance_tasks(0.0))
    test_check(reordered.component.root.children.entries[0].value.hits == 1)
    test_check(reordered.component.root.children.entries[1].value.hits == 1)

def request_statuses_and_bounded_storage():
    var app = App(HandlerHost(Root()), Rect(0.0, 0.0, 520.0, 320.0))
    var target = root_button_id(app)
    var superseded = schedule_action(app, target, 50, "old", 60.0)
    var current = schedule_action(app, target, 50, "new", 60.0)
    test_check(not complete_action(app, superseded))
    test_check(complete_action(app, current, TASK_FAILED))
    test_check(not app.advance_tasks(0.0))
    test_check(app.component.root.count == 0)

    var cancelled = schedule_action(app, target, 51, "cancelled", 60.0)
    test_check(complete_action(app, cancelled, TASK_CANCELLED))
    test_check(not app.advance_tasks(0.0))
    test_check(not complete_action(app, cancelled))

    var done = schedule_action(app, target, 52, "done", 60.0)
    test_check(complete_action(app, done))
    test_check(not complete_action(app, done))
    test_check(app.advance_tasks(0.0))
    test_check(app.component.root.count == 1)
    test_check(not app.advance_tasks(0.0))

    var background = app.schedule_request(900, "background", 60.0)
    var owned = schedule_action(app, target, 53, "owned", 60.0)
    reset_headless(app, Root())
    test_check(app.request_is_current(background))
    test_check(not complete_action(app, owned))
    test_check(not app.advance_tasks(0.0))
    test_check(app.request_is_current(background))
    test_check(app.complete_request(background, TASK_COMPLETED))
    test_check(not app.advance_tasks(0.0))
    test_check(not app.request_is_current(background))

    for _ in range(1000):
        var churn_target = root_button_id(app)
        var churned = schedule_action(app, churn_target, 100, "churn", 60.0)
        reset_headless(app, Root())
        test_check(not complete_action(app, churned))
        _ = app.advance_tasks(0.0)
    test_check(app.requests.mounted_scope_count() == 0)
    test_check(app.requests.retained_count() == 0)
    test_check(len(app.requests.tasks.tasks) == 0)
    test_check(len(app.component._request_scopes) == 0)
    test_check(len(app.component._pending_requests) == 0)

    var overflow_target = root_button_id(app)
    var capacity = app.requests.capacity()
    for index in range(capacity * 2 + 4):
        var overflow = schedule_action(
            app, overflow_target, 1000 + index, "overflow", 60.0
        )
        test_check(complete_action(app, overflow))
    test_check(app.requests.ready_count() <= capacity)
    test_check(app.requests.dropped_count() > 0)
    test_check(len(app.component._pending_requests) <= capacity + 1)
    _ = app.advance_tasks(0.0)
    test_check(app.pending_request_count() == 0)
    test_check(app.retained_request_count() == 0)
    test_check(len(app.requests.tasks.tasks) == 0)
    test_check(len(app.component._pending_requests) == 0)

    # A caller can close a scope using the existing App scheduler API. A later
    # submission for the still-mounted control must allocate a live scope.
    reset_headless(app, Root())
    target = root_button_id(app)
    var closed = schedule_action(app, target, 8, "closed", 60.0)
    test_check(app.cancel_request_scope(RequestScopeHandle(closed.handle.scope_id)))
    var reopened = schedule_action(app, target, 8, "reopened", 0.0)
    test_check(reopened.handle.is_valid())
    test_check(reopened.handle.scope_id != closed.handle.scope_id)
    test_check(app.advance_tasks(0.0))
    test_check(app.component.root.count == 1)

struct UnsupportedWindow(WindowBackend):
    def __init__(out self):
        pass

    def supports_input_reset(self) -> Bool:
        return False

def integrated_reset_and_backend_guard() raises:
    var app = App(HandlerHost(Root()), Rect(0.0, 0.0, 520.0, 320.0))
    var window = TestWindow()
    window.open(WindowConfig("authoring", 320.0, 180.0))
    window.enqueue(Event(ResizeEvent(Size(320.0, 180.0))))
    var old_target = root_button_id(app)
    var bounds = app.view.bounds_for(old_target)
    test_check(app.dispatch(Event(PointerEvent(
        POINTER_DOWN_KIND, Point(bounds.x + 1.0, bounds.y + 1.0)
    ))))
    test_check(app.pressed_id() == old_target)
    app.remember_scroll(700, 12.0)
    var old_bounds = app.root_bounds
    var renderer = TestRenderer()
    reset(app, Root(), window, renderer)
    test_check(window.opened)
    test_check(window.config.title == "authoring")
    test_check(window.config.width == 320.0 and window.config.height == 180.0)
    test_check(window.pending_count() == 1)
    test_check(app.root_bounds.width == old_bounds.width)
    test_check(len(app.scroll_ids) == 0 and len(app.scroll_values) == 0)
    test_check(app.pressed_id() == -1)
    var new_target = root_button_id(app)
    test_check(new_target != old_target)
    test_check(app.focus_id() == new_target)
    test_check(renderer.last_accessibility_count > 0)

    var guarded = App(HandlerHost(Root()), Rect(0.0, 0.0, 520.0, 320.0))
    var guarded_target = root_button_id(guarded)
    var guarded_request = schedule_action(guarded, guarded_target, 70, "guarded", 60.0)
    var unsupported = UnsupportedWindow()
    var guarded_renderer = TestRenderer()
    var rejected = False
    try:
        reset(guarded, Root(), unsupported, guarded_renderer)
    except:
        rejected = True
    test_check(rejected)
    test_check(root_button_id(guarded) == guarded_target)
    test_check(guarded.request_is_current(guarded_request.handle))
    test_check(guarded.component.root.count == 0)


struct LoopWindow(WindowBackend):
    var input: TestWindow
    var turns: Int

    def __init__(out self, target: Int):
        self.input = TestWindow()
        self.input.enqueue(Event(SemanticActionEvent(target, ACTION_PRESS)))
        self.turns = 0

    def is_open(self) -> Bool:
        return self.turns < 3

    def pump(mut self):
        self.turns += 1

    def clock_nanoseconds(self) -> Int:
        return self.turns * 1_000_000_000

    def poll_event(mut self) raises -> Event:
        return self.input.poll_event()

    def wait_for_work(mut self, timeout_seconds: Float32):
        pass


def existing_app_loop_and_editing_state() raises:
    var app = App(HandlerHost(Root()), Rect(0, 0, 520, 320))
    var target = root_button_id(app)
    var pending = schedule_action(app, target, 1, "timer", 1.0)
    var window = LoopWindow(target)
    var renderer = TestRenderer()
    app.run(window, renderer)
    test_check(app.component.root.count == 2)
    test_check(not complete_action(app, pending))
    test_check(len(app.component._pending_requests) == 0)
    test_check(renderer.last_accessibility_count > 0)

    var editor_target = -1
    for item in app.component.ui.controls:
        if item.kind == TEXT_INPUT_VIEW_KIND:
            editor_target = item.id
    var composition = Event(CompositionEvent("marked", 1, 2))
    composition.set_target(editor_target)
    test_check(app.update(composition))
    var index = app.component.ui.index(editor_target)
    var cursor = app.component.ui.controls[index].editor.cursor
    update_model(app, Root.increment)
    index = app.component.ui.index(editor_target)
    test_check(app.component.ui.controls[index].editor.composition == "marked")
    test_check(app.component.ui.controls[index].editor.cursor == cursor)
    test_check(app.component.root.draft == "draft")
    reset_headless(app, Root())
    test_check(app.component.ui.index(editor_target) < 0)
    test_check(not app.update(composition))

struct LabelPane(Pane):
    comptime Context = NoneType

    def __init__(out self):
        pass

    def edit(mut self, value: String):
        pass

    def toggle(mut self, value: Bool):
        pass

    def render(self, mut ui: UI[Self, Self.Context], context: NoneType):
        ui.text_input("Visible editor", "one", Self.edit, hint="Enter your name")
        ui.text_input("Named editor", "two", Self.edit, show_label=False)
        ui.checkbox("Visible check", True, Self.toggle)
        ui.checkbox("Named check", False, Self.toggle, show_label=False)

struct LabelRoot(Screen):
    def __init__(out self):
        pass

    def route(mut self, key: Int, action: Action[LabelPane]):
        pass

    def route_context(mut self, mut context: NoneType, key: Int, action: Action[LabelPane]):
        pass

    def render(self, mut ui: UI[Self]):
        ui.child(LabelPane(), NoneType(), Self.route, key=1)
        ui.child(LabelPane(), NoneType(), Self.route_context, key=2)

def visible_and_accessible_labels():
    var app = App(HandlerHost(LabelRoot()), Rect(0, 0, 520, 600))
    # Both child-routing overloads preserve visible text and accessible names.
    test_check(app.view.child_count() == 10)
    for offset in range(0, 10, 5):
        test_check(app.view.child(offset).text == "Visible editor")
        test_check(app.view.child(offset + 1).semantics.label == "Visible editor")
        test_check(app.view.child(offset + 1).semantics.hint == "Enter your name")
        test_check(app.view.child(offset + 2).text == "two")
        test_check(app.view.child(offset + 2).semantics.label == "Named editor")
        test_check(app.view.child(offset + 3).text == "Visible check")
        test_check(app.view.child(offset + 3).semantics.label == "Visible check")
        test_check(app.view.child(offset + 4).text == "")
        test_check(app.view.child(offset + 4).semantics.label == "Named check")

def reset_preserves_unrelated_queue_capacity():
    var app = App(HandlerHost(Root()), Rect(0, 0, 520, 320))
    var owned = schedule_action(app, root_button_id(app), 1, "owned", 60.0)
    # Reset must not leave a cancellation result occupying the shared queue.
    reset_headless(app, Root())
    test_check(not complete_action(app, owned))
    test_check(app.requests.ready_count() == 0)
    for key in range(app.requests.capacity()):
        var unrelated = app.schedule_request(key, "unrelated", 60.0)
        test_check(app.complete_request(unrelated, TASK_COMPLETED))
    test_check(app.requests.ready_count() == app.requests.capacity())
    test_check(app.requests.dropped_count() == 0)
    for key in range(app.requests.capacity()):
        var result = app.requests.pop_ready()
        test_check(result.key == key and app.requests.should_deliver(result))
    test_check(len(app.requests.tasks.tasks) == 0)

def embedded_model_reset():
    # A parent can retire one host without replacing App's shared scheduler.
    var app = App(HandlerHost(Root()), Rect(0, 0, 520, 320))
    var target = root_button_id(app)
    var action = app.component.capture(target)
    var event = Event(SemanticActionEvent(target, ACTION_PRESS))
    var queued = app.component.queue(event)
    var owned = schedule_action(app, target, 91, "owned", 60.0)
    var sibling = app.schedule_request(92, "sibling", 60.0)
    test_check(app.complete_request(owned.handle, TASK_COMPLETED))
    test_check(app.complete_request(sibling, TASK_COMPLETED))
    app.component.reset_model(Root())
    app.rebuild()
    test_check(root_button_id(app) > target)
    test_check(not app.component.accepts(queued))
    test_check(not app.component.deliver_action(action))
    test_check(not app.dispatch(event))
    test_check(app.component.root.count == 0)
    test_check(not complete_action(app, owned))
    test_check(app.requests.ready_count() == 1)
    var result = app.requests.pop_ready()
    test_check(result.key == 92 and app.requests.should_deliver(result))

def interleaved_control_ids():
    # Embedded slots may share an unbounded allocation space by residue.
    var left = HandlerHost(Root(), id_stride=5)
    var right = HandlerHost(Root(), id_stride=5)
    for lifetime in range(250):
        for control in left.ui.controls:
            test_check(control.id % 5 == 1)
            for other in right.ui.controls:
                test_check(control.id != other.id + 1)
        left.reset_model(Root())
        if lifetime % 3 == 0:
            right.reset_model(Root())
    test_check(left.ui.next_id > 1000)


def main() raises:
    root_and_copy_lifetimes()
    collection_lifetimes_and_reorder()
    request_statuses_and_bounded_storage()
    integrated_reset_and_backend_guard()
    existing_app_loop_and_editing_state()
    visible_and_accessible_labels()
    reset_preserves_unrelated_queue_capacity()
    embedded_model_reset()
    interleaved_control_ids()
    print("PASS authoring lifetimes, request delivery, and reset contracts")
