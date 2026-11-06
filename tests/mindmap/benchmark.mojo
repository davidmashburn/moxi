from std.time import perf_counter_ns
from std.collections import List
from moxi_mindmap.fixtures import large_map
from moxi_mindmap.layout import MapLayout
from moxi_mindmap.codec import encode, decode
from moxi_mindmap.model import Crosslink

def sample(count: Int, folded: Bool, deep: Bool, rich: Bool = False) raises:
    var doc = large_map(count, folded, deep)
    if rich:
        for i in range(len(doc.topics)):
            doc.topics[i].text = String("Topic ", i, " · 日本語 العربية café ") * 12
            doc.topics[i].note = "Original synthetic long note. " * 48
        for i in range(1, count - 1):
            doc.links.append(Crosslink(i, doc.topics[i].id, doc.topics[i + 1].id, "Related"))
        doc.validate()
    var layout = MapLayout()
    var start = perf_counter_ns()
    layout.compute(doc)
    var first = Float64(perf_counter_ns() - start) / 1_000_000
    var times = List[Float64]()
    for trial in range(21):
        doc.topics[len(doc.topics) - 1].text = String("Updated ", trial, " · 日本語")
        start = perf_counter_ns()
        layout.compute(doc)
        times.append(Float64(perf_counter_ns() - start) / 1_000_000)
    # Deliberately simple bounded sort; timing excludes statistic calculation.
    for i in range(len(times)):
        for j in range(i + 1, len(times)):
            if times[j] < times[i]:
                var swap = times[i]
                times[i] = times[j]
                times[j] = swap
    start = perf_counter_ns()
    var projection = layout.project(doc)
    var project_ms = Float64(perf_counter_ns() - start) / 1_000_000
    start = perf_counter_ns()
    var restored = decode(encode(doc))
    var codec_ms = Float64(perf_counter_ns() - start) / 1_000_000
    print("topics", count, "folded", folded, "deep", deep, "rich", rich, "visible", layout.visible, "cold_layout_ms", first, "update_p95_ms", times[19], "p99_max_ms", times[20], "measured_last", layout.measured, "changed_last", layout.changed, "projection_ms", project_ms, "roundtrip_ms", codec_ms, "objects", len(projection.objects), "edges", len(projection.edges), "native_commands", "NOT_SUBMITTED")

def main() raises:
    for count in List[Int]([100, 1000, 10000]):
        sample(count, False, False)
        sample(count, True, False)
        sample(count, False, True)
    sample(1000, False, False, True)
    print("No allocation instrumentation; no native presentation/frame/GPU timing. Native ordinary command limit remains 1024.")
