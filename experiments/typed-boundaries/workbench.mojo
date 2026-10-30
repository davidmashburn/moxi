"""Application-owned values and methods; no cache dependencies or dirty flags."""
from domain import Services, Settings, Document
from editor import Editor
from runtime import Pane, UI
from bindings import Action

# Stable domain slots. Inspector mounts use a separate increasing identity.
comptime HEADER = 1
comptime LEFT = 2
comptime RIGHT = 3
comptime SETTINGS = 4
comptime HISTORY = 5
comptime SCRATCH = 6
comptime PREVIEW = 7
comptime INSPECTOR_BASE = 100

struct Header(Pane):
    comptime Context = NoneType
    var inspector_visible: Bool
    def __init__(out self):
        self.inspector_visible = True
    def toggle(mut self):
        self.inspector_visible = not self.inspector_visible
    def render(self, mut ui: UI[Self], context: NoneType):
        ui.label("Document workbench")
        ui.button("Toggle inspector", Self.toggle)

struct SettingsPanel(Pane):
    comptime Context = Settings
    var explanation: String
    def __init__(out self):
        self.explanation = ""
    def toggle_write(mut self, mut settings: Settings):
        settings.writable = not settings.writable
    def tighter(mut self, mut settings: Settings):
        settings.max_length = 3 if settings.max_length == 24 else 24
    def set_explanation(mut self, value: String):
        self.explanation = value
    def render(self, mut ui: UI[Self, Settings], settings: Settings):
        ui.label("Writable: " + String(settings.writable))
        ui.label("Limit: " + String(settings.max_length))
        ui.button("Toggle permission", Self.toggle_write)
        ui.button("Change limit", Self.tighter)
        ui.text_input("Policy note", self.explanation, Self.set_explanation)

struct Activity(Pane):
    comptime Context = Services
    var expanded: Bool
    def __init__(out self):
        self.expanded = False
    def toggle(mut self):
        self.expanded = not self.expanded
    def undo(mut self, mut services: Services):
        services.document.undo(services.settings)
    def render(self, mut ui: UI[Self, Services], services: Services):
        ui.label("Revision: " + String(services.document.revision))
        ui.label("History: " + String(len(services.document.history)))
        ui.button("Undo", Self.undo, enabled=services.settings.writable)
        ui.button("Expand history", Self.toggle)
        if self.expanded:
            for i in range(len(services.document.history)):
                ui.label(services.document.history[i])

struct Scratchpad(Pane):
    comptime Context = NoneType
    var text: String
    def __init__(out self):
        self.text = ""
    def set_text(mut self, value: String):
        self.text = value
    def render(self, mut ui: UI[Self], context: NoneType):
        ui.text_input("Independent scratchpad", self.text, Self.set_text)

struct Inspector(Pane):
    comptime Context = Document
    var show_history: Bool
    var note: String
    def __init__(out self):
        self.show_history = False
        self.note = ""
    def toggle(mut self):
        self.show_history = not self.show_history
    def set_note(mut self, value: String):
        self.note = value
    def render(self, mut ui: UI[Self, Document], document: Document):
        ui.label("Inspect: " + document.name)
        ui.button("Inspect history", Self.toggle)
        ui.text_input("Inspector note", self.note, Self.set_note)
        if self.show_history:
            ui.label("Last: " + (document.history[len(document.history)-1] if len(document.history) > 0 else "none"))

struct Workbench(ImplicitlyCopyable):
    var services: Services
    var header: Header
    var left: Editor
    var right: Editor
    var settings: SettingsPanel
    var history: Activity
    var scratch: Scratchpad
    var preview: Editor
    var inspector: Inspector
    var inspector_epoch: Int

    def __init__(out self):
        self.services = Services()
        self.header = Header()
        self.left = Editor(self.services)
        self.right = Editor(self.services)
        self.settings = SettingsPanel()
        self.history = Activity()
        self.scratch = Scratchpad()
        self.preview = Editor(self.services)
        self.inspector = Inspector()
        self.inspector_epoch = 1

    def preview_context(self) -> Services:
        # Explicit scope override. This currently copies document history too.
        var context = self.services
        context.settings.writable = False
        return context^

    def inspector_key(self) -> Int:
        return INSPECTOR_BASE + self.inspector_epoch

    def route_header(mut self, key: Int, action: Action[Header]):
        if key != HEADER:
            return
        var was_visible = self.header.inspector_visible
        var context: NoneType = None
        action(self.header, context)
        if self.header.inspector_visible and not was_visible:
            self.inspector_epoch += 1
            self.inspector = Inspector()

    def route_left(mut self, key: Int, action: Action[Editor, Services]):
        if key == LEFT:
            action(self.left, self.services)
    def route_right(mut self, key: Int, action: Action[Editor, Services]):
        if key == RIGHT:
            action(self.right, self.services)
    def route_settings(mut self, key: Int, action: Action[SettingsPanel, Settings]):
        if key == SETTINGS:
            action(self.settings, self.services.settings)
    def route_history(mut self, key: Int, action: Action[Activity, Services]):
        if key == HISTORY:
            action(self.history, self.services)
    def route_scratch(mut self, key: Int, action: Action[Scratchpad]):
        if key == SCRATCH:
            var context: NoneType = None
            action(self.scratch, context)
    def route_preview(mut self, key: Int, action: Action[Editor, Services]):
        if key == PREVIEW:
            var context = self.preview_context()
            action(self.preview, context)
            # The scoped document is read-only and is never written back.
    def route_inspector(mut self, key: Int, action: Action[Inspector, Document]):
        if self.header.inspector_visible and key == self.inspector_key():
            action(self.inspector, self.services.document)
