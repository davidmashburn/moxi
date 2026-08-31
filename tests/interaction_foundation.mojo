"""Contract tests for stable-key collections, scrollbars, and popups."""

from std.collections import List

from moxi import (
    CollectionSelection,
    CollectionColumn,
    COLUMN_SORT_ASCENDING,
    KEY_A,
    KEY_DOWN,
    KEY_ENTER,
    KEY_ESCAPE,
    MOD_COMMAND,
    make_interaction_foundation_scenario,
    Point,
    POPUP_COMBO,
    POPUP_DIALOG,
    POPUP_MENU,
    POPUP_PLACE_BELOW,
    PopupLayerState,
    Rect,
    SCROLLBAR_END,
    SCROLLBAR_HIT_THUMB,
    SCROLLBAR_PAGE_FORWARD,
    SCROLLBAR_VERTICAL,
    ScrollbarState,
    Size,
    TreeCollectionState,
    place_popup,
    test_check,
)


def main():
    var column = CollectionColumn(1, "Name", 240.0, 40.0, 200.0)
    test_check(column.width == 200.0)
    test_check(column.set_width(80.0))
    test_check(column.width == 80.0)
    test_check(column.set_sort(COLUMN_SORT_ASCENDING))

    var shared = make_interaction_foundation_scenario()
    test_check(shared.collection.item_count() == 10000)
    test_check(shared.collection.key_at(1) == 1003)
    test_check(shared.tree.selection.item_count() == 3)
    test_check(shared.scrollbar.can_scroll())
    test_check(shared.popups.top_kind() == POPUP_COMBO)

    var selection = CollectionSelection(5, True)
    test_check(selection.item_count() == 5)
    test_check(selection.focus_key == 0)
    test_check(selection.select_index(1))
    test_check(selection.select_index(3, True))
    test_check(selection.selected_count() == 3)
    test_check(selection.is_selected(1))
    test_check(selection.is_selected(2))
    test_check(selection.is_selected(3))
    test_check(selection.handle_key(KEY_A, MOD_COMMAND))
    test_check(selection.selected_count() == 5)

    var reordered = selection.reorder(0, 4)
    test_check(reordered.changed)
    test_check(reordered.key == 0)
    test_check(selection.key_at(4) == 0)
    test_check(selection.is_selected(0))

    var stable_keys = List[Int]()
    stable_keys.append(4)
    stable_keys.append(3)
    stable_keys.append(20)
    test_check(selection.set_keys(stable_keys))
    test_check(selection.focus_key == 3)
    test_check(selection.selected_count() == 2)
    test_check(selection.is_selected(3))
    test_check(selection.is_selected(4))

    var tree = TreeCollectionState()
    test_check(tree.add_node(10, -1, True))
    test_check(tree.add_node(20, 10))
    test_check(tree.add_node(30, 20))
    test_check(tree.add_node(40))
    test_check(tree.selection.item_count() == 3)
    test_check(tree.toggle_expanded(20))
    test_check(tree.selection.item_count() == 4)
    test_check(tree.select_key(30))
    test_check(tree.set_expanded(20, False))
    test_check(not tree.selection.is_selected(30))

    var scrollbar = ScrollbarState(SCROLLBAR_VERTICAL, 12.0)
    scrollbar.set_metrics(1000.0, 100.0)
    scrollbar.set_step(20.0)
    test_check(scrollbar.max_offset() == 900.0)
    _ = scrollbar.set_offset(450.0)
    var geometry = scrollbar.geometry(Rect(0.0, 0.0, 20.0, 100.0))
    test_check(geometry.visible)
    test_check(geometry.thumb.height == 12.0)
    test_check(scrollbar.hit_test(Rect(0.0, 0.0, 20.0, 100.0), Point(10.0, 50.0)) == SCROLLBAR_HIT_THUMB)
    test_check(scrollbar.apply_command(SCROLLBAR_END))
    test_check(scrollbar.offset == 900.0)
    _ = scrollbar.apply_command(SCROLLBAR_PAGE_FORWARD)
    test_check(scrollbar.offset == 900.0)

    var short_scroll = ScrollbarState()
    short_scroll.set_metrics(80.0, 100.0)
    test_check(not short_scroll.can_scroll())
    test_check(not short_scroll.geometry(Rect(0.0, 0.0, 10.0, 100.0)).visible)

    var viewport = Rect(0.0, 0.0, 100.0, 100.0)
    var popup_bounds = place_popup(
        Rect(90.0, 90.0, 20.0, 10.0),
        Size(50.0, 40.0),
        viewport,
        POPUP_PLACE_BELOW,
    )
    test_check(popup_bounds.x == 50.0)
    test_check(popup_bounds.y == 60.0)

    var popups = PopupLayerState()
    test_check(
        popups.open_root(
            100,
            POPUP_COMBO,
            7,
            Rect(10.0, 10.0, 20.0, 20.0),
            Rect(10.0, 30.0, 120.0, 80.0),
            POPUP_PLACE_BELOW,
            False,
            101,
            7,
        )
    )
    var combo_actions = List[Int]()
    combo_actions.append(500)
    combo_actions.append(500)
    combo_actions.append(501)
    test_check(popups.set_actions(100, combo_actions))
    test_check(popups.top_action_count() == 2)
    test_check(popups.highlighted_action() == 500)
    test_check(popups.handle_key(KEY_DOWN))
    test_check(popups.highlighted_action() == 501)

    test_check(
        popups.open(
            200,
            POPUP_MENU,
            100,
            Rect(20.0, 20.0, 10.0, 10.0),
            Rect(30.0, 20.0, 100.0, 80.0),
        )
    )
    test_check(popups.depth() == 2)
    test_check(not popups.dismiss_if_outside(Point(35.0, 25.0)))
    test_check(popups.dismiss_if_outside(Point(500.0, 500.0)))
    test_check(popups.depth() == 1)
    test_check(popups.open(200, POPUP_MENU, 100, Rect(20.0, 20.0, 10.0, 10.0), Rect(30.0, 20.0, 100.0, 80.0)))
    test_check(popups.depth() == 2)
    test_check(popups.handle_key(KEY_ESCAPE))
    test_check(popups.depth() == 1)
    test_check(popups.focus_target() == 101)
    test_check(popups.handle_key(KEY_ESCAPE))
    test_check(popups.depth() == 0)
    test_check(popups.restored_focus_target() == 7)

    test_check(
        popups.open_root(
            300,
            POPUP_DIALOG,
            7,
            Rect(0.0, 0.0, 0.0, 0.0),
            Rect(10.0, 10.0, 80.0, 80.0),
            POPUP_PLACE_BELOW,
            True,
            301,
            7,
        )
    )
    test_check(popups.traps_focus())
    test_check(popups.allows_focus(301))
    test_check(not popups.allows_focus(7))
    test_check(not popups.dismiss_if_outside(Point(0.0, 0.0)))
    var dialog_actions = List[Int]()
    dialog_actions.append(900)
    test_check(popups.set_actions(300, dialog_actions))
    test_check(popups.handle_key(KEY_ENTER))
    test_check(popups.depth() == 0)
    test_check(popups.restored_focus_target() == 7)

    print("Moxi interaction-foundation test passed")
