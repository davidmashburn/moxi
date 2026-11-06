"""Collection keys belong to entries, so they travel with reordered drafts."""
from moxi.authoring import Keyed, field
from moxi.authoring import Pane, Screen, UI

comptime EDITORS = 1


struct Editor(Pane):
    comptime Context = NoneType
    var draft: String

    def __init__(out self, draft: String):
        self.draft = draft

    def change(mut self, text: String):
        self.draft = text

    def render(self, mut ui: UI[Self, NoneType], context: NoneType):
        ui.text_input("Draft", self.draft, Self.change)


struct Workspace(Screen):
    var editors: Keyed[Editor]

    def __init__(out self):
        self.editors = Keyed[Editor]()
        _ = self.editors.append(Editor("First"))
        _ = self.editors.append(Editor("Second"))

    def reverse(mut self):
        var first = self.editors.entries[0]
        self.editors.entries[0] = self.editors.entries[1]
        self.editors.entries[1] = first

    def new_drafts(mut self):
        self.editors.reset()
        _ = self.editors.append(Editor("New first"))
        _ = self.editors.append(Editor("New second"))

    def render(self, mut ui: UI[Self]):
        ui.button("Reverse", Self.reverse)
        ui.button("New drafts", Self.new_drafts)
        field["editors"](ui, self, NoneType(), key=EDITORS)
