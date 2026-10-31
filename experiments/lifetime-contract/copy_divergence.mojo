"""Independent host copies must not share a namespace after allocation diverges."""
from lifetime_check import Root, target, count, refresh, event
from runtime import HandlerHost, require, deliver
from moxi import App, Rect


def main():
    var original = App(HandlerHost(Root()), Rect(0, 0, 600, 900))
    var copied = App(original.component, Rect(0, 0, 600, 900))
    original.component.root.reset_children()
    copied.component.root.reset_children()
    refresh(original)
    refresh(copied)
    require(target(original) == target(copied), "independent allocators deliberately converge")
    var captured = original.component.capture(target(original))
    var queued = original.component.queue(event(target(original)))
    require(not deliver(copied, captured), "diverged copy rejects original fresh action")
    require(not deliver(copied, queued), "diverged copy rejects original fresh event")
    require(count(copied) == 0, "copy's independent new lifetime stays untouched")
    require(deliver(original, captured) and deliver(original, queued), "original work still valid")
    require(count(original) == 2, "original lifetime receives work")
    print("PASS divergent host copies isolate fresh work despite equal keys and IDs")
