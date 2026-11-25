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
    FRACTAL_SCROLL_ID,
    FractalState,
    ActionEvent,
    Event,
    PointerEvent,
    POINTER_DOWN_KIND,
    POINTER_MOVE_KIND,
    POINTER_UP_KIND,
    Point,
    Rect,
    ROOT_SCROLL_ID,
    SCROLLBAR_KIND,
    ScrollEvent,
    fractal_preset_geometry,
    fractal_preset_group,
    test_check,
)
from moxi.fractal import FRACTAL_PANEL_ID, FRACTAL_RENDER_BATCH, FRACTAL_MAX_RENDERED_SEGMENTS


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
    test_check(app.view.scroll_max_offset(ROOT_SCROLL_ID) == 0.0)
    test_check(app.view.scroll_max_offset(FRACTAL_PANEL_ID) == 0.0)
    test_check(app.view.scroll_max_offset(FRACTAL_SCROLL_ID) > 0.0)
    var commands = app.paint()
    var scrollbar_count = 0
    for index in range(commands.count()):
        var command = commands.command(index)
        if command.kind == SCROLLBAR_KIND:
            scrollbar_count += 1
            test_check(command.id == FRACTAL_SCROLL_ID)
    test_check(scrollbar_count == 1)
    var portal = app.view.bounds_for(FRACTAL_SCROLL_ID)
    test_check(app.dispatch(Event(ScrollEvent(
        Point(portal.x + 1.0, portal.y + 1.0), Point(0.0, 30.0),
    ))))
    test_check(app.view.scroll_offset_for(FRACTAL_SCROLL_ID) > 0.0)
    test_check(app.view.scroll_offset_for(FRACTAL_PANEL_ID) == 0.0)
    app.reset_scroll(FRACTAL_SCROLL_ID)
    app.rebuild()
    var canvas = app.view.bounds_for(FRACTAL_CANVAS_ID)
    test_check(canvas.width > 0.0)
    test_check(canvas.height > 0.0)
    test_check(app.component.rendered_segment_count() > 0)
    test_check(app.component.rendered_segment_count() <= FRACTAL_RENDER_BATCH)
    var preview_count = app.component.rendered_segment_count()
    test_check(not app.component.advance_render(1))
    test_check(app.component.rendered_segment_count() == preview_count)

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
    test_check(app.component.rendered_segment_count() > 0)
    test_check(app.component.rendered_segment_count() <= FRACTAL_RENDER_BATCH)
    var drag_jobs = app.component.pending_job_count()
    test_check(not app.component.advance_render(10000))
    test_check(app.component.pending_job_count() == drag_jobs)
    # Repeated positions must not reset the same in-flight render.
    test_check(not app.dispatch(Event(PointerEvent(
        POINTER_MOVE_KIND, Point(point.x, point.y + 10.0),
    ))))
    test_check(app.dispatch(Event(PointerEvent(
        POINTER_UP_KIND,
        Point(point.x, point.y + 10.0),
    ))))
    test_check(app.component.geometry.generator_points[1].y == initial_point_y + 10.0)
    test_check(not app.component.dragging)
    while not app.component.render_complete():
        _ = app.component.advance_render(10000)
    test_check(app.component.rendered_segment_count() > preview_count)

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

    # Every preset has a complete bounded preview even at maximum depth.
    # Refinement keeps that preview until a complete replacement is ready.
    for preset in range(FRACTAL_PRESET_COUNT):
        var dense = FractalState()
        dense.geometry = fractal_preset_geometry(preset)
        dense.depth = 12
        dense.reset_render_progress()
        var coarse_count = dense.rendered_segment_count()
        test_check(coarse_count > 0 and coarse_count <= FRACTAL_RENDER_BATCH)
        var coarse_start = dense.rendered_segments[0].start
        _ = dense.advance_render(1)
        if not dense.render_complete():
            test_check(dense.rendered_segment_count() == coarse_count)
            test_check(dense.rendered_segments[0].start.x == coarse_start.x)
        while not dense.render_complete():
            _ = dense.advance_render(10000)
        test_check(dense.rendered_segment_count() > 0)
        test_check(dense.rendered_segment_count() <= FRACTAL_MAX_RENDERED_SEGMENTS)

    var dragging = App[FractalState](FractalState(), Rect(0, 0, 1180, 900))
    dragging.component.geometry = fractal_preset_geometry(8)
    dragging.component.depth = 12
    dragging.component.reset_render_progress()
    dragging.rebuild()
    var dense_canvas = dragging.view.bounds_for(FRACTAL_CANVAS_ID)
    var handle = dragging.component.geometry.generator_points[1]
    var origin = Point(dense_canvas.x + handle.x, dense_canvas.y + handle.y)
    test_check(dragging.dispatch(Event(PointerEvent(POINTER_DOWN_KIND, origin))))
    for move in range(1, 13):
        test_check(dragging.dispatch(Event(PointerEvent(
            POINTER_MOVE_KIND, Point(origin.x + Float32(move), origin.y + Float32(move)),
        ))))
        test_check(dragging.component.geometry.generator_points[1].x == handle.x + Float32(move))
        test_check(dragging.component.rendered_segment_count() > 0)
        test_check(dragging.component.rendered_segment_count() <= FRACTAL_RENDER_BATCH)
        test_check(not dragging.component.advance_render())
    test_check(dragging.dispatch(Event(PointerEvent(
        POINTER_UP_KIND, Point(origin.x + 12, origin.y + 12),
    ))))
    var drag_preview = dragging.component.rendered_segment_count()
    while not dragging.component.render_complete():
        _ = dragging.component.advance_render(10000)
    test_check(dragging.component.rendered_segment_count() > drag_preview)

    print("Moxi fractal contract passed")
