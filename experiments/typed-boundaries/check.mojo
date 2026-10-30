"""Differential real-App transactions with independent domain assertions."""
from host import WorkbenchHost
from boundary import ID_STRIDE
from workbench import HEADER, LEFT, RIGHT, SETTINGS, HISTORY, SCRATCH, PREVIEW
from runtime import RetainedUI, require
from workbench import Workbench
from selective import equal_value
from moxi import App, Rect, Point, Event, ActionEvent, TextInputEvent, ClickEvent, KeyEvent, CompositionEvent, KEY_LEFT, KEY_END, test_check


def control(ui: RetainedUI[Workbench], key: Int, position: Int) -> Int:
    var path = "/k" + String(String(key).byte_length()) + ":" + String(key) + "/p" + String(position)
    for item in ui.controls:
        if item.active and item.path == path:
            return key * ID_STRIDE + item.id
    require(False, "check:16")
    return -1


def target[S: Bool](app: App[WorkbenchHost[S]], key: Int, position: Int) -> Int:
    if key == HEADER: return control(app.component.caches.header.ui, key, position)
    if key == LEFT: return control(app.component.caches.left.ui, key, position)
    if key == RIGHT: return control(app.component.caches.right.ui, key, position)
    if key == SETTINGS: return control(app.component.caches.settings.ui, key, position)
    if key == HISTORY: return control(app.component.caches.history.ui, key, position)
    if key == SCRATCH: return control(app.component.caches.scratch.ui, key, position)
    if key == PREVIEW: return control(app.component.caches.preview.ui, key, position)
    return control(app.component.caches.inspector.ui, key, position)


def compare(mut a: App[WorkbenchHost[True]], mut b: App[WorkbenchHost[False]]):
    require(equal_value(a.component.root, b.component.root), "check:32")
    require(a.view.child_count() == b.view.child_count(), "check:33")
    for i in range(a.view.child_count()):
        require(equal_value(a.view.child(i), b.view.child(i)), "check:35")
    require(equal_value(a.view.layout_spec, b.view.layout_spec), "root layout metadata")
    var pa = a.paint()
    var pb = b.paint()
    require(pa.count() == pb.count(), "check:38")
    require(pa.changed_count() == pb.changed_count(), "changed command count")
    require(pa.removed_count() == pb.removed_count(), "removed command count")
    require(pa.has_dirty_region() == pb.has_dirty_region(), "dirty region presence")
    require(equal_value(pa.dirty_region(), pb.dirty_region()), "dirty region bounds")
    for i in range(pa.removed_count()):
        require(equal_value(pa.removed_region(i), pb.removed_region(i)), "removed region")
    for i in range(pa.count()):
        require(equal_value(pa.command(i), pb.command(i)), "check:40")


def act(mut a: App[WorkbenchHost[True]], mut b: App[WorkbenchHost[False]], key: Int, position: Int, expected: Bool = True):
    var ta = target(a, key, position)
    var tb = target(b, key, position)
    require(ta == tb, "check:46")
    var ea = Event(ActionEvent(ta))
    var eb = Event(ActionEvent(tb))
    ea.set_target(ta)
    eb.set_target(tb)
    var handled_a = a.update(ea)
    var handled_b = b.update(eb)
    require(handled_a == expected, "expected action dispatch")
    require(handled_b == expected, "expected reference dispatch")
    compare(a, b)


def text(mut a: App[WorkbenchHost[True]], mut b: App[WorkbenchHost[False]], key: Int, position: Int, value: String):
    var ta = target(a, key, position)
    var tb = target(b, key, position)
    var ea = Event(TextInputEvent(value, 0, 1000000))
    var eb = ea
    ea.set_target(ta)
    eb.set_target(tb)
    _ = a.update(ea)
    _ = b.update(eb)
    compare(a, b)


def refresh(mut a: App[WorkbenchHost[True]], mut b: App[WorkbenchHost[False]]):
    a.component.refresh()
    b.component.refresh()
    a.rebuild()
    b.rebuild()
    compare(a, b)


def main():
    var a = App(WorkbenchHost[True](), Rect(0, 0, 800, 4000))
    var b = App(WorkbenchHost[False](), Rect(0, 0, 800, 4000))
    compare(a, b)
    a.component.reset_counts()
    text(a, b, LEFT, 4, "private")
    require(a.component.root.left.note == "private", "check:78")
    require(a.component.root.right.note == "", "check:79")
    require(a.component.render_count() == 1, "check:80")
    text(a, b, LEFT, 2, "Grace")
    a.component.reset_counts()
    act(a, b, LEFT, 5)
    require(a.component.root.services.document.name == "Grace", "check:84")
    require(a.component.root.services.document.commits == 1, "check:85")
    require(a.component.render_count() == 5, "check:86")
    require(a.component.caches.scratch.renders == 0, "check:87")
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
    var preview_id = target(a, PREVIEW, 5) - PREVIEW * ID_STRIDE
    var preview_action = a.component.caches.preview.ui.controls[a.component.caches.preview.ui.index(preview_id)].action
    var reference_action = b.component.caches.preview.ui.controls[b.component.caches.preview.ui.index(preview_id)].action
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
    var local_id = old_id - old_key * ID_STRIDE
    var retained = a.component.caches.inspector.ui.controls[a.component.caches.inspector.ui.index(local_id)].action.with_input("stale", False)
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
    print("PASS differential: 500 mixed transactions; complete ViewNode and PaintCommand equality after each")

    # Native editing state belongs to retained controls, not the domain snapshot.
    text(a, b, SCRATCH, 1, "abc")
    var edit_id = target(a, SCRATCH, 1)
    var bounds = a.view.bounds_for(edit_id)
    _ = a.update(ClickEvent(Point(bounds.x + 8, bounds.y + 8)))
    _ = b.update(ClickEvent(Point(bounds.x + 8, bounds.y + 8)))
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
