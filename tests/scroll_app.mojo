"""Integration test for automatic portal scrolling and offset persistence."""

from moxi import (
    App,
    CLICK_KIND,
    ColumnView,
    Component,
    DRAG_BEGIN_KIND,
    DRAG_UPDATE_KIND,
    DROP_KIND,
    Point,
    PointerEvent,
    POINTER_DOWN_KIND,
    POINTER_MOVE_KIND,
    POINTER_UP_KIND,
    Rect,
    ScrollEvent,
    Event,
    ROOT_SCROLL_ID,
    SCROLLBAR_HORIZONTAL,
    SCROLL_KIND,
    SCROLLBAR_KIND,
    scene_from_paint,
    test_check,
)


struct RootOverflowState(Component):
    """A component whose ordinary root content needs the implicit viewport."""

    def __init__(out self):
        pass

    def build(self, bounds: Rect) -> ColumnView:
        var view = ColumnView(bounds, 0.0, 0.0)
        view.add_label(1, "one", 30.0)
        view.add_label(2, "two", 30.0)
        view.add_label(3, "three", 30.0)
        view.add_label(4, "four", 30.0)
        view.layout()
        return view^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        return False


struct OverlayScrollState(Component):
    """A control beneath a root scrollbar verifies overlay hit priority."""

    var clicks: Int

    def __init__(out self):
        self.clicks = 0

    def build(self, bounds: Rect) -> ColumnView:
        var view = ColumnView(bounds, 0.0, 0.0)
        view.add_button(1, "under the scrollbar", 30.0)
        view.add_label(2, "two", 30.0)
        view.add_label(3, "three", 30.0)
        view.add_label(4, "four", 30.0)
        view.layout()
        return view^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        if event.kind == CLICK_KIND and event.target == 1:
            self.clicks += 1
            return True
        return False


struct SlotOverflowState(Component):
    """A component slot whose allocated box is smaller than its contents."""

    def __init__(out self):
        pass

    def build(self, bounds: Rect) -> ColumnView:
        var child = ColumnView(Rect(0.0, 0.0, bounds.width, 90.0), 0.0, 0.0)
        child.add_label(1, "one", 30.0)
        child.add_label(2, "two", 30.0)
        child.add_label(3, "three", 30.0)
        child.layout()

        var view = ColumnView(bounds, 0.0, 0.0)
        view.add_component_view_to(-1, 10, child, 100, 40.0)
        view.layout()
        return view^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        return False


struct RowOverflowState(Component):
    """A horizontal root verifies the matching x-axis wheel delta path."""

    def __init__(out self):
        pass

    def build(self, bounds: Rect) -> ColumnView:
        var view = ColumnView(bounds, 0.0, 0.0)
        view.set_row_layout()
        view.add_label(1, "one", 30.0)
        view.add_label(2, "two", 30.0)
        view.add_label(3, "three", 30.0)
        view.set_fixed_width(1, 80.0)
        view.set_fixed_width(2, 80.0)
        view.set_fixed_width(3, 80.0)
        view.layout()
        return view^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        return False


struct ScrollState(Component):
    def __init__(out self):
        pass

    def build(self, bounds: Rect) -> ColumnView:
        var view = ColumnView(bounds, 0.0, 0.0)
        var portal = view.add_portal(10, 40.0, 0.0, 0.0)
        view.add_label_to(portal, 11, "one", 20.0)
        view.add_label_to(portal, 12, "two", 20.0)
        view.add_label_to(portal, 13, "three", 20.0)
        view.add_label_to(portal, 14, "four", 20.0)
        view.layout()
        return view^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        return False


struct NestedScrollState(Component):
    """A nested portal whose inner content extends beyond an outer clip."""

    def __init__(out self):
        pass

    def build(self, bounds: Rect) -> ColumnView:
        var view = ColumnView(bounds, 0.0, 0.0)
        var outer = view.add_portal(10, 40.0, 0.0, 0.0)
        var inner = view.add_portal_to(outer, 20, 80.0, 0.0, 0.0)
        view.add_label_to(inner, 21, "one", 30.0)
        view.add_label_to(inner, 22, "two", 30.0)
        view.add_label_to(inner, 23, "three", 30.0)
        view.add_label_to(inner, 24, "four", 30.0)
        view.layout()
        return view^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        return False


