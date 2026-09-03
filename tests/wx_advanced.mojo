"""Behavior test for the advanced controls in the shared wx showcase."""

from moxi import (
    App,
    ACTION_COLLAPSE,
    ACTION_INCREMENT,
    ACTION_PRESS,
    ACTION_SELECT,
    ClickEvent,
    DRAG_BEGIN_KIND,
    DRAG_UPDATE_KIND,
    DROP_KIND,
    Event,
    Point,
    PointerEvent,
    POINTER_DOWN_KIND,
    POINTER_MOVE_KIND,
    POINTER_UP_KIND,
    Rect,
    ScrollEvent,
    SemanticActionEvent,
    WxStyleState,
    WX_ADVANCED_ID,
    WX_CANVAS_ID,
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
    var slider_bounds = app.view.bounds_for(WX_SLIDER_ID)
    var slider_start = Point(slider_bounds.x + 2.0, slider_bounds.y + 2.0)
    var slider_end = Point(
        slider_bounds.x + slider_bounds.width * 0.75,
        slider_bounds.y + 2.0,
    )
    test_check(app.dispatch(Event(PointerEvent(POINTER_DOWN_KIND, slider_start))))
    test_check(app.dispatch(Event(PointerEvent(DRAG_BEGIN_KIND, slider_start))))
    test_check(app.dispatch(Event(PointerEvent(DRAG_UPDATE_KIND, slider_end))))
    test_check(app.component.slider.value > 0.0)
    _ = app.dispatch(Event(PointerEvent(DROP_KIND, slider_end)))
    test_check(app.pressed_id() == -1)
    var web_slider_app = App[WxStyleState](WxStyleState(), Rect(0.0, 0.0, 560.0, 1100.0))
    var web_slider_bounds = web_slider_app.view.bounds_for(WX_SLIDER_ID)
    var web_slider_track = web_slider_app.component.slider_track_bounds(web_slider_bounds)
    var web_slider_start = Point(web_slider_track.x, web_slider_track.y + 2.0)
    var web_slider_end = Point(web_slider_track.x + web_slider_track.width, web_slider_track.y + 2.0)
    test_check(web_slider_app.dispatch(Event(PointerEvent(POINTER_DOWN_KIND, web_slider_start, 9, 1))))
    test_check(web_slider_app.dispatch(Event(PointerEvent(POINTER_MOVE_KIND, web_slider_end, 9, 1))))
    test_check(web_slider_app.component.slider.value == web_slider_app.component.slider.maximum)
    _ = web_slider_app.dispatch(Event(PointerEvent(POINTER_UP_KIND, web_slider_end, 9, 0)))
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
        Point(0.0, 1000.0),
    )))
    test_check(scroll_changed)
    test_check(app.view.scroll_offset_for(WX_ADVANCED_ID) > 0.0)
    var canvas_bounds = app.view.bounds_for(WX_CANVAS_ID)
    var canvas_start = Point(canvas_bounds.x + 24.0, canvas_bounds.y + 24.0)
    var canvas_end = Point(canvas_start.x + 18.0, canvas_start.y + 12.0)
    test_check(app.dispatch(Event(PointerEvent(POINTER_DOWN_KIND, canvas_start))))
    test_check(app.component.canvas.dragging)
    test_check(app.dispatch(Event(PointerEvent(POINTER_MOVE_KIND, canvas_end))))
    test_check(app.component.canvas.pointer.x == canvas_end.x)
    _ = app.dispatch(Event(PointerEvent(POINTER_UP_KIND, canvas_end)))
    test_check(not app.component.canvas.dragging)
    print("Moxi wx-advanced test passed")
