"""Localized component invalidation and typed-subtree execution contract."""

from moxi import (
    ActionEvent,
    COUNTER_INCREMENT_ACTION,
    CounterState,
    Event,
    LocalizedExecution,
    Rect,
    TypedSubtreeExecutor,
    test_check,
)


def main():
    var execution = LocalizedExecution()
    test_check(execution.add_scope(10))
    test_check(execution.add_scope(20, 10))
    test_check(not execution.add_scope(30, 99))
    test_check(execution.add_dependency(1, 10))
    test_check(execution.add_dependency(2, 20))
    test_check(not execution.add_dependency(1, 10))
    test_check(execution.invalidate_scope(10))
    test_check(execution.dirty_count() == 2)
    test_check(execution.component_is_dirty(1))
    test_check(execution.component_is_dirty(2))
    test_check(execution.take_dirty(1))
    test_check(execution.build_count(1) == 1)
    test_check(not execution.take_dirty(1))
    test_check(execution.take_dirty(2))
    test_check(execution.invalidate_scope(20))
    test_check(execution.take_dirty(2))
    test_check(execution.clear_scope(10))

    var subtree = TypedSubtreeExecutor[CounterState](
        CounterState(),
        Rect(0.0, 0.0, 200.0, 80.0),
        7,
        30,
    )
    var initial = subtree.work_counters()
    test_check(subtree.mounted)
    test_check(initial.component_builds == 1)
    test_check(initial.reconciled_nodes > 0)
    test_check(not subtree.rebuild_if_dirty())
    test_check(
        subtree.dispatch(Event(ActionEvent(COUNTER_INCREMENT_ACTION)))
    )
    test_check(subtree.component.count == 1)
    var after = subtree.work_counters()
    test_check(after.invalidation_count == 1)
    test_check(after.dependency_visits == 1)
    test_check(after.dirty_consumed == 1)
    test_check(after.component_builds == 2)
    test_check(after.reconciled_nodes > initial.reconciled_nodes)
    test_check(subtree.work_counters().total_work() > initial.total_work())
    test_check(not subtree.rebuild_if_dirty())
    print("Moxi localized-execution test passed")
