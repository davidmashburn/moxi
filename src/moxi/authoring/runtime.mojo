"""Direct method bindings over ephemeral declarations and retained controls."""
from std.collections import List, Dict
from .delivery import DeliveryScope, QueuedEvent, CapturedAction
from .identity import key_path
from .actions import Action, child_action, _local, _text, _toggle, _write_context
from std.ffi import external_call
from ..app_runtime import App
from ..column_view import ColumnView
from ..component import Component
from ..geometry import Rect
from ..controls_text import TextInputControl, TextInputState
from ..event import (
    Event, KeyEvent, TextInputEvent, ACTION_KIND, CLICK_KIND, KEY_DOWN_KIND,
    TEXT_INPUT_KIND, COMPOSITION_UPDATE_KIND, COMPOSITION_END_KIND,
    KEY_ENTER, KEY_SPACE, KEY_X, MOD_COMMAND, TASK_RESULT_KIND,
)
from ..view_node import BUTTON_KIND, CHECKBOX_KIND, TEXT_INPUT_VIEW_KIND, LABEL_KIND, CONTAINER_KIND
from ..tasks import RequestScheduler, RequestHandle, RequestScopeHandle, RequestResult, TASK_COMPLETED
from ..column_runtime import ColumnRuntime
from ..window import WindowBackend
from ..paint import Renderer



def _require(condition: Bool, message: String):
    if not condition:
        print("Handler API error:", message)
        external_call["exit", NoneType](1)


def available(view: ColumnView, target: Int) -> Bool:
    for i in range(view.child_count()):
        if view.child(i).id == target:
            return view.child(i).enabled
    return False


def activated(event: Event) -> Bool:
    return event.kind == CLICK_KIND or event.kind == ACTION_KIND or (
        event.kind == KEY_DOWN_KIND and (event.key == KEY_ENTER or event.key == KEY_SPACE)
    )


def edit(mut state: TextInputState, event: Event) -> Bool:
    if event.kind == COMPOSITION_UPDATE_KIND:
        state.set_composition(event.text, event.selection_start, event.selection_end)
        return True
    if event.kind == COMPOSITION_END_KIND:
        if not state.has_composition():
            return False
        state.clear_composition()
        return True
    if event.kind == TEXT_INPUT_KIND:
        if event.replacement_start >= 0 and event.replacement_end >= 0:
            return state.replace_text_range(event.text, event.replacement_start, event.replacement_end)
        return state.insert_text(event.text)
    if event.kind == KEY_DOWN_KIND:
        return state.handle_key(event.key, event.modifiers)
    return False


struct Control[S: ImplicitlyCopyable](ImplicitlyCopyable):
    var path: String
    var id: Int
    var kind: Int
    var seen: Bool
    var active: Bool
    var checked: Bool
    var editor: TextInputState
    var editor_initialized: Bool
    var action: Action[Self.S]

    def __init__(out self, path: String, id: Int, kind: Int):
        self.path = path
        self.id = id
        self.kind = kind
        self.seen = False
        self.active = False
        self.checked = False
        self.editor = TextInputState()
        self.editor_initialized = False
        self.action = Action[Self.S]()


struct Frame(ImplicitlyCopyable):
    var path: String
    var next: Int
    def __init__(out self, path: String):
        self.path = path
        self.next = 0


struct Declaration[S: ImplicitlyCopyable, C: ImplicitlyCopyable](ImplicitlyCopyable):
    var path: String
    var kind: Int
    var label: String
    var value: String
    var enabled: Bool
    var checked: Bool
    var show_label: Bool
    var action: Action[Self.S, Self.C]

    def __init__(out self, path: String, kind: Int, label: String = "", value: String = "", action: Action[Self.S, Self.C] = Action[Self.S, Self.C](), enabled: Bool = True, checked: Bool = False, show_label: Bool = True):
        self.path = path
        self.kind = kind
        self.label = label
        self.value = value
        self.action = action
        self.enabled = enabled
        self.checked = checked
        self.show_label = show_label


