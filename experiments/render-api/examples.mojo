"""Author-written Mojo: ordinary fields, functions, if statements and borrows."""
from runtime import Renderable, UI


def counter(mut ui: UI, key: String, mut count: Int):
    if ui.button(key, "Clicked " + String(count) + " times"):
        count += 1


struct Counters(Renderable):
    var first: Int
    var second: Int
    var shared: Int

    def __init__(out self):
        self.first = 0
        self.second = 0
        self.shared = 0

    def render(mut self, mut ui: UI):
        ui.label("Independent counters")
        counter(ui, "first", self.first)
        counter(ui, "second", self.second)
        ui.label("Shared counters")
        counter(ui, "shared-a", self.shared)
        counter(ui, "shared-b", self.shared)


struct GreetingForm(Renderable):
    var name: String
    var nickname: String
    var use_nickname: Bool
    var saved: String

    def __init__(out self):
        self.name = "Ada"
        self.nickname = ""
        self.use_nickname = False
        self.saved = ""

    def render(mut self, mut ui: UI):
        ui.text_input("name", "Name", self.name)
        ui.checkbox("use-nickname", "Use nickname", self.use_nickname)
        if self.use_nickname:
            ui.text_input("nickname", "Nickname", self.nickname)

        var source = self.name
        if self.use_nickname:
            source = self.nickname
        var selected = String(source.strip())
        var valid = selected != ""
        if valid:
            ui.label("Hello, " + selected)
        else:
            ui.label("Name required")

        if ui.button("save", "Save", enabled=valid):
            self.saved = selected
        if ui.button("restore", "Restore defaults"):
            self.name = "Ada"
            self.nickname = ""
            self.use_nickname = False
            self.saved = ""
        if self.saved != "":
            ui.label("Saved: " + self.saved)


struct Demo(Renderable):
    var counters: Counters
    var form: GreetingForm

    def __init__(out self):
        self.counters = Counters()
        self.form = GreetingForm()

    def render(mut self, mut ui: UI):
        self.counters.render(ui)
        ui.label("Greeting form")
        self.form.render(ui)
