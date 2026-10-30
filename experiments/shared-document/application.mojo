"""Composition source under test: one route, regardless of fields or instances."""
from std.collections import List
from document_handle import DocumentHandle
from editor import Editor, EditorAction, EditorRoute, editor_view
from runtime import Screen, UI


struct Workspace(ImplicitlyCopyable):
    var document: DocumentHandle
    var editors: List[Editor]

    def __init__(out self):
        self.document = DocumentHandle()
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


struct Application(Screen, EditorRoute):
    var shell: Shell
    var next_key: Int

    def __init__(out self):
        self.shell = Shell()
        self.next_key = 3

    def route_editor(mut self, key: Int, action: EditorAction, text: String):
        for index in range(len(self.shell.workspace.editors)):
            if self.shell.workspace.editors[index].key == key and self.shell.workspace.editors[index].mounted:
                action(self.shell.workspace.editors[index], text)
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
        ui.label("Document: " + self.shell.workspace.document.name())
        ui.button("Undo", Self.undo)
        ui.button("Remove first", Self.remove_first)
        ui.button("Remount first", Self.remount_first)
        ui.button("Add editor", Self.add_editor)
        for editor in self.shell.workspace.editors:
            if editor.mounted:
                editor_view(ui, editor)
