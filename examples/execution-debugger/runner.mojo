"""I13: replay I15 observations through real localized Moxi components.

The Python boundary validates the bounded input. This program owns dispatch,
work accounting, retained frame rendering, and the bounded trace buffer.
"""

from std.collections import List
from std.ffi import external_call
from std.sys import argv
from moxi import (
    ACTION_KIND, ActionEvent, ColumnView, Component, Event,
    ExecutionWorkCounters, Rect, SvgSceneRenderer, TypedSubtreeExecutor,
    default_surface_style, scene_from_paint,
)

comptime SAMPLE_ACTION = 101
comptime RESULT_ACTION = 102


def clock_ns() -> Int64:
    return external_call["moxi_benchmark_time_ns", Int64]()


def quote(value: String) -> String:
    var output = String("\"")
    for char in value.codepoints():
        var text = String(char)
        if text == "\"" or text == "\\":
            output += "\\"
        output += text
    return output + "\""


struct ValuePanel(Component):
    var title: String
    var value: String
    var action: Int

    def __init__(out self, title: String, action: Int, value: String):
        self.title = title
        self.action = action
        self.value = value

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        if event.kind != ACTION_KIND or event.action_id != self.action:
            return False
        if self.value == event.text:
            return False
        self.value = event.text
        return True

    def build(self, bounds: Rect) -> ColumnView:
        var view = ColumnView(bounds, 20.0, 8.0)
        view.set_surface_style(default_surface_style())
        view.add_label(1, self.title, 28.0)
        view.add_label(2, self.value, 36.0)
        view.add_label(3, "Recorded I15 observation", 24.0)
        view.layout()
        return view^


def work(after: ExecutionWorkCounters, before: ExecutionWorkCounters) -> String:
    return String(
        "{\"builds\":", after.component_builds - before.component_builds,
        ",\"nodes\":", after.reconciled_nodes - before.reconciled_nodes,
        ",\"paints\":", after.paint_commands - before.paint_commands,
        ",\"invalidations\":", after.invalidation_count - before.invalidation_count,
        ",\"visits\":", after.dependency_visits - before.dependency_visits,
        ",\"total_builds\":", after.component_builds, "}",
    )


def main() raises:
    # broad, capacity (0 disables tracing), peak (-1 means absent), tick/value...
    var args = argv()
    if len(args) < 4 or (len(args) - 4) % 2 != 0:
        raise Error("Expected broad, capacity, peak and tick/value pairs")
    var broad = Int(args[1]) != 0
    var capacity = Int(args[2])
    var peak = Int(args[3])
    if capacity < 0 or capacity > 32 or len(args) > 28:
        raise Error("Replay exceeds the bounded runner profile")
    var reading = TypedSubtreeExecutor[ValuePanel](
        ValuePanel("Reading / scope 10", SAMPLE_ACTION, "No retained sample"),
        Rect(0, 0, 320, 150), 1, 10,
    )
    var result = TypedSubtreeExecutor[ValuePanel](
        ValuePanel("Peak / scope 20", RESULT_ACTION, "Unavailable"),
        Rect(320, 0, 320, 150), 2, 20,
    )
    var records = List[String]()
    var emitted = 0
    var capture_ns: Int64 = 0
    var action_ns: Int64 = 0
    var count = (len(args) - 4) // 2
    if peak >= 0:
        count += 1
    for index in range(count):
        var is_sample = index < (len(args) - 4) // 2
        var tick = -1
        var value = peak
        if is_sample:
            tick = Int(args[4 + index * 2])
            value = Int(args[5 + index * 2])
        var reading_before = reading.component.value
        var result_before = result.component.value
        var before_a = reading.work_counters()
        var before_b = result.work_counters()
        var started = clock_ns()
        if is_sample:
            _ = reading.dispatch(Event(ActionEvent(SAMPLE_ACTION, String(value))))
            if broad:
                _ = result.invalidate()
                _ = result.rebuild_if_dirty()
        else:
            _ = result.dispatch(Event(ActionEvent(RESULT_ACTION, String(value))))
            if broad:
                _ = reading.invalidate()
                _ = reading.rebuild_if_dirty()
        var finished = clock_ns()
        action_ns += finished - started
        if capacity > 0:
            var captured = clock_ns()
            var commands = reading.paint()
            var other = result.paint()
            for command_index in range(other.count()):
                commands.append(other.command(command_index))
            var renderer = SvgSceneRenderer(640, 150)
            renderer.render_scene(scene_from_paint(commands))
            var record = String(
                "{\"ordinal\":", index + 1,
                ",\"tick\":", tick,
                ",\"action\":", quote("sample" if is_sample else "async-result"),
                ",\"target\":", quote("reading" if is_sample else "peak"),
                ",\"value\":", value,
                ",\"before\":[", quote(reading_before), ",", quote(result_before), "]",
                ",\"after\":[", quote(reading.component.value), ",", quote(result.component.value), "]",
                ",\"work\":[", work(reading.work_counters(), before_a), ",",
                work(result.work_counters(), before_b), "]",
                ",\"dispatch_ns\":", finished - started,
                ",\"svg\":", quote(renderer.markup()), "}",
            )
            if len(records) == capacity:
                _ = records.pop(0)
            records.append(record)
            capture_ns += clock_ns() - captured
        emitted += 1
    print(String(
        "{\"emitted\":", emitted,
        ",\"dropped\":", emitted - len(records),
        ",\"dispatch_ns\":", action_ns,
        ",\"capture_ns\":", capture_ns,
        ",\"builds\":[", reading.work_counters().component_builds,
        ",", result.work_counters().component_builds, "]",
        ",\"final\":[", quote(reading.component.value), ",",
        quote(result.component.value), "]}",
    ))
    for index in range(len(records)):
        print(records[index])
