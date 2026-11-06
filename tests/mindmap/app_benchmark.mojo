from std.time import perf_counter_ns
from std.collections import List
from moxi import Rect, Event
from moxi.event import FRAME_TICK_KIND
from moxi_mindmap.fixtures import large_map
from moxi_mindmap.application import MindMapApp
from moxi_mindmap.commands import MapCommand

def percentiles(kind: String, mut times: List[Float64]):
    for i in range(len(times)):
        for j in range(i + 1, len(times)):
            if times[j] < times[i]:
                var old = times[i]
                times[i] = times[j]
                times[j] = old
    print(kind, "samples", len(times), "p95_ms", times[19], "p99_max_ms", times[20])

def main() raises:
    for count in [100, 1000, 10000]:
        for folded in [False, True]:
            var start = perf_counter_ns()
            var app = MindMapApp(large_map(count, folded))
            var constructed = perf_counter_ns()
            var candidate = app.doc
            candidate.topics[len(candidate.topics)-1].text += " revised"
            _ = app.commit(candidate, "Benchmark update")
            var updated = perf_counter_ns()
            var commands = app.app.paint().count()
            var painted = perf_counter_ns()
            print("app_topics", count, "folded", folded, "construct_ms", Float64(constructed-start)/1e6, "semantic_update_ms", Float64(updated-constructed)/1e6, "paint_list_ms", Float64(painted-updated)/1e6, "ordinary_commands", commands, "viewport", 1180, 820)
    # Demonstrate the inherited fixed ordinary-command limit without submitting
    # an invalid native frame. Huge logical viewport deliberately defeats culling.
    var capacity = MindMapApp(large_map(1000), Rect(0,0,100000,100000))
    var ordinary = capacity.app.paint().count()
    if ordinary <= 1024:
        raise Error("capacity fixture failed to exercise inherited native limit")
    print("capacity_probe_ordinary_commands", ordinary, "native_submission", "SKIPPED_OVER_1024")
    var local = MindMapApp(large_map(1000))
    var edit_times = List[Float64]()
    var move_times = List[Float64]()
    var reflow_times = List[Float64]()
    for trial in range(21):
        local.select(1000)
        var start = perf_counter_ns()
        local.expected = local.history.generation
        var candidate = local.doc
        candidate.topics[len(candidate.topics)-1].text = String("Edit ", trial, " 日本語")
        _ = local.commit(candidate, "Edit timing")
        _ = local.app.paint()
        edit_times.append(Float64(perf_counter_ns()-start)/1e6)
        start = perf_counter_ns()
        local.begin_move()
        local.close_search()
        local.propose(2 if trial % 2 == 0 else 3, 0)
        local.finish_move()
        _ = local.app.paint()
        move_times.append(Float64(perf_counter_ns()-start)/1e6)
        var tick = Event()
        tick.kind = FRAME_TICK_KIND
        tick.delta_seconds = 0.09
        start = perf_counter_ns()
        _ = local.dispatch(tick)
        _ = local.app.paint()
        reflow_times.append(Float64(perf_counter_ns()-start)/1e6)
    percentiles("1000-topic_application_edit", edit_times)
    percentiles("1000-topic_application_move_preview_commit", move_times)
    percentiles("1000-topic_application_reflow_frame", reflow_times)
    print("No allocator or GPU/presentation measurements. Fixture matrix uses one sample; 1000-topic edit/move use 21 samples. Not native frame acceptance.")