trait Pane(ImplicitlyCopyable):
    """A value-owned child model declaring controls with a typed shared context."""
    comptime Context: ImplicitlyCopyable
    def render(self, mut ui: UI[Self, Self.Context], context: Self.Context): ...


struct UI[S: ImplicitlyCopyable, C: ImplicitlyCopyable = NoneType](ImplicitlyCopyable):
    """Ephemeral control declarations; methods receive the current model.

    Fixed controls use sibling positions. Use keyed children or balanced scopes
    when logical controls can change position. Render must have no side effects.
    """
    var declarations: List[Declaration[Self.S, Self.C]]
    var frames: List[Frame]

    def __init__(out self):
        self.declarations = List[Declaration[Self.S, Self.C]]()
        self.frames = List[Frame]()
        self.frames.append(Frame(""))

    def __init__(out self, *, copy: Self):
        self.declarations = copy.declarations.copy()
        self.frames = copy.frames.copy()

    def path(mut self) -> String:
        var f = len(self.frames) - 1
        var path = self.frames[f].path + "/p" + String(self.frames[f].next)
        self.frames[f].next += 1
        return path^

    def begin_scope(mut self, key: String):
        _require(key != "", "scope key must not be empty")
        var path = self.frames[len(self.frames) - 1].path + "/k" + String(key.byte_length()) + ":" + key
        self.declarations.append(Declaration[Self.S, Self.C](path, CONTAINER_KIND))
        self.frames.append(Frame(path))

    def end_scope(mut self):
        _require(len(self.frames) > 1, "end_scope without begin_scope")
        _ = self.frames.pop()

    def label(mut self, text: String):
        self.declarations.append(Declaration[Self.S, Self.C](self.path(), LABEL_KIND, text))

    def button(mut self, text: String, on_click: def(mut Self.S) thin -> None, enabled: Bool = True):
        self.declarations.append(Declaration[Self.S, Self.C](self.path(), BUTTON_KIND, text, action=Action[Self.S, Self.C](payload=on_click, invoke=_local[Self.S, Self.C]), enabled=enabled))

    def button(mut self, text: String, on_click: def(mut Self.S, mut Self.C) thin -> None, enabled: Bool = True):
        self.declarations.append(Declaration[Self.S, Self.C](self.path(), BUTTON_KIND, text, action=Action[Self.S, Self.C](payload=on_click, invoke=_write_context[Self.S, Self.C]), enabled=enabled))

    def text_input(mut self, label: String, value: String, on_change: def(mut Self.S, String) thin -> None, *, show_label: Bool = True):
        """Declare an editor; show_label=False keeps only its accessible name.

        Keep show_label fixed within a mount: the visible label occupies a slot.
        """
        if show_label:
            self.label(label)
        self.declarations.append(Declaration[Self.S, Self.C](self.path(), TEXT_INPUT_VIEW_KIND, label, value, Action[Self.S, Self.C](payload=on_change, invoke=_text[Self.S, Self.C])))

    def checkbox(mut self, label: String, checked: Bool, on_change: def(mut Self.S, Bool) thin -> None, *, show_label: Bool = True):
        """Declare a checkbox, optionally hiding its text but keeping its name."""
        self.declarations.append(Declaration[Self.S, Self.C](self.path(), CHECKBOX_KIND, label, action=Action[Self.S, Self.C](payload=on_change, invoke=_toggle[Self.S, Self.C]), checked=checked, show_label=show_label))

    def child[Child: Pane, K: ImplicitlyCopyable & Deinitable = Int](mut self, child: Child, context: Child.Context, route: def(mut Self.S, K, Action[Child, Child.Context]) thin -> None, *, key: K):
        var ui = UI[Child, Child.Context]()
        child.render(ui, context)
        _require(len(ui.frames) == 1, "unclosed child scope")
        self.begin_scope(key_path(key))
        var prefix = self.frames[len(self.frames) - 1].path
        for item in ui.declarations:
            var action = Action[Self.S, Self.C]()
            if item.action._storage:
                action = child_action[Self.S, Self.C, Child, Child.Context, K](key, route, item.action)
            self.declarations.append(Declaration[Self.S, Self.C](prefix + item.path, item.kind, item.label, item.value, action, item.enabled, item.checked, item.show_label))
        self.end_scope()


    def child[Child: Pane, K: ImplicitlyCopyable & Deinitable = Int](mut self, child: Child, context: Child.Context, route: def(mut Self.S, mut Self.C, K, Action[Child, Child.Context]) thin -> None, *, key: K):
        var ui = UI[Child, Child.Context]()
        child.render(ui, context)
        _require(len(ui.frames) == 1, "unclosed child scope")
        self.begin_scope(key_path(key))
        var prefix = self.frames[len(self.frames) - 1].path
        for item in ui.declarations:
            var action = Action[Self.S, Self.C]()
            if item.action._storage:
                action = child_action[Self.S, Self.C, Child, Child.Context, K](key, route, item.action)
            self.declarations.append(Declaration[Self.S, Self.C](prefix + item.path, item.kind, item.label, item.value, action, item.enabled, item.checked, item.show_label))
        self.end_scope()