def main():
    var root_app = App[RootOverflowState](
        RootOverflowState(),
        Rect(0.0, 0.0, 200.0, 70.0),
    )
    test_check(root_app.view.scroll_max_offset(ROOT_SCROLL_ID) > 0.0)
    test_check(
        root_app.dispatch(
            Event(ScrollEvent(Point(10.0, 10.0), Point(0.0, 30.0)))
        )
    )
    test_check(root_app.view.scroll_offset_for(ROOT_SCROLL_ID) > 0.0)
    root_app.rebuild()
    test_check(root_app.view.scroll_offset_for(ROOT_SCROLL_ID) > 0.0)
    var root_commands = root_app.paint()
    var root_scrollbar_count = 0
    for index in range(root_commands.count()):
        var command = root_commands.command(index)
        if command.kind == SCROLLBAR_KIND:
            root_scrollbar_count += 1
            test_check(command.id == ROOT_SCROLL_ID)
            test_check(command.scrollbar_visible)
    test_check(root_scrollbar_count == 1)

    # A painted scrollbar is an overlay. Pointer hover and click must not
    # leak through to a full-width control laid out underneath its track.
    var overlay_app = App[OverlayScrollState](
        OverlayScrollState(),
        Rect(0.0, 0.0, 200.0, 70.0),
    )
    var under_button = overlay_app.view.bounds_for(1)
    var under_point = Point(under_button.x + 20.0, under_button.y + 10.0)
    test_check(overlay_app.dispatch(Event(PointerEvent(
        POINTER_DOWN_KIND,
        under_point,
    ))))
    test_check(overlay_app.dispatch(Event(PointerEvent(
        POINTER_UP_KIND,
        under_point,
    ))))
    test_check(overlay_app.component.clicks == 1)
    var overlay_track_point = Point(190.0, 20.0)
    test_check(overlay_app.dispatch(Event(PointerEvent(
        POINTER_MOVE_KIND,
        overlay_track_point,
    ))))
    test_check(overlay_app.hover_id() == -1)
    test_check(overlay_app.dispatch(Event(PointerEvent(
        POINTER_DOWN_KIND,
        overlay_track_point,
    ))))
    test_check(overlay_app.dispatch(Event(PointerEvent(
        POINTER_UP_KIND,
        overlay_track_point,
    ))))
    test_check(overlay_app.component.clicks == 1)

    var slot_app = App[SlotOverflowState](
        SlotOverflowState(),
        Rect(0.0, 0.0, 200.0, 100.0),
    )
    test_check(slot_app.view.scroll_max_offset(10) > 0.0)
    test_check(
        slot_app.dispatch(
            Event(ScrollEvent(Point(10.0, 10.0), Point(0.0, 30.0)))
        )
    )
    test_check(slot_app.view.scroll_offset_for(10) > 0.0)
    var slot_commands = slot_app.paint()
    var slot_scrollbar_count = 0
    for index in range(slot_commands.count()):
        var command = slot_commands.command(index)
        if command.kind == SCROLLBAR_KIND:
            slot_scrollbar_count += 1
            test_check(command.id == 10)
    test_check(slot_scrollbar_count == 1)

    var row_app = App[RowOverflowState](
        RowOverflowState(),
        Rect(0.0, 0.0, 100.0, 70.0),
    )
    test_check(row_app.view.scroll_max_offset(ROOT_SCROLL_ID) > 0.0)
    test_check(
        row_app.dispatch(
            Event(ScrollEvent(Point(10.0, 10.0), Point(30.0, 0.0)))
        )
    )
    test_check(row_app.view.scroll_offset_for(ROOT_SCROLL_ID) > 0.0)
    var row_commands = row_app.paint()
    var row_scrollbar_count = 0
    for index in range(row_commands.count()):
        var command = row_commands.command(index)
        if command.kind == SCROLLBAR_KIND:
            row_scrollbar_count += 1
            test_check(command.scrollbar_orientation == SCROLLBAR_HORIZONTAL)
    test_check(row_scrollbar_count == 1)

    var row_scrollbar_app = App[RowOverflowState](
        RowOverflowState(),
        Rect(0.0, 0.0, 100.0, 70.0),
    )
    var row_track = Rect(4.0, 58.0, 92.0, 8.0)
    var row_thumb = row_scrollbar_app.scrollbar_state_for(ROOT_SCROLL_ID).geometry(row_track)
    var row_thumb_point = Point(row_thumb.thumb.x + 2.0, row_thumb.thumb.y + 4.0)
    test_check(row_scrollbar_app.dispatch(Event(PointerEvent(
        POINTER_DOWN_KIND,
        row_thumb_point,
        4,
        1,
    ))))
    test_check(row_scrollbar_app.dispatch(Event(PointerEvent(
        DRAG_BEGIN_KIND,
        row_thumb_point,
        4,
        1,
    ))))
    test_check(row_scrollbar_app.dispatch(Event(PointerEvent(
        DRAG_UPDATE_KIND,
        Point(row_track.x + row_track.width - 2.0, row_thumb_point.y),
        4,
        1,
    ))))
    test_check(row_scrollbar_app.view.scroll_offset_for(ROOT_SCROLL_ID) > 0.0)
    test_check(row_scrollbar_app.dispatch(Event(PointerEvent(
        DROP_KIND,
        Point(row_track.x + row_track.width - 2.0, row_thumb_point.y),
        4,
        0,
    ))))

    var app = App[ScrollState](ScrollState(), Rect(0.0, 0.0, 200.0, 100.0))
    var initial = app.view.scroll_offset_for(10)
    test_check(initial == 0.0)
    test_check(app.dispatch(Event(ScrollEvent(Point(10.0, 10.0), Point(0.0, 30.0)))))
    test_check(app.view.scroll_offset_for(10) > 0.0)
    test_check(app.view.scroll_offset_for(10) <= app.view.scroll_max_offset(10))
    var portal_bounds = app.view.bounds_for(10)
    var portal_track = Rect(
        portal_bounds.x + portal_bounds.width - 12.0,
        portal_bounds.y + 4.0,
        8.0,
        portal_bounds.height - 8.0,
    )
    var portal_track_app = App[ScrollState](
        ScrollState(),
        Rect(0.0, 0.0, 200.0, 100.0),
    )
    var thumb = portal_track_app.scrollbar_state_for(10).geometry(portal_track)
    var thumb_point = Point(thumb.thumb.x + 4.0, thumb.thumb.y + 2.0)
    var down_changed = portal_track_app.dispatch(Event(PointerEvent(
        POINTER_DOWN_KIND,
        thumb_point,
        3,
        1,
    )))
    test_check(down_changed)
    var begin_changed = portal_track_app.dispatch(Event(PointerEvent(
        DRAG_BEGIN_KIND,
        thumb_point,
        3,
        1,
    )))
    test_check(begin_changed)
    var move_changed = portal_track_app.dispatch(Event(PointerEvent(
        DRAG_UPDATE_KIND,
        Point(thumb_point.x, portal_track.y + portal_track.height - 2.0),
        3,
        1,
    )))
    test_check(move_changed)
    test_check(portal_track_app.view.scroll_offset_for(10) > 0.0)
    var drop_changed = portal_track_app.dispatch(Event(PointerEvent(
        DROP_KIND,
        Point(thumb_point.x, portal_track.y + portal_track.height - 2.0),
        3,
        0,
    )))
    test_check(drop_changed)
    var track_click_app = App[ScrollState](
        ScrollState(),
        Rect(0.0, 0.0, 200.0, 100.0),
    )
    var track_click_point = Point(
        portal_track.x + 4.0,
        portal_track.y + portal_track.height - 2.0,
    )
    var track_down_changed = track_click_app.dispatch(Event(PointerEvent(
        POINTER_DOWN_KIND,
        track_click_point,
    )))
    test_check(track_down_changed)
    test_check(
        track_click_app.view.scroll_offset_for(10)
        == track_click_app.view.scroll_max_offset(10)
    )
    _ = track_click_app.dispatch(Event(PointerEvent(
        POINTER_UP_KIND,
        track_click_point,
    )))
    var commands = app.paint()
    var scrollbar_count = 0
    for index in range(commands.count()):
        var command = commands.command(index)
        if command.kind == SCROLLBAR_KIND:
            scrollbar_count += 1
            test_check(command.scrollbar_visible)
            test_check(command.scrollbar_thumb.height < command.bounds.height)
            test_check(command.scrollbar_thumb.y > command.bounds.y)
    test_check(scrollbar_count == 1)
    test_check(scene_from_paint(commands).count() == commands.count() + 1)
    test_check(app.dispatch(Event(ScrollEvent(Point(10.0, 10.0), Point(0.0, -1000.0)))))
    test_check(app.view.scroll_offset_for(10) == 0.0)

    # A nested portal may lay out content beyond its clipped parent. Wheel
    # input in that invisible portion must not scroll the hidden child.
    var nested_app = App[NestedScrollState](
        NestedScrollState(),
        Rect(0.0, 0.0, 220.0, 120.0),
    )
    test_check(nested_app.view.scroll_max_offset(20) > 0.0)
    test_check(not nested_app.dispatch(Event(ScrollEvent(
        Point(12.0, 60.0),
        Point(0.0, 30.0),
    ))))
    test_check(nested_app.view.scroll_offset_for(20) == 0.0)
    test_check(nested_app.dispatch(Event(ScrollEvent(
        Point(12.0, 20.0),
        Point(0.0, 30.0),
    ))))
    test_check(nested_app.view.scroll_offset_for(20) > 0.0)
    print("Moxi scroll-app test passed")
