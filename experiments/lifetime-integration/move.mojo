"""Moving an App preserves its owner; copying its host creates another owner."""
from moxi import App, Rect
from runtime import HandlerHost, require, deliver
from lifetime_check import Root, target, count
from request_bridge import RequestBridge


def main():
    var original = App(HandlerHost(Root()), Rect(0, 0, 600, 900))
    var action = original.component.capture(target(original))
    var bridge = RequestBridge(original)
    var completion = bridge.submit(original, target(original))
    var moved = original^
    require(deliver(moved, action) and count(moved) == 1, "move preserves captured action owner")
    require(bridge.complete(moved, completion) and bridge.drain(moved) == 1 and count(moved) == 2, "move preserves scheduler and bridge provenance")
    var duplicate = App(HandlerHost[Root](copy=moved.component), Rect(0, 0, 600, 900))
    require(not deliver(duplicate, action) and count(duplicate) == 2, "copy keeps values but rejects moved host's action")
    require(deliver(moved, action) and count(moved) == 3 and count(duplicate) == 2, "copy does not retire moved source")
    print("PASS App move preserves action/request ownership; host copy remains independent")
