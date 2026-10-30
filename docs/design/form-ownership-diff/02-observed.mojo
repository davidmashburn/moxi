# SOURCE SPECIFICATION ONLY — proposed APIs; not a compiled application.
# Flattened from form-ownership-comparison.md for side-by-side reading.

# === COMMON CODE: ordinary domain data ===
struct Details(ImplicitlyCopyable):
    var nickname: String
    var use_nickname: Bool
    var saved: String
    var saves: Int

    def __init__(out self):
        self.nickname = ""
        self.use_nickname = False
        self.saved = ""
        self.saves = 0

    def selected(self, name: String) -> String:
        var source = name
        if self.use_nickname:
            source = self.nickname
        return String(source.strip())

    def save(mut self, name: String):
        var selected = self.selected(name)
        if selected != "":
            self.saved = selected
            self.saves += 1

    def restore(mut self):
        self.nickname = ""
        self.use_nickname = False
        self.saved = ""
        # Preserve the count of successful Save actions.


# === OWNERSHIP VARIANT ===
from proposed import Cell, UI, ProjectionUI

struct Form(ImplicitlyCopyable):
    var name: Cell[String]
    var details: Details

    def __init__(out self, name: Cell[String]):
        self.name = name       # Copies a handle to the SAME cell.
        self.details = Details()

    def rename(mut self, text: String):
        self.name.set(text)

    def nickname(mut self, text: String):
        self.details.nickname = text

    def toggle(mut self, checked: Bool):
        self.details.use_nickname = checked

    def save(mut self):
        self.details.save(self.name.get())

    def restore(mut self):
        self.name.set("Ada")
        self.details.restore()

    def render(self, mut ui: UI[Self]):
        var name = self.name.get()
        ui.text_input("Name", name, Self.rename)
        ui.checkbox("Use nickname", self.details.use_nickname, Self.toggle)
        if self.details.use_nickname:
            ui.begin_scope("nickname")
            ui.text_input("Nickname", self.details.nickname, Self.nickname)
            ui.end_scope()
        var selected = self.details.selected(name)
        if selected != "":
            ui.label("Hello, " + selected)
        else:
            ui.label("Name required")
        ui.button("Save", Self.save, enabled=selected != "")
        ui.button("Restore defaults", Self.restore)
        if self.details.saved != "":
            ui.begin_scope("saved")
            ui.label("Saved: " + self.details.saved)
            ui.end_scope()

struct Model(ImplicitlyCopyable):
    var first: Form
    var second: Form

    def __init__(out self):
        var name = Cell[String]("Ada")
        self.first = Form(name)
        self.second = Form(name)

    def first_form(mut self) -> ref[self.first] Form:
        return self.first

    def second_form(mut self) -> ref[self.second] Form:
        return self.second

    def render(self, mut ui: ProjectionUI[Self]):
        ui.project("first", self.first, Self.first_form)
        ui.project("second", self.second, Self.second_form)


# === COMMON CODE: native launch ===
from proposed import Host
from moxi import App, Rect, WindowConfig
from moxi.macos import MacOSClipboard, MacOSRenderer, MacOSWindow

def main() raises:
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    var clipboard = MacOSClipboard()
    window.open(WindowConfig("Two greeting forms", 520, 760))
    var size = window.size()
    var app = App[Host[Model]](
        Host[Model](Model()), Rect(0, 0, size.width, size.height),
    )
    app.run_with_clipboard(window, renderer, clipboard)
