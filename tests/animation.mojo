"""Invalidation and deterministic animation contract test."""

from moxi import test_check
from moxi import (
    Animation,
    App,
    Component,
    CounterState,
    ColumnRuntime,
    ColumnView,
    EASE_IN_OUT,
    Event,
    FRAME_TICK_KIND,
    INVALIDATE_ALL,
    INVALIDATE_CONTENT,
    Invalidation,
    MemoryClipboard,
    Point,
    Rect,
    ClickEvent,
    TestRenderer,
    TestWindow,
)


struct TickingState(Component):
    """Small component used to verify frame ticks use the normal update path."""

    var ticks: Int

    def __init__(out self):
        self.ticks = 0

    def build(self, bounds: Rect) -> ColumnView:
        var view = ColumnView(bounds, 8.0, 4.0)
        view.add_label(1, String("Ticks: ", self.ticks), 24.0)
        view.layout()
        return view^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        if event.kind == FRAME_TICK_KIND:
            self.ticks += 1
            return True
        return False


struct PruningState(Component):
    """Remove one command on a frame tick for incremental-backend coverage."""

    var show_extra: Bool

    def __init__(out self):
        self.show_extra = True

    def build(self, bounds: Rect) -> ColumnView:
        var view = ColumnView(bounds, 8.0, 4.0)
        view.add_label(1, "Kept", 24.0)
        if self.show_extra:
            view.add_label(2, "Removed", 24.0)
        view.layout()
        return view^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        if event.kind == FRAME_TICK_KIND and self.show_extra:
            self.show_extra = False
            return True
        return False


