"""Equivalent retained trees, real dispatch and paint, unchanged editor source."""
from runtime import require
from std.time import perf_counter_ns
from application import Application
from domain import Services
from selective import SelectiveHost, AllInputs, SharedInputs, equal_value
from benchmark import selective_control_id
from moxi import App, Rect, Event, TextInputEvent, ActionEvent, PaintCommands


struct ForcedInputs(SharedInputs):
    # Same owned input snapshot as AllInputs; only cache acceptance differs.
    var snapshot: Services
    def __init__(out self, services: Services):
        self.snapshot = services
    def matches(self, services: Services) -> Bool:
        return False


def paint_equal(a: PaintCommands, b: PaintCommands):
    require(a.count() == b.count(), "frame:21")
    require(a.changed_count() == b.changed_count(), "frame:22")
    require(a.removed_count() == b.removed_count(), "frame:23")
    require(a.has_dirty_region() == b.has_dirty_region(), "frame:24")
    require(equal_value(a.dirty_region(), b.dirty_region()), "frame:25")
    for i in range(a.count()):
        require(equal_value(a.command(i), b.command(i)), "frame:27")
    for i in range(a.removed_count()):
        require(equal_value(a.removed_region(i), b.removed_region(i)), "frame:29")


def pair(count: Int, sample: Int, shared: Bool):
    var bounds = Rect(0, 0, 640, 400000)
    var cached = App(SelectiveHost[AllInputs](Application(count)), bounds)
    var forced = App(SelectiveHost[ForcedInputs](Application(count)), bounds)
    paint_equal(cached.paint(), forced.paint())
    var ca = selective_control_id(cached.component, count, 2)
    var cb = selective_control_id(forced.component, count, 2)
    require(ca == cb, "frame:39")
    var event = Event(TextInputEvent("Local", 0, 3))
    event.set_target(ca)
    if shared:
        require(cached.update(event), "frame:43")
        require(forced.update(event), "frame:44")
        paint_equal(cached.paint(), forced.paint())
        ca = selective_control_id(cached.component, count, 5)
        cb = selective_control_id(forced.component, count, 5)
        require(ca == cb, "frame:48")
        event = Event(ActionEvent(ca))
        event.set_target(ca)
    cached.component.reset_counts()
    forced.component.reset_counts()
    var cached_update: Int
    var cached_paint: Int
    var forced_update: Int
    var forced_paint: Int
    var pc: PaintCommands
    var pf: PaintCommands
    var hc: Bool
    var hf: Bool
    # Alternate mode order to reduce a systematic warm-cache/order advantage.
    if sample % 2 == 0:
        var start = perf_counter_ns()
        hc = cached.update(event)
        var middle = perf_counter_ns()
        pc = cached.paint()
        var end = perf_counter_ns()
        cached_update = Int(middle - start)
        cached_paint = Int(end - middle)
        start = perf_counter_ns()
        hf = forced.update(event)
        middle = perf_counter_ns()
        pf = forced.paint()
        end = perf_counter_ns()
        forced_update = Int(middle - start)
        forced_paint = Int(end - middle)
    else:
        var start = perf_counter_ns()
        hf = forced.update(event)
        var middle = perf_counter_ns()
        pf = forced.paint()
        var end = perf_counter_ns()
        forced_update = Int(middle - start)
        forced_paint = Int(end - middle)
        start = perf_counter_ns()
        hc = cached.update(event)
        middle = perf_counter_ns()
        pc = cached.paint()
        end = perf_counter_ns()
        cached_update = Int(middle - start)
        cached_paint = Int(end - middle)
    require(hc and hf, "frame:92")
    # List[Entry[Editor]] does not provide value equality. Reflecting its
    # storage would compare buffer metadata; compare its logical contents.
    require(equal_value(cached.component.root.services, forced.component.root.services), "services")
    ref cg = cached.component.root.shell.workspace.group
    ref fg = forced.component.root.shell.workspace.group
    require(cg.next_key == fg.next_key and len(cg.entries) == len(fg.entries), "collection metadata")
    for i in range(len(cg.entries)):
        require(cg.entries[i].key == fg.entries[i].key, "entry key")
        require(equal_value(cg.entries[i].value, fg.entries[i].value), "entry value")
    require(cached.view.child_count() == forced.view.child_count(), "frame:94")
    require(equal_value(cached.view.layout_spec, forced.view.layout_spec), "frame:95")
    for i in range(cached.view.child_count()):
        require(equal_value(cached.view.child(i), forced.view.child(i)), "frame:97")
    paint_equal(pc, pf)
    require(cached.component.editor_renders == (count if shared else 1), "frame:99")
    require(forced.component.editor_renders == count, "frame:100")
    require(cached.component.root.shell.workspace.group.entries[count-1].value.draft == "Local", "frame:101")
    require(cached.component.root.services.document.name == ("Local" if shared else "Ada"), "frame:102")
    require(cached.component.root.services.document.commits == (1 if shared else 0), "frame:103")
    if sample >= 0:
        print("FRAME", count, shared, sample, cached_update, cached_paint, forced_update, forced_paint, pc.count(), cached.component.editor_renders, forced.component.editor_renders)


def main():
    for level in range(3):
        var count = 2 if level == 0 else (100 if level == 1 else 300)
        for operation in range(2):
            var shared = operation == 1
            pair(count, -1, shared)
            pair(count, -2, shared)
            for i in range(5):
                pair(count, i, shared)
    print("PASS equivalent trees, domain effects, full commands and dirty metadata")
