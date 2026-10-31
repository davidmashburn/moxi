"""Equal sibling generations and surviving editing state during repeated mounts."""
from screen import Workbench
from check import keyed_target, root_toggle_target, action
from runtime import HandlerHost, require
from moxi import App, Rect, Point, ClickEvent, Event, TextInputEvent, KeyEvent, CompositionEvent, KEY_END, KEY_LEFT, MOD_SHIFT
from workbench import HEADER, LEFT


def main():
    var app = App(HandlerHost(Workbench()), Rect(0, 0, 800, 5000))
    var toggle = root_toggle_target(app)
    require(app.update(action(toggle)), "show third")
    var header = keyed_target(app, HEADER, 1)
    require(app.update(action(header)), "hide inspector")
    require(app.update(action(header)), "show inspector")
    require(app.component.root.third_epoch == app.component.root.inspector_epoch, "start with equal generations")
    require(app.component.root.third_key() != app.component.root.inspector_key(), "different sibling slots")
    var input = keyed_target(app, LEFT, 2)
    var bounds = app.view.bounds_for(input)
    require(app.update(ClickEvent(Point(bounds.x + 8, bounds.y + 8))), "focus survivor")
    var text = Event(TextInputEvent("abcdef", 0, 1000000))
    text.set_target(input)
    require(app.update(text), "prepare survivor")
    # Inserting text may already leave the caret at the end (a valid no-op).
    _ = app.update(Event(KeyEvent(KEY_END)))
    require(app.update(Event(KeyEvent(KEY_LEFT, MOD_SHIFT))), "nonempty selection")
    var composition = Event(CompositionEvent("ime", 1, 2))
    composition.set_target(input)
    require(app.update(composition), "active IME")
    var snapshot = app.component.ui.controls[app.component.ui.index(input)].editor
    require(snapshot.cursor != snapshot.anchor, "ordinary selection is nonempty")
    for _ in range(110):
        var third_input = keyed_target(app, app.component.root.third_key(), 2)
        var retained = app.component.ui.controls[app.component.ui.index(third_input)].action.with_input("stale", False)
        require(app.update(action(toggle)), "hide third")
        require(app.update(action(toggle)), "remount third")
        require(app.update(action(header)), "hide inspector again")
        require(app.update(action(header)), "remount inspector")
        require(app.component.root.third_epoch == app.component.root.inspector_epoch, "equal generations remain disjoint")
        var context: NoneType = None
        retained(app.component.root, context)
        require(app.component.root.third.draft == "Ada", "old action rejected")
        var stale = Event(TextInputEvent("stale event"))
        stale.set_target(third_input)
        require(not app.update(stale), "old event rejected")
        require(app.focus_id() == input, "survivor retains focus")
        var live = app.component.ui.controls[app.component.ui.index(input)].editor
        require(live.text == snapshot.text, "surviving text")
        require(live.cursor == snapshot.cursor and live.anchor == snapshot.anchor, "surviving selection")
        require(live.composition == snapshot.composition, "surviving composition")
        require(live.composition_selection_start == snapshot.composition_selection_start and live.composition_selection_end == snapshot.composition_selection_end, "surviving IME range")
    app.component.root.reverse_editors = True
    app.component.refresh()
    app.rebuild()
    require(keyed_target(app, LEFT, 2) == input, "editing child reorder retains ID")
    require(app.focus_id() == input, "editing child reorder retains focus")
    var live = app.component.ui.controls[app.component.ui.index(input)].editor
    require(live.text == snapshot.text and live.cursor == snapshot.cursor and live.anchor == snapshot.anchor, "editing state after reorder")
    require(live.composition == snapshot.composition and live.composition_selection_start == snapshot.composition_selection_start and live.composition_selection_end == snapshot.composition_selection_end, "IME after reorder")
    print("PASS 110 equal-generation sibling remounts, stale deliveries, focus, nonempty selection, IME and focused-child reorder")