def main() raises:
    var pending = Invalidation()
    test_check(pending.is_empty())
    pending.invalidate(INVALIDATE_CONTENT, Rect(10.0, 20.0, 30.0, 40.0))
    pending.invalidate(INVALIDATE_CONTENT, Rect(0.0, 30.0, 50.0, 20.0))
    test_check(pending.has(INVALIDATE_CONTENT))
    test_check(pending.bounds.x == 0.0)
    test_check(pending.bounds.y == 20.0)
    test_check(pending.bounds.width == 50.0)
    test_check(pending.bounds.height == 40.0)
    pending.clear()
    test_check(pending.is_empty())

    var tween = Animation(0.0, 100.0, 1.0, EASE_IN_OUT)
    test_check(not tween.finished())
    test_check(tween.value() == 0.0)
    test_check(tween.advance(0.25))
    test_check(tween.value() == 12.5)
    test_check(tween.advance(0.75))
    test_check(tween.finished())
    test_check(tween.value() == 100.0)
    test_check(not tween.advance(0.1))

    var initial_view = ColumnView(Rect(0.0, 0.0, 320.0, 160.0), 8.0, 4.0)
    initial_view.add_label(10, "Stable", 24.0)
    initial_view.add_button(11, "Go", 32.0)
    initial_view.layout()
    var removed_bounds = initial_view.child(1).bounds
    var paint_runtime = ColumnRuntime()
    paint_runtime.reconcile(initial_view)
    var first_frame = paint_runtime.paint()
    test_check(first_frame.count() == 3)
    test_check(first_frame.changed_count() == 3)
    test_check(first_frame.removed_count() == 0)
    test_check(first_frame.has_dirty_region())

    var idle_frame = paint_runtime.paint()
    test_check(idle_frame.changed_count() == 0)
    test_check(idle_frame.removed_count() == 0)
    test_check(not idle_frame.has_dirty_region())

    var edited_view = ColumnView(Rect(0.0, 0.0, 320.0, 160.0), 8.0, 4.0)
    edited_view.add_label(10, "Changed", 24.0)
    edited_view.add_button(11, "Go", 32.0)
    edited_view.layout()
    paint_runtime.reconcile(edited_view)
    var edited_frame = paint_runtime.paint()
    test_check(edited_frame.changed_count() == 1)
    test_check(edited_frame.removed_count() == 0)

    var move_initial = ColumnView(Rect(0.0, 0.0, 320.0, 160.0), 8.0, 4.0)
    move_initial.add_label(10, "Moved", 24.0)
    move_initial.add_button(11, "Go", 32.0)
    move_initial.set_max_width(10, 120.0)
    move_initial.layout()
    var move_runtime = ColumnRuntime()
    move_runtime.reconcile(move_initial)
    _ = move_runtime.paint()
    var moved_view = ColumnView(Rect(0.0, 0.0, 320.0, 160.0), 8.0, 4.0)
    moved_view.add_label(10, "Moved", 24.0)
    moved_view.add_button(11, "Go", 32.0)
    moved_view.set_max_width(10, 120.0)
    moved_view.layout()
    moved_view.children[0].bounds = Rect(96.0, 8.0, 120.0, 24.0)
    move_runtime.reconcile(moved_view)
    var moved_frame = move_runtime.paint()
    test_check(moved_frame.changed_count() == 1)
    test_check(moved_frame.dirty_region().x == 8.0)
    test_check(moved_frame.dirty_region().width == 208.0)

    var trimmed_view = ColumnView(Rect(0.0, 0.0, 320.0, 160.0), 8.0, 4.0)
    trimmed_view.add_label(10, "Changed", 24.0)
    trimmed_view.layout()
    paint_runtime.reconcile(trimmed_view)
    var trimmed_frame = paint_runtime.paint()
    test_check(trimmed_frame.changed_count() == 0)
    test_check(trimmed_frame.removed_count() == 1)
    test_check(trimmed_frame.has_dirty_region())
    test_check(trimmed_frame.removed_region(0).x == removed_bounds.x)
    test_check(trimmed_frame.removed_region(0).y == removed_bounds.y)
    test_check(trimmed_frame.removed_region(0).width == removed_bounds.width)
    test_check(trimmed_frame.removed_region(0).height == removed_bounds.height)

    var ticking_app = App[TickingState](
        TickingState(),
        Rect(0.0, 0.0, 160.0, 80.0),
    )
    test_check(ticking_app.tick(1.0 / 60.0))
    test_check(ticking_app.component.ticks == 1)

    var app = App[CounterState](CounterState(), Rect(0.0, 0.0, 384.0, 184.0))
    test_check(app.pending_invalidation().has(INVALIDATE_ALL))
    app.clear_invalidation()
    test_check(app.pending_invalidation().is_empty())
    app.invalidate(INVALIDATE_CONTENT, Rect(4.0, 6.0, 8.0, 10.0))
    test_check(app.pending_invalidation().has(INVALIDATE_CONTENT))
    test_check(app.update(ClickEvent(Point(72.0, 130.0))))
    test_check(app.pending_invalidation().has(INVALIDATE_ALL))
    var renderer = TestRenderer()
    app.render(renderer)
    test_check(app.pending_invalidation().is_empty())

    var incremental_renderer = TestRenderer()
    incremental_renderer.set_incremental()
    var incremental_app = App[CounterState](
        CounterState(),
        Rect(0.0, 0.0, 384.0, 184.0),
    )
    incremental_app.render(incremental_renderer)
    test_check(incremental_renderer.count() == 5)
    incremental_app.render(incremental_renderer)
    test_check(incremental_renderer.count() == 0)
    test_check(incremental_renderer.clear_count() == 0)

    var pruning_renderer = TestRenderer()
    pruning_renderer.set_incremental()
    var pruning_app = App[PruningState](
        PruningState(),
        Rect(0.0, 0.0, 160.0, 80.0),
    )
    pruning_app.render(pruning_renderer)
    test_check(pruning_renderer.count() == 3)
    test_check(pruning_app.tick(1.0 / 60.0))
    pruning_app.render(pruning_renderer)
    test_check(pruning_renderer.count() == 0)
    test_check(pruning_renderer.clear_count() == 1)

    var closed_window = TestWindow()
    var run_renderer = TestRenderer()
    var run_app = App[CounterState](
        CounterState(),
        Rect(0.0, 0.0, 160.0, 80.0),
    )
    run_app.run(closed_window, run_renderer)
    test_check(run_renderer.count() == 5)

    var clipboard_window = TestWindow()
    var clipboard_renderer = TestRenderer()
    var clipboard = MemoryClipboard()
    var clipboard_run_app = App[CounterState](
        CounterState(),
        Rect(0.0, 0.0, 160.0, 80.0),
    )
    clipboard_run_app.run_with_clipboard(
        clipboard_window,
        clipboard_renderer,
        clipboard,
    )
    test_check(clipboard_renderer.count() == 5)
    print("Moxi animation and invalidation test passed")
