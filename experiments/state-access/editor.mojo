from domain import Services
from runtime import Pane, UI

struct Editor(Pane):
    comptime Context = Services
    var draft: String
    var note: String
    var error: String
    var base_identity: Int
    var base_revision: Int

    def __init__(out self, services: Services):
        self.draft = services.document.name
        self.note = ""
        self.error = ""
        self.base_identity = services.document.identity
        self.base_revision = services.document.revision

    def set_draft(mut self, text: String):
        self.draft = text
        self.error = ""

    def set_note(mut self, text: String):
        self.note = text

    def apply(mut self, mut services: Services):
        self.error = services.document.rename(self.draft, self.base_identity, self.base_revision, services.settings)
        if self.error == "":
            self.reload(services)

    def reload(mut self, services: Services):
        self.draft = services.document.name
        self.base_identity = services.document.identity
        self.base_revision = services.document.revision
        self.error = ""

    def render(self, mut ui: UI[Self, Services], services: Services):
        ui.label("Current: " + services.document.name)
        ui.text_input("Name draft", self.draft, Self.set_draft)
        ui.text_input("Private note", self.note, Self.set_note)
        ui.button("Apply", Self.apply, enabled=services.settings.writable)
        ui.button("Reload", Self.reload)
        ui.label(self.error)
