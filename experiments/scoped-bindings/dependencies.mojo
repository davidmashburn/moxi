"""Decision probe: explicit dependency unions/branches versus tracked reads.

Experimental adapter only. No public API, compiler inference, or hidden globals.
"""

from std.collections import List
from std.time import perf_counter_ns
from moxi import (
    ColumnRuntime, ColumnView, DependencyEdge, LocalizedExecution,
    PaintCommands, Rect, test_check,
)

comptime UNION = 0
comptime PRECISE = 1
comptime TRACKED = 2
comptime ORACLE = 3
comptime BROKEN = 4
comptime PRIMARY = 0
comptime ALTERNATE = 1
comptime SELECTOR = 2
comptime UNRELATED = 3
comptime GREETING = 0
comptime COUNT = 1
comptime SUMMARY = 2
comptime DETAIL = 3
comptime INDEPENDENT = 4
comptime COMPONENTS = 5


struct Reads[enabled: Bool](ImplicitlyCopyable):
    var mask: Int
    var calls: Int

    def __init__(out self):
        self.mask = 0
        self.calls = 0

    def read(mut self, values: List[String], source: Int) -> String:
        comptime if Self.enabled:
            self.mask |= 1 << source
            self.calls += 1
        return values[source]


def selected[tracked: Bool](mut reads: Reads[tracked], values: List[String]) -> String:
    if reads.read(values, SELECTOR) == "alternate":
        return reads.read(values, ALTERNATE)
    return reads.read(values, PRIMARY)


def greeting[tracked: Bool](mut reads: Reads[tracked], values: List[String]) -> String:
    return String("Hello, ", selected(reads, values))


def count[tracked: Bool](mut reads: Reads[tracked], values: List[String]) -> String:
    return String("Characters: ", selected(reads, values).count_codepoints())


def evaluate[tracked: Bool](component: Int, mut reads: Reads[tracked], values: List[String]) -> String:
    if component == GREETING:
        return greeting(reads, values)
    if component == COUNT:
        return count(reads, values)
    if component == SUMMARY:
        # Shared nested helpers: repeated reads must produce one edge per source.
        return String(greeting(reads, values), " / ", count(reads, values))
    if component == DETAIL:
        return String("Alternate: ", reads.read(values, ALTERNATE))
    return String("Independent: ", reads.read(values, UNRELATED))


def expected(component: Int, values: List[String]) -> String:
    """Independent full-recompute oracle; deliberately bypasses read helpers."""
    var name = values[PRIMARY]
    if values[SELECTOR] == "alternate":
        name = values[ALTERNATE]
    if component == GREETING:
        return String("Hello, ", name)
    if component == COUNT:
        return String("Characters: ", name.count_codepoints())
    if component == SUMMARY:
        return String("Hello, ", name, " / Characters: ", name.count_codepoints())
    if component == DETAIL:
        return String("Alternate: ", values[ALTERNATE])
    return String("Independent: ", values[UNRELATED])


def explicit_mask(component: Int, values: List[String], precise: Bool) -> Int:
    """The separate wiring that an explicit caller must keep in sync."""
    if component == DETAIL:
        return 1 << ALTERNATE
    if component == INDEPENDENT:
        return 1 << UNRELATED
    if not precise:
        return (1 << PRIMARY) | (1 << ALTERNATE) | (1 << SELECTOR)
    var source = PRIMARY
    if values[SELECTOR] == "alternate":
        source = ALTERNATE
    return (1 << SELECTOR) | (1 << source)


def leaf(component: Int, text: String) -> ColumnView:
    var height: Float32 = 24
    if component == INDEPENDENT:
        height = 2024
    var view = ColumnView(Rect(0, 0, 480, height), 0, 0)
    view.add_label(1, text, 24)
    view.layout()
    return view^


struct Work(ImplicitlyCopyable):
    var evaluations: Int
    var independent_builds: Int
    var frames: Int
    var reconciled_nodes: Int
    var read_calls: Int
    var rewires: Int
    var rewire_edge_visits: Int

    def __init__(out self):
        self.evaluations = 0
        self.independent_builds = 0
        self.frames = 0
        self.reconciled_nodes = 0
        self.read_calls = 0
        self.rewires = 0
        self.rewire_edge_visits = 0


