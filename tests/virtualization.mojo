"""Stable-key recycling contract test."""

from moxi import VirtualRecycler, test_check


def main():
    var recycler = VirtualRecycler(10000, 20.0, 1, True)
    var first = recycler.update(0.0, 80.0, 300.0)
    test_check(first.start == 0)
    test_check(first.end == 6)
    test_check(recycler.active_count() == 6)
    test_check(recycler.slot_count() == 6)
    test_check(recycler.last_created_count == 6)
    var first_slot = recycler.slot_for_item(0)
    test_check(first_slot.key == 0)

    _ = recycler.update(100.0, 80.0, 300.0)
    test_check(recycler.slot_count() == 7)
    test_check(recycler.last_reused_count == 2)
    test_check(recycler.last_created_count == 1)
    test_check(recycler.last_recycled_count == 4)

    # Stable keys survive a logical reorder in the visible window.
    _ = recycler.set_key(5, 50000)
    _ = recycler.set_key(6, 60000)
    test_check(not recycler.set_key(7, 50000))
    _ = recycler.update(100.0, 80.0, 300.0)
    test_check(recycler.slot_for_item(5).key == 50000)
    test_check(recycler.slot_for_item(6).key == 60000)
    test_check(recycler.slot_count() == 7)

    _ = recycler.update(600.0, 80.0, 300.0)
    test_check(recycler.active_count() == 7)
    test_check(recycler.last_recycled_count > 0)
    test_check(recycler.last_released_count > 0)
    test_check(recycler.max_offset(80.0) == 199920.0)
    test_check(recycler.clamp_offset(300000.0, 80.0) == 199920.0)
    test_check(recycler.ensure_visible(9999, 80.0, 0.0) == 199920.0)
    print("Moxi virtualization test passed")
