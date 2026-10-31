"""Direct method bindings with bounded retained control storage."""
from std.collections import List, Dict
from bindings import Action, child_action, _local, _text, _toggle, _write_context
from std.ffi import external_call
from moxi import (
    ColumnView, Component, Event, KeyEvent, Rect, TextInputControl,
    TextInputEvent, TextInputState, ACTION_KIND, CLICK_KIND, KEY_DOWN_KIND,
    TEXT_INPUT_KIND, COMPOSITION_UPDATE_KIND, COMPOSITION_END_KIND,
    KEY_ENTER, KEY_SPACE, KEY_X, MOD_COMMAND,
    BUTTON_KIND, CHECKBOX_KIND, TEXT_INPUT_VIEW_KIND, LABEL_KIND, CONTAINER_KIND,
)


def require(condition: Bool, message: String):
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
    var action: Action[Self.S, Self.C]

    def __init__(out self, path: String, kind: Int, label: String = "", value: String = "", action: Action[Self.S, Self.C] = Action[Self.S, Self.C](), enabled: Bool = True, checked: Bool = False):
        self.path = path
        self.kind = kind
        self.label = label
        self.value = value
        self.action = action
        self.enabled = enabled
        self.checked = checked


trait Pane(ImplicitlyCopyable):
    comptime Context: ImplicitlyCopyable
    def render(self, mut ui: UI[Self, Self.Context], context: Self.Context): ...


struct UI[S: ImplicitlyCopyable, C: ImplicitlyCopyable = NoneType](ImplicitlyCopyable):
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
        require(key != "", "scope key must not be empty")
        var path = self.frames[len(self.frames) - 1].path + "/k" + String(key.byte_length()) + ":" + key
        self.declarations.append(Declaration[Self.S, Self.C](path, CONTAINER_KIND))
        self.frames.append(Frame(path))

    def end_scope(mut self):
        require(len(self.frames) > 1, "end_scope without begin_scope")
        _ = self.frames.pop()

    def label(mut self, text: String):
        self.declarations.append(Declaration[Self.S, Self.C](self.path(), LABEL_KIND, text))

    def button(mut self, text: String, on_click: def(mut Self.S) thin -> None, enabled: Bool = True):
        self.declarations.append(Declaration[Self.S, Self.C](self.path(), BUTTON_KIND, text, action=Action[Self.S, Self.C](payload=on_click, invoke=_local[Self.S, Self.C]), enabled=enabled))

    def button(mut self, text: String, on_click: def(mut Self.S, mut Self.C) thin -> None, enabled: Bool = True):
        self.declarations.append(Declaration[Self.S, Self.C](self.path(), BUTTON_KIND, text, action=Action[Self.S, Self.C](payload=on_click, invoke=_write_context[Self.S, Self.C]), enabled=enabled))

    def text_input(mut self, label: String, value: String, on_change: def(mut Self.S, String) thin -> None):
        self.label(label)
        self.declarations.append(Declaration[Self.S, Self.C](self.path(), TEXT_INPUT_VIEW_KIND, label, value, Action[Self.S, Self.C](payload=on_change, invoke=_text[Self.S, Self.C])))

    def checkbox(mut self, label: String, checked: Bool, on_change: def(mut Self.S, Bool) thin -> None):
        self.declarations.append(Declaration[Self.S, Self.C](self.path(), CHECKBOX_KIND, label, action=Action[Self.S, Self.C](payload=on_change, invoke=_toggle[Self.S, Self.C]), checked=checked))

    def child[Child: Pane](mut self, child: Child, context: Child.Context, route: def(mut Self.S, Int, Action[Child, Child.Context]) thin -> None, *, key: Int):
        var ui = UI[Child, Child.Context]()
        child.render(ui, context)
        require(len(ui.frames) == 1, "unclosed child scope")
        self.begin_scope(String(key))
        var prefix = self.frames[len(self.frames) - 1].path
        for item in ui.declarations:
            var action = Action[Self.S, Self.C]()
            if item.action._storage:
                action = child_action[Self.S, Self.C, Child, Child.Context](key, route, item.action)
            self.declarations.append(Declaration[Self.S, Self.C](prefix + item.path, item.kind, item.label, item.value, action, item.enabled, item.checked))
        self.end_scope()


    def child[Child: Pane](mut self, child: Child, context: Child.Context, route: def(mut Self.S, mut Self.C, Int, Action[Child, Child.Context]) thin -> None, *, key: Int):
        var ui = UI[Child, Child.Context]()
        child.render(ui, context)
        require(len(ui.frames) == 1, "unclosed child scope")
        self.begin_scope(String(key))
        var prefix = self.frames[len(self.frames) - 1].path
        for item in ui.declarations:
            var action = Action[Self.S, Self.C]()
            if item.action._storage:
                action = child_action[Self.S, Self.C, Child, Child.Context](key, route, item.action)
            self.declarations.append(Declaration[Self.S, Self.C](prefix + item.path, item.kind, item.label, item.value, action, item.enabled, item.checked))
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
        require(not self.controls[index].seen, "duplicate identity: " + path)
        require(self.controls[index].kind == kind, "control kind changed: " + path)
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
                self.view.add_checkbox(self.controls[i].id, item.label, item.checked, 28)
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
    def render(self, mut ui: UI[Self]):
        ...


struct HandlerHost[Root: Screen & Deinitable](Component):
    var root: Self.Root
    var ui: RetainedUI[Self.Root]
    var renders: Int

    def __init__(out self, root: Self.Root):
        self.root = root
        self.ui = RetainedUI[Self.Root]()
        self.renders = 0
        self.refresh()

    def refresh(mut self):
        var ui = UI[Self.Root]()
        self.root.render(ui)
        require(len(ui.frames) == 1, "unclosed scope")
        self.ui.rebuild(ui.declarations)
        self.renders += 1

    def build(self, bounds: Rect) -> ColumnView:
        var view = self.ui.view.clone()
        view.layout_spec.bounds = bounds
        view.row_layout.bounds = bounds
        view.layout()
        return view^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
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