struct RetainedUI[S: ImplicitlyCopyable](ImplicitlyCopyable):
    var controls: List[Control[Self.S]]
    var path_indices: Dict[String, Int]
    var id_indices: Dict[Int, Int]
    var view: ColumnView
    var next_id: Int
    var dispatches: Int

    def __init__(out self):
        self.controls = List[Control[Self.S]]()
        self.path_indices = Dict[String, Int]()
        self.id_indices = Dict[Int, Int]()
        self.view = ColumnView(Rect(0, 0, 520, 900), 16, 8)
        self.next_id = 1
        self.dispatches = 0

    def __init__(out self, *, copy: Self):
        self.controls = copy.controls.copy()
        self.path_indices = copy.path_indices.copy()
        self.id_indices = copy.id_indices.copy()
        self.view = copy.view.clone()
        self.next_id = copy.next_id
        self.dispatches = copy.dispatches

    def begin(mut self):
        self.view = ColumnView(self.view.layout_spec.bounds, 16, 8)
        for i in range(len(self.controls)):
            self.controls[i].seen = False

    def rebuild_indices(mut self):
        self.path_indices = Dict[String, Int]()
        self.id_indices = Dict[Int, Int]()
        for i in range(len(self.controls)):
            self.path_indices[self.controls[i].path] = i
            self.id_indices[self.controls[i].id] = i

    def finish(mut self):
        for i in range(len(self.controls)):
            if not self.controls[i].seen:
                self.controls[i].active = False
                self.controls[i].editor = TextInputState()
                self.controls[i].editor_initialized = False
                self.controls[i].action = Action[Self.S]()

        # Retire unseen records before rebuilding both indexes. Live records
        # keep their state and IDs; every newly claimed path receives next_id.
        var kept = List[Control[Self.S]](capacity=len(self.controls))
        for i in range(len(self.controls)):
            if self.controls[i].seen:
                kept.append(self.controls[i])
        self.controls = kept^
        self.rebuild_indices()
        self.view.layout()

    def claim(mut self, path: String, kind: Int) -> Int:
        var index = self.path_indices.get(path, -1)
        if index < 0 or not self.controls[index].active:
            index = len(self.controls)
            self.controls.append(Control[Self.S](path, self.next_id, kind))
            self.path_indices[path] = index
            self.id_indices[self.next_id] = index
            self.next_id += 1
        _require(not self.controls[index].seen, "duplicate identity: " + path)
        _require(self.controls[index].kind == kind, "control kind changed: " + path)
        self.controls[index].seen = True
        self.controls[index].active = True
        return index

    def add_editor(mut self, i: Int, label: String, value: String):
        if not self.controls[i].editor_initialized:
            self.controls[i].editor = TextInputState(value)
            self.controls[i].editor_initialized = True
        elif self.controls[i].editor.text != value:
            self.controls[i].editor.set_text(value)
        var state = self.controls[i].editor
        var control = TextInputControl(self.controls[i].id, state.text, state.cursor, state.anchor, 34)
        control.set_composition(state.composition, state.composition_selection_start, state.composition_selection_end)
        self.view.add(control.node())
        self.view.set_accessibility_label(self.controls[i].id, label)

    def rebuild(mut self, declarations: List[Declaration[Self.S, NoneType]]):
        self.begin()
        for item in declarations:
            var i = self.claim(item.path, item.kind)
            self.controls[i].action = item.action
            if item.kind == LABEL_KIND:
                self.view.add_label(self.controls[i].id, item.label, 24)
            elif item.kind == BUTTON_KIND:
                self.view.add_button_enabled(self.controls[i].id, item.label, 36, item.enabled)
            elif item.kind == CHECKBOX_KIND:
                self.controls[i].checked = item.checked
                self.view.add_checkbox(self.controls[i].id, item.label if item.show_label else "", item.checked, 28)
                self.view.set_accessibility_label(self.controls[i].id, item.label)
            elif item.kind == TEXT_INPUT_VIEW_KIND:
                self.add_editor(i, item.label, item.value)
        self.finish()

    def index(self, id: Int) -> Int:
        var index = self.id_indices.get(id, -1)
        if index >= 0 and index < len(self.controls) and self.controls[index].active:
            return index
        return -1

    def dispatch(mut self, mut state: Self.S, event: Event, view: ColumnView) -> Bool:
        var i = self.index(event.target)
        if i < 0 or not available(view, event.target):
            return False
        if self.controls[i].kind == BUTTON_KIND and activated(event):
            var context: NoneType = None
            self.controls[i].action(state, context)
        elif self.controls[i].kind == CHECKBOX_KIND and activated(event):
            var context: NoneType = None
            self.controls[i].action.with_input("", not self.controls[i].checked)(state, context)
        elif self.controls[i].kind == TEXT_INPUT_VIEW_KIND:
            var previous = self.controls[i].editor.text
            if not edit(self.controls[i].editor, event):
                return False
            # Cursor/selection/composition changes redraw but are not value changes.
            if previous == self.controls[i].editor.text:
                return True
            var context: NoneType = None
            self.controls[i].action.with_input(self.controls[i].editor.text, False)(state, context)
        else:
            return False
        self.dispatches += 1
        return True


