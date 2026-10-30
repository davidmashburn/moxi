"""Composition source under test: one route, regardless of fields or instances."""
from std.collections import List
from document import Document
from editor import Editor
from bindings import Action
from runtime import Screen, UI


struct Workspace(ImplicitlyCopyable):
    var document: Document
    var editors: List[Editor]

    def __init__(out self):
        self.document = Document()
        self.editors = List[Editor]()
        self.editors.append(Editor(1, self.document))
        self.editors.append(Editor(2, self.document))

    def __init__(out self, *, copy: Self):
        self.document = copy.document
        self.editors = copy.editors.copy()


struct Shell(ImplicitlyCopyable):
    var workspace: Workspace
    def __init__(out self):
        self.workspace = Workspace()


struct Application(Screen):
    var shell: Shell
    var next_key: Int

    def __init__(out self):
        self.shell = Shell()
        self.next_key = 3

    def route_editor(mut self, key: Int, action: Action[Editor, Document]):
        for index in range(len(self.shell.workspace.editors)):
            if self.shell.workspace.editors[index].key == key and self.shell.workspace.editors[index].mounted:
                action(self.shell.workspace.editors[index], self.shell.workspace.document)
                return

    def undo(mut self):
        self.shell.workspace.document.undo()

    def remove_first(mut self):
        self.shell.workspace.editors[0].mounted = False

    def remount_first(mut self):
        var key = self.shell.workspace.editors[0].key
        self.shell.workspace.editors[0] = Editor(key, self.shell.workspace.document)

    def add_editor(mut self):
        self.shell.workspace.editors.append(Editor(self.next_key, self.shell.workspace.document))
        self.next_key += 1

    def render(self, mut ui: UI[Self]):
        ui.label("Document: " + self.shell.workspace.document.name)
        ui.button("Undo", Self.undo)
        ui.button("Remove first", Self.remove_first)
        ui.button("Remount first", Self.remount_first)
        ui.button("Add editor", Self.add_editor)
        for editor in self.shell.workspace.editors:
            if editor.mounted:
                ui.child(editor, self.shell.workspace.document, Self.route_editor, key=editor.key)