struct Probe[mode: Int]:
    var values: List[String]
    var views: List[ColumnView]
    var texts: List[String]
    var masks: List[Int]
    var execution: LocalizedExecution
    var runtime: ColumnRuntime
    var commands: PaintCommands
    var visible: Bool
    var structure_dirty: Bool
    var work: Work

    def __init__(out self):
        self.values = ["Ada", "Grace", "primary", "untouched"]
        self.views = List[ColumnView]()
        self.texts = List[String]()
        self.masks = List[Int]()
        self.execution = LocalizedExecution()
        self.runtime = ColumnRuntime()
        self.commands = PaintCommands()
        self.visible = True
        self.structure_dirty = True
        self.work = Work()
        for source in range(4):
            test_check(self.execution.add_scope(source))
        for component in range(COMPONENTS):
            self.views.append(leaf(component, ""))
            self.texts.append("")
            self.masks.append(0)
            self.rebuild(component)
        self.flush()
        self.work = Work()
        self.execution.reset_work_counters()

    def replace_dependencies(mut self, component: Int, mask: Int):
        if self.masks[component] == mask:
            return
        # LocalizedExecution has no dependency replacement/removal API. Keep this
        # experimental adapter here rather than quietly changing production code.
        var edges = List[DependencyEdge]()
        for index in range(len(self.execution.dependencies)):
            self.work.rewire_edge_visits += 1
            var edge = self.execution.dependencies[index]
            if edge.component_id != component:
                edges.append(edge)
        for source in range(4):
            if mask & (1 << source):
                edges.append(DependencyEdge(component, source))
        self.execution.dependencies = edges^
        self.execution.dependency_fanout.rebuild(self.execution.dependencies)
        self.masks[component] = mask
        self.work.rewires += 1

    def rebuild(mut self, component: Int):
        var reads = Reads[Self.mode == TRACKED]()
        var text: String
        comptime if Self.mode == ORACLE:
            text = expected(component, self.values)
        else:
            text = evaluate(component, reads, self.values)
        self.work.evaluations += 1
        self.work.read_calls += reads.calls
        self.texts[component] = text
        var view = leaf(component, text)
        if component == INDEPENDENT:
            self.work.independent_builds += 1
            for row in range(100):
                view.add_label(10 + row, String("Independent row ", row), 20)
            view.layout()
        self.views[component] = view^
        comptime if Self.mode == TRACKED:
            self.replace_dependencies(component, reads.mask)
        elif Self.mode != ORACLE:
            var mask = explicit_mask(component, self.values, Self.mode == PRECISE)
            comptime if Self.mode == BROKEN:
                if component == GREETING:
                    mask &= ~(1 << ALTERNATE)
            self.replace_dependencies(component, mask)

    def write(mut self, source: Int, value: String) -> Bool:
        if self.values[source] == value:
            return False
        self.values[source] = value
        test_check(self.execution.invalidate_scope(source))
        return True

    def show_detail(mut self, show: Bool):
        if self.visible == show:
            return
        self.visible = show
        self.structure_dirty = True
        _ = self.execution.discard_dirty(DETAIL)
        if show:
            self.rebuild(DETAIL)
        else:
            self.replace_dependencies(DETAIL, 0)

    def flush(mut self):
        comptime if Self.mode != ORACLE:
            if self.execution.dirty_count() == 0 and not self.structure_dirty:
                return
        for component in range(COMPONENTS):
            if component == DETAIL and not self.visible:
                test_check(not self.execution.component_is_dirty(DETAIL))
                continue
            comptime if Self.mode == ORACLE:
                self.rebuild(component)
            else:
                if self.execution.take_dirty(component):
                    self.rebuild(component)
        var parent = ColumnView(Rect(0, 0, 480, 2400), 0, 0)
        for component in range(COMPONENTS):
            if component != DETAIL or self.visible:
                parent.add_component_view_to(
                    -1, 100 + component, self.views[component], 1000 * (component + 1),
                )
        parent.layout()
        self.runtime.reconcile(parent)
        self.commands = self.runtime.paint()
        self.work.frames += 1
        self.work.reconciled_nodes += parent.child_count()
        self.structure_dirty = False
        for source in range(4):
            _ = self.execution.clear_scope(source)

    def report(self, name: String):
        print(name, ",", self.work.evaluations, ",", self.work.independent_builds,
              ",", self.work.frames, ",", self.work.reconciled_nodes,
              ",", self.work.read_calls, ",", self.work.rewires,
              ",", self.work.rewire_edge_visits,
              ",", self.execution.work_counters().dependency_visits, sep="")


