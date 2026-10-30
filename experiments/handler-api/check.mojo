"""Behavior gates through the real Moxi App; no native window required."""
from moxi import (
    App, ColumnView, Event, ClickEvent, KeyEvent, TextInputEvent, CompositionEvent,
    Point, Rect, ViewNode, test_check, KEY_A, KEY_LEFT, KEY_BACKSPACE, KEY_SPACE,
    KEY_TAB, KEY_C, KEY_X, KEY_V, MOD_COMMAND,
)
from runtime import HandlerHost, Screen, UI
from examples import Counters, GreetingForm, TwoForms, Rows, Row


def id[R: Screen & Deinitable](app: App[HandlerHost[R]], path: String) -> Int:
    for control in app.component.ui.controls:
        if control.path == path and control.active:
            return control.id
    test_check(False)
    return -1


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


def click[R: Screen & Deinitable](mut app: App[HandlerHost[R]], path: String) -> Bool:
    var bounds = app.view.bounds_for(id(app, path))
    return app.update(ClickEvent(Point(bounds.x + 8, bounds.y + 8)))


def replace[R: Screen & Deinitable](mut app: App[HandlerHost[R]], path: String, text: String):
    _ = click(app, path)
    _ = app.update(Event(KeyEvent(KEY_A, MOD_COMMAND)))
    _ = app.update(Event(TextInputEvent(text)))


def refresh[R: Screen & Deinitable](mut app: App[HandlerHost[R]]):
    app.component.refresh()
    app.rebuild()


struct OrderProbe(Screen):
    var count: Int
    var show: Bool
    def __init__(out self):
        self.count = 0
        self.show = True
    def act(mut self):
        self.count += 1
        self.show = False
    def render(self, mut ui: UI[Self]):
        ui.label("Before: " + String(self.count))
        if self.show:
            ui.begin_scope("conditional")
            ui.label("Still visible")
            ui.end_scope()
        ui.button("Act once", Self.act)
        ui.label("After: " + String(self.count))


struct SharedEditors(Screen):
    var text: String
    var changes: Int
    def __init__(out self):
        self.text = "Ada"
        self.changes = 0
    def change(mut self, text: String):
        self.text = text
        self.changes += 1
    def render(self, mut ui: UI[Self]):
        ui.text_input("A", self.text, Self.change)
        ui.text_input("B", self.text, Self.change)


struct UnkeyedRows(Screen):
    """Deliberately invalid identity strategy; records its observable cost."""
    var reverse: Bool
    def __init__(out self):
        self.reverse = False
    def rename(mut self, text: String):
        pass
    def render(self, mut ui: UI[Self]):
        if self.reverse:
            ui.text_input("Beta", "Beta", Self.rename)
            ui.text_input("Alpha", "Alpha", Self.rename)
        else:
            ui.text_input("Alpha", "Alpha", Self.rename)
            ui.text_input("Beta", "Beta", Self.rename)