trait Screen(ImplicitlyCopyable):
    """Root model whose pure render declares controls from ordinary fields."""
    def render(self, mut ui: UI[Self]):
        ...


struct _OwnedRequestScope(ImplicitlyCopyable):
    var target: Int
    var handle: RequestScopeHandle

    def __init__(out self, target: Int, handle: RequestScopeHandle):
        self.target = target
        self.handle = handle


struct ActionRequest[R: Screen & Deinitable](ImplicitlyCopyable):
    """Completion identity captured when scheduling work for a live button."""
    var handle: RequestHandle
    var action: CapturedAction[Self.R]

    def __init__(out self, handle: RequestHandle, action: CapturedAction[Self.R]):
        self.handle = handle
        self.action = action


struct HandlerHost[Root: Screen & Deinitable](Component):
    """Connect a Screen to App with retained controls and current-owner routing.

    Construct once at the application boundary. Use update_model for external
    mutations and reset for a new session; direct field writes skip publication.
    """
    var root: Self.Root
    var ui: RetainedUI[Self.Root]
    var renders: Int
    var scope: DeliveryScope
    var _request_scopes: List[_OwnedRequestScope]
    var _pending_requests: List[ActionRequest[Self.Root]]

    def __init__(out self, root: Self.Root):
        self.root = root
        self.ui = RetainedUI[Self.Root]()
        self.renders = 0
        self.scope = DeliveryScope()
        self._request_scopes = List[_OwnedRequestScope]()
        self._pending_requests = List[ActionRequest[Self.Root]]()
        self.refresh()

    def __init__(out self, *, copy: Self):
        self.root = copy.root
        self.ui = copy.ui
        self.renders = copy.renders
        # A copied runtime can allocate independently. It needs a new delivery
        # namespace even though its initial view IDs/model keys are identical.
        self.scope = DeliveryScope()
        # Scheduler handles belong to the original App, never its host copy.
        self._request_scopes = List[_OwnedRequestScope]()
        self._pending_requests = List[ActionRequest[Self.Root]]()

    def reconcile_requests(mut self, mut requests: RequestScheduler):
        """Retire control-owned work; App remains the only ready-queue consumer."""
        var owners = List[_OwnedRequestScope]()
        for owner in self._request_scopes:
            if self.ui.index(owner.target) >= 0 and requests.scope_is_active(owner.handle):
                owners.append(owner)
            else:
                _ = requests.discard_scope(owner.handle)
        self._request_scopes = owners^
        var pending = List[ActionRequest[Self.Root]]()
        for item in self._pending_requests:
            if requests.is_current(item.handle):
                pending.append(item)
        self._pending_requests = pending^

    def _discard_requests(mut self, mut requests: RequestScheduler):
        for owner in self._request_scopes:
            _ = requests.discard_scope(owner.handle)
        self._request_scopes = List[_OwnedRequestScope]()
        self._pending_requests = List[ActionRequest[Self.Root]]()

    def _request_result(mut self, event: Event) -> Bool:
        var result = RequestResult(event.request_key, event.request_generation,
                                   event.task_id, event.task_status, event.text,
                                   event.request_scope_id)
        for i in range(len(self._pending_requests)):
            if result.matches(self._pending_requests[i].handle):
                var pending = self._pending_requests.pop(i)
                if result.status == TASK_COMPLETED:
                    return self.deliver_action(pending.action)
                return False
        return False

    def reset_model(mut self, root: Self.Root):
        """Replace an embedded model, retiring its controls and captured actions.

        The parent must rebuild and forward reconcile_requests before delivering
        more events. Retired IDs are never reused. This does not drain native
        input; whole-window callers must use reset(app, root, window, renderer).
        """
        # Keep the allocator outside replaced model values. Do not recycle IDs.
        var next_id = self.ui.next_id
        self.root = root
        self.scope = DeliveryScope()
        self.ui = RetainedUI[Self.Root]()
        self.ui.next_id = next_id
        self.refresh()

    def queue(self, event: Event) -> QueuedEvent:
        return QueuedEvent(self.scope, event)

    def capture(self, target: Int) -> CapturedAction[Self.Root]:
        var i = self.ui.index(target)
        _require(i >= 0, "capture requires a live control")
        _require(self.ui.controls[i].kind == BUTTON_KIND, "capture supports parameterless button actions; queue text/IME events instead")
        return CapturedAction(self.scope, target, self.ui.controls[i].action)

    def accepts(self, packet: QueuedEvent) -> Bool:
        if not self.scope.matches(packet.scope):
            return False
        # App re-resolves focus/pointer targets for other event kinds. Until the
        # native adapter captures that provenance, reject those queued inputs.
        var kind = packet.event.kind
        if kind != ACTION_KIND and kind != TEXT_INPUT_KIND and kind != COMPOSITION_UPDATE_KIND and kind != COMPOSITION_END_KIND:
            return False
        return packet.event.target >= 0 and self.ui.index(packet.event.target) >= 0

    def deliver_action(mut self, packet: CapturedAction[Self.Root]) -> Bool:
        if not self.scope.matches(packet.scope):
            return False
        if self.ui.index(packet.target) < 0 or not available(self.ui.view, packet.target):
            return False
        var context: NoneType = None
        packet.action(self.root, context)
        self.refresh()
        return True

    def refresh(mut self):
        var ui = UI[Self.Root]()
        self.root.render(ui)
        _require(len(ui.frames) == 1, "unclosed scope")
        self.ui.rebuild(ui.declarations)
        self.renders += 1

    def build(self, bounds: Rect) -> ColumnView:
        var view = self.ui.view.clone()
        view.layout_spec.bounds = bounds
        view.row_layout.bounds = bounds
        view.layout()
        return view^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        if event.kind == TASK_RESULT_KIND:
            return self._request_result(event)
        if not self.ui.dispatch(self.root, event, view):
            return False
        self.refresh()
        return True

    def clipboard_copy(mut self, target: Int, view: ColumnView) -> String:
        var i = self.ui.index(target)
        if i < 0 or not available(view, target) or self.ui.controls[i].kind != TEXT_INPUT_VIEW_KIND:
            return ""
        return self.ui.controls[i].editor.selected_text()

    def clipboard_cut(mut self, target: Int, view: ColumnView) -> String:
        var text = self.clipboard_copy(target, view)
        if text != "":
            var event = Event(KeyEvent(KEY_X, MOD_COMMAND))
            event.set_target(target)
            _ = self.update(event, view)
        return text

    def clipboard_paste(mut self, target: Int, text: String, view: ColumnView) -> Bool:
        var event = Event(TextInputEvent(text))
        event.set_target(target)
        return self.update(event, view)