def same_output(a: PaintCommands, b: PaintCommands) -> Bool:
    # A skipped frame retains prior changed/removal metadata. Compare observable
    # current content/geometry, not flags from frames that did not happen.
    if a.count() != b.count():
        return False
    for index in range(a.count()):
        var left = a.command(index)
        var right = b.command(index)
        if (left.id != right.id or left.kind != right.kind
            or left.text != right.text or left.bounds.x != right.bounds.x
            or left.bounds.y != right.bounds.y
            or left.bounds.width != right.bounds.width
            or left.bounds.height != right.bounds.height
            or left.semantics.label != right.semantics.label
            or left.semantics.value != right.semantics.value):
            return False
    return True


struct Scenario:
    var union: Probe[UNION]
    var precise: Probe[PRECISE]
    var tracked: Probe[TRACKED]
    var oracle: Probe[ORACLE]
    var checks: Int

    def __init__(out self):
        self.union = Probe[UNION]()
        self.precise = Probe[PRECISE]()
        self.tracked = Probe[TRACKED]()
        self.oracle = Probe[ORACLE]()
        self.checks = 0

    def write(mut self, source: Int, value: String):
        var changed = self.oracle.write(source, value)
        test_check(self.union.write(source, value) == changed)
        test_check(self.precise.write(source, value) == changed)
        test_check(self.tracked.write(source, value) == changed)

    def show_detail(mut self, show: Bool):
        self.union.show_detail(show)
        self.precise.show_detail(show)
        self.tracked.show_detail(show)
        self.oracle.show_detail(show)

    def flush(mut self):
        self.union.flush()
        self.precise.flush()
        self.tracked.flush()
        self.oracle.flush()
        test_check(same_output(self.union.commands, self.oracle.commands))
        test_check(same_output(self.precise.commands, self.oracle.commands))
        test_check(same_output(self.tracked.commands, self.oracle.commands))
        for component in range(COMPONENTS):
            if component != DETAIL or self.tracked.visible:
                test_check(self.tracked.texts[component] == expected(component, self.tracked.values))
                test_check(self.precise.masks[component] == self.tracked.masks[component])
        test_check(self.tracked.work.evaluations == self.precise.work.evaluations)
        test_check(self.tracked.work.frames == self.precise.work.frames)
        test_check(self.tracked.execution.dirty_count() == 0)
        test_check(len(self.tracked.execution.dependencies) <= 8)
        self.checks += 1

    def action(mut self, step: Int, action: Int):
        apply_action(self.union, step, action)
        apply_action(self.precise, step, action)
        apply_action(self.tracked, step, action)
        apply_action(self.oracle, step, action)
        self.flush()


def apply_action[mode: Int](mut probe: Probe[mode], step: Int, action: Int):
    """Identical deterministic actions in correctness and timed runs."""
    if action < 2:
        _ = probe.write(action, String("Name ", step % 17, " 日本語"))
    elif action == 2:
        var selected_name = String("primary")
        if step % 2:
            selected_name = "alternate"
        _ = probe.write(SELECTOR, selected_name)
    elif action == 3:
        probe.show_detail(not probe.visible)
    elif action == 4:
        _ = probe.write(UNRELATED, String("Independent ", step))
    elif action == 5:
        var unchanged = probe.values[PRIMARY]
        _ = probe.write(PRIMARY, unchanged)
    elif action == 6:
        _ = probe.write(PRIMARY, String("Batch A ", step))
        _ = probe.write(PRIMARY, String("Batch B ", step))
        _ = probe.write(ALTERNATE, String("Batch alt ", step))
    else:
        _ = probe.write(SELECTOR, "alternate")
        _ = probe.write(SELECTOR, "primary")


def elapsed[mode: Int]() -> Int:
    var probe = Probe[mode]()
    var seed: UInt64 = 1753
    var start = perf_counter_ns()
    for step in range(1000):
        seed = seed * 6364136223846793005 + 1442695040888963407
        apply_action(probe, step, Int((seed >> 32) % 8))
        probe.flush()
    var duration = perf_counter_ns() - start
    # Outside timed region: keep work observable and verify final output.
    for component in range(COMPONENTS):
        if component != DETAIL or probe.visible:
            test_check(probe.texts[component] == expected(component, probe.values))
    return duration


