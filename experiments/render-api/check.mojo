"""Run real Moxi App routing against the proposed render API."""
from moxi import (
    App, ColumnView, Event, ClickEvent, KeyEvent, TextInputEvent, CompositionEvent,
    Point, Rect, ViewNode, test_check, KEY_A, KEY_LEFT, KEY_BACKSPACE, KEY_SPACE,
    KEY_TAB, KEY_C, KEY_X, KEY_V, MOD_COMMAND,
)
from examples import Counters, GreetingForm, counter
from runtime import Renderable, RenderHost, UI


def node(view: ColumnView, id: Int) -> ViewNode:
    for i in range(view.child_count()):
        if view.child(i).id == id:
            return view.child(i)
    test_check(False)
    return view.child(0)


def has_text(view: ColumnView, text: String) -> Bool:
    for i in range(view.child_count()):
        if view.child(i).text == text:
            return True
    return False


def click[R: Renderable & Deinitable](mut app: App[RenderHost[R]], key: String) -> Bool:
    var bounds = app.view.bounds_for(app.component.ui.id(key))
    return app.update(ClickEvent(Point(bounds.x + 8, bounds.y + 8)))


def replace[R: Renderable & Deinitable](mut app: App[RenderHost[R]], key: String, text: String):
    _ = click(app, key)
    _ = app.update(Event(KeyEvent(KEY_A, MOD_COMMAND)))
    _ = app.update(Event(TextInputEvent(text)))


struct OrderProbe(Renderable):
    var count: Int
    var show: Bool

    def __init__(out self):
        self.count = 0
        self.show = True

    def render(mut self, mut ui: UI):
        # Both label and conditional occur BEFORE the action that changes them.
        ui.label("Before: " + String(self.count))
        if self.show:
            ui.label("Still visible")
        if ui.button("act", "Act once"):
            self.count += 1
            self.show = False
        ui.label("After: " + String(self.count))


struct SharedEditors(Renderable):
    var text: String
    var reverse: Bool
    var visible: Bool
    var count: Int

    def __init__(out self):
        self.text = "Ada"
        self.reverse = False
        self.visible = True
        self.count = 0

    def render(mut self, mut ui: UI):
        if self.reverse:
            ui.text_input("b", "B", self.text)
            ui.text_input("a", "A", self.text)
        else:
            ui.text_input("a", "A", self.text)
            ui.text_input("b", "B", self.text)
        ui.checkbox("reverse", "Reverse", self.reverse)
        ui.checkbox("visible", "Show counter", self.visible)
        if self.visible:
            counter(ui, "conditional", self.count)


