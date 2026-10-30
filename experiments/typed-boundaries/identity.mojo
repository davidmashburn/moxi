"""Changing control structure needs a stable scope, independent of caching."""
from runtime import Pane, UI, RetainedUI, require

# The runner changes this constant for the expected failing negative control.
comptime SCOPED = True

struct Panel(Pane):
    comptime Context = NoneType
    var notice: Bool
    var note: String
    def __init__(out self):
        self.notice = False
        self.note = "draft"
    def set_note(mut self, value: String):
        self.note = value
    def render(self, mut ui: UI[Self], context: NoneType):
        if self.notice:
            comptime if SCOPED:
                ui.begin_scope("notice")
            ui.label("Unsaved changes")
            comptime if SCOPED:
                ui.end_scope()
        ui.text_input("Note", self.note, Self.set_note)


def main():
    var panel = Panel()
    var retained = RetainedUI[Panel]()
    var before = UI[Panel]()
    panel.render(before, None)
    retained.rebuild(before.declarations)
    var input_id = retained.view.child(1).id
    var index = retained.index(input_id)
    retained.controls[index].editor.set_composition("marked", 1, 2)
    panel.notice = True
    var after = UI[Panel]()
    panel.render(after, None)
    retained.rebuild(after.declarations)
    require(retained.view.child(2).id == input_id, "input identity survives conditional notice")
    require(retained.controls[retained.index(input_id)].editor.composition == "marked", "composition survives conditional notice")
    print("PASS scoped conditional insertion preserves control identity and composition")