def timings():
    # Warm all specializations, then rotate order to reduce ordering bias.
    _ = elapsed[UNION]()
    _ = elapsed[PRECISE]()
    _ = elapsed[TRACKED]()
    print("sample,explicit_union_ns,explicit_precise_ns,tracked_ns")
    for sample in range(9):
        var union: Int
        var precise: Int
        var tracked: Int
        if sample % 3 == 0:
            union = elapsed[UNION]()
            precise = elapsed[PRECISE]()
            tracked = elapsed[TRACKED]()
        elif sample % 3 == 1:
            tracked = elapsed[TRACKED]()
            union = elapsed[UNION]()
            precise = elapsed[PRECISE]()
        else:
            precise = elapsed[PRECISE]()
            tracked = elapsed[TRACKED]()
            union = elapsed[UNION]()
        print(sample, ",", union, ",", precise, ",", tracked, sep="")


def check_missing_edge():
    var broken = Probe[BROKEN]()
    test_check(broken.write(SELECTOR, "alternate"))
    broken.flush()
    test_check(broken.write(ALTERNATE, "日本語"))
    broken.flush()
    test_check(broken.texts[GREETING] != expected(GREETING, broken.values))
    print("PASS: intentionally omitted explicit alternate edge detected as stale output")


def main():
    var scenario = Scenario()
    scenario.flush()
    # Hand-auditable inactive-source test: only DETAIL should rebuild.
    scenario.write(ALTERNATE, "日本語")
    scenario.flush()
    test_check(scenario.union.work.evaluations == 4)
    test_check(scenario.tracked.work.evaluations == 1)
    test_check(scenario.tracked.work.independent_builds == 0)
    # Coalesce two sources plus a branch change; no mixed/intermediate output.
    scenario.write(PRIMARY, "Alan")
    scenario.write(ALTERNATE, "日!語")
    scenario.write(SELECTOR, "alternate")
    test_check(scenario.tracked.texts[GREETING] == "Hello, Ada")
    scenario.flush()
    test_check(scenario.tracked.texts[GREETING] == "Hello, 日!語")
    # Old source subscriptions disappear after switching, while no-op writes
    # do not schedule work. The union control intentionally still rebuilds.
    var frames = scenario.tracked.work.frames
    var evaluations = scenario.tracked.work.evaluations
    scenario.write(PRIMARY, "inactive primary")
    scenario.flush()
    test_check(scenario.tracked.work.frames == frames)
    test_check(scenario.tracked.work.evaluations == evaluations)
    scenario.write(ALTERNATE, "日!語")
    scenario.flush()
    test_check(scenario.tracked.work.frames == frames)
    # Removing a dirty consumer discards its pending build and subscriptions.
    scenario.write(ALTERNATE, "removed while dirty")
    scenario.show_detail(False)
    scenario.flush()
    test_check(scenario.tracked.masks[DETAIL] == 0)
    test_check(scenario.tracked.runtime.retained_index(4001) == -1)
    scenario.write(ALTERNATE, "hidden edit")
    scenario.flush()
    scenario.show_detail(True)
    scenario.flush()
    test_check(scenario.tracked.texts[DETAIL] == "Alternate: hidden edit")
    # Reproducible mixed trace; every transaction checked against recomputation.
    var seed: UInt64 = 1753
    for step in range(1000):
        seed = seed * 6364136223846793005 + 1442695040888963407
        scenario.action(step, Int((seed >> 32) % 8))
    print("mode,evaluations,independent_builds,frames,reconciled_nodes,tracked_read_calls,rewires,adapter_edge_visits,invalidation_edge_visits")
    scenario.union.report("explicit_union")
    scenario.precise.report("explicit_precise")
    scenario.tracked.report("tracked")
    scenario.oracle.report("full_recompute")
    print("PASS: ", scenario.checks, " transactions; oracle parity, precise/tracked work parity, branching, batching, no-op, Unicode, dirty unmount/remount, bounded subscriptions", sep="")
    check_missing_edge()
    timings()
