"""Reusable editor: ordinary methods bound directly to its controls."""
from document import Document
from runtime import UI, Pane


struct Editor(Pane):
    comptime Context = Document
    var key: Int
    var mounted: Bool
    var draft: String
    var base_revision: Int
    var note: String
    var error: String

    def __init__(out self, key: Int, document: Document):
        self.key = key
        self.mounted = True
        self.draft = document.name
        self.base_revision = document.revision
        self.note = ""
        self.error = ""

    def set_draft(mut self, text: String):
        self.draft = text
        self.error = ""

    def set_note(mut self, text: String):
        self.note = text

    def apply(mut self, mut document: Document):
        self.error = document.rename(self.draft, self.base_revision)
        if self.error == "":
            self.reload(document)

    def reload(mut self, document: Document):
        self.draft = document.name
        self.base_revision = document.revision
        self.error = ""

    def render(self, mut ui: UI[Self, Document], document: Document):
        ui.label("Current: " + document.name)
        ui.text_input("Name draft", self.draft, Self.set_draft)
        ui.text_input("Private note", self.note, Self.set_note)
        ui.button("Apply", Self.apply)
        ui.button("Reload", Self.reload)
        ui.label(self.error)
