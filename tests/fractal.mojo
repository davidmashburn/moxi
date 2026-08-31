"""Contract tests for the interactive line-fractal port."""

from moxi import (
    ACTION_PRESS,
    App,
    FRACTAL_CANVAS_ID,
    FRACTAL_DEPTH_UP_ID,
    FRACTAL_GUIDES_ID,
    FRACTAL_GROUP_CLASSIC,
    FRACTAL_GROUP_EXPERIMENT,
    FRACTAL_PRESET_COUNT,
    FRACTAL_PRESET_BUTTON_BASE,
    FractalState,
    ActionEvent,
    Event,
    PointerEvent,
    POINTER_DOWN_KIND,
    POINTER_MOVE_KIND,
    POINTER_UP_KIND,
    Point,
    Rect,
    fractal_preset_geometry,
    fractal_preset_group,
    test_check,
)


def action(target: Int) -> Event:
    var event = Event(ActionEvent(ACTION_PRESS))
    event.set_target(target)
    return event


def main():
    test_check(FRACTAL_PRESET_COUNT == 27)
    test_check(fractal_preset_group(0) == FRACTAL_GROUP_CLASSIC)
    test_check(fractal_preset_group(26) == FRACTAL_GROUP_EXPERIMENT)

    var koch = fractal_preset_geometry(0)
    test_check(koch.point_count() == 5)
    test_check(koch.endpoint0_docked)
    test_check(koch.endpoint1_docked)
    test_check(koch.baseline_start.x == koch.generator_points[0].x)
    test_check(koch.baseline_end.x == koch.generator_points[4].x)

    var turtle = fractal_preset_geometry(4)
    test_check(turtle.point_count() > 2)

    var app = App[FractalState](
        FractalState(),
        Rect(0.0, 0.0, 1180.0, 900.0),
    )
    test_check(app.view.is_valid())
    test_check(app.runtime.widget_count() > 0)
    var canvas = app.view.bounds_for(FRACTAL_CANVAS_ID)
    test_check(canvas.width > 0.0)
    test_check(canvas.height > 0.0)
    test_check(app.component.rendered_segment_count() == 0)

    while not app.component.render_complete():
        _ = app.component.advance_render(10000)
    test_check(app.component.rendered_segment_count() > 0)
    test_check(app.component.pending_job_count() == 0)
    test_check(app.component.build_scene(canvas).count() > 0)

    var initial_point_y = app.component.geometry.generator_points[1].y
    var point = Point(
        canvas.x + app.component.geometry.generator_points[1].x,
        canvas.y + initial_point_y,
    )
    test_check(app.dispatch(Event(PointerEvent(POINTER_DOWN_KIND, point))))
    test_check(app.dispatch(Event(PointerEvent(
        POINTER_MOVE_KIND,
        Point(point.x, point.y + 10.0),
    ))))
    test_check(app.dispatch(Event(PointerEvent(
        POINTER_UP_KIND,
        Point(point.x, point.y + 10.0),
    ))))
    test_check(app.component.geometry.generator_points[1].y == initial_point_y + 10.0)

    test_check(app.dispatch(action(FRACTAL_DEPTH_UP_ID)))
    test_check(app.component.depth == 6)
    test_check(app.dispatch(action(FRACTAL_GUIDES_ID)))
    test_check(not app.component.show_guides)
    test_check(app.dispatch(action(FRACTAL_PRESET_BUTTON_BASE + 1)))
    test_check(app.component.preset_id == 1)

    # Two quick clicks on a docked endpoint reveal the nested draggable point.
    var endpoint = Point(
        canvas.x + app.component.geometry.baseline_start.x,
        canvas.y + app.component.geometry.baseline_start.y,
    )
    test_check(app.dispatch(Event(PointerEvent(POINTER_DOWN_KIND, endpoint))))
    test_check(app.dispatch(Event(PointerEvent(POINTER_UP_KIND, endpoint))))
    test_check(app.dispatch(Event(PointerEvent(POINTER_DOWN_KIND, endpoint))))
    test_check(app.component.endpoint0_revealed)
    test_check(app.dispatch(Event(PointerEvent(POINTER_UP_KIND, endpoint))))

    # Copying component state must not alias its mutable render queues.
    var partial = FractalState()
    _ = partial.advance_render(1)
    var copy = partial
    test_check(copy.rendered_segment_count() == partial.rendered_segment_count())
    _ = copy.advance_render(1)
    test_check(copy.pending_job_count() != partial.pending_job_count())

    print("Moxi fractal contract passed")
