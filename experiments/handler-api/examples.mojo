"""Compiled authoring surface: immutable rendering, ordinary method handlers."""
from std.collections import List
from runtime import Screen, UI


def counter[S: ImplicitlyCopyable](mut ui: UI[S], count: Int, increment: def(mut S) thin -> None):
    ui.button("Clicked " + String(count) + " times", increment)


struct Counters(Screen):
    var first: Int
    var second: Int
    var shared: Int

    def __init__(out self):
        self.first = 0
        self.second = 0
        self.shared = 0

    def increment_first(mut self):
        self.first += 1

    def increment_second(mut self):
        self.second += 1

    def increment_shared(mut self):
        self.shared += 1

    def render(self, mut ui: UI[Self]):
        ui.label("Independent counters")
        counter(ui, self.first, Self.increment_first)
        counter(ui, self.second, Self.increment_second)
        ui.label("Shared counters")
        counter(ui, self.shared, Self.increment_shared)
        counter(ui, self.shared, Self.increment_shared)


struct GreetingForm(Screen):
    var name: String
    var nickname: String
    var use_nickname: Bool
    var saved: String
    var saves: Int

    def __init__(out self):
        self.name = "Ada"
        self.nickname = ""
        self.use_nickname = False
        self.saved = ""
        self.saves = 0

    def selected(self) -> String:
        var source = self.name
        if self.use_nickname:
            source = self.nickname
        return String(source.strip())

    def set_name(mut self, text: String):
        self.name = text

    def set_nickname(mut self, text: String):
        self.nickname = text

    def set_use_nickname(mut self, checked: Bool):
        self.use_nickname = checked

    def save(mut self):
        self.saved = self.selected()
        self.saves += 1

    def restore(mut self):
        self.name = "Ada"
        self.nickname = ""
        self.use_nickname = False
        self.saved = ""

    def render(self, mut ui: UI[Self]):
        greeting_form(ui, self, Self.set_name, Self.set_nickname,
                      Self.set_use_nickname, Self.save, Self.restore)


def greeting_form[S: ImplicitlyCopyable](
    mut ui: UI[S], form: GreetingForm,
    set_name: def(mut S, String) thin -> None,
    set_nickname: def(mut S, String) thin -> None,
    set_use_nickname: def(mut S, Bool) thin -> None,
    save: def(mut S) thin -> None,
    restore: def(mut S) thin -> None,
):
    ui.text_input("Name", form.name, set_name)
    ui.checkbox("Use nickname", form.use_nickname, set_use_nickname)
    if form.use_nickname:
        ui.begin_scope("nickname")
        ui.text_input("Nickname", form.nickname, set_nickname)
        ui.end_scope()
    var selected = form.selected()
    if selected != "":
        ui.label("Hello, " + selected)
    else:
        ui.label("Name required")
    ui.button("Save", save, enabled=selected != "")
    ui.button("Restore defaults", restore)
    if form.saved != "":
        ui.begin_scope("saved")
        ui.label("Saved: " + form.saved)
        ui.end_scope()


struct TwoForms(Screen):
    """Nested state is explicit; forwarding is intentionally visible."""
    var first: GreetingForm
    var second: GreetingForm

    def __init__(out self):
        self.first = GreetingForm()
        self.second = GreetingForm()

    def first_name(mut self, text: String):
        self.first.set_name(text)
    def first_nickname(mut self, text: String):
        self.first.set_nickname(text)
    def first_use_nickname(mut self, checked: Bool):
        self.first.set_use_nickname(checked)
    def first_save(mut self):
        self.first.save()
    def first_restore(mut self):
        self.first.restore()
    def second_name(mut self, text: String):
        self.second.set_name(text)
    def second_nickname(mut self, text: String):
        self.second.set_nickname(text)
    def second_use_nickname(mut self, checked: Bool):
        self.second.set_use_nickname(checked)
    def second_save(mut self):
        self.second.save()
    def second_restore(mut self):
        self.second.restore()

    def render(self, mut ui: UI[Self]):
        ui.label("First form")
        ui.begin_scope("first")
        greeting_form(ui, self.first, Self.first_name, Self.first_nickname,
                      Self.first_use_nickname, Self.first_save, Self.first_restore)
        ui.end_scope()
        ui.label("Second form")
        ui.begin_scope("second")
        greeting_form(ui, self.second, Self.second_name, Self.second_nickname,
                      Self.second_use_nickname, Self.second_save, Self.second_restore)
        ui.end_scope()


struct Row(ImplicitlyCopyable):
    var id: Int
    var name: String
    var count: Int
    def __init__(out self, id: Int, name: String):
        self.id = id
        self.name = name
        self.count = 0


def row[S: ImplicitlyCopyable](mut ui: UI[S], item: Row,
    increment: def(mut S, Int) thin -> None,
    rename: def(mut S, Int, String) thin -> None,
):
    ui.begin_scope(String(item.id))
    ui.button_for("Row " + String(item.id) + ": " + String(item.count), increment, item.id)
    ui.text_input_for("Name", item.name, rename, item.id)
    ui.end_scope()


struct Rows(Screen):
    var items: List[Row]
    def __init__(out self):
        self.items = [Row(10, "Alpha"), Row(20, "Beta")]
    def __init__(out self, *, copy: Self):
        self.items = copy.items.copy()
    def increment(mut self, key: Int):
        for i in range(len(self.items)):
            if self.items[i].id == key:
                self.items[i].count += 1
                return
    def rename(mut self, key: Int, text: String):
        for i in range(len(self.items)):
            if self.items[i].id == key:
                self.items[i].name = text
                return
    def render(self, mut ui: UI[Self]):
        for item in self.items:
            row(ui, item, Self.increment, Self.rename)
