"""Pending envelopes keep scope identity distinct after the source host dies."""
from lifetime_check import Root, target, event, count
from delivery import CapturedAction, QueuedEvent
from runtime import HandlerHost, require, deliver
from moxi import App, Rect


def retired_action() -> CapturedAction[Root]:
    var app = App(HandlerHost(Root()), Rect(0, 0, 600, 900))
    return app.component.capture(target(app))


def retired_event() -> QueuedEvent:
    var app = App(HandlerHost(Root()), Rect(0, 0, 600, 900))
    return app.component.queue(event(target(app)))


def main():
    var captured = retired_action()
    var queued = retired_event()
    var copied_action = captured
    var copied_event = queued
    for _ in range(100):
        var app = App(HandlerHost(Root()), Rect(0, 0, 600, 900))
        require(target(app) == captured.target and target(app) == queued.event.target, "numeric IDs reused after host destruction")
        require(not deliver(app, captured) and not deliver(app, copied_action), "retired source action rejected")
        require(not deliver(app, queued) and not deliver(app, copied_event), "retired source event rejected")
        require(count(app) == 0, "retired scopes leave replacement untouched")
        require(deliver(app, app.component.capture(target(app))), "replacement's own action works")
        require(count(app) == 1, "replacement receives current work")
    print("PASS retired hosts and copied envelopes retain non-reusable scope identity")
