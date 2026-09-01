"""Integration test for automatic portal scrolling and offset persistence."""

from moxi import (
    App,
    ColumnView,
    Component,
    Point,
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

    var app = App[ScrollState](ScrollState(), Rect(0.0, 0.0, 200.0, 100.0))
    var initial = app.view.scroll_offset_for(10)
    test_check(initial == 0.0)
    test_check(app.dispatch(Event(ScrollEvent(Point(10.0, 10.0), Point(0.0, 30.0)))))
    test_check(app.view.scroll_offset_for(10) > 0.0)
    test_check(app.view.scroll_offset_for(10) <= app.view.scroll_max_offset(10))
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
    print("Moxi scroll-app test passed")
