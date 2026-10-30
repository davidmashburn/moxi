"""Bounded handler experiment. No borrowed application state is retained."""
from std.collections import List
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


def no_action[S: ImplicitlyCopyable](mut state: S):
    pass


def no_text[S: ImplicitlyCopyable](mut state: S, text: String):
    pass


def no_bool[S: ImplicitlyCopyable](mut state: S, checked: Bool):
    pass


def no_item[S: ImplicitlyCopyable](mut state: S, key: Int):
    pass


def no_item_text[S: ImplicitlyCopyable](mut state: S, key: Int, text: String):
    pass


struct Control[S: ImplicitlyCopyable](ImplicitlyCopyable):
    var path: String
    var id: Int
    var kind: Int
    var seen: Bool
    var active: Bool
    var checked: Bool
    var item_key: Int
    var item_handler: Bool
    var editor: TextInputState
    var editor_initialized: Bool
    var action: def(mut Self.S) thin -> None
    var change: def(mut Self.S, String) thin -> None
    var toggle: def(mut Self.S, Bool) thin -> None
    var item_action: def(mut Self.S, Int) thin -> None
    var item_change: def(mut Self.S, Int, String) thin -> None

    def __init__(out self, path: String, id: Int, kind: Int):
        self.path = path
        self.id = id
        self.kind = kind
        self.seen = False
        self.active = False
        self.checked = False
        self.item_key = 0
        self.item_handler = False
        self.editor = TextInputState()
        self.editor_initialized = False
        self.action = no_action[Self.S]
        self.change = no_text[Self.S]
        self.toggle = no_bool[Self.S]
        self.item_action = no_item[Self.S]
        self.item_change = no_item_text[Self.S]


struct Frame(ImplicitlyCopyable):
    var path: String
    var next: Int
    def __init__(out self, path: String):
        self.path = path
        self.next = 0


