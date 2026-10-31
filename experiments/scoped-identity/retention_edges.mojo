"""Combined-only checks: empty storage, same-path remount and copied indexes."""
from runtime import Screen, UI, HandlerHost, require
from moxi import App, Rect, Point, ClickEvent, Event, TextInputEvent, CompositionEvent

struct Root(Screen):
    var visible: Bool
    var text: String
    def __init__(out self):
        self.visible = True
        self.text = "initial"
    def hide(mut self):
        self.visible = False
    def show(mut self):
        self.text = "fresh"
        self.visible = True
    def set_text(mut self, value: String):
        self.text = value
    def render(self, mut ui: UI[Self]):
        if self.visible:
            ui.text_input("Text", self.text, Self.set_text)


def refresh(mut app: App[HandlerHost[Root]]):
    app.component.refresh()
    app.rebuild()


def main():
    var app = App(HandlerHost(Root()), Rect(0, 0, 600, 900))
    var old = app.component.ui.controls[1].id
    var old_path = app.component.ui.controls[1].path
    var bounds = app.view.bounds_for(old)
    _ = app.update(ClickEvent(Point(bounds.x + 8, bounds.y + 8)))
    require(app.focus_id() == old, "focus retiring control")
    var ime = Event(CompositionEvent("ime", 1, 2))
    ime.set_target(old)
    require(app.update(ime), "retiring control has IME")
    require(app.component.ui.controls[1].editor.has_composition(), "IME initialized")
    app.component.root.hide()
    refresh(app)
    require(app.focus_id() == -1, "removed focus clears")
    require(len(app.component.ui.controls) == 0, "all retired records removed")
    require(len(app.component.ui.path_indices) == 0 and len(app.component.ui.id_indices) == 0, "all retired indexes removed")
    require(app.component.ui.index(old) < 0, "old ID absent")
    var empty_copy = app.component.ui
    require(empty_copy.index(old) < 0 and len(empty_copy.controls) == 0, "empty copy has no stale index")
    app.component.root.show()
    refresh(app)
    var fresh = app.component.ui.controls[1].id
    require(app.component.ui.controls[1].path == old_path, "same path deliberately reused")
    require(fresh > old, "same path receives fresh ID after absence")
    require(app.component.ui.controls[1].editor.text == "fresh", "fresh editor text")
    require(not app.component.ui.controls[1].editor.has_composition(), "retired IME not resurrected")
    var stale = Event(TextInputEvent("stale"))
    stale.set_target(old)
    require(not app.update(stale), "same-path old event rejected")
    require(app.component.root.text == "fresh", "stale event did not write current owner")
    var copied = app.component.ui
    var declarations = UI[Root]()
    app.component.root.render(declarations)
    copied.rebuild(declarations.declarations)
    require(copied.index(fresh) == 1 and copied.next_id == app.component.ui.next_id, "live copy reuses ID")
    var empty = UI[Root]()
    copied.rebuild(empty.declarations)
    require(copied.index(fresh) < 0 and len(copied.controls) == 0, "copy retires independently")
    require(app.component.ui.index(fresh) == 1 and len(app.component.ui.controls) == 2, "original maps unchanged")
    var live = Event(TextInputEvent("live", 0, 1000000))
    live.set_target(fresh)
    require(app.update(live), "fresh event works")
    require(app.component.root.text == "live", "fresh event updates current owner")
    print("PASS empty reclamation, removed focus, same-path fresh ID, IME reset, copied index isolation")
