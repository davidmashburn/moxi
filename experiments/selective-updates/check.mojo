"""Actual App behavior plus measured cached declaration/retained-control work."""
from application import Application
from selective import SelectiveHost, SharedInputs, AllInputs, DisplayInputs, ID_STRIDE, equal_value
from runtime import UI
from editor import Editor
from domain import Services
from moxi import App, Rect, Point, Event, ClickEvent, KeyEvent, TextInputEvent, test_check, KEY_A, KEY_SPACE, KEY_LEFT, MOD_COMMAND, LABEL_KIND, TEXT_INPUT_VIEW_KIND


def control_id[I: SharedInputs](host: SelectiveHost[I], key: Int, position: Int) -> Int:
    var index = host.lookup.find(key)
    test_check(index >= 0)
    var path = "/k" + String(String(key).byte_length()) + ":" + String(key) + "/p" + String(position)
    for control in host.regions[index].ui.controls:
        if control.path == path and control.active:
            return key * ID_STRIDE + control.id
    test_check(False)
    return -1


def click[I: SharedInputs](mut app: App[SelectiveHost[I]], key: Int, position: Int):
    var bounds = app.view.bounds_for(control_id(app.component, key, position))
    _ = app.update(ClickEvent(Point(bounds.x + 8, bounds.y + 8)))


def replace[I: SharedInputs](mut app: App[SelectiveHost[I]], key: Int, position: Int, text: String):
    click(app, key, position)
    _ = app.update(Event(KeyEvent(KEY_A, MOD_COMMAND)))
    app.component.reset_counts()
    _ = app.update(Event(TextInputEvent(text)))
    test_check(app.component.editor_renders == 1)


def matches_full[I: SharedInputs](host: SelectiveHost[I]) -> Bool:
    # Independent full render of every editor. Compare all actual retained
    # node values and enabled flags, including any generated extension nodes.
    for i in range(len(host.regions)):
        var ui = UI[Editor, Services]()
        host.root.shell.workspace.group.entries[i].value.render(ui, host.root.services)
        ref view = host.regions[i].ui.view
        if len(ui.declarations) != view.child_count():
            return False
        for j in range(len(ui.declarations)):
            ref item = ui.declarations[j]
            var node = view.child(j)
            var text = item.value if item.kind == TEXT_INPUT_VIEW_KIND else item.label
            if node.kind != item.kind or node.text != text or node.enabled != item.enabled or node.checked != item.checked:
                return False
    return True


def visible_count[I: SharedInputs](app: App[SelectiveHost[I]], text: String) -> Int:
    var count = 0
    for i in range(app.view.child_count()):
        if app.view.child(i).text == text:
            count += 1
    return count


def refresh[I: SharedInputs](mut app: App[SelectiveHost[I]]):
    app.component.refresh()
    app.rebuild()
    test_check(matches_full(app.component))


def behavior[I: SharedInputs]():
    var app = App(SelectiveHost[I](Application()), Rect(0, 0, 640, 2000))
    replace(app, 1, 2, "  Grace  ")
    replace(app, 1, 4, "private")
    test_check(app.component.root.services.document.name == "Ada")
    test_check(app.component.root.shell.workspace.group.entries[1].value.draft == "Ada")
    test_check(app.component.root.shell.workspace.group.entries[1].value.note == "")
    app.component.reset_counts()
    click(app, 1, 5)
    test_check(app.component.editor_renders == 2)
    test_check(app.component.root.services.document.name == "Grace")
    test_check(app.component.root.services.document.commits == 1)
    test_check(matches_full(app.component))
    test_check(visible_count(app, "Current: Grace") == 2)
    refresh(app)
    _ = app.resize(Rect(0, 0, 700, 2000))
    _ = app.paint()
    test_check(app.component.root.services.document.commits == 1)
    replace(app, 2, 2, "Lin")
    click(app, 2, 5)
    test_check(app.component.root.shell.workspace.group.entries[1].value.error == "Document changed; reload before applying")
    click(app, 2, 6)
    replace(app, 2, 2, "Lin")
    click(app, 2, 5)
    test_check(app.component.root.services.document.commits == 2)
    app.component.root.undo()
    app.component.services_changed()
    app.rebuild()
    test_check(matches_full(app.component))
    test_check(visible_count(app, "Current: Grace") == 2)
    test_check(app.component.root.services.document.name == "Grace")
    test_check(app.component.root.shell.workspace.group.entries[1].value.draft == "Lin")
    click(app, 1, 6)
    replace(app, 1, 2, "   ")
    click(app, 1, 5)
    test_check(app.component.root.shell.workspace.group.entries[0].value.error == "Name required")
    # max_length is command-only in the original editor. Cached handlers must
    # read its CURRENT value even when the projected UI did not rerender.
    app.component.root.set_max_length(2)
    app.component.services_changed()
    replace(app, 1, 2, "long")
    click(app, 1, 5)
    test_check(app.component.root.shell.workspace.group.entries[0].value.error == "Name is too long")
    replace(app, 1, 2, "é🙂")
    click(app, 1, 5)
    test_check(app.component.root.services.document.name == "é🙂")
    app.component.root.set_writable(False)
    app.component.services_changed()
    app.rebuild()
    test_check(matches_full(app.component))
    var apply_target = control_id(app.component, 1, 5)
    var saw_disabled = False
    for i in range(app.view.child_count()):
        if app.view.child(i).id == apply_target:
            saw_disabled = not app.view.child(i).enabled
    test_check(saw_disabled)
    var commits = app.component.root.services.document.commits
    click(app, 1, 5)
    test_check(app.component.root.services.document.commits == commits)
    app.component.root.apply_first()
    test_check(app.component.root.shell.workspace.group.entries[0].value.error == "Document is read-only")
    refresh(app)
    print("PASS App: local drafts/notes, commit/conflict/reload/undo, validation, Unicode, permission, repeatable render")


