# Original failed integration probe. Compiler crashed before model-method wrappers.
# Excluded from the normal suite; not a runtime assertion failure.
"""Synthetic events through real Moxi App and the existing binding runtime."""
from application import Application
from domain import Services
from editor import Editor
from adapters import Keyed
from runtime import HandlerHost, Screen, UI
from bindings import Action
from moxi import App, Rect, Point, Event, ClickEvent, KeyEvent, TextInputEvent, test_check, KEY_A, KEY_SPACE, MOD_COMMAND

def path(key: Int, position: Int) -> String:
    return "/k1:1/k1:1/k1:1/k1:" + String(key) + "/p" + String(position)

def control_id[R: Screen & Deinitable](app: App[HandlerHost[R]], target: String) -> Int:
    for control in app.component.ui.controls:
        if control.path == target and control.active:
            return control.id
    test_check(False)
    return -1

def click[R: Screen & Deinitable](mut app: App[HandlerHost[R]], target: String):
    var bounds = app.view.bounds_for(control_id(app, target))
    _ = app.update(ClickEvent(Point(bounds.x + 8, bounds.y + 8)))

def replace[R: Screen & Deinitable](mut app: App[HandlerHost[R]], target: String, text: String):
    click(app, target)
    _ = app.update(Event(KeyEvent(KEY_A, MOD_COMMAND)))
    _ = app.update(Event(TextInputEvent(text)))

def refresh[R: Screen & Deinitable](mut app: App[HandlerHost[R]]):
    app.component.refresh()
    app.rebuild()

def behavior():
    var app = App(HandlerHost(Application()), Rect(0, 0, 640, 2000))
    replace(app, path(1, 2), "  Grace  ")
    replace(app, path(1, 4), "private")
    test_check(app.component.root.services.document.name == "Ada")
    test_check(app.component.root.shell.workspace.group.entries[1].value.draft == "Ada")
    test_check(app.component.root.shell.workspace.group.entries[1].value.note == "")
    var before = app.component.renders
    click(app, path(1, 5))
    test_check(app.component.renders == before + 1)
    test_check(app.component.root.services.document.name == "Grace")
    test_check(app.component.root.services.document.commits == 1)
    var labels = 0
    for i in range(app.view.child_count()):
        if app.view.child(i).text == "Current: Grace":
            labels += 1
    test_check(labels == 2)
    refresh(app)
    _ = app.resize(Rect(0, 0, 700, 2000))
    _ = app.paint()
    test_check(app.component.root.services.document.commits == 1)
    replace(app, path(2, 2), "Lin")
    click(app, path(2, 5))
    test_check(app.component.root.shell.workspace.group.entries[1].value.error == "Document changed; reload before applying")
    click(app, path(2, 6))
    replace(app, path(2, 2), "Lin")
    click(app, path(2, 5))
    test_check(app.component.root.services.document.commits == 2)
    app.component.root.services.document.undo(app.component.root.services.settings)
    refresh(app)
    test_check(app.component.root.services.document.name == "Grace")
    test_check(app.component.root.services.document.revision == 3)
    test_check(app.component.root.shell.workspace.group.entries[1].value.draft == "Lin")
    click(app, path(1, 6))
    replace(app, path(1, 2), "   ")
    click(app, path(1, 5))
    test_check(app.component.root.shell.workspace.group.entries[0].value.error == "Name required")
    app.component.root.services.settings.max_length = 2
    replace(app, path(1, 2), "long")
    click(app, path(1, 5))
    test_check(app.component.root.shell.workspace.group.entries[0].value.error == "Name is too long")
    replace(app, path(1, 2), "é🙂")
    click(app, path(1, 5))
    test_check(app.component.root.services.document.name == "é🙂")
    app.component.root.services.settings.writable = False
    refresh(app)
    var apply_id = control_id(app, path(1, 5))
    for i in range(app.view.child_count()):
        if app.view.child(i).id == apply_id:
            test_check(not app.view.child(i).enabled)
    var commits = app.component.root.services.document.commits
    click(app, path(1, 5))
    test_check(app.component.root.services.document.commits == commits)
    # Commands are validated even if invoked outside the disabled widget.
    app.component.root.shell.workspace.group.entries[0].value.apply(app.component.root.services)
    test_check(app.component.root.shell.workspace.group.entries[0].value.error == "Document is read-only")
    print("PASS App: nested projection, private drafts/notes, commit/conflict/reload/undo, validation, Unicode, second settings dependency, repeatable render")

def lifetime():
    var app = App(HandlerHost(Application()), Rect(0, 0, 640, 2000))
    replace(app, path(1, 2), "old draft")
    var old_apply = control_id(app, path(1, 5))
    var old_reload = control_id(app, path(1, 6))
    var event = Event(KeyEvent(KEY_SPACE))
    event.set_target(old_apply)
    # Same revision on a DIFFERENT document must not accept an old draft.
    app.component.root.replace_document(2, "New")
    _ = app.component.update(event, app.view)
    test_check(app.component.root.services.document.name == "New")
    test_check(app.component.root.shell.workspace.group.entries[0].value.error == "Document changed; reload before applying")
    var copied = app.component
    copied.root.replace_document(3, "Copy")
    event.set_target(old_reload)
    _ = copied.update(event, app.view)
    test_check(copied.root.shell.workspace.group.entries[0].value.draft == "Copy")
    test_check(app.component.root.shell.workspace.group.entries[0].value.draft == "old draft")
    # Retain the actual root action across removal and remount. It resolves
    # current membership; it cannot operate on a removed or new-generation child.
    var retained = app.component.ui.controls[app.component.ui.index(old_apply)].action
    app.component.root.remove(1)
    var new_key = app.component.root.add()
    test_check(new_key == 3)
    var no_context = NoneType()
    retained(app.component.root, no_context)
    test_check(app.component.root.services.document.commits == 0)
    test_check(app.component.root.shell.workspace.group.entries[1].value.draft == "New")
    refresh(app)
    test_check(app.component.ui.index(old_apply) < 0)
    event.set_target(old_apply)
    test_check(not app.component.update(event, app.view))
    for i in range(100):
        app.component.root.remove(new_key)
        new_key = app.component.root.add()
        retained(app.component.root, no_context)
    test_check(len(app.component.root.shell.workspace.group.entries) == 2)
    test_check(app.component.root.services.document.commits == 0)
    print("PASS identity guard, copied host/current document, stale retained action rejected, fresh remount and 100 collection removals")

def explicit_scope():
    # This exercises an explicit service override at a child boundary. There
    # is no implicit provider lookup on this side of the comparison.
    var outer = Services()
    var inner = Services()
    inner.replace_document(2, "Inner")
    inner.settings.max_length = 3
    var group = Keyed[Editor]()
    _ = group.append(Editor(inner))
    var ui = UI[Keyed[Editor], Services]()
    group.render(ui, inner)
    group.entries[0].value.set_draft("Too long")
    # Keyed scope is declaration 0, Apply is position 5 inside it.
    ui.declarations[6].action(group, inner)
    test_check(group.entries[0].value.error == "Name is too long")
    group.entries[0].value.set_draft("Ivy")
    ui.declarations[6].action(group, inner)
    test_check(inner.document.name == "Ivy")
    test_check(outer.document.name == "Ada")
    print("PASS explicit service override isolates document and settings")

def main():
    behavior()
    lifetime()
    explicit_scope()
