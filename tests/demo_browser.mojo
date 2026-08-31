"""Headless contract test for the wxPython-style demo browser."""

from moxi import (
    ACTION_PRESS,
    App,
    DEMO_CATEGORY_ALL,
    DEMO_CATEGORY_BUTTON_BASE,
    DEMO_CATEGORY_PLOTTING,
    DEMO_COUNTER_ID,
    DEMO_COUNTER_ID_OFFSET,
    DEMO_ENTRY_VIEW_BASE,
    DEMO_PLOT_ID,
    DEMO_PLOT_GALLERY_ID,
    DEMO_PLOT_SVG_ID,
    DEMO_RUN_BUTTON_ID,
    DEMO_SEARCH_ID,
    DEMO_SOURCE_TEXT_ID,
    DEMO_TAB_DEMO,
    DEMO_TAB_DEMO_ID,
    DEMO_TAB_SOURCE,
    DEMO_TAB_SOURCE_ID,
    DEMO_WX_STYLE_ID,
    DEMO_WX_STYLE_ID_OFFSET,
    WX_TITLE_ID,
    DemoBrowserState,
    DemoCatalog,
    Event,
    PointerEvent,
    POINTER_DOWN_KIND,
    POINTER_UP_KIND,
    Point,
    Rect,
    TextInputEvent,
    ActionEvent,
    test_check,
)


def action(target: Int) -> Event:
    var event = Event(ActionEvent(ACTION_PRESS))
    event.set_target(target)
    return event


def main() raises:
    var catalog = DemoCatalog()
    test_check(catalog.count() == 18)
    test_check(catalog.visible_count("plot", DEMO_CATEGORY_ALL) == 3)
    test_check(catalog.visible_count("PLOT", DEMO_CATEGORY_ALL) == 3)
    test_check(catalog.visible_count("", DEMO_CATEGORY_PLOTTING) == 3)
    test_check(catalog.entry(0).source == "examples/hello_window.mojo")
    test_check(catalog.entry(11).id == DEMO_PLOT_ID)

    var app = App[DemoBrowserState](
        DemoBrowserState(),
        Rect(0.0, 0.0, 1180.0, 760.0),
    )
    test_check(app.view.is_valid())
    test_check(app.view.bounds_for(DEMO_SEARCH_ID).width > 0.0)
    test_check(app.view.bounds_for(DEMO_ENTRY_VIEW_BASE + DEMO_COUNTER_ID).width > 0.0)
    test_check(app.accessibility().count() > 12)

    test_check(app.dispatch(action(DEMO_RUN_BUTTON_ID)))
    test_check(app.component.tab == DEMO_TAB_DEMO)
    test_check(app.component.take_pending_task() == "hello-window-demo")
    test_check(app.component.take_pending_task().count_codepoints() == 0)

    test_check(app.dispatch(action(DEMO_ENTRY_VIEW_BASE + DEMO_WX_STYLE_ID)))
    test_check(app.dispatch(action(DEMO_TAB_DEMO_ID)))
    test_check(app.view.bounds_for(DEMO_WX_STYLE_ID_OFFSET + WX_TITLE_ID).width > 0.0)
    test_check(app.dispatch(action(DEMO_ENTRY_VIEW_BASE + DEMO_COUNTER_ID)))
    test_check(app.component.selected_id == DEMO_COUNTER_ID)
    test_check(app.component.tab == 0)
    test_check(app.dispatch(action(DEMO_TAB_DEMO_ID)))
    test_check(app.component.tab == DEMO_TAB_DEMO)
    var increment = app.view.bounds_for(DEMO_COUNTER_ID_OFFSET + 3)
    test_check(increment.width > 0.0)
    var increment_point = Point(increment.x + 1.0, increment.y + 1.0)
    test_check(app.dispatch(Event(PointerEvent(POINTER_DOWN_KIND, increment_point))))
    test_check(app.dispatch(Event(PointerEvent(POINTER_UP_KIND, increment_point))))
    test_check(app.component.counter.component.count == 1)

    test_check(app.dispatch(action(DEMO_TAB_SOURCE_ID)))
    test_check(app.component.tab == DEMO_TAB_SOURCE)
    test_check(app.view.bounds_for(DEMO_SOURCE_TEXT_ID).height > 0.0)

    # The search field is the first focusable control, so committed text is
    # routed through the same focus path used by the native AppKit window.
    test_check(app.dispatch(Event(TextInputEvent("plot"))))
    test_check(app.component.search.text == "plot")
    test_check(app.component.visible_count() == 3)
    test_check(app.component.selected_id == DEMO_PLOT_ID)
    test_check(app.view.bounds_for(DEMO_ENTRY_VIEW_BASE + DEMO_PLOT_ID).width > 0.0)
    test_check(app.view.bounds_for(DEMO_ENTRY_VIEW_BASE + DEMO_PLOT_GALLERY_ID).width > 0.0)
    test_check(app.view.bounds_for(DEMO_ENTRY_VIEW_BASE + DEMO_PLOT_SVG_ID).width > 0.0)
    test_check(app.dispatch(action(DEMO_CATEGORY_BUTTON_BASE + DEMO_CATEGORY_PLOTTING)))
    test_check(app.component.category == DEMO_CATEGORY_PLOTTING)
    print("Moxi demo-browser test passed")