def deliver[R: Screen & Deinitable](mut app: App[HandlerHost[R]], packet: QueuedEvent) -> Bool:
    # Reject a foreign session before App can alter focus or dispatch an event.
    if not app.component.accepts(packet):
        return False
    return app.update(packet.event)


def deliver[R: Screen & Deinitable](mut app: App[HandlerHost[R]], packet: CapturedAction[R]) -> Bool:
    if not app.component.deliver_action(packet):
        return False
    app.rebuild()
    return True


def reset_headless[R: Screen & Deinitable](mut app: App[HandlerHost[R]], root: R):
    """Start a fresh root without a native backend. Native callers use reset."""
    app.component._discard_requests(app.requests)
    app.component.reset_model(root)
    # These live on App, outside the model and retained declarations. A new
    # root lifetime must not inherit its predecessor's root scrollbar gesture.
    app.scroll_ids = List[Int]()
    app.scroll_values = List[Float32]()
    app.scrollbar_pointer_id = -1
    app.scrollbar_target_id = -1
    app.scrollbar_grab_offset = 0.0
    app.scrollbar_dragging = False
    app.runtime = ColumnRuntime()
    app.rebuild()


def update_model[R: Screen & Deinitable](mut app: App[HandlerHost[R]], change: def(mut R) thin -> None):
    # External synchronous updates publish one complete frame before the caller
    # can drain queued work. Event handlers already have this lifecycle in App.
    change(app.component.root)
    app.component.refresh()
    app.rebuild()


