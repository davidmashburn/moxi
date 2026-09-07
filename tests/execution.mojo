"""Localized component invalidation and typed-subtree execution contract."""

from std.collections import List

from moxi import (
    ActionEvent,
    COUNTER_INCREMENT_ACTION,
    CounterState,
    Event,
    KeyedSubtreeDescriptor,
    KeyedSubtreeExecutor,
    LocalizedExecution,
    Rect,
    TypedSubtreeExecutor,
    test_check,
)


def main():
    var execution = LocalizedExecution()
    test_check(execution.add_scope(10))
    test_check(execution.add_scope(20, 10))
    test_check(execution.add_scope(40))
    test_check(not execution.add_scope(30, 99))
    test_check(execution.add_dependency(1, 10))
    test_check(execution.add_dependency(2, 20))
    test_check(execution.add_dependency(3, 40))
    test_check(not execution.add_dependency(1, 10))
    test_check(execution.invalidate_scope(10))
    test_check(execution.dirty_count() == 2)
    test_check(execution.work_counters().dependency_visits == 2)
    test_check(execution.component_is_dirty(1))
    test_check(execution.component_is_dirty(2))
    test_check(execution.take_dirty(1))
    test_check(execution.build_count(1) == 1)
    test_check(not execution.take_dirty(1))
    test_check(execution.take_dirty(2))
    test_check(execution.invalidate_scope(20))
    test_check(execution.take_dirty(2))
    test_check(execution.work_counters().dependency_visits == 3)
    test_check(execution.invalidate_scope(40))
    test_check(execution.take_dirty(3))
    test_check(execution.work_counters().dependency_visits == 4)
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

    var keyed = KeyedSubtreeExecutor[CounterState](50)
    var first_descriptor = KeyedSubtreeDescriptor(11, 101, 51, 1, 1000)
    var second_descriptor = KeyedSubtreeDescriptor(22, 102, 52, 2, 2000)
    test_check(
        keyed.insert(
            first_descriptor,
            CounterState(),
            Rect(0.0, 0.0, 200.0, 80.0),
        )
    )
    test_check(
        keyed.insert(
            second_descriptor,
            CounterState(),
            Rect(0.0, 0.0, 200.0, 80.0),
        )
    )
    test_check(keyed.active_count() == 2)
    test_check(keyed.active_key(0) == 11)
    test_check(keyed.child_build_count(11) == 1)
    test_check(keyed.child_build_count(22) == 1)

    test_check(keyed.invalidate_child(11))
    test_check(keyed.rebuild_dirty() == 1)
    test_check(keyed.child_build_count(11) == 2)
    test_check(keyed.child_build_count(22) == 1)

    var reordered = List[Int](capacity=2)
    reordered.append(22)
    reordered.append(11)
    test_check(keyed.reorder(reordered))
    test_check(keyed.active_key(0) == 22)
    test_check(keyed.work_counters().keyed_moves == 2)
    test_check(keyed.remove(22))
    test_check(keyed.active_count() == 1)
    test_check(keyed.work_counters().keyed_removals == 1)

    test_check(keyed.invalidate_parent())
    test_check(keyed.work_counters().root_fallbacks == 1)
    test_check(keyed.dirty_count() == 1)
    test_check(keyed.rebuild_dirty() == 1)
    var parent = keyed.build_parent(Rect(0.0, 0.0, 220.0, 100.0))
    test_check(parent.child_count() == 4)
    test_check(keyed.work_counters().parent_builds == 1)
    test_check(keyed.work_counters().root_fallbacks > 0)

    # Stable-key indexes must remain correct when registration order differs
    # from key order and when a middle child is removed.
    var indexed = KeyedSubtreeExecutor[CounterState](60)
    var high_descriptor = KeyedSubtreeDescriptor(30, 301, 61, 3, 3000)
    var low_descriptor = KeyedSubtreeDescriptor(10, 302, 62, 4, 4000)
    var middle_descriptor = KeyedSubtreeDescriptor(20, 303, 63, 5, 5000)
    test_check(
        indexed.insert(
            high_descriptor,
            CounterState(),
            Rect(0.0, 0.0, 120.0, 60.0),
        )
    )
    test_check(
        indexed.insert(
            low_descriptor,
            CounterState(),
            Rect(0.0, 0.0, 120.0, 60.0),
        )
    )
    test_check(
        indexed.insert(
            middle_descriptor,
            CounterState(),
            Rect(0.0, 0.0, 120.0, 60.0),
        )
    )
    test_check(indexed.schedule.descriptor_index(10) == 1)
    test_check(indexed.schedule.descriptor_index(20) == 2)
    test_check(indexed.schedule.order_index(30) == 0)
    test_check(indexed.schedule.order_index(10) == 1)
    test_check(indexed.invalidate_child(30))
    test_check(indexed.invalidate_child(10))
    test_check(indexed.rebuild_dirty() == 2)
    test_check(indexed.remove(10))
    test_check(indexed.child_build_count(20) == 1)
    test_check(indexed.schedule.descriptor(20).slot_id == 303)
    print("Moxi keyed-subtree scheduling test passed")