struct UI[S: ImplicitlyCopyable](ImplicitlyCopyable):
    var controls: List[Control[Self.S]]
    var frames: List[Frame]
    var view: ColumnView
    var next_id: Int
    var dispatches: Int

    def __init__(out self):
        self.controls = List[Control[Self.S]]()
        self.frames = List[Frame]()
        self.view = ColumnView(Rect(0, 0, 520, 900), 16, 8)
        self.next_id = 1
        self.dispatches = 0

    def __init__(out self, *, copy: Self):
        self.controls = copy.controls.copy()
        self.frames = copy.frames.copy()
        self.view = copy.view.clone()
        self.next_id = copy.next_id
        self.dispatches = copy.dispatches

    def begin(mut self):
        self.frames.clear()
        self.frames.append(Frame(""))
        self.view = ColumnView(self.view.layout_spec.bounds, 16, 8)
        for i in range(len(self.controls)):
            self.controls[i].seen = False

    def finish(mut self):
        require(len(self.frames) == 1, "unclosed scope")
        for i in range(len(self.controls)):
            if not self.controls[i].seen:
                self.controls[i].active = False
                self.controls[i].editor = TextInputState()
        self.view.layout()

    def claim(mut self, path: String, kind: Int) -> Int:
        var index = -1
        for i in range(len(self.controls)):
            if self.controls[i].path == path and self.controls[i].active:
                index = i
                break
        if index < 0:
            index = len(self.controls)
            self.controls.append(Control[Self.S](path, self.next_id, kind))
            self.next_id += 1
        require(not self.controls[index].seen, "duplicate identity: " + path)
        require(self.controls[index].kind == kind, "control kind changed: " + path)
        self.controls[index].seen = True
        self.controls[index].active = True
        self.controls[index].item_handler = False
        return index

    def slot(mut self, kind: Int) -> Int:
        var f = len(self.frames) - 1
        var path = self.frames[f].path + "/p" + String(self.frames[f].next)
        self.frames[f].next += 1
        return self.claim(path, kind)

    def begin_scope(mut self, key: String):
        require(key != "", "scope key must not be empty")
        var path = self.frames[len(self.frames) - 1].path + "/k" + String(key.byte_length()) + ":" + key
        _ = self.claim(path, CONTAINER_KIND)
        self.frames.append(Frame(path))

    def end_scope(mut self):
        require(len(self.frames) > 1, "end_scope without begin_scope")
        _ = self.frames.pop()

    def label(mut self, text: String):
        var i = self.slot(LABEL_KIND)
        self.view.add_label(self.controls[i].id, text, 24)

    def button(mut self, text: String, on_click: def(mut Self.S) thin -> None, enabled: Bool = True):
        var i = self.slot(BUTTON_KIND)
        self.controls[i].action = on_click
        self.view.add_button_enabled(self.controls[i].id, text, 36, enabled)

    def button_for(mut self, text: String, on_click: def(mut Self.S, Int) thin -> None, key: Int):
        var i = self.slot(BUTTON_KIND)
        self.controls[i].item_handler = True
        self.controls[i].item_key = key
        self.controls[i].item_action = on_click
        self.view.add_button(self.controls[i].id, text, 36)

    def checkbox(mut self, text: String, checked: Bool, on_change: def(mut Self.S, Bool) thin -> None):
        var i = self.slot(CHECKBOX_KIND)
        self.controls[i].checked = checked
        self.controls[i].toggle = on_change
        self.view.add_checkbox(self.controls[i].id, text, checked, 28)

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

    def text_input(mut self, label: String, value: String, on_change: def(mut Self.S, String) thin -> None):
        self.label(label)
        var i = self.slot(TEXT_INPUT_VIEW_KIND)
        self.controls[i].change = on_change
        self.add_editor(i, label, value)

    def text_input_for(mut self, label: String, value: String, on_change: def(mut Self.S, Int, String) thin -> None, key: Int):
        self.label(label)
        var i = self.slot(TEXT_INPUT_VIEW_KIND)
        self.controls[i].item_handler = True
        self.controls[i].item_key = key
        self.controls[i].item_change = on_change
        self.add_editor(i, label, value)

    def index(self, id: Int) -> Int:
        for i in range(len(self.controls)):
            if self.controls[i].id == id and self.controls[i].active:
                return i
        return -1

    def dispatch(mut self, mut state: Self.S, event: Event, view: ColumnView) -> Bool:
        var i = self.index(event.target)
        if i < 0 or not available(view, event.target):
            return False
        if self.controls[i].kind == BUTTON_KIND and activated(event):
            if self.controls[i].item_handler:
                self.controls[i].item_action(state, self.controls[i].item_key)
            else:
                self.controls[i].action(state)
        elif self.controls[i].kind == CHECKBOX_KIND and activated(event):
            self.controls[i].toggle(state, not self.controls[i].checked)
        elif self.controls[i].kind == TEXT_INPUT_VIEW_KIND:
            var previous = self.controls[i].editor.text
            if not edit(self.controls[i].editor, event):
                return False
            # Cursor/selection/composition changes redraw but are not value changes.
            if previous == self.controls[i].editor.text:
                return True
            if self.controls[i].item_handler:
                self.controls[i].item_change(state, self.controls[i].item_key, self.controls[i].editor.text)
            else:
                self.controls[i].change(state, self.controls[i].editor.text)
        else:
            return False
        self.dispatches += 1
        return True


trait Screen(ImplicitlyCopyable):
    def render(self, mut ui: UI[Self]):
        ...


struct HandlerHost[Root: Screen & Deinitable](Component):
    var root: Self.Root
    var ui: UI[Self.Root]
    var renders: Int

    def __init__(out self, root: Self.Root):
        self.root = root
        self.ui = UI[Self.Root]()
        self.renders = 0
        self.refresh()

    def refresh(mut self):
        self.ui.begin()
        self.root.render(self.ui)
        self.ui.finish()
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
