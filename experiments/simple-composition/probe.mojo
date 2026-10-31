"""Behavioral differential check; topology intentionally differs between hosts."""
from screen import Workbench
from host import WorkbenchHost
from check import target as reference_target
from runtime import HandlerHost, require
from bindings import Action
from workbench import HEADER, LEFT, RIGHT, SETTINGS, HISTORY, SCRATCH, PREVIEW
from selective import equal_value
from moxi import App, Rect, Point, Event, ActionEvent, TextInputEvent, ClickEvent, KeyEvent, CompositionEvent, KEY_LEFT, KEY_END, CONTAINER_KIND


def target(app: App[HandlerHost[Workbench]], key: Int, position: Int) -> Int:
    var path = "/k" + String(String(key).byte_length()) + ":" + String(key) + "/p" + String(position)
    for item in app.component.ui.controls:
        if item.active and item.path == path:
            return item.id
    require(False, "missing simple control")
    return -1


def target[S: Bool](app: App[WorkbenchHost[S]], key: Int, position: Int) -> Int:
    return reference_target(app, key, position)


def action(app: App[HandlerHost[Workbench]], id: Int) -> Action[Workbench]:
    return app.component.ui.controls[app.component.ui.index(id)].action


def compare(mut a: App[HandlerHost[Workbench]], mut b: App[WorkbenchHost[False]]):
    require(equal_value(a.component.root.services, b.component.root.services), "logical services")
    require(equal_value(a.component.root.header, b.component.root.header), "logical header")
    require(equal_value(a.component.root.left, b.component.root.left), "logical left")
    require(equal_value(a.component.root.right, b.component.root.right), "logical right")
    require(equal_value(a.component.root.settings, b.component.root.settings), "logical settings")
    require(equal_value(a.component.root.history, b.component.root.history), "logical history")
    require(equal_value(a.component.root.scratch, b.component.root.scratch), "logical scratch")
    require(equal_value(a.component.root.preview, b.component.root.preview), "logical preview")
    require(equal_value(a.component.root.inspector, b.component.root.inspector), "logical inspector")
    require(equal_value(a.component.root.inspector_epoch, b.component.root.inspector_epoch), "logical inspector_epoch")
    var j = 0
    for i in range(a.view.child_count()):
        var left = a.view.child(i)
        if left.kind == CONTAINER_KIND:
            continue
        while j < b.view.child_count() and b.view.child(j).kind == CONTAINER_KIND:
            j += 1
        require(j < b.view.child_count(), "reference widget exists")
        var right = b.view.child(j)
        # Flattened composition has different IDs and geometry. Compare every
        # remaining ViewNode field, including editing state and semantics.
        left.id = right.id
        left.action_id = right.action_id
        left.parent_id = right.parent_id
        left.bounds = right.bounds
        left.semantics.id = right.semantics.id
        left.semantics.parent_id = right.semantics.parent_id
        left.semantics.bounds = right.semantics.bounds
        require(equal_value(left, right), "logical widget fields")
        j += 1
    while j < b.view.child_count() and b.view.child(j).kind == CONTAINER_KIND:
        j += 1
    require(j == b.view.child_count(), "same logical widget count")
    _ = a.paint()
    _ = b.paint()

from boundary import ID_STRIDE

def act(mut a: App[HandlerHost[Workbench]], mut b: App[WorkbenchHost[False]], key: Int, position: Int, expected: Bool = True):
    var ta = target(a, key, position)
    var tb = target(b, key, position)
    var ea = Event(ActionEvent(ta))
    var eb = Event(ActionEvent(tb))
    ea.set_target(ta)
    eb.set_target(tb)
    var handled_a = a.update(ea)
    var handled_b = b.update(eb)
    require(handled_a == expected, "expected action dispatch")
    require(handled_b == expected, "expected reference dispatch")
    compare(a, b)


def text(mut a: App[HandlerHost[Workbench]], mut b: App[WorkbenchHost[False]], key: Int, position: Int, value: String):
    var ta = target(a, key, position)
    var tb = target(b, key, position)
    var ea = Event(TextInputEvent(value, 0, 1000000))
    var eb = ea
    ea.set_target(ta)
    eb.set_target(tb)
    _ = a.update(ea)
    _ = b.update(eb)
    compare(a, b)


def refresh(mut a: App[HandlerHost[Workbench]], mut b: App[WorkbenchHost[False]]):
    a.component.refresh()
    b.component.refresh()
    a.rebuild()
    b.rebuild()
    compare(a, b)


