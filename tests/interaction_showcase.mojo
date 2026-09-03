"""Headless coverage for the live collection interaction showcase."""

from moxi import (
    ACTION_PRESS,
    ActionEvent,
    App,
    ClickEvent,
    COLUMN_SORT_DESCENDING,
    DRAG_BEGIN_KIND,
    DRAG_UPDATE_KIND,
    DROP_KIND,
    Event,
    INTERACTION_SHOWCASE_CANVAS_ID,
    INTERACTION_SHOWCASE_DIALOG_ID,
    INTERACTION_SHOWCASE_MENU_ID,
    INTERACTION_SHOWCASE_MOVE_ID,
    INTERACTION_SHOWCASE_SCROLL_FORWARD_ID,
    INTERACTION_SHOWCASE_SELECT_NEXT_ID,
    INTERACTION_SHOWCASE_SORT_ID,
    INTERACTION_SHOWCASE_TREE_ID,
    InteractionShowcaseState,
    KEY_ESCAPE,
    KeyEvent,
    POINTER_DOWN_KIND,
    POINTER_MOVE_KIND,
    POINTER_UP_KIND,
    Point,
    PointerEvent,
    Rect,
    ScrollEvent,
    test_check,
)


def action(target: Int) -> Event:
    var event = Event(ActionEvent(ACTION_PRESS))
    event.set_target(target)
    return event