def reset[R: Screen & Deinitable, W: WindowBackend, P: Renderer](
    mut app: App[HandlerHost[R]], root: R, mut window: W, mut renderer: P,
) raises:
    """Reset input, owned requests and root, then publish before resuming delivery.

    Call on the UI thread between dispatches. Unsupported backends fail before
    changing the application. Do not deliver an Event polled before this call.
    """
    if not window.supports_input_reset():
        raise Error("This window backend does not support authoring session reset")
    window.reset_input()
    reset_headless(app, root)
    app.render(renderer)


def schedule_action[R: Screen & Deinitable](
    mut app: App[HandlerHost[R]], target: Int, key: Int,
    label: String, delay_seconds: Float32,
) -> ActionRequest[R]:
    """Schedule a successful parameterless button action in its owner's scope.

    The scheduler may complete deterministically after delay_seconds, or an
    adapter can call complete_action earlier. Same-target/key work supersedes.
    This bounded adapter does not transport result payloads into model methods.
    """
    app.component.reconcile_requests(app.requests)
    var action = app.component.capture(target)
    var scope = RequestScopeHandle()
    for owner in app.component._request_scopes:
        if owner.target == target:
            scope = owner.handle
    if not scope.is_valid():
        scope = app.create_request_scope()
        app.component._request_scopes.append(_OwnedRequestScope(target, scope))
    var handle = app.schedule_scoped_request(scope, key, label, delay_seconds)
    var pending = ActionRequest(handle, action)
    if handle.is_valid():
        app.component._pending_requests.append(pending)
    app.component.reconcile_requests(app.requests)
    return pending


def complete_action[R: Screen & Deinitable](
    mut app: App[HandlerHost[R]], request: ActionRequest[R], status: Int = TASK_COMPLETED,
) -> Bool:
    """Enqueue a completion; App.advance_tasks delivers it exactly once."""
    if not app.component.scope.matches(request.action.scope):
        return False
    app.component.reconcile_requests(app.requests)
    if app.component.ui.index(request.action.target) < 0:
        return False
    return app.complete_request(request.handle, status)
