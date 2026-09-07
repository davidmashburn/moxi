"""Repeatable workload for the shared collection interaction scenario."""

from moxi import (
    KEY_DOWN,
    Point,
    Rect,
    VirtualRecycler,
    canonical_scenarios,
    make_interaction_foundation_scenario,
)


def main():
    var registry = canonical_scenarios()
    var descriptor = registry.entry(registry.index_for_fixture("collection"))
    var item_count = descriptor.fixture_size
    var scenario = make_interaction_foundation_scenario()
    var recycler = VirtualRecycler(item_count, 24.0, 2, True)
    var passes = 100
    var geometry = scenario.scrollbar.geometry(Rect(0.0, 0.0, 12.0, 320.0))
    _ = scenario.reorder.set_threshold(4.0)
    var moved = 0
    for pass_index in range(passes):
        var index = pass_index % item_count
        _ = scenario.collection.select_index(index)
        _ = scenario.collection.handle_key(KEY_DOWN)
        var source_index = pass_index % 1000
        var destination_index = (pass_index * 13 + 7) % 1000
        var row_key = scenario.collection.key_at(source_index)
        scenario.reorder.reset()
        _ = scenario.reorder.begin(row_key, source_index, Point(0.0, 0.0), 1)
        _ = scenario.reorder.update(1, Point(8.0, 0.0))
        _ = scenario.reorder.set_destination(1, destination_index)
        var reorder_result = scenario.reorder.drop(1, destination_index)
        if reorder_result.changed:
            _ = scenario.collection.reorder(
                reorder_result.from_index,
                reorder_result.to_index,
            )
            moved += 1
        _ = scenario.scrollbar.set_offset(Float32(pass_index) * 48.0)
        geometry = scenario.scrollbar.geometry(Rect(0.0, 0.0, 12.0, 320.0))
        _ = recycler.update(
            scenario.scrollbar.offset,
            320.0,
            640.0,
        )
    print("Moxi interaction benchmark scenario: ", descriptor.fixture)
    print("Moxi interaction benchmark rows: ", scenario.collection.item_count())
    print("Moxi interaction benchmark passes: ", passes)
    print("Moxi interaction benchmark active slots: ", recycler.active_count())
    print("Moxi interaction benchmark slot pool: ", recycler.slot_count())
    print("Moxi interaction benchmark selected keys: ", scenario.collection.selected_count())
    print("Moxi interaction benchmark reorder commands: ", moved)
    print("Moxi interaction benchmark thumb extent: ", geometry.thumb.height)
    print("Moxi interaction benchmark timing: /usr/bin/time reports wall-clock process time")