def main():
    var a = App(HandlerHost(Workbench()), Rect(0, 0, 800, 4000))
    var b = App(WorkbenchHost[False](), Rect(0, 0, 800, 4000))
    compare(a, b)
    text(a, b, LEFT, 4, "private")
    require(a.component.root.left.note == "private", "check:78")
    require(a.component.root.right.note == "", "check:79")
    text(a, b, LEFT, 2, "Grace")
    act(a, b, LEFT, 5)
    require(a.component.root.services.document.name == "Grace", "check:84")
    require(a.component.root.services.document.commits == 1, "check:85")
    text(a, b, RIGHT, 2, "Lin")
    act(a, b, RIGHT, 5)
    require(a.component.root.right.error == "Document changed; reload before applying", "check:90")
    act(a, b, RIGHT, 6)
    text(a, b, RIGHT, 2, "Lin")
    act(a, b, RIGHT, 5)
    require(a.component.root.services.document.name == "Lin", "check:94")
    act(a, b, HISTORY, 2)
    require(a.component.root.services.document.name == "Grace", "check:96")
    act(a, b, LEFT, 6)
    act(a, b, SETTINGS, 3)
    text(a, b, LEFT, 2, "long")
    act(a, b, LEFT, 5)
    require(a.component.root.left.error == "Name is too long", "check:101")
    text(a, b, LEFT, 2, "é🙂")
    act(a, b, LEFT, 5)
    require(a.component.root.services.document.name == "é🙂", "check:104")
    act(a, b, SETTINGS, 2)
    require(not a.component.root.services.settings.writable, "permission toggled off")
    text(a, b, LEFT, 2, "Ok")
    var commits = a.component.root.services.document.commits
    act(a, b, LEFT, 5, False)
    require(a.component.root.services.document.commits == commits, "check:109")
    act(a, b, SETTINGS, 2)
    require(a.component.root.services.settings.writable, "permission toggled on")
    text(a, b, PREVIEW, 2, "Ok")
    act(a, b, PREVIEW, 5, False)
    var preview_id = target(a, PREVIEW, 5)
    var preview_action = action(a, preview_id)
    var reference_preview = target(b, PREVIEW, 5) - PREVIEW * ID_STRIDE
    var reference_action = b.component.caches.preview.ui.controls[b.component.caches.preview.ui.index(reference_preview)].action
    var readonly_history = len(a.component.root.services.document.history)
    var readonly_name = a.component.root.services.document.name
    var no_context: NoneType = None
    preview_action(a.component.root, no_context)
    reference_action(b.component.root, no_context)
    require(a.component.root.preview.error == "Document is read-only", "scoped command enforces permission")
    require(a.component.root.services.document.name == readonly_name, "preview cannot rename shared document")
    require(len(a.component.root.services.document.history) == readonly_history, "preview cannot change shared history")
    refresh(a, b)
    require(a.component.root.services.document.commits == commits, "check:113")
    a.component.root.scratch.text = "external"
    b.component.root.scratch.text = "external"
    a.component.root.services.settings.unrelated += 1
    b.component.root.services.settings.unrelated += 1
    refresh(a, b)
    print("PASS domain: isolation, commit/conflict/reload/undo, validation, Unicode, permission, readonly scope, direct writes")

    var old_key = a.component.root.inspector_key()
    var old_id = target(a, old_key, 3)
    var reference_old_id = target(b, old_key, 3)
    var retained = action(a, old_id).with_input("stale", False)
    text(a, b, old_key, 3, "old mount")
    act(a, b, HEADER, 1)
    act(a, b, HEADER, 1)
    require(a.component.root.inspector_key() != old_key, "check:128")
    require(a.component.root.inspector.note == "", "check:129")
    var context: NoneType = None
    retained(a.component.root, context)
    require(a.component.root.inspector.note == "", "check:132")
    var stale = Event(TextInputEvent("stale"))
    stale.set_target(old_id)
    _ = a.update(stale)
    stale.set_target(reference_old_id)
    _ = b.update(stale)
    compare(a, b)
    require(a.component.root.inspector.note == "", "check:138")
    var copied = a.component
    copied.root.services.document.name = "Copy"
    # Deliberately dispatch with cached old context: route must use current root.
    var copy_app = App(copied^, Rect(0, 0, 800, 4000))
    var copied_target = target(copy_app, LEFT, 6)
    var copied_event = Event(ActionEvent(copied_target))
    copied_event.set_target(copied_target)
    _ = copy_app.update(copied_event)
    require(copy_app.component.root.left.draft == "Copy", "check:144")
    require(a.component.root.services.document.name != "Copy", "check:145")
    print("PASS lifetime: hidden/remounted inspector, stale callback/event rejected, copied host uses its own root")

    for i in range(500):
        var op = i % 10
        if op == 0:
            text(a, b, LEFT, 4, "left-" + String(i))
        elif op == 1:
            text(a, b, SCRATCH, 1, "scratch-" + String(i))
        elif op == 2:
            act(a, b, SETTINGS, 2)
        elif op == 3:
            act(a, b, LEFT, 6)
        elif op == 4:
            text(a, b, LEFT, 2, String(i))
        elif op == 5:
            var can_apply = a.component.root.services.settings.writable
            act(a, b, LEFT, 5, can_apply)
        elif op == 6:
            act(a, b, HISTORY, 3)
        elif op == 7:
            act(a, b, HEADER, 1)
        elif op == 8:
            act(a, b, RIGHT, 6)
        else:
            a.component.root.services.settings.max_length = 24 if i % 20 == 9 else 3
            b.component.root.services.settings.max_length = a.component.root.services.settings.max_length
            refresh(a, b)
    print("PASS differential: 500 mixed transactions; logical state and normalized widget equality after each")

    # Native editing state belongs to retained controls, not the domain snapshot.
    text(a, b, SCRATCH, 1, "abc")
    var edit_id = target(a, SCRATCH, 1)
    var bounds = a.view.bounds_for(edit_id)
    _ = a.update(ClickEvent(Point(bounds.x + 8, bounds.y + 8)))
    var reference_bounds = b.view.bounds_for(target(b, SCRATCH, 1))
    _ = b.update(ClickEvent(Point(reference_bounds.x + 8, reference_bounds.y + 8)))
    compare(a, b)
    _ = a.update(Event(KeyEvent(KEY_END)))
    _ = b.update(Event(KeyEvent(KEY_END)))
    _ = a.update(Event(KeyEvent(KEY_LEFT)))
    _ = b.update(Event(KeyEvent(KEY_LEFT)))
    compare(a, b)
    _ = a.update(Event(TextInputEvent("X")))
    _ = b.update(Event(TextInputEvent("X")))
    compare(a, b)
    require(a.component.root.scratch.text == "abXc", "caret survives refresh")
    _ = a.update(Event(CompositionEvent("marked", 1, 2)))
    _ = b.update(Event(CompositionEvent("marked", 1, 2)))
    compare(a, b)
    act(a, b, SETTINGS, 3)
    require(target(a, SCRATCH, 1) == edit_id, "stable editing identity")
    _ = a.resize(Rect(0, 0, 700, 4000))
    _ = b.resize(Rect(0, 0, 700, 4000))
    compare(a, b)
    require(a.component.root.scratch.text == "abXc", "composition is not committed text")
    print("PASS editing: focus, caret insertion, composition across sibling update, resize")

    # Reorder the child that is actively being edited, not just its siblings.
    var left_id = target(a, LEFT, 2)
    var reset = Event(TextInputEvent("abc", 0, 1000000))
    reset.set_target(left_id)
    require(a.update(reset), "prepare reordered editor")
    var left_bounds = a.view.bounds_for(left_id)
    _ = a.update(ClickEvent(Point(left_bounds.x + 8, left_bounds.y + 8)))
    _ = a.update(Event(KeyEvent(KEY_END)))
    _ = a.update(Event(KeyEvent(KEY_LEFT)))
    _ = a.update(Event(CompositionEvent("moving", 1, 2)))
    var before_editor = a.component.ui.controls[a.component.ui.index(left_id)].editor
    require(before_editor.has_composition(), "active IME before reorder")
    require(a.focus_id() == left_id, "edited child focused before reorder")
    a.component.root.reverse_editors = True
    a.component.root.show_notice = True
    a.component.refresh()
    a.rebuild()
    require(target(a, LEFT, 2) == left_id, "reordered child identity")
    require(target(a, SCRATCH, 1) == edit_id, "conditional sibling identity")
    require(equal_value(before_editor, a.component.ui.controls[a.component.ui.index(left_id)].editor), "caret and IME preserved")
    require(a.focus_id() == left_id, "focus preserved")
    require(a.component.root.left.draft == "abc", "composition remains uncommitted")
    require(a.view.bounds_for(left_id).y != left_bounds.y, "edited child actually moved")
    print("PASS conditional insertion/reorder: moving edited child retains identity, focus, caret, selection and composition")
