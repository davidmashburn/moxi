"""Contract tests for the stable-key reorder gesture lifecycle."""

from moxi import (
    CollectionSelection,
    KEY_ESCAPE,
    KeyEvent,
    Point,
    POINTER_CANCEL_KIND,
    POINTER_DOWN_KIND,
    POINTER_MOVE_KIND,
    POINTER_UP_KIND,
    REORDER_ARMED,
    REORDER_CANCELLED,
    REORDER_DRAGGING,
    REORDER_DROPPED,
    ReorderInteraction,
    test_check,
    PointerEvent,
)


def main():
    var selection = CollectionSelection(6, True)
    _ = selection.select_index(2)
    var interaction = ReorderInteraction(6.0, selection.item_count())

    test_check(not interaction.begin(-1, 2, Point(10.0, 10.0), 7))
    test_check(interaction.begin(2, 2, Point(10.0, 10.0), 7))
    test_check(interaction.phase == REORDER_ARMED)
    test_check(not interaction.update(8, Point(40.0, 10.0)))
    test_check(not interaction.update(7, Point(13.0, 14.0)))
    test_check(interaction.is_armed())
    test_check(interaction.update(7, Point(16.0, 10.0)))
    test_check(interaction.phase == REORDER_DRAGGING)
    test_check(not interaction.set_destination(8, 4))
    test_check(interaction.set_destination(7, 4))
    test_check(not interaction.set_destination(7, 4))

    var wrong_drop = interaction.drop(8, 4)
    test_check(not wrong_drop.changed)
    test_check(interaction.is_dragging())
    var result = interaction.drop(7, 4)
    test_check(result.changed)
    test_check(result.key == 2)
    test_check(result.from_index == 2)
    test_check(result.to_index == 4)
    test_check(interaction.phase == REORDER_DROPPED)
    var applied = selection.reorder(result.from_index, result.to_index)
    test_check(applied.changed)
    test_check(selection.key_at(4) == 2)
    test_check(selection.is_selected(2))
    test_check(not interaction.begin(2, 4, Point(0.0, 0.0), 7))

    interaction.reset()
    test_check(interaction.phase == 0)
    test_check(interaction.begin(2, 4, Point(0.0, 0.0), 7))
    test_check(not interaction.update(7, Point(1.0, 1.0)))
    var click_result = interaction.drop(7, 1)
    test_check(not click_result.changed)
    test_check(interaction.is_dropped())
    test_check(selection.key_at(4) == 2)

    interaction.reset()
    test_check(interaction.begin(2, 4, Point(0.0, 0.0), 7))
    test_check(interaction.update(7, Point(10.0, 0.0)))
    var invalid_result = interaction.drop(7, 99)
    test_check(not invalid_result.changed)
    test_check(interaction.phase == REORDER_CANCELLED)
    test_check(selection.key_at(4) == 2)

    interaction.reset()
    test_check(interaction.begin(2, 4, Point(0.0, 0.0), 7))
    test_check(not interaction.cancel_pointer(8))
    test_check(interaction.handle_key(KeyEvent(KEY_ESCAPE)))
    test_check(interaction.phase == REORDER_CANCELLED)
    test_check(not interaction.cancel())
    test_check(not interaction.drop(7, 1).changed)

    interaction.reset()
    var down = PointerEvent(
        POINTER_DOWN_KIND,
        Point(2.0, 2.0),
        9,
        1,
    )
    test_check(interaction.begin_event(2, 4, down))
    var cancel = PointerEvent(
        POINTER_CANCEL_KIND,
        Point(2.0, 2.0),
        8,
        0,
    )
    test_check(not interaction.cancel_event(cancel))
    var move = PointerEvent(
        POINTER_MOVE_KIND,
        Point(10.0, 2.0),
        9,
        1,
    )
    test_check(interaction.update_event(move))
    cancel.pointer_id = 9
    test_check(interaction.cancel_event(cancel))
    test_check(interaction.is_cancelled())
    interaction.reset()
    test_check(interaction.begin_event(2, 4, down))
    test_check(interaction.update_event(move))
    var up = PointerEvent(
        POINTER_UP_KIND,
        Point(10.0, 2.0),
        9,
        0,
    )
    test_check(interaction.drop_event(up, 0).changed)

    print("Moxi reorder-interaction test passed")
