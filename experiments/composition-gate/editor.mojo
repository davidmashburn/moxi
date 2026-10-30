"""Reusable editor and its explicitly counted current-state callback adapter."""
from document import Document
from runtime import UI


struct Editor(ImplicitlyCopyable):
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


comptime EditorAction = def(mut Editor, mut Document, String) thin -> None


trait EditorRoute(ImplicitlyCopyable):
    def route_editor(mut self, key: Int, action: EditorAction, text: String): ...


# These bridges adapt ordinary methods to the current pair supplied by the root.
# They are real component-specific boilerplate, not free framework machinery.
def write_draft(mut editor: Editor, mut document: Document, text: String):
    editor.set_draft(text)


def write_note(mut editor: Editor, mut document: Document, text: String):
    editor.set_note(text)


def apply_draft(mut editor: Editor, mut document: Document, text: String):
    editor.apply(document)


def reload_draft(mut editor: Editor, mut document: Document, text: String):
    editor.reload(document)


def draft_changed[R: EditorRoute](mut root: R, key: Int, text: String):
    root.route_editor(key, write_draft, text)


def note_changed[R: EditorRoute](mut root: R, key: Int, text: String):
    root.route_editor(key, write_note, text)


def apply_clicked[R: EditorRoute](mut root: R, key: Int):
    root.route_editor(key, apply_draft, "")


def reload_clicked[R: EditorRoute](mut root: R, key: Int):
    root.route_editor(key, reload_draft, "")


def editor_view[R: EditorRoute](mut ui: UI[R], editor: Editor, document: Document):
    ui.begin_scope("editor-" + String(editor.key))
    ui.label("Current: " + document.name)
    ui.text_input_for("Name draft", editor.draft, draft_changed[R], editor.key)
    ui.text_input_for("Private note", editor.note, note_changed[R], editor.key)
    ui.button_for("Apply", apply_clicked[R], editor.key)
    ui.button_for("Reload", reload_clicked[R], editor.key)
    ui.label(editor.error)
    ui.end_scope()
