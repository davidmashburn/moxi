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


def main():
    var app = App(HandlerHost(Application()), Rect(0, 0, 640, 2000))
    replace(app, "/k8:editor-1/p2", " ")
    test_check(app.component.root.shell.workspace.editors[0].draft == " ")
    click(app, "/k8:editor-1/p5")
    test_check(app.component.root.shell.workspace.editors[0].error == "Name required")
    app.component.root.shell.workspace.document.max_length = 3
