"""A shared document with keyed groups and keyed local drafts."""
from moxi.authoring import Action, Keyed, field
from moxi import App, Rect
from moxi.authoring import HandlerHost, Pane, Screen, UI
from shared import Document, Draft


comptime GROUPS = 1
comptime DRAFTS = 2


struct Group(Pane):
    comptime Context = Document
    var name: String
    var drafts: Keyed[Draft]

    def __init__(out self, name: String, first: String, second: String):
        self.name = name
        self.drafts = Keyed[Draft]()
        _ = self.drafts.append(Draft(first))
        _ = self.drafts.append(Draft(second))

    def add_draft(mut self):
        _ = self.drafts.append(Draft(self.name + " new draft"))

    def close_first_draft(mut self):
        if len(self.drafts.entries) > 0:
            self.drafts.remove(self.drafts.entries[0].key)

    def reverse_drafts(mut self):
        for i in range(len(self.drafts.entries) // 2):
            var j = len(self.drafts.entries) - i - 1
            var entry = self.drafts.entries[i]
            self.drafts.entries[i] = self.drafts.entries[j]
            self.drafts.entries[j] = entry

    def reset_drafts(mut self):
        self.drafts.reset()
        _ = self.drafts.append(Draft(self.name + " reset draft"))

    def revert_group(mut self, document: Document):
        for ref entry in self.drafts.entries:
            entry.value.revert(document)

    def render(self, mut ui: UI[Self, Self.Context], context: Document):
        ui.label(self.name)
        ui.button("Add draft", Self.add_draft)
        ui.button("Close first draft", Self.close_first_draft)
        ui.button("Reverse drafts", Self.reverse_drafts)
        ui.button("Reset drafts", Self.reset_drafts)
        ui.button("Revert group", Self.revert_group)
        field["drafts"](ui, self, context, key=DRAFTS)


struct Workspace(Screen):
    var document: Document
    var groups: Keyed[Group]

    def __init__(out self):
        self.document = Document()
        self.groups = Keyed[Group]()
        _ = self.groups.append(Group("Alpha", "Alpha first", "Alpha second"))
        _ = self.groups.append(Group("Beta", "Beta first", "Beta second"))

    def add_group(mut self):
        _ = self.groups.append(Group("New group", "New first", "New second"))

    def reverse_groups(mut self):
        for i in range(len(self.groups.entries) // 2):
            var j = len(self.groups.entries) - i - 1
            var entry = self.groups.entries[i]
            self.groups.entries[i] = self.groups.entries[j]
            self.groups.entries[j] = entry

    def close_first_group(mut self):
        if len(self.groups.entries) > 0:
            self.groups.remove(self.groups.entries[0].key)

    def route_groups(mut self, key: Int, action: Action[Keyed[Group], Document]):
        if key == GROUPS:
            action(self.groups, self.document)

    def render(self, mut ui: UI[Self]):
        ui.label("Saved: " + self.document.title)
        ui.button("Add group", Self.add_group)
        ui.button("Reverse groups", Self.reverse_groups)
        ui.button("Close first group", Self.close_first_group)
        ui.child(self.groups, self.document, Self.route_groups, key=GROUPS)


def main():
    var app = App(HandlerHost(Workspace()), Rect(0, 0, 560, 700))
    print("Workspace groups:", len(app.component.root.groups.entries))
