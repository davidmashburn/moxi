"""Characterize positional aliasing and verify explicit stable scopes prevent it."""
from runtime import Screen, UI, HandlerHost, require, deliver, update_model
from moxi import App, Rect, Event, ActionEvent, BUTTON_KIND

comptime ALPHA_SCOPE = "alpha"
comptime BETA_SCOPE = "beta"


struct Root[stable_scopes: Bool](Screen):
    var show_alpha: Bool
    var alpha: Int
    var beta: Int
    def __init__(out self):
        self.show_alpha = True
        self.alpha = 0
        self.beta = 0
    def hide_alpha(mut self):
        self.show_alpha = False
    def increment_alpha(mut self):
        self.alpha += 1
    def increment_beta(mut self):
        self.beta += 1
    def render(self, mut ui: UI[Self]):
        if self.show_alpha:
            comptime if Self.stable_scopes:
                ui.begin_scope(ALPHA_SCOPE)
            ui.button("Alpha", Self.increment_alpha)
            comptime if Self.stable_scopes:
                ui.end_scope()
        comptime if Self.stable_scopes:
            ui.begin_scope(BETA_SCOPE)
        ui.button("Beta", Self.increment_beta)
        comptime if Self.stable_scopes:
            ui.end_scope()


def first[stable: Bool](app: App[HandlerHost[Root[stable]]]) -> Int:
    for item in app.component.ui.controls:
        if item.kind == BUTTON_KIND:
            return item.id
    require(False, "missing button")
    return -1


def check[stable: Bool]():
    var app = App(HandlerHost(Root[stable]()), Rect(0, 0, 600, 900))
    var alpha = first(app)
    var captured = app.component.capture(alpha)
    var click = Event(ActionEvent(alpha))
    click.set_target(alpha)
    var queued = app.component.queue(click)
    update_model(app, Root[stable].hide_alpha)
    comptime if stable:
        require(first(app) != alpha, "stable scope keeps Beta distinct")
        require(not deliver(app, captured) and not deliver(app, queued), "removed scoped Alpha rejects both deliveries")
        require(app.component.root.alpha == 0 and app.component.root.beta == 0, "stable scope preserves both counters")
    else:
        require(first(app) == alpha, "negative control positional alias")
        require(deliver(app, captured) and deliver(app, queued), "negative control accepts aliased deliveries")
        require(app.component.root.alpha == 1 and app.component.root.beta == 1, "old action and queued event disagree about positional identity")


def main():
    check[False]()
    check[True]()
    print("PASS positional-alias counterexample retained; stable scopes reject removed-control work")
