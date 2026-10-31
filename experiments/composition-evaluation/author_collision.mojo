"""Parent-authored held-out task: two independent remount counters must coexist.

This program intentionally exits unsuccessfully if their key ranges overlap.
It uses actual user events, not direct mutation of either generation counter.
"""
from screen import Workbench
from workbench import HEADER
from runtime import HandlerHost, require
from moxi import App, Rect, Event, ActionEvent


def target(app: App[HandlerHost[Workbench]], path: String) -> Int:
    for item in app.component.ui.controls:
        if item.active and item.path == path:
            return item.id
    require(False, "held-out missing target")
    return -1


def click(mut app: App[HandlerHost[Workbench]], id: Int):
    var event = Event(ActionEvent(id))
    event.set_target(id)
    require(app.update(event), "held-out event handled")


def main():
    var app = App(HandlerHost(Workbench()), Rect(0, 0, 800, 5000))
    click(app, target(app, "/p0"))
    require(app.component.root.show_third, "third mounted")
    var header_path = "/k" + String(String(HEADER).byte_length()) + ":" + String(HEADER) + "/p1"
    for _ in range(101):
        click(app, target(app, header_path))
        require(not app.component.root.header.inspector_visible, "inspector hidden")
        click(app, target(app, header_path))
        require(app.component.root.header.inspector_visible, "inspector shown")
    print("PASS independent remount identities coexist")
