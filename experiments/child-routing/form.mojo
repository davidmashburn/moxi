"""Same greeting behavior, with handlers owned by the form itself."""
from runtime import Screen, UI


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
        ui.text_input("Name", self.name, Self.set_name)
        ui.checkbox("Use nickname", self.use_nickname, Self.set_use_nickname)
        if self.use_nickname:
            ui.begin_scope("nickname")
            ui.text_input("Nickname", self.nickname, Self.set_nickname)
            ui.end_scope()
        var selected = self.selected()
        if selected != "":
            ui.label("Hello, " + selected)
        else:
            ui.label("Name required")
        ui.button("Save", Self.save, enabled=selected != "")
        ui.button("Restore defaults", Self.restore)
        if self.saved != "":
            ui.begin_scope("saved")
            ui.label("Saved: " + self.saved)
            ui.end_scope()
