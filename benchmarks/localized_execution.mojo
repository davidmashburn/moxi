"""Repeatable typed-subtree workload for localized execution accounting."""

from moxi import (
    ActionEvent,
    COUNTER_INCREMENT_ACTION,
    CounterState,
    Event,
    Rect,
    TypedSubtreeExecutor,
)


comptime BENCHMARK_PASSES: Int = 1000


def main():
    var subtree = TypedSubtreeExecutor[CounterState](
        CounterState(),
        Rect(0.0, 0.0, 240.0, 96.0),
        7,
        30,
    )
    var initial = subtree.work_counters()
    for _ in range(BENCHMARK_PASSES):
        _ = subtree.dispatch(Event(ActionEvent(COUNTER_INCREMENT_ACTION)))
    var final = subtree.work_counters()
    print("Moxi localized benchmark passes: ", BENCHMARK_PASSES)
    print("Moxi localized benchmark count: ", subtree.component.count)
    print("Moxi localized benchmark initial builds: ", initial.component_builds)
    print("Moxi localized benchmark final builds: ", final.component_builds)
    print("Moxi localized benchmark invalidations: ", final.invalidation_count)
    print("Moxi localized benchmark dependency visits: ", final.dependency_visits)
    print("Moxi localized benchmark dirty consumed: ", final.dirty_consumed)
    print("Moxi localized benchmark reconciled nodes: ", final.reconciled_nodes)
    print("Moxi localized benchmark paint commands: ", final.paint_commands)
    print("Moxi localized benchmark total work: ", final.total_work())