def main():
    var counters = App[HandlerHost[Counters]](HandlerHost[Counters](Counters()), Rect(0, 0, 520, 520))
    test_check(counters.paint().count() > 0)
    test_check(click(counters, "/p1"))
    test_check(counters.component.root.first == 1)
    test_check(counters.component.root.second == 0)
    test_check(click(counters, "/p5"))
    test_check(counters.component.root.shared == 1)
    test_check(node(counters.view, id(counters, "/p4")).text == "Clicked 1 times")
    test_check(node(counters.view, id(counters, "/p5")).text == "Clicked 1 times")
    test_check(counters.update(Event(KeyEvent(KEY_SPACE))))
    test_check(counters.component.root.shared == 2)
    test_check(counters.component.renders == 4)
    test_check(counters.component.ui.dispatches == 3)
    var copy = counters.component
    var event = Event(KeyEvent(KEY_SPACE))
    event.set_target(id(counters, "/p5"))
    _ = copy.update(event, counters.view)
    test_check(copy.root.shared == 3)
    test_check(counters.component.root.shared == 2)
    print("PASS stored method handlers, independent/shared counters, keyboard, copy isolation")

    var order = App[HandlerHost[OrderProbe]](HandlerHost[OrderProbe](OrderProbe()), Rect(0, 0, 520, 520))
    var target = id(order, "/p1")
    test_check(click(order, "/p1"))
    test_check(order.component.root.count == 1)
    test_check(order.component.renders == 2)
    test_check(order.component.ui.dispatches == 1)
    test_check(has_text(order.view, "Before: 1"))
    test_check(has_text(order.view, "After: 1"))
    test_check(not has_text(order.view, "Still visible"))
    test_check(id(order, "/p1") == target)
    order.rebuild()
    _ = order.resize(Rect(0, 0, 600, 550))
    _ = order.paint()
    test_check(order.component.root.count == 1)
    test_check(order.component.renders == 2)
    test_check(order.component.ui.dispatches == 1)
    print("PASS one handler then one render; earlier labels/branches settle; no replay on rebuild/resize/paint")

    var form = App[HandlerHost[GreetingForm]](HandlerHost[GreetingForm](GreetingForm()), Rect(0, 0, 520, 650))
    var name_id = id(form, "/p1")
    var save_id = id(form, "/p4")
    replace(form, "/p1", "  Grace  ")
    test_check(has_text(form.view, "Hello, Grace"))
    _ = click(form, "/p4")
    test_check(form.component.root.saved == "Grace")
    test_check(form.component.root.saves == 1)
    _ = click(form, "/p2")
    var nickname_id = id(form, "/k8:nickname/p1")
    test_check(id(form, "/p4") == save_id)
    test_check(has_text(form.view, "Name required"))
    test_check(not node(form.view, save_id).enabled)
    test_check(not click(form, "/p4"))
    test_check(form.component.root.saves == 1)
    replace(form, "/k8:nickname/p1", "  Mox  ")
    _ = click(form, "/p4")
    test_check(form.component.root.saved == "Mox")
    test_check(form.component.root.saves == 2)
    _ = click(form, "/p2")
    var stale = Event(TextInputEvent("bad"))
    stale.set_target(nickname_id)
    test_check(not form.component.update(stale, form.view))
    _ = click(form, "/p2")
    test_check(id(form, "/k8:nickname/p1") != nickname_id)
    test_check(not form.component.update(stale, form.view))
    test_check(form.component.root.nickname == "  Mox  ")
    _ = click(form, "/p5")
    test_check(form.component.root.name == "Ada")
    test_check(form.component.root.nickname == "")
    test_check(not form.component.root.use_nickname)
    test_check(form.component.root.saved == "")
    test_check(node(form.view, name_id).text == "Ada")
    test_check(has_text(form.view, "Hello, Ada"))
    test_check(not has_text(form.view, "Saved: Mox"))
    print("PASS form editing, validation, Save once, reset, conditional identity and stale remount events")

    replace(form, "/p1", "λ🙂")
    _ = form.update(Event(KeyEvent(KEY_BACKSPACE)))
    test_check(form.component.root.name == "λ")
    _ = form.update(Event(CompositionEvent("に", 0, 1)))
    test_check(form.component.root.name == "λ")
    _ = form.update(Event(TextInputEvent("日")))
    test_check(form.component.root.name == "λ日")
    _ = form.update(Event(KeyEvent(KEY_A, MOD_COMMAND)))
    _ = form.update(Event(KeyEvent(KEY_C, MOD_COMMAND)))
    test_check(form.clipboard_text() == "λ日")
    _ = form.update(Event(KeyEvent(KEY_X, MOD_COMMAND)))
    test_check(form.component.root.name == "")
    _ = form.update(Event(KeyEvent(KEY_V, MOD_COMMAND)))
    test_check(form.component.root.name == "λ日")
    _ = form.update(Event(KeyEvent(KEY_TAB)))
    test_check(form.focus_id() == id(form, "/p2"))
    print("PASS Unicode, synthetic composition, App clipboard and Tab")

    var editors = App[HandlerHost[SharedEditors]](HandlerHost[SharedEditors](SharedEditors()), Rect(0, 0, 520, 500))
    var a = id(editors, "/p1")
    var b = id(editors, "/p3")
    _ = click(editors, "/p1")
    _ = editors.update(Event(KeyEvent(KEY_LEFT)))
    test_check(editors.component.root.changes == 0)
    var cursor_a = editors.component.ui.controls[editors.component.ui.index(a)].editor.cursor
    replace(editors, "/p3", "Grace")
    test_check(editors.component.root.changes == 1)
    test_check(node(editors.view, a).text == "Grace")
    test_check(node(editors.view, b).text == "Grace")
    test_check(editors.component.ui.controls[editors.component.ui.index(a)].editor.cursor == cursor_a)
    _ = editors.update(Event(CompositionEvent("に", 0, 1)))
    test_check(editors.component.root.changes == 1)
    test_check(editors.component.ui.controls[editors.component.ui.index(b)].editor.has_composition())
    _ = editors.update(Event(TextInputEvent("日")))
    test_check(editors.component.root.changes == 2)
    var cursor_b = editors.component.ui.controls[editors.component.ui.index(b)].editor.cursor
    _ = editors.resize(Rect(0, 0, 550, 600))
    test_check(editors.focus_id() == b)
    test_check(editors.component.ui.controls[editors.component.ui.index(b)].editor.cursor == cursor_b)
    test_check(editors.component.root.changes == 2)
    print("PASS shared editors, separate cursors; value handlers skip cursor/selection/composition-only changes")

    var nested = App[HandlerHost[TwoForms]](HandlerHost[TwoForms](TwoForms()), Rect(0, 0, 520, 1000))
    replace(nested, "/k5:first/p1", "Grace")
    _ = click(nested, "/k5:first/p4")
    test_check(nested.component.root.first.saved == "Grace")
    test_check(nested.component.root.second.name == "Ada")
    test_check(nested.component.root.second.saved == "")
    _ = click(nested, "/k6:second/p2")
    replace(nested, "/k6:second/k8:nickname/p1", "Mox")
    _ = click(nested, "/k6:second/p4")
    test_check(nested.component.root.second.saved == "Mox")
    test_check(nested.component.root.first.saved == "Grace")
    _ = click(nested, "/k5:first/p2")
    test_check(id(nested, "/k5:first/k8:nickname/p1") != id(nested, "/k6:second/k8:nickname/p1"))
    print("PASS reusable form and independent nested state; duplicate local scope names across instances")

    var rows = App[HandlerHost[Rows]](HandlerHost[Rows](Rows()), Rect(0, 0, 520, 900))
    var alpha_editor = id(rows, "/k2:10/p2")
    var beta_editor = id(rows, "/k2:20/p2")
    var alpha_button = id(rows, "/k2:10/p0")
    _ = click(rows, "/k2:10/p2")
    _ = rows.update(Event(KeyEvent(KEY_LEFT)))
    var cursor = rows.component.ui.controls[rows.component.ui.index(alpha_editor)].editor.cursor
    var temp = rows.component.root.items[0]
    rows.component.root.items[0] = rows.component.root.items[1]
    rows.component.root.items[1] = temp
    refresh(rows)
    test_check(id(rows, "/k2:10/p2") == alpha_editor)
    test_check(id(rows, "/k2:20/p2") == beta_editor)
    test_check(rows.focus_id() == alpha_editor)
    test_check(rows.component.ui.controls[rows.component.ui.index(alpha_editor)].editor.cursor == cursor)
    _ = rows.update(Event(TextInputEvent("!")))
    test_check(rows.component.root.items[1].name == "Alph!a")
    _ = click(rows, "/k2:10/p0")
    test_check(rows.component.root.items[1].count == 1)
    test_check(rows.component.root.items[0].count == 0)
    rows.component.root.items.insert(0, Row(30, "Gamma"))
    refresh(rows)
    test_check(id(rows, "/k2:10/p0") == alpha_button)
    test_check(id(rows, "/k2:20/p2") == beta_editor)
    _ = rows.component.root.items.pop()
    refresh(rows)
    var old = Event(KeyEvent(KEY_SPACE))
    old.set_target(alpha_button)
    test_check(not rows.component.update(old, rows.view))
    rows.component.root.items.append(Row(10, "New Alpha"))
    refresh(rows)
    test_check(id(rows, "/k2:10/p0") != alpha_button)
    test_check(not rows.component.update(old, rows.view))
    test_check(rows.component.root.items[2].count == 0)
    print("PASS keyed reorder/insertion/removal/remount, cursor/focus continuity and owned item context")

    var unkeyed = App[HandlerHost[UnkeyedRows]](HandlerHost[UnkeyedRows](UnkeyedRows()), Rect(0, 0, 520, 500))
    _ = click(unkeyed, "/p1")
    var positional_id = unkeyed.focus_id()
    test_check(node(unkeyed.view, positional_id).text == "Alpha")
    unkeyed.component.root.reverse = True
    refresh(unkeyed)
    test_check(unkeyed.focus_id() == positional_id)
    test_check(node(unkeyed.view, positional_id).text == "Beta")
    print("KNOWN LIMIT position-only identity transfers focus to another item after reorder")
    print("All handler API checks passed")
