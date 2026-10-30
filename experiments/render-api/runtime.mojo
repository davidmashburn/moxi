"""Experimental ordinary-Mojo authoring API; not a shipped Moxi contract."""
from std.collections import List
from std.ffi import external_call
from moxi import (
    ColumnView, Component, Event, KeyEvent, Rect, TextInputControl,
    TextInputEvent, TextInputState, ACTION_KIND, CLICK_KIND, KEY_DOWN_KIND,
    TEXT_INPUT_KIND, COMPOSITION_UPDATE_KIND, COMPOSITION_END_KIND,
    KEY_ENTER, KEY_SPACE, KEY_X, MOD_COMMAND,
    BUTTON_KIND, CHECKBOX_KIND, TEXT_INPUT_VIEW_KIND,
)


def require(condition: Bool, message: String):
    if not condition:
        print("Render API error:", message)
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


struct Control(ImplicitlyCopyable):
    var key: String
    var kind: Int
    var seen: Bool
    var active: Bool
    var editor: TextInputState

    def __init__(out self, key: String, kind: Int):
        self.key = key
        self.kind = kind
        self.seen = False
        self.active = False
        self.editor = TextInputState()


struct UI(ImplicitlyCopyable):
    """Own native editor state and consume at most one event per pass.

    Control keys are unique across one root. No field references are retained.
    """
    var controls: List[Control]
    var view: ColumnView
    var event: Event
    var event_available: Bool
    var consumed: Bool
    var handled: Bool
    var label_count: Int

    def __init__(out self):
        self.controls = List[Control]()
        self.view = ColumnView(Rect(0, 0, 520, 800), 16, 8)
        self.event = Event()
        self.event_available = False
        self.consumed = False
        self.handled = False
        self.label_count = 0

    def __init__(out self, *, copy: Self):
        self.controls = copy.controls.copy()
        self.view = copy.view.clone()
        self.event = copy.event
        self.event_available = copy.event_available
        self.consumed = copy.consumed
        self.handled = copy.handled
        self.label_count = copy.label_count

    def begin(mut self, event: Event, previous: ColumnView):
        self.event = event
        self.event_available = available(previous, event.target)
        self.consumed = False
        self.handled = False
        self.label_count = 0
        self.view = ColumnView(previous.layout_spec.bounds, 16, 8)
        for i in range(len(self.controls)):
            self.controls[i].seen = False

    def finish(mut self):
        for i in range(len(self.controls)):
            self.controls[i].active = self.controls[i].seen
            if not self.controls[i].active:
                self.controls[i].editor = TextInputState()
        self.view.layout()

    def id(self, key: String) -> Int:
        for i in range(len(self.controls)):
            if self.controls[i].key == key:
                return i + 1
        return -1

    def claim(mut self, key: String, kind: Int) -> Int:
        require(key != "", "control key must not be empty")
        var index = self.id(key) - 1
        if index < 0:
            index = len(self.controls)
            require(index < 999999, "control ID space exhausted")
            self.controls.append(Control(key, kind))
        require(not self.controls[index].seen, "duplicate control key: " + key)
        require(self.controls[index].kind == kind, "control kind changed for key: " + key)
        self.controls[index].seen = True
        return index

    def matches(self, index: Int) -> Bool:
        return self.event_available and not self.consumed and self.event.target == index + 1

    def label(mut self, text: String):
        self.label_count += 1
        self.view.add_label(1000000 + self.label_count, text, 24)

    def button(mut self, key: String, text: String, enabled: Bool = True) -> Bool:
        var index = self.claim(key, BUTTON_KIND)
        self.view.add_button_enabled(index + 1, text, 36, enabled)
        if enabled and self.matches(index) and activated(self.event):
            self.consumed = True
            self.handled = True
            return True
        return False

    def checkbox(mut self, key: String, text: String, mut value: Bool):
        var index = self.claim(key, CHECKBOX_KIND)
        if self.matches(index) and activated(self.event):
            value = not value
            self.consumed = True
            self.handled = True
        self.view.add_checkbox(index + 1, text, value, 28)

    def text_input(mut self, key: String, label: String, mut value: String):
        var index = self.claim(key, TEXT_INPUT_VIEW_KIND)
        if not self.controls[index].active:
            self.controls[index].editor = TextInputState(value)
            self.controls[index].active = True
        elif self.controls[index].editor.text != value:
            self.controls[index].editor.set_text(value)
        if self.matches(index):
            self.consumed = True
            if edit(self.controls[index].editor, self.event):
                value = self.controls[index].editor.text
                self.handled = True
        self.label(label)
        var state = self.controls[index].editor
        var control = TextInputControl(index + 1, state.text, state.cursor, state.anchor, 34)
        control.set_composition(state.composition, state.composition_selection_start, state.composition_selection_end)
        self.view.add(control.node())
        self.view.set_accessibility_label(index + 1, label)


trait Renderable(ImplicitlyCopyable):
    def render(mut self, mut ui: UI):
        ...


struct RenderHost[Root: Renderable & Deinitable](Component):
    """Temporary bridge to today's build/update Component contract.

    Each event gets one dispatch pass and one event-free display pass. Effects
    must be inside button branches; arbitrary effects in render run each pass.
    """
    var root: Self.Root
    var ui: UI

    def __init__(out self, root: Self.Root):
        self.root = root
        self.ui = UI()
        self.refresh()

    def refresh(mut self):
        var previous = self.ui.view.clone()
        self.ui.begin(Event(), previous)
        self.root.render(self.ui)
        self.ui.finish()

    def build(self, bounds: Rect) -> ColumnView:
        var view = self.ui.view.clone()
        view.layout_spec.bounds = bounds
        view.row_layout.bounds = bounds
        view.layout()
        return view^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        if not available(view, event.target):
            return False
        self.ui.begin(event, view)
        self.root.render(self.ui)
        var handled = self.ui.handled
        self.ui.finish()
        # The dispatch output may contain labels evaluated before a mutation.
        # Re-evaluate with no event: no button action can fire a second time.
        self.refresh()
        return handled

    def clipboard_copy(mut self, target: Int, view: ColumnView) -> String:
        var index = target - 1
        if not available(view, target) or index < 0 or index >= len(self.ui.controls):
            return ""
        if self.ui.controls[index].kind != TEXT_INPUT_VIEW_KIND:
            return ""
        return self.ui.controls[index].editor.selected_text()

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