def main():
    var component = InteractionShowcaseState()
    var view = component.build(Rect(0.0, 0.0, 760.0, 680.0))
    var canvas = view.bounds_for(INTERACTION_SHOWCASE_CANVAS_ID)
    test_check(view.is_valid())
    test_check(component.collection.item_count() == 10)
    test_check(len(component.columns) == 3)
    test_check(component.tree.selection.item_count() == 3)
    test_check(component.scrollbar.can_scroll())
    test_check(component.scene(canvas).count() > 20)

    test_check(component.update(action(INTERACTION_SHOWCASE_SELECT_NEXT_ID), view))
    test_check(component.collection.focus_index() == 2)
    test_check(component.update(action(INTERACTION_SHOWCASE_MOVE_ID), view))
    test_check(component.collection.key_at(4) == 114)
    test_check(component.update(action(INTERACTION_SHOWCASE_SORT_ID), view))
    test_check(component.columns[0].sort_order == COLUMN_SORT_DESCENDING)
    test_check(component.collection.key_at(7) == 114)
    test_check(component.update(action(INTERACTION_SHOWCASE_SCROLL_FORWARD_ID), view))
    test_check(component.scrollbar.offset == 32.0)
    test_check(component.update(action(INTERACTION_SHOWCASE_TREE_ID), view))
    test_check(not component.tree.is_expanded(10))

    test_check(component.update(action(INTERACTION_SHOWCASE_MENU_ID), view))
    test_check(component.popups.depth() == 2)
    test_check(component.update(Event(KeyEvent(KEY_ESCAPE)), view))
    test_check(component.popups.depth() == 1)
    test_check(component.update(Event(KeyEvent(KEY_ESCAPE)), view))
    test_check(component.popups.depth() == 0)

    test_check(component.update(action(INTERACTION_SHOWCASE_DIALOG_ID), view))
    test_check(component.popups.traps_focus())
    var dialog_offset = component.scrollbar.offset
    test_check(component.update(Event(ScrollEvent(
        Point(canvas.x + 40.0, canvas.y + 70.0),
        Point(0.0, 32.0),
    )), view))
    test_check(component.scrollbar.offset == dialog_offset)
    test_check(component.update(Event(KeyEvent(KEY_ESCAPE)), view))
    test_check(component.popups.depth() == 0)

    # The renderer-independent scrollbar policy also owns track clicks and
    # thumb drags when the scene is hosted by a real canvas node.
    component.reset()
    view = component.build(Rect(0.0, 0.0, 760.0, 680.0))
    canvas = view.bounds_for(INTERACTION_SHOWCASE_CANVAS_ID)
    var track_x = canvas.x + canvas.width - 232.0
    var thumb_down = Event(PointerEvent(
        POINTER_DOWN_KIND,
        Point(track_x + 5.0, canvas.y + 90.0),
        5,
        1,
    ))
    thumb_down.set_target(INTERACTION_SHOWCASE_CANVAS_ID)
    test_check(component.update(thumb_down, view))
    var thumb_move = Event(PointerEvent(
        POINTER_MOVE_KIND,
        Point(track_x + 5.0, canvas.y + 150.0),
        5,
        1,
    ))
    thumb_move.set_target(INTERACTION_SHOWCASE_CANVAS_ID)
    test_check(component.update(thumb_move, view))
    test_check(component.scrollbar.offset > 0.0)
    var thumb_up = Event(PointerEvent(
        POINTER_UP_KIND,
        Point(track_x + 5.0, canvas.y + 150.0),
        5,
        0,
    ))
    thumb_up.set_target(INTERACTION_SHOWCASE_CANVAS_ID)
    test_check(component.update(thumb_up, view))
    test_check(component.scrollbar_pointer_id == -1)

    component.reset()
    view = component.build(Rect(0.0, 0.0, 760.0, 680.0))
    canvas = view.bounds_for(INTERACTION_SHOWCASE_CANVAS_ID)
    var native_thumb_down = Event(PointerEvent(
        POINTER_DOWN_KIND,
        Point(track_x + 5.0, canvas.y + 90.0),
        7,
        1,
    ))
    native_thumb_down.set_target(INTERACTION_SHOWCASE_CANVAS_ID)
    test_check(component.update(native_thumb_down, view))
    var native_thumb_begin = Event(PointerEvent(
        DRAG_BEGIN_KIND,
        Point(track_x + 5.0, canvas.y + 90.0),
        7,
        1,
    ))
    native_thumb_begin.set_target(INTERACTION_SHOWCASE_CANVAS_ID)
    test_check(component.update(native_thumb_begin, view))
    var native_thumb_move = Event(PointerEvent(
        DRAG_UPDATE_KIND,
        Point(track_x + 5.0, canvas.y + 150.0),
        7,
        1,
    ))
    native_thumb_move.set_target(INTERACTION_SHOWCASE_CANVAS_ID)
    test_check(component.update(native_thumb_move, view))
    test_check(component.scrollbar.offset > 0.0)
    var native_thumb_drop = Event(PointerEvent(
        DROP_KIND,
        Point(track_x + 5.0, canvas.y + 150.0),
        7,
        0,
    ))
    native_thumb_drop.set_target(INTERACTION_SHOWCASE_CANVAS_ID)
    test_check(component.update(native_thumb_drop, view))
    test_check(component.scrollbar_pointer_id == -1)

    component.reset()
    view = component.build(Rect(0.0, 0.0, 760.0, 680.0))
    canvas = view.bounds_for(INTERACTION_SHOWCASE_CANVAS_ID)
    var track_click = Event(PointerEvent(
        POINTER_DOWN_KIND,
        Point(track_x + 5.0, canvas.y + 230.0),
        6,
        1,
    ))
    track_click.set_target(INTERACTION_SHOWCASE_CANVAS_ID)
    test_check(component.update(track_click, view))
    test_check(component.scrollbar.offset == component.scrollbar.max_offset())

    component.reset()
    view = component.build(Rect(0.0, 0.0, 760.0, 680.0))
    canvas = view.bounds_for(INTERACTION_SHOWCASE_CANVAS_ID)
    var wheel = Event(ScrollEvent(
        Point(canvas.x + 40.0, canvas.y + 70.0),
        Point(0.0, 32.0),
    ))
    test_check(component.update(wheel, view))
    test_check(component.scrollbar.offset == 32.0)

    # Tree rows and popup actions use the same canvas hit route as the table.
    component.reset()
    view = component.build(Rect(0.0, 0.0, 760.0, 680.0))
    canvas = view.bounds_for(INTERACTION_SHOWCASE_CANVAS_ID)
    var tree_click = Event(ClickEvent(
        Point(canvas.x + canvas.width - 180.0, canvas.y + 66.0)
    ))
    tree_click.set_target(INTERACTION_SHOWCASE_CANVAS_ID)
    test_check(component.update(tree_click, view))
    test_check(not component.tree.is_expanded(10))
    test_check(component.tree.selection.focus_key == 10)

    test_check(component.update(action(INTERACTION_SHOWCASE_MENU_ID), view))
    var popup = component.popups.top_bounds()
    var popup_click = Event(ClickEvent(
        Point(canvas.x + popup.x + 20.0, canvas.y + popup.y + 48.0)
    ))
    popup_click.set_target(INTERACTION_SHOWCASE_CANVAS_ID)
    test_check(component.update(popup_click, view))
    test_check(component.popups.depth() == 1)

    component.reset()
    view = component.build(Rect(0.0, 0.0, 760.0, 680.0))
    canvas = view.bounds_for(INTERACTION_SHOWCASE_CANVAS_ID)
    var down = Event(PointerEvent(
        POINTER_DOWN_KIND,
        Point(canvas.x + 30.0, canvas.y + 90.0),
        4,
        1,
    ))
    down.set_target(INTERACTION_SHOWCASE_CANVAS_ID)
    test_check(component.update(down, view))
    var move = Event(PointerEvent(
        POINTER_MOVE_KIND,
        Point(canvas.x + 30.0, canvas.y + 122.0),
        4,
        1,
    ))
    move.set_target(INTERACTION_SHOWCASE_CANVAS_ID)
    test_check(component.update(move, view))
    test_check(component.reorder.is_dragging())
    var up = Event(PointerEvent(
        POINTER_UP_KIND,
        Point(canvas.x + 30.0, canvas.y + 122.0),
        4,
        0,
    ))
    up.set_target(INTERACTION_SHOWCASE_CANVAS_ID)
    test_check(component.update(up, view))
    test_check(component.collection.key_at(2) == 107)

    component.reset()
    view = component.build(Rect(0.0, 0.0, 760.0, 680.0))
    canvas = view.bounds_for(INTERACTION_SHOWCASE_CANVAS_ID)
    var native_down = Event(PointerEvent(
        POINTER_DOWN_KIND,
        Point(canvas.x + 30.0, canvas.y + 90.0),
        8,
        1,
    ))
    native_down.set_target(INTERACTION_SHOWCASE_CANVAS_ID)
    test_check(component.update(native_down, view))
    var native_begin = Event(PointerEvent(
        DRAG_BEGIN_KIND,
        Point(canvas.x + 30.0, canvas.y + 90.0),
        8,
        1,
    ))
    native_begin.set_target(INTERACTION_SHOWCASE_CANVAS_ID)
    test_check(component.update(native_begin, view))
    var native_move = Event(PointerEvent(
        DRAG_UPDATE_KIND,
        Point(canvas.x + 30.0, canvas.y + 122.0),
        8,
        1,
    ))
    native_move.set_target(INTERACTION_SHOWCASE_CANVAS_ID)
    test_check(component.update(native_move, view))
    test_check(component.reorder.is_dragging())
    var native_drop = Event(PointerEvent(
        DROP_KIND,
        Point(canvas.x + 30.0, canvas.y + 122.0),
        8,
        0,
    ))
    native_drop.set_target(INTERACTION_SHOWCASE_CANVAS_ID)
    test_check(component.update(native_drop, view))
    test_check(component.collection.key_at(2) == 107)
    test_check(component.scene(canvas).count() > 20)

    # An open scene popup owns the pointer stream: clicking its modal outside
    # area must not move focus to the underlying canvas or leave it pressed.
    var popup_app = App[InteractionShowcaseState](
        InteractionShowcaseState(),
        Rect(0.0, 0.0, 760.0, 680.0),
    )
    var focus_before_popup = popup_app.focus_id()
    test_check(popup_app.dispatch(action(INTERACTION_SHOWCASE_DIALOG_ID)))
    var popup_canvas = popup_app.view.bounds_for(INTERACTION_SHOWCASE_CANVAS_ID)
    var outside_popup = Point(popup_canvas.x + 20.0, popup_canvas.y + 20.0)
    test_check(popup_app.dispatch(Event(PointerEvent(
        POINTER_DOWN_KIND,
        outside_popup,
        12,
        1,
    ))))
    test_check(popup_app.focus_id() == focus_before_popup)
    test_check(popup_app.dispatch(Event(PointerEvent(
        POINTER_UP_KIND,
        outside_popup,
        12,
        0,
    ))))
    test_check(popup_app.focus_id() == focus_before_popup)
    test_check(popup_app.pressed_id() == -1)
    test_check(popup_app.component.popups.is_open())
    test_check(popup_app.dispatch(Event(KeyEvent(KEY_ESCAPE))))
    test_check(not popup_app.component.popups.is_open())
    print("Moxi interaction-showcase test passed")
