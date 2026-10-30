"""Real App integration checks for the bounded current-state composition gate."""
from application import Application, Workspace
from editor import EditorAction, EditorRoute, editor_view
from runtime import HandlerHost, Screen, UI
from moxi import (
    App, Rect, Point, Event, ClickEvent, KeyEvent, TextInputEvent,
    test_check, KEY_A, KEY_LEFT, KEY_SPACE, MOD_COMMAND,
)


def id[R: Screen & Deinitable](app: App[HandlerHost[R]], path: String) -> Int:
    for control in app.component.ui.controls:
        if control.path == path and control.active:
            return control.id
    test_check(False)
    return -1


def click[R: Screen & Deinitable](mut app: App[HandlerHost[R]], path: String):
    var bounds = app.view.bounds_for(id(app, path))
    _ = app.update(ClickEvent(Point(bounds.x + 8, bounds.y + 8)))


def replace[R: Screen & Deinitable](mut app: App[HandlerHost[R]], path: String, text: String):
    click(app, path)
    _ = app.update(Event(KeyEvent(KEY_A, MOD_COMMAND)))
    _ = app.update(Event(TextInputEvent(text)))


def refresh[R: Screen & Deinitable](mut app: App[HandlerHost[R]]):
    app.component.refresh()
    app.rebuild()


struct FlatApplication(Screen, EditorRoute):
    """Same component under another root, with a different state and UI path."""
    var workspace: Workspace
    def __init__(out self):
        self.workspace = Workspace()

    def route_editor(mut self, key: Int, action: EditorAction, text: String):
        for index in range(len(self.workspace.editors)):
            if self.workspace.editors[index].key == key and self.workspace.editors[index].mounted:
                action(self.workspace.editors[index], self.workspace.document, text)
                return

    def render(self, mut ui: UI[Self]):
        ui.begin_scope("panel")
        for editor in self.workspace.editors:
            editor_view(ui, editor, self.workspace.document)
        ui.end_scope()


def drafts_and_history():
    var app = App(HandlerHost(Application()), Rect(0, 0, 640, 2000))
    replace(app, "/k8:editor-1/p2", "  Grace  ")
    replace(app, "/k8:editor-1/p4", "private")
    test_check(app.component.root.shell.workspace.document.name == "Ada")
    test_check(app.component.root.shell.workspace.editors[1].draft == "Ada")
    test_check(app.component.root.shell.workspace.editors[1].note == "")
    var renders = app.component.renders
    click(app, "/k8:editor-1/p5")
    test_check(app.component.renders == renders + 1)
    test_check(app.component.root.shell.workspace.document.name == "Grace")
    test_check(app.component.root.shell.workspace.document.commits == 1)
    test_check(len(app.component.root.shell.workspace.document.history) == 1)
    test_check(app.component.root.shell.workspace.editors[0].draft == "Grace")
    test_check(app.component.root.shell.workspace.editors[0].note == "private")
    var labels = 0
    for index in range(app.view.child_count()):
        if app.view.child(index).text == "Current: Grace":
            labels += 1
    test_check(labels == 2)
    refresh(app)
    _ = app.resize(Rect(0, 0, 700, 2000))
    test_check(app.paint().count() > 0)
    test_check(app.component.root.shell.workspace.document.commits == 1)
    click(app, "/k8:editor-1/p5")
    test_check(app.component.root.shell.workspace.document.commits == 1)
    replace(app, "/k8:editor-2/p2", "Lin")
    click(app, "/k8:editor-2/p5")
    test_check(app.component.root.shell.workspace.editors[1].error == "Document changed; reload before applying")
    test_check(app.component.root.shell.workspace.editors[1].draft == "Lin")
    test_check(app.component.root.shell.workspace.document.name == "Grace")
    click(app, "/k8:editor-2/p6")
    replace(app, "/k8:editor-2/p2", "Lin")
    click(app, "/k8:editor-2/p5")
    test_check(app.component.root.shell.workspace.document.commits == 2)
    click(app, "/p1")
    test_check(app.component.root.shell.workspace.document.name == "Grace")
    test_check(app.component.root.shell.workspace.document.revision == 3)
    test_check(app.component.root.shell.workspace.editors[1].draft == "Lin")
    click(app, "/k8:editor-2/p5")
    test_check(app.component.root.shell.workspace.editors[1].error == "Document changed; reload before applying")
    click(app, "/p1")
    test_check(app.component.root.shell.workspace.document.name == "Ada")
    test_check(app.component.root.shell.workspace.document.revision == 4)
    click(app, "/p1")
    test_check(app.component.root.shell.workspace.document.revision == 4)
    print("PASS independent drafts/notes, normalized commit, shared refresh, once-only effects, no-op, conflict and undo")