def lifetime[I: SharedInputs]():
    var app = App(SelectiveHost[I](Application()), Rect(0, 0, 640, 2000))
    replace(app, 1, 2, "old draft")
    var old_apply = control_id(app.component, 1, 5)
    var old_reload = control_id(app.component, 1, 6)
    var event = Event(KeyEvent(KEY_SPACE))
    event.set_target(old_apply)
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
    test_check(matches_full(copied))
    test_check(matches_full(app.component))
    var local_id = old_apply - ID_STRIDE
    var retained = app.component.regions[0].ui.controls[app.component.regions[0].ui.index(local_id)].action
    app.component.root.remove(1)
    var new_key = app.component.root.add()
    test_check(new_key == 3)
    var no_context = NoneType()
    retained(app.component.root, no_context)
    test_check(app.component.root.services.document.commits == 0)
    refresh(app)
    event.set_target(old_apply)
    test_check(not app.component.update(event, app.view))
    for _ in range(100):
        app.component.root.remove(new_key)
        new_key = app.component.root.add()
        retained(app.component.root, no_context)
    refresh(app)
    test_check(len(app.component.regions) == 2)
    test_check(app.component.root.services.document.commits == 0)
    # Unknown direct local writes and order/topology changes use full fallback.
    app.component.root.shell.workspace.group.entries[0].value.set_note("outside event")
    test_check(not matches_full(app.component))
    refresh(app)
    var first = app.component.root.shell.workspace.group.entries[0]
    app.component.root.shell.workspace.group.entries[0] = app.component.root.shell.workspace.group.entries[1]
    app.component.root.shell.workspace.group.entries[1] = first
    refresh(app)
    print("PASS current document, copied cache, stale removal callback, 100 remounts, direct-write fallback, reorder")


def editing_state[I: SharedInputs]():
    var app = App(SelectiveHost[I](Application()), Rect(0, 0, 640, 2000))
    replace(app, 1, 2, "abc")
    _ = app.update(Event(KeyEvent(KEY_LEFT)))
    _ = app.update(Event(TextInputEvent("X")))
    test_check(app.component.root.shell.workspace.group.entries[0].value.draft == "abXc")
    _ = app.update(Event(KeyEvent(KEY_A, MOD_COMMAND)))
    var target = control_id(app.component, 1, 2)
    test_check(app.component.clipboard_copy(target, app.view) == "abXc")
    test_check(app.component.clipboard_cut(target, app.view) == "abXc")
    app.rebuild()
    test_check(app.component.root.shell.workspace.group.entries[0].value.draft == "")
    test_check(app.component.clipboard_paste(target, "pasted", app.view))
    test_check(app.component.root.shell.workspace.group.entries[0].value.draft == "pasted")
    test_check(matches_full(app.component))
    print("PASS retained caret and clipboard through selective editor rebuilding")


def report[I: SharedInputs](mut host: SelectiveHost[I], name: String, operation: String):
    test_check(matches_full(host))
    print("WORK", len(host.regions), name, operation, host.shared_checks, host.editor_renders, host.declarations, host.full_fallbacks)


def scale[I: SharedInputs](count: Int, name: String):
    var host = SelectiveHost[I](Application(count))
    # Scale path dispatches through the real retained input and action, with
    # a composed view, but omits App hit-testing/reconciliation/paint timing.
    var view = host.build(Rect(0, 0, 640, 400000))
    host.reset_counts()
    var event = Event(TextInputEvent("Local", 0, 3))
    event.set_target(control_id(host, count, 2))
    test_check(host.update(event, view))
    report(host, name, "draft")
    host.reset_counts()
    event = Event(TextInputEvent("Note"))
    event.set_target(control_id(host, count, 4))
    test_check(host.update(event, view))
    report(host, name, "note")
    host.reset_counts()
    _ = host.root.services.document.rename("Grace", 1, 0, host.root.services.settings)
    host.services_changed()
    report(host, name, "name")
    host.reset_counts()
    host.root.set_writable(False)
    host.services_changed()
    report(host, name, "writable")
    host.reset_counts()
    host.root.services.settings.unrelated += 1
    host.services_changed()
    report(host, name, "unrelated")
    host.reset_counts()
    host.root.set_max_length(3)
    host.services_changed()
    report(host, name, "max_length")


def main():
    behavior[AllInputs]()
    behavior[DisplayInputs]()
    lifetime[AllInputs]()
    lifetime[DisplayInputs]()
    editing_state[AllInputs]()
    editing_state[DisplayInputs]()
    scale[AllInputs](2, "all")
    scale[AllInputs](100, "all")
    scale[AllInputs](1000, "all")
    scale[DisplayInputs](2, "display")
    scale[DisplayInputs](100, "display")
    scale[DisplayInputs](1000, "display")
