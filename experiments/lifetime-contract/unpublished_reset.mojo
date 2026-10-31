"""Negative control: raw mutations without refresh are not a published reset."""
from lifetime_check import Root, target, count
from runtime import HandlerHost, require, deliver
from moxi import App, Rect, Event, TextInputEvent, TEXT_INPUT_VIEW_KIND


def main():
    var app = App(HandlerHost(Root()), Rect(0, 0, 600, 900))
    var captured = app.component.capture(target(app))
    app.component.root.reset_children()
    # The transport sees the previous view. Key routing suppresses the model write,
    # but the True result is acceptance, not proof the action reached its owner.
    require(deliver(app, captured), "negative control accepts unpublished stale action")
    require(count(app) == 0, "key route suppresses old callback write")
    var second = App(HandlerHost(Root()), Rect(0, 0, 600, 900))
    var text = Event(TextInputEvent("stale", 0, 1000000))
    text.set_target(target(second, TEXT_INPUT_VIEW_KIND))
    var queued = second.component.queue(text)
    second.component.root.reset_children()
    require(deliver(second, queued), "negative control accepts stale text through unpublished view")
    require(second.component.root.children.entries[0].value.text == "draft", "old route still guards replacement values")
    print("PASS negative control: raw mutation without publication can accept stale work; use update_model")