def main():
    var counters = App[RenderHost[Counters]](RenderHost[Counters](Counters()), Rect(0, 0, 520, 520))
    test_check(counters.paint().count() > 0)
    test_check(click(counters, "first"))
    test_check(counters.component.root.first == 1)
    test_check(counters.component.root.second == 0)
    test_check(click(counters, "shared-b"))
    test_check(counters.component.root.shared == 1)
    test_check(node(counters.view, counters.component.ui.id("shared-a")).text == "Clicked 1 times")
    test_check(node(counters.view, counters.component.ui.id("shared-b")).text == "Clicked 1 times")
    test_check(click(counters, "shared-a"))
    test_check(counters.update(Event(KeyEvent(KEY_SPACE))))
    test_check(counters.component.root.shared == 3)
    var fresh = App[RenderHost[Counters]](RenderHost[Counters](Counters()), Rect(0, 0, 520, 520))
    test_check(fresh.component.root.shared == 0)
    print("PASS independent/shared counters, earlier sibling refresh, keyboard, fresh root")

    var order = App[RenderHost[OrderProbe]](RenderHost[OrderProbe](OrderProbe()), Rect(0, 0, 520, 520))
    test_check(click(order, "act"))
    test_check(order.component.root.count == 1)
    test_check(has_text(order.view, "Before: 1"))
    test_check(has_text(order.view, "After: 1"))
    test_check(not has_text(order.view, "Still visible"))
    order.rebuild()
    _ = order.resize(Rect(0, 0, 600, 550))
    _ = order.paint()
    test_check(order.component.root.count == 1)
    test_check(click(order, "act"))
    test_check(order.component.root.count == 2)
    print("PASS action exactly once, earlier label/branch refresh, rebuild/resize/paint do not replay")

    var form = App[RenderHost[GreetingForm]](RenderHost[GreetingForm](GreetingForm()), Rect(0, 0, 520, 600))
    test_check(has_text(form.view, "Hello, Ada"))
    replace(form, "name", "  Grace  ")
    var name_id = form.component.ui.id("name")
    test_check(form.focus_id() == name_id)
    test_check(has_text(form.view, "Hello, Grace"))
    _ = form.update(Event(KeyEvent(KEY_LEFT)))
    var cursor = form.component.ui.controls[name_id - 1].editor.cursor
    var anchor = form.component.ui.controls[name_id - 1].editor.anchor
    _ = form.resize(Rect(0, 0, 540, 620))
    test_check(form.component.ui.controls[name_id - 1].editor.cursor == cursor)
    test_check(form.component.ui.controls[name_id - 1].editor.anchor == anchor)
    test_check(form.focus_id() == name_id)
    _ = click(form, "save")
    test_check(form.component.root.saved == "Grace")
    test_check(has_text(form.view, "Saved: Grace"))
    _ = click(form, "use-nickname")
    test_check(has_text(form.view, "Name required"))
    test_check(not node(form.view, form.component.ui.id("save")).enabled)
    test_check(not click(form, "save"))
    test_check(form.component.root.saved == "Grace")
    replace(form, "nickname", "  Mox  ")
    _ = click(form, "save")
    test_check(form.component.root.saved == "Mox")
    _ = click(form, "use-nickname")
    var stale = Event(TextInputEvent("bad"))
    stale.set_target(form.component.ui.id("nickname"))
    test_check(not form.component.update(stale, form.view))
    test_check(form.component.root.nickname == "  Mox  ")
    _ = click(form, "use-nickname")
    test_check(has_text(form.view, "Hello, Mox"))
    _ = click(form, "restore")
    test_check(form.component.root.name == "Ada")
    test_check(form.component.root.nickname == "")
    test_check(not form.component.root.use_nickname)
    test_check(form.component.root.saved == "")
    test_check(node(form.view, name_id).text == "Ada")
    test_check(has_text(form.view, "Hello, Ada"))
    test_check(not has_text(form.view, "Saved: Mox"))
    print("PASS trim/validation/Save, cursor/focus, hidden state, stale-event rejection, late reset")

    replace(form, "name", "λ🙂")
    _ = form.update(Event(KeyEvent(KEY_BACKSPACE)))
    test_check(form.component.root.name == "λ")
    _ = form.update(Event(CompositionEvent("に", 0, 1)))
    test_check(form.component.ui.controls[name_id - 1].editor.has_composition())
    test_check(form.component.root.name == "λ")
    _ = form.update(Event(TextInputEvent("日")))
    test_check(form.component.root.name == "λ日")
    test_check(not form.component.ui.controls[name_id - 1].editor.has_composition())
    _ = form.update(Event(KeyEvent(KEY_A, MOD_COMMAND)))
    _ = form.update(Event(KeyEvent(KEY_C, MOD_COMMAND)))
    test_check(form.clipboard_text() == "λ日")
    _ = form.update(Event(KeyEvent(KEY_X, MOD_COMMAND)))
    test_check(form.component.root.name == "")
    test_check(has_text(form.view, "Name required"))
    _ = form.update(Event(KeyEvent(KEY_V, MOD_COMMAND)))
    test_check(form.component.root.name == "λ日")
    _ = form.update(Event(KeyEvent(KEY_TAB)))
    test_check(form.focus_id() == form.component.ui.id("use-nickname"))
    print("PASS Unicode, composition/commit, App clipboard commands, Tab")

    var shared = App[RenderHost[SharedEditors]](RenderHost[SharedEditors](SharedEditors()), Rect(0, 0, 520, 600))
    var a = shared.component.ui.id("a")
    var b = shared.component.ui.id("b")
    _ = click(shared, "a")
    _ = shared.update(Event(KeyEvent(KEY_LEFT)))
    var a_cursor = shared.component.ui.controls[a - 1].editor.cursor
    replace(shared, "b", "Grace")
    test_check(node(shared.view, a).text == "Grace")
    test_check(node(shared.view, b).text == "Grace")
    test_check(shared.component.ui.controls[a - 1].editor.cursor == a_cursor)
    test_check(shared.component.ui.controls[b - 1].editor.cursor == 5)
    _ = click(shared, "reverse")
    test_check(shared.component.ui.id("a") == a)
    test_check(shared.component.ui.id("b") == b)
    replace(shared, "a", "Lin")
    test_check(node(shared.view, b).text == "Lin")
    test_check(node(shared.view, a).text == "Lin")
    _ = click(shared, "conditional")
    _ = click(shared, "visible")
    _ = click(shared, "visible")
    test_check(shared.component.root.count == 1)
    test_check(node(shared.view, shared.component.ui.id("conditional")).text == "Clicked 1 times")
    print("PASS shared editors, independent cursors, reordered keys, conditional field lifetime")
    print("All render API checks passed")
