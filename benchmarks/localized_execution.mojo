"""Repeatable typed-subtree workload for localized execution accounting."""

from moxi import (
    ActionEvent,
    COUNTER_INCREMENT_ACTION,
    CounterState,
    Component,
    ColumnView,
    Event,
    LabelControl,
    Rect,
    TypedSubtreeExecutor,
)


comptime BENCHMARK_PASSES: Int = 1000


struct LocalizedChildrenState(Component):
    """Build a controlled number of sibling nodes for work-scaling checks."""

    var child_count: Int
    var revision: Int

    def __init__(out self, child_count: Int):
        self.child_count = child_count if child_count > 0 else 1
        self.revision = 0

    def build(self, bounds: Rect) -> ColumnView:
        var view = ColumnView(bounds, 0.0, 1.0)
        for index in range(self.child_count):
            var label = LabelControl(
                100 + index,
                String("Child ", index, " revision ", self.revision),
                18.0,
            )
            view.add(label.node())
        view.layout()
        return view^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        if event.target >= 100 and event.target < 100 + self.child_count:
            self.revision += 1
            return True
        return False


def run_child_workload(child_count: Int) raises:
    var subtree = TypedSubtreeExecutor[LocalizedChildrenState](
        LocalizedChildrenState(child_count),
        Rect(0.0, 0.0, 480.0, 10000.0),
        child_count + 10,
        child_count + 10,
    )
    var event = Event(ActionEvent(COUNTER_INCREMENT_ACTION))
    event.set_target(100 + child_count - 1)
    var initial = subtree.work_counters()
    for _ in range(BENCHMARK_PASSES):
        _ = subtree.dispatch(event)
    var final = subtree.work_counters()
    print(
        "Moxi localized matrix children/passes: ",
        child_count,
        "/",
        BENCHMARK_PASSES,
    )
    print("Moxi localized matrix initial builds: ", initial.component_builds)
    print("Moxi localized matrix final builds: ", final.component_builds)
    print("Moxi localized matrix invalidations: ", final.invalidation_count)
    print("Moxi localized matrix dependency visits: ", final.dependency_visits)
    print("Moxi localized matrix reconciled nodes: ", final.reconciled_nodes)
    print("Moxi localized matrix paint commands: ", final.paint_commands)
    print("Moxi localized matrix total work: ", final.total_work())


def main() raises:
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
    run_child_workload(1)
    run_child_workload(10)
    run_child_workload(100)
