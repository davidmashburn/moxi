"""Behavior test for the advanced controls in the shared wx showcase."""

from moxi import (
    App,
    ACTION_COLLAPSE,
    ACTION_INCREMENT,
    ACTION_PRESS,
    ACTION_SELECT,
    ClickEvent,
    Event,
    Point,
    PointerEvent,
    POINTER_DOWN_KIND,
    POINTER_UP_KIND,
    Rect,
    ScrollEvent,
    SemanticActionEvent,
    WxStyleState,
    WX_ADVANCED_ID,
    WX_COMBO_ID,
    WX_DIALOG_ID,
    WX_RADIO_ID,
    WX_SLIDER_ID,
    WX_SWITCH_ID,
    WX_TREE_ID,
    test_check,
)


def main():
    var app = App[WxStyleState](WxStyleState(), Rect(0.0, 0.0, 560.0, 1100.0))
    test_check(app.view.bounds_for(WX_ADVANCED_ID).height > 0.0)
    test_check(app.view.bounds_for(WX_SLIDER_ID).width > 0.0)
    var slider_value = app.component.slider.value
    var slider_changed = app.dispatch(Event(SemanticActionEvent(WX_SLIDER_ID, ACTION_INCREMENT)))
    test_check(slider_changed)
    test_check(app.component.slider.value > slider_value)
    test_check(app.dispatch(Event(ClickEvent(
        Point(
            app.view.bounds_for(WX_SLIDER_ID).x + app.view.bounds_for(WX_SLIDER_ID).width - 1.0,
            app.view.bounds_for(WX_SLIDER_ID).y + 2.0,
        )
    ))))
    test_check(app.component.slider.value >= slider_value)
    var switch_bounds = app.view.bounds_for(WX_SWITCH_ID)
    var switch_point = Point(switch_bounds.x + 1.0, switch_bounds.y + 1.0)
    test_check(app.dispatch(Event(PointerEvent(POINTER_DOWN_KIND, switch_point))))
    test_check(app.dispatch(Event(PointerEvent(POINTER_UP_KIND, switch_point))))
    test_check(not app.component.notifications.checked)
    var radio_bounds = app.view.bounds_for(WX_RADIO_ID)
    var radio_point = Point(radio_bounds.x + 1.0, radio_bounds.y + 1.0)
    test_check(app.dispatch(Event(PointerEvent(POINTER_DOWN_KIND, radio_point))))
    test_check(app.dispatch(Event(PointerEvent(POINTER_UP_KIND, radio_point))))
    test_check(app.component.radio.is_selected(WX_RADIO_ID))
    test_check(app.dispatch(Event(SemanticActionEvent(WX_COMBO_ID, ACTION_SELECT))))
    test_check(app.component.combo.selection.selected_index == 1)

    test_check(app.dispatch(Event(SemanticActionEvent(WX_TREE_ID, ACTION_COLLAPSE))))
    test_check(not app.component.tree.expanded)

    test_check(app.dispatch(Event(SemanticActionEvent(WX_DIALOG_ID, ACTION_PRESS))))
    test_check(not app.component.dialog.open)

    var advanced_bounds = app.view.bounds_for(WX_ADVANCED_ID)
    var scroll_changed = app.dispatch(Event(ScrollEvent(
        Point(advanced_bounds.x + 2.0, advanced_bounds.y + 2.0),
        Point(0.0, 100.0),
    )))
    test_check(scroll_changed)
    test_check(app.view.scroll_offset_for(WX_ADVANCED_ID) > 0.0)
    print("Moxi wx-advanced test passed")
