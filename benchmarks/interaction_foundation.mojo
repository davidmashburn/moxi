"""Repeatable workload for the shared collection interaction scenario."""

from moxi import (
    KEY_DOWN,
    Rect,
    VirtualRecycler,
    make_interaction_foundation_scenario,
)


def main():
    var scenario = make_interaction_foundation_scenario(10000)
    var recycler = VirtualRecycler(10000, 24.0, 2, True)
    var passes = 100
    var geometry = scenario.scrollbar.geometry(Rect(0.0, 0.0, 12.0, 320.0))
    for pass_index in range(passes):
        var index = pass_index % 10000
        _ = scenario.collection.select_index(index)
        _ = scenario.collection.handle_key(KEY_DOWN)
        _ = scenario.scrollbar.set_offset(Float32(pass_index) * 48.0)
        geometry = scenario.scrollbar.geometry(Rect(0.0, 0.0, 12.0, 320.0))
        _ = recycler.update(
            scenario.scrollbar.offset,
            320.0,
            640.0,
        )
    print("Moxi interaction benchmark rows: ", scenario.collection.item_count())
    print("Moxi interaction benchmark passes: ", passes)
    print("Moxi interaction benchmark active slots: ", recycler.active_count())
    print("Moxi interaction benchmark slot pool: ", recycler.slot_count())
    print("Moxi interaction benchmark selected keys: ", scenario.collection.selected_count())
    print("Moxi interaction benchmark thumb extent: ", geometry.thumb.height)
    print("Moxi interaction benchmark timing: /usr/bin/time reports wall-clock process time")