def owner_policy():
    var app = App(HandlerHost(Application()), Rect(0, 0, 640, 2000))
    replace(app, "/k8:editor-1/p2", " ")
    test_check(app.component.root.shell.workspace.editors[0].draft == " ")
    click(app, "/k8:editor-1/p5")
    test_check(app.component.root.shell.workspace.editors[0].error == "Name required")
    app.component.root.shell.workspace.document.set_max_length(3)
    refresh(app)
    replace(app, "/k8:editor-1/p2", "Grace")
    replace(app, "/k8:editor-2/p2", "Linus")
    click(app, "/k8:editor-1/p5")
    click(app, "/k8:editor-2/p5")
    test_check(app.component.root.shell.workspace.editors[0].error == "Name is too long")
    test_check(app.component.root.shell.workspace.editors[1].error == "Name is too long")
    app.component.root.shell.workspace.document.set_writable(False)
    refresh(app)
    replace(app, "/k8:editor-2/p2", "Lin")
    click(app, "/k8:editor-2/p5")
    test_check(app.component.root.shell.workspace.editors[1].error == "Document is read-only")
    test_check(app.component.root.shell.workspace.document.commits == 0)
    test_check(len(app.component.root.shell.workspace.document.history) == 0)
    app.component.root.shell.workspace.document.set_writable(True)
    click(app, "/k8:editor-2/p5")
    test_check(app.component.root.shell.workspace.document.name == "Lin")
    app.component.root.shell.workspace.document.set_writable(False)
    click(app, "/p1")
    test_check(app.component.root.shell.workspace.document.name == "Lin")
    test_check(len(app.component.root.shell.workspace.document.history) == 1)
    print("PASS incomplete draft, owner-only length/read-only policy for both instances, rejected edits leave history unchanged")


def identity_and_composition():
    var app = App(HandlerHost(Application()), Rect(0, 0, 640, 2000))
    var first_id = id(app, "/k8:editor-1/p2")
    click(app, "/p4")
    test_check(len(app.component.root.shell.workspace.editors) == 3)
    test_check(id(app, "/k8:editor-1/p2") == first_id)
    replace(app, "/k8:editor-3/p4", "third note")
    replace(app, "/k8:editor-3/p2", "Edsger")
    click(app, "/k8:editor-3/p5")
    test_check(app.component.root.shell.workspace.document.name == "Edsger")
    test_check(app.component.root.shell.workspace.editors[0].draft == "Ada")
    click(app, "/k8:editor-1/p2")
    _ = app.update(Event(KeyEvent(KEY_LEFT)))
    var cursor = app.component.ui.controls[app.component.ui.index(first_id)].editor.cursor
    var temp = app.component.root.shell.workspace.editors[0]
    app.component.root.shell.workspace.editors[0] = app.component.root.shell.workspace.editors[1]
    app.component.root.shell.workspace.editors[1] = temp
    refresh(app)
    test_check(id(app, "/k8:editor-1/p2") == first_id)
    test_check(app.focus_id() == first_id)
    test_check(app.component.ui.controls[app.component.ui.index(first_id)].editor.cursor == cursor)
    _ = app.update(Event(TextInputEvent("!")))
    test_check(app.component.root.shell.workspace.editors[1].draft == "Ad!a")
    test_check(app.component.root.shell.workspace.editors[0].draft == "Ada")
    var removed_input = id(app, "/k8:editor-2/p2")
    var removed_button = id(app, "/k8:editor-2/p5")
    click(app, "/p2")
    test_check(app.component.ui.index(removed_input) < 0)
    var stale_text = Event(TextInputEvent("bad"))
    stale_text.set_target(removed_input)
    var stale_apply = Event(KeyEvent(KEY_SPACE))
    stale_apply.set_target(removed_button)
    test_check(not app.component.update(stale_text, app.view))
    test_check(not app.component.update(stale_apply, app.view))
    click(app, "/p3")
    test_check(id(app, "/k8:editor-2/p2") != removed_input)
    test_check(id(app, "/k8:editor-2/p5") != removed_button)
    test_check(app.component.root.shell.workspace.editors[0].draft == "Edsger")
    test_check(not app.component.update(stale_text, app.view))
    test_check(not app.component.update(stale_apply, app.view))
    test_check(app.component.root.shell.workspace.document.commits == 1)
    var flat = App(HandlerHost(FlatApplication()), Rect(0, 0, 640, 2000))
    replace(flat, "/k5:panel/k8:editor-1/p2", "Grace")
    click(flat, "/k5:panel/k8:editor-1/p5")
    test_check(flat.component.root.workspace.document.name == "Grace")
    test_check(flat.component.root.workspace.editors[1].draft == "Ada")
    print("PASS third instance, second root/nested scope, keyed reorder, focus/cursor continuity, removal/remount and stale targets")


def copy_isolation():
    var source = Application()
    source.shell.workspace.editors[0].set_draft("Grace")
    source.shell.workspace.editors[0].apply(source.shell.workspace.document)
    var snapshot = source
    source.shell.workspace.document.undo()
    source.shell.workspace.editors[0].set_note("changed")
    source.shell.workspace.editors[0].mounted = False
    test_check(snapshot.shell.workspace.document.name == "Grace")
    test_check(len(snapshot.shell.workspace.document.history) == 1)
    test_check(snapshot.shell.workspace.editors[0].note == "")
    test_check(snapshot.shell.workspace.editors[0].mounted)
    print("PASS copied nested state/history are isolated values")


def main():
    drafts_and_history()
    owner_policy()
    identity_and_composition()
    copy_isolation()
