"""The same Editor inside a reusable pane, with context routed through two levels."""
from std.collections import List
from runtime import UI, Screen, Pane, HandlerHost
from bindings import Action
from editor import Editor
from document import Document
from check import replace, click, id, refresh
from moxi import App, Rect, Event, KeyEvent, KEY_SPACE, test_check

comptime GROUP_KEY = 10
comptime EDITOR_KEY = 1
comptime EDITOR_PATH = "/k2:10/k1:1"


struct Group(Pane):
    comptime Context = Document
    var editor: Editor
    def __init__(out self, document: Document):
        self.editor = Editor(EDITOR_KEY, document)

    def route_editor(mut self, mut document: Document, key: Int, action: Action[Editor, Document]):
        if self.editor.key == key and self.editor.mounted:
            action(self.editor, document)

    def render(self, mut ui: UI[Self, Document], document: Document):
        if self.editor.mounted:
            ui.child(self.editor, document, Self.route_editor, key=self.editor.key)


struct Nested(Screen):
    var document: Document
    var group: Group
    def __init__(out self):
        self.document = Document()
        self.group = Group(self.document)

    def replace_document(mut self):
        self.document = Document()
        self.document.name = "Lin"

    def unmount_editor(mut self):
        self.group.editor.set_draft("should not commit")
        self.group.editor.mounted = False

    def route_group(mut self, key: Int, action: Action[Group, Document]):
        if key == GROUP_KEY:
            action(self.group, self.document)

    def render(self, mut ui: UI[Self]):
        ui.child(self.group, self.document, Self.route_group, key=GROUP_KEY)


def main():
    var app = App(HandlerHost(Nested()), Rect(0, 0, 640, 1000))
    replace(app, EDITOR_PATH + "/p2", "Grace")
    click(app, EDITOR_PATH + "/p5")
    test_check(app.component.root.document.name == "Grace")
    test_check(app.component.root.document.commits == 1)
    # A retained UI copied to another root must route through that root's current document.
    var copied = app.component
    copied.root.replace_document()
    var reload_id = id(app, EDITOR_PATH + "/p6")
    var event = Event(KeyEvent(KEY_SPACE))
    event.set_target(reload_id)
    test_check(copied.update(event, app.view))
    test_check(copied.root.group.editor.draft == "Lin")
    test_check(app.component.root.group.editor.draft == "Grace")
    test_check(app.component.root.document.name == "Grace")
    # Even before refresh, the current route refuses the now-unmounted child.
    var apply_id = id(app, EDITOR_PATH + "/p5")
    app.component.root.unmount_editor()
    event.set_target(apply_id)
    _ = app.component.update(event, app.view)
    test_check(app.component.root.document.name == "Grace")
    test_check(app.component.ui.index(apply_id) < 0)
    test_check(not app.component.update(event, app.view))
    print("PASS nested reusable pane, inherited context, copied Host routes to its current document, pre-refresh unmount blocks mutation")
