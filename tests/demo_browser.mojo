"""Headless contract test for the wxPython-style demo browser."""

from moxi import (
    ACTION_PRESS,
    App,
    DEMO_CATEGORY_ALL,
    DEMO_CATEGORY_BUTTON_BASE,
    DEMO_CATEGORY_PLOTTING,
    DEMO_COUNTER_ID,
    DEMO_COUNTER_ID_OFFSET,
    DEMO_CLEAR_SEARCH_ID,
    DEMO_ENTRY_VIEW_BASE,
    DEMO_EMPTY_CLEAR_ID,
    DEMO_FRACTAL_ID,
    DEMO_HEADER_KICKER_ID,
    DEMO_INTERACTION_ID,
    DEMO_INTERACTION_ID_OFFSET,
    DEMO_LIVE_SCRIPT_ID,
    DEMO_LIVE_SCRIPT_ID_OFFSET,
    DEMO_PAGE_QUICKSTART_ID,
    DEMO_PLOT_ID,
    DEMO_PLOT_GALLERY_ID,
    DEMO_PLOT_SVG_ID,
    DEMO_RUN_BUTTON_ID,
    DEMO_SEARCH_ID,
    DEMO_SHOWCASE_ID_OFFSET,
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
    KEY_ESCAPE,
    KeyEvent,
    PointerEvent,
    POINTER_DOWN_KIND,
    POINTER_MOVE_KIND,
    POINTER_UP_KIND,
    Point,
    Rect,
    SHOWCASE_CANVAS_ID,
    SHOWCASE_PLOT,
    LIVE_SCRIPT_CANVAS_ID,
    INTERACTION_SHOWCASE_CANVAS_ID,
    INTERACTION_SHOWCASE_DIALOG_ID,
    INTERACTION_SHOWCASE_MENU_ID,
    INTERACTION_SHOWCASE_MOVE_ID,
    INTERACTION_SHOWCASE_RESET_ID,
    INTERACTION_SHOWCASE_SELECT_NEXT_ID,
    INTERACTION_SHOWCASE_SORT_ID,
    INTERACTION_SHOWCASE_TREE_ID,
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
    test_check(catalog.count() == 21)
    test_check(catalog.visible_count("plot", DEMO_CATEGORY_ALL) == 4)
    test_check(catalog.visible_count("PLOT", DEMO_CATEGORY_ALL) == 4)
    test_check(catalog.visible_count("", DEMO_CATEGORY_PLOTTING) == 4)
    test_check(catalog.entry(0).source == "examples/hello_window.mojo")
    var plot_index = catalog.index_for_id(DEMO_PLOT_ID)
    test_check(plot_index >= 0)
    test_check(catalog.entry(plot_index).id == DEMO_PLOT_ID)
    test_check(catalog.index_for_id(DEMO_INTERACTION_ID) >= 0)

    var app = App[DemoBrowserState](
        DemoBrowserState(),
        Rect(0.0, 0.0, 1180.0, 760.0),
    )
    test_check(app.view.is_valid())
    test_check(app.view.has_panel)
    test_check(app.view.panel.style.corner_radius == 18.0)
    test_check(app.view.bounds_for(DEMO_SEARCH_ID).width > 0.0)
    test_check(app.view.bounds_for(DEMO_ENTRY_VIEW_BASE + DEMO_COUNTER_ID).width > 0.0)
    test_check(app.view.bounds_for(DEMO_CLEAR_SEARCH_ID).width > 0.0)
    test_check(app.view.bounds_for(DEMO_HEADER_KICKER_ID).height > 0.0)
    test_check(app.view.bounds_for(DEMO_PAGE_QUICKSTART_ID).height > 0.0)
    test_check(app.accessibility().count() > 12)

    test_check(app.dispatch(action(DEMO_RUN_BUTTON_ID)))
    test_check(app.component.tab == DEMO_TAB_DEMO)
    test_check(app.component.take_pending_task().count_codepoints() == 0)

    # The editable page is a normal component shell with a live module canvas.
    test_check(app.dispatch(action(DEMO_ENTRY_VIEW_BASE + DEMO_LIVE_SCRIPT_ID)))
    test_check(app.dispatch(action(DEMO_TAB_DEMO_ID)))
    test_check(app.component.has_live_script())
    test_check(
        app.view.bounds_for(
            DEMO_LIVE_SCRIPT_ID_OFFSET + LIVE_SCRIPT_CANVAS_ID
        ).width > 0.0
    )

    # Plot pages are real component-owned canvases, not static preview cards.
    test_check(app.dispatch(action(DEMO_ENTRY_VIEW_BASE + DEMO_PLOT_ID)))
    test_check(app.dispatch(action(DEMO_TAB_DEMO_ID)))
    test_check(app.component.showcase.component.mode == SHOWCASE_PLOT)
    test_check(
        app.view.bounds_for(
            DEMO_SHOWCASE_ID_OFFSET + SHOWCASE_CANVAS_ID
        ).width > 0.0
    )
    test_check(app.component.selected_scene(app.view).count() > 0)

    # The interaction lab mounts as a real child component and exposes the
    # state/scene primitives through the same browser route as every other
    # in-process example.
    test_check(app.dispatch(action(DEMO_ENTRY_VIEW_BASE + DEMO_INTERACTION_ID)))
    test_check(app.dispatch(action(DEMO_TAB_DEMO_ID)))
    var interaction_canvas = app.view.bounds_for(
        DEMO_INTERACTION_ID_OFFSET + INTERACTION_SHOWCASE_CANVAS_ID
    )
    test_check(interaction_canvas.width > 0.0)
    test_check(app.component.selected_scene(app.view).count() > 20)
    test_check(
        app.dispatch(
            action(
                DEMO_INTERACTION_ID_OFFSET + INTERACTION_SHOWCASE_SELECT_NEXT_ID
            )
        )
    )
    test_check(
        app.component.interaction.component.collection.focus_index() == 2
    )
    test_check(
        app.dispatch(
            action(DEMO_INTERACTION_ID_OFFSET + INTERACTION_SHOWCASE_MOVE_ID)
        )
    )
    test_check(app.component.interaction.component.collection.key_at(4) == 114)
    test_check(
        app.dispatch(
            action(DEMO_INTERACTION_ID_OFFSET + INTERACTION_SHOWCASE_SORT_ID)
        )
    )
    test_check(app.component.interaction.component.collection.key_at(7) == 114)
    test_check(
        app.dispatch(
            action(DEMO_INTERACTION_ID_OFFSET + INTERACTION_SHOWCASE_TREE_ID)
        )
    )
    test_check(
        not app.component.interaction.component.tree.is_expanded(10)
    )
    test_check(
        app.dispatch(
            action(DEMO_INTERACTION_ID_OFFSET + INTERACTION_SHOWCASE_MENU_ID)
        )
    )
    test_check(app.component.interaction.component.popups.depth() == 2)
    test_check(app.dispatch(Event(KeyEvent(KEY_ESCAPE))))
    test_check(app.component.interaction.component.popups.depth() == 1)
    test_check(app.dispatch(Event(KeyEvent(KEY_ESCAPE))))
    test_check(app.component.interaction.component.popups.depth() == 0)
    test_check(
        app.dispatch(
            action(DEMO_INTERACTION_ID_OFFSET + INTERACTION_SHOWCASE_DIALOG_ID)
        )
    )
    test_check(app.component.interaction.component.popups.traps_focus())
    test_check(app.dispatch(Event(KeyEvent(KEY_ESCAPE))))
    test_check(app.component.interaction.component.popups.depth() == 0)

    # Pointer routing reaches the canvas, where the state machine owns the
    # gesture and applies the resulting stable-key command to the collection.
    test_check(
        app.dispatch(
            action(
                DEMO_INTERACTION_ID_OFFSET + INTERACTION_SHOWCASE_RESET_ID
            )
        )
    )
    interaction_canvas = app.view.bounds_for(
        DEMO_INTERACTION_ID_OFFSET + INTERACTION_SHOWCASE_CANVAS_ID
    )
    var down_point = Point(
        interaction_canvas.x + 30.0,
        interaction_canvas.y + 16.0 + 34.0 + 32.0 + 10.0,
    )
    var down = Event(PointerEvent(POINTER_DOWN_KIND, down_point, 4, 1))
    test_check(app.dispatch(down))
    var move_point = Point(
        interaction_canvas.x + 30.0,
        interaction_canvas.y + 16.0 + 34.0 + 64.0 + 10.0,
    )
    var move = Event(PointerEvent(POINTER_MOVE_KIND, move_point, 4, 1))
    test_check(app.dispatch(move))
    var up = Event(PointerEvent(POINTER_UP_KIND, move_point, 4, 0))
    test_check(app.dispatch(up))
    test_check(app.component.interaction.component.collection.key_at(2) == 107)

    # The line-fractal page is embedded through the same Component contract.
    test_check(app.dispatch(action(DEMO_ENTRY_VIEW_BASE + DEMO_FRACTAL_ID)))
    test_check(app.dispatch(action(DEMO_TAB_DEMO_ID)))
    test_check(app.component.selected_scene(app.view).count() > 0)

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
    test_check(app.component.visible_count() == 4)
    test_check(app.component.selected_id == DEMO_PLOT_ID)
    test_check(app.view.bounds_for(DEMO_ENTRY_VIEW_BASE + DEMO_PLOT_ID).width > 0.0)
    test_check(app.view.bounds_for(DEMO_ENTRY_VIEW_BASE + DEMO_PLOT_GALLERY_ID).width > 0.0)
    test_check(app.view.bounds_for(DEMO_ENTRY_VIEW_BASE + DEMO_PLOT_SVG_ID).width > 0.0)
    test_check(app.dispatch(action(DEMO_CATEGORY_BUTTON_BASE + DEMO_CATEGORY_PLOTTING)))
    test_check(app.component.category == DEMO_CATEGORY_PLOTTING)

    # A clear action restores the catalog and the escape key provides the
    # native keyboard equivalent while the search field is focused.
    test_check(app.dispatch(action(DEMO_CLEAR_SEARCH_ID)))
    test_check(app.component.search.text.count_codepoints() == 0)
    test_check(app.component.visible_count() == 4)
    test_check(app.dispatch(Event(TextInputEvent("no-such-example"))))
    test_check(app.component.visible_count() == 0)
    test_check(app.component.selected_id == -1)
    test_check(app.view.bounds_for(DEMO_EMPTY_CLEAR_ID).width > 0.0)
    test_check(app.dispatch(action(DEMO_EMPTY_CLEAR_ID)))
    test_check(app.component.visible_count() == 4)
    test_check(app.dispatch(Event(TextInputEvent("plot"))))
    var escape = Event(KeyEvent(KEY_ESCAPE))
    test_check(app.dispatch(escape))
    test_check(app.component.search.text.count_codepoints() == 0)

    # Host task state remains observable without disabling an in-process page.
    app.component.set_task_result("plot-demo", True)
    test_check(app.component.task_running)
    test_check(app.component.active_task == "plot-demo")
    app.rebuild()
    test_check(app.view.is_focusable(DEMO_RUN_BUTTON_ID))
    app.component.set_task_completion("plot-demo", 0)
    test_check(not app.component.task_running)
    test_check(app.component.active_task.count_codepoints() == 0)
    app.rebuild()
    test_check(app.view.is_focusable(DEMO_RUN_BUTTON_ID))
    print("Moxi demo-browser test passed")
