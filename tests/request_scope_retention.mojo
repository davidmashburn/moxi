"""Closing request scopes reclaims metadata without accepting stale results."""
from moxi import RequestScheduler, TASK_COMPLETED, test_check


def main():
    var scheduler = RequestScheduler()
    var survivor = scheduler.mount_scope(42)
    var live = scheduler.request_in_scope(survivor, 7, "survivor", 60.0)
    var stale_scope = scheduler.mount_scope(99)
    var stale = scheduler.request_in_scope(stale_scope, 7, "stale", 60.0)
    test_check(scheduler.complete(stale, TASK_COMPLETED))
    test_check(scheduler.unmount_scope(99))
    var old_result = scheduler.pop_ready()
    test_check(old_result.matches(stale))
    test_check(not scheduler.should_deliver(old_result))
    for _ in range(1000):
        var scope = scheduler.mount_scope(99)
        test_check(scope.id > stale_scope.id)
        var request = scheduler.request_in_scope(scope, 7, "churn", 60.0)
        test_check(scheduler.unmount_scope(99))
        test_check(not scheduler.scope_is_active(scope))
        test_check(not scheduler.complete(request, TASK_COMPLETED))
        while scheduler.has_ready():
            test_check(not scheduler.should_deliver(scheduler.pop_ready()))
        test_check(len(scheduler.scopes) == 1)
        test_check(scheduler.mounted_scope_count() == 1)
        test_check(len(scheduler.scope_bindings) == 1)
        test_check(len(scheduler.key_states) == 1)
        test_check(scheduler.is_current(live))
        test_check(not scheduler.should_deliver(old_result))
    test_check(scheduler.complete(live, TASK_COMPLETED))
    var live_result = scheduler.pop_ready()
    test_check(live_result.matches(live) and scheduler.should_deliver(live_result))
    test_check(scheduler.cancel_scope(survivor))
    test_check(len(scheduler.scopes) == 0)
    test_check(not scheduler.should_deliver(live_result))
    test_check(not scheduler.cancel_scope(survivor))
    test_check(len(scheduler.scope_bindings) == 0)
    for _ in range(1000):
        var scope = scheduler.mount_scope(42)
        test_check(scheduler.cancel_scope(scope))
        test_check(len(scheduler.scopes) == 0 and len(scheduler.scope_bindings) == 0)
        test_check(not scheduler.scope_for_owner(42).is_valid())
    print("PASS 1000 request scope lifetimes: bounded records, stale rejection, live sibling")
