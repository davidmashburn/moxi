"""Localized component invalidation contract test."""

from moxi import LocalizedExecution, test_check


def main():
    var execution = LocalizedExecution()
    test_check(execution.add_scope(10))
    test_check(execution.add_scope(20, 10))
    test_check(execution.add_dependency(1, 10))
    test_check(execution.add_dependency(2, 20))
    test_check(not execution.add_dependency(1, 10))
    test_check(execution.invalidate_scope(10))
    test_check(execution.dirty_count() == 1)
    test_check(execution.component_is_dirty(1))
    test_check(not execution.component_is_dirty(2))
    test_check(execution.take_dirty(1))
    test_check(execution.build_count(1) == 1)
    test_check(not execution.take_dirty(1))
    test_check(execution.invalidate_scope(20))
    test_check(execution.take_dirty(2))
    test_check(execution.clear_scope(10))
    print("Moxi localized-execution test passed")
