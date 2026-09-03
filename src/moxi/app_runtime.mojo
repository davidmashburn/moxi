"""High-level component lifecycle for mounting, updating, and rendering."""

from std.collections import List

from .component import Component
from .clipboard import ClipboardBackend
from .accessibility import AccessibilitySnapshot
from .invalidation import (
    INVALIDATE_ALL,
    INVALIDATE_CONTENT,
    INVALIDATE_STRUCTURE,
    Invalidation,
)
from .event import (
    CLICK_KIND,
    CompositionEvent,
    KEY_DOWN_KIND,
    KEY_C,
    KEY_DOWN,
    KEY_LEFT,
    KEY_TAB,
    KEY_RIGHT,
    KEY_UP,
    KEY_V,
    KEY_X,
    MOD_COMMAND,
    MOD_CONTROL,
    MOD_SHIFT,
    NONE_KIND,
    POINTER_MOVE_KIND,
    POINTER_DOWN_KIND,
    POINTER_UP_KIND,
    SCROLL_KIND,
    WINDOW_RESIZED_KIND,
    ClickEvent,
    ActionEvent,
    POINTER_CANCEL_KIND,
    DRAG_BEGIN_KIND,
    DRAG_UPDATE_KIND,
    DROP_KIND,
    ACTION_KIND,
    Event,
    FrameEvent,
    TaskEvent,
)
from .geometry import Point, Rect
from .paint import PaintCommands, Renderer
from .runtime import ColumnRuntime
from .reactivity import ActionMessage, ActionQueue
from .execution import LocalizedExecution
from .layout import ROW_AXIS
from .scrollbar import (
    SCROLLBAR_HIT_THUMB,
    SCROLLBAR_HIT_TRACK,
    SCROLLBAR_HORIZONTAL,
    SCROLLBAR_VERTICAL,
    ScrollbarState,
)
from .tasks import TaskHandle, TaskScheduler
from .view import (
    CONTAINER_KIND,
    ColumnView,
    ROOT_SCROLL_ID,
    TEXT_INPUT_VIEW_KIND,
)
from .window import WindowBackend


struct App[ComponentType: Component & Deinitable]:
    """Own a component, its current view, and its retained runtime."""

    var component: Self.ComponentType
    var root_bounds: Rect
    var view: ColumnView
    var runtime: ColumnRuntime
    var clipboard: String
    var pending: Invalidation
    var tasks: TaskScheduler
    var scroll_ids: List[Int]
    var scroll_values: List[Float32]
    var scrollbar_pointer_id: Int
    var scrollbar_target_id: Int
    var scrollbar_grab_offset: Float32
    var scrollbar_dragging: Bool
    var local_execution: LocalizedExecution

    def __init__(out self, component: Self.ComponentType, bounds: Rect):
        self.component = component
        self.root_bounds = bounds
        self.runtime = ColumnRuntime()
        self.view = self.component.build(bounds)
        self.runtime.reconcile(self.view)
        self.clipboard = ""
        self.pending = Invalidation()
        self.pending.invalidate(INVALIDATE_ALL, bounds)
        self.tasks = TaskScheduler()
        self.scroll_ids = List[Int]()
        self.scroll_values = List[Float32]()
        self.scrollbar_pointer_id = -1
        self.scrollbar_target_id = -1
        self.scrollbar_grab_offset = 0.0
        self.scrollbar_dragging = False
        self.local_execution = LocalizedExecution()
        _ = self.local_execution.add_scope(0)
        _ = self.local_execution.add_dependency(0, 0)
        _ = self.local_execution.invalidate_scope(0)
        _ = self.local_execution.take_dirty(0)

    def update(mut self, event: ClickEvent) -> Bool:
        """Compatibility spelling for dispatching a pointer click."""
        return self.dispatch(Event(event))

    def update(mut self, event: Event) -> Bool:
        """Compatibility spelling for dispatching a routed event."""
        return self.dispatch(event)

    def tick(mut self, delta_seconds: Float32) -> Bool:
        """Deliver a frame tick and any task results ready at that time."""
        var changed = self.dispatch(Event(FrameEvent(delta_seconds)))
        self.tasks.advance(delta_seconds)
        while self.tasks.has_ready():
            var result = self.tasks.pop_ready()
            var task_changed = self.dispatch(Event(
                TaskEvent(result.task_id, result.status, result.payload)
            ))
            changed = changed or task_changed
        return changed

    def schedule_task(
        mut self,
        label: String,
        delay_seconds: Float32,
        payload: String = "",
    ) -> TaskHandle:
        """Schedule deterministic work; adapters may replace its result."""
        return self.tasks.schedule(label, delay_seconds, payload)

    def cancel_task(mut self, handle: TaskHandle) -> Bool:
        """Cancel a pending task and deliver its result on the next tick."""
        return self.tasks.cancel(handle)

    def forget_task(mut self, handle: TaskHandle) -> Bool:
        """Release a terminal task record when the application no longer needs it."""
        return self.tasks.forget(handle)

    def register_execution_scope(
        mut self,
        scope_id: Int,
        parent_id: Int = -1,
    ) -> Bool:
        """Register a component state scope for localized invalidation."""
        return self.local_execution.add_scope(scope_id, parent_id)

    def register_execution_dependency(
        mut self,
        component_id: Int,
        scope_id: Int,
    ) -> Bool:
        """Connect a component to only the state scope it consumes."""
        return self.local_execution.add_dependency(component_id, scope_id)

    def invalidate_execution_scope(mut self, scope_id: Int) -> Bool:
        """Mark dependent components dirty without broad invalidation."""
        return self.local_execution.invalidate_scope(scope_id)

    def take_execution_dirty(mut self, component_id: Int) -> Bool:
        """Consume one localized rebuild token after running a typed builder."""
        return self.local_execution.take_dirty(component_id)

    def execution_build_count(self, component_id: Int) -> Int:
        return self.local_execution.build_count(component_id)

    def dispatch_action(mut self, message: ActionMessage) -> Bool:
        """Deliver a typed action without inventing a pointer target."""
        var event = Event(ActionEvent(message.id, message.payload))
        var updated = self.component.update(event, self.view)
        if updated:
            self.rebuild()
        return updated

    def dispatch_actions(mut self, mut queue: ActionQueue) -> Bool:
        """Drain an explicit action queue through the component lifecycle."""
        var changed = False
        while queue.has_next():
            var next = queue.dequeue()
            changed = self.dispatch_action(next) or changed
        return changed

    def task_status(self, handle: TaskHandle) -> Int:
        return self.tasks.status(handle)

    def pending_task_count(self) -> Int:
        return self.tasks.pending_count()

    def ready_task_count(self) -> Int:
        return self.tasks.ready_count()

    def dispatch(mut self, event: Event) -> Bool:
        """Route an event through focus, hit-testing, and component state."""
        if event.kind == WINDOW_RESIZED_KIND:
            return self.resize(
                Rect(
                    self.root_bounds.x,
                    self.root_bounds.y,
                    event.size.width,
                    event.size.height,
                )
            )

        if event.kind == KEY_DOWN_KIND and self.is_clipboard_command(event):
            return self.dispatch_clipboard(event)

        var routed = event
        var focus_changed = False
        var pointer_changed = False
        var rebuilt = False
        var component_dispatched = False
        var updated = False
        var scrollbar_handled = False
        var pointer_intercepted = (
            event.kind == CLICK_KIND
            or event.kind == POINTER_DOWN_KIND
            or event.kind == POINTER_MOVE_KIND
            or event.kind == POINTER_UP_KIND
            or event.kind == POINTER_CANCEL_KIND
            or event.kind == DRAG_BEGIN_KIND
            or event.kind == DRAG_UPDATE_KIND
            or event.kind == DROP_KIND
        ) and self.component.intercepts_pointer(event)

        if event.kind == POINTER_DOWN_KIND and not pointer_intercepted:
            var scrollbar_target = self.scrollbar_target_at(event.position)
            if scrollbar_target != -1:
                var scrollbar = self.scrollbar_state_for(scrollbar_target)
                var track = self.scrollbar_track_for(scrollbar_target)
                var hit = scrollbar.hit_test(track, event.position)
                if hit == SCROLLBAR_HIT_THUMB:
                    var geometry = scrollbar.geometry(track)
                    self.scrollbar_pointer_id = event.pointer_id
                    self.scrollbar_target_id = scrollbar_target
                    self.scrollbar_dragging = True
                    if scrollbar.orientation == SCROLLBAR_VERTICAL:
                        self.scrollbar_grab_offset = (
                            event.position.y - geometry.thumb.y
                        )
                    else:
                        self.scrollbar_grab_offset = (
                            event.position.x - geometry.thumb.x
                        )
                    scrollbar_handled = True
                elif hit == SCROLLBAR_HIT_TRACK:
                    self.scrollbar_pointer_id = event.pointer_id
                    self.scrollbar_target_id = scrollbar_target
                    self.scrollbar_grab_offset = 0.0
                    self.scrollbar_dragging = False
                    if scrollbar.handle_track_click(track, event.position):
                        self.remember_scroll(
                            scrollbar_target,
                            scrollbar.offset,
                        )
                        self.view.set_scroll_offset(
                            scrollbar_target,
                            scrollbar.offset,
                        )
                        self.view.layout()
                        self.runtime.reconcile(self.view)
                        pointer_changed = True
                    scrollbar_handled = True
                if scrollbar_handled:
                    pointer_changed = True
                    pointer_changed = self.runtime.set_hover(-1) or pointer_changed
        elif (
            self.scrollbar_pointer_id >= 0
            and event.pointer_id == self.scrollbar_pointer_id
            and (
                event.kind == POINTER_MOVE_KIND
                or event.kind == POINTER_UP_KIND
                or event.kind == POINTER_CANCEL_KIND
                or event.kind == DRAG_BEGIN_KIND
                or event.kind == DRAG_UPDATE_KIND
                or event.kind == DROP_KIND
            )
        ):
            scrollbar_handled = True
            var scrollbar_target = self.scrollbar_target_id
            if event.kind == DRAG_BEGIN_KIND:
                pointer_changed = True
            elif (
                event.kind == POINTER_MOVE_KIND
                or event.kind == DRAG_UPDATE_KIND
            ):
                if self.scrollbar_dragging:
                    var scrollbar = self.scrollbar_state_for(scrollbar_target)
                    var track = self.scrollbar_track_for(scrollbar_target)
                    var next = scrollbar.offset_for_thumb_position(
                        track,
                        event.position,
                        self.scrollbar_grab_offset,
                    )
                    var current = self.view.scroll_offset_for(scrollbar_target)
                    if next != current:
                        self.remember_scroll(scrollbar_target, next)
                        self.view.set_scroll_offset(scrollbar_target, next)
                        self.view.layout()
                        self.runtime.reconcile(self.view)
                        pointer_changed = True
                pointer_changed = self.runtime.set_hover(-1) or pointer_changed
            elif (
                event.kind == POINTER_UP_KIND
                or event.kind == POINTER_CANCEL_KIND
                or event.kind == DROP_KIND
            ):
                self.scrollbar_pointer_id = -1
                self.scrollbar_target_id = -1
                self.scrollbar_grab_offset = 0.0
                self.scrollbar_dragging = False
                pointer_changed = True

        if event.kind == CLICK_KIND or event.kind == POINTER_DOWN_KIND:
            var target = (
                -1
                if scrollbar_handled
                else self.runtime.hit_test(event.position)
            )
            routed.set_target(target)
            routed.set_action(self.runtime.action_for(target))
            var previous_focus = self.runtime.focus_id()
            if (
                not pointer_intercepted
                and (event.kind == POINTER_DOWN_KIND or target != -1)
            ):
                focus_changed = self.runtime.set_focus(target)
                if focus_changed and previous_focus != -1:
                    if self.end_composition(previous_focus):
                        self.rebuild()
                        rebuilt = True
            if event.kind == POINTER_DOWN_KIND:
                pointer_changed = self.runtime.press(target) or pointer_changed
                if pointer_intercepted:
                    pointer_changed = self.runtime.set_hover(-1) or pointer_changed
        elif event.kind == POINTER_MOVE_KIND:
            var hover_target = self.runtime.hit_test(event.position)
            if self.scrollbar_target_at(event.position) != -1:
                # Painted scrollbars sit above the widget stream. Do not let
                # a control behind the track light up while the pointer is
                # over the affordance.
                hover_target = -1
            var captured_target = self.runtime.pressed_view_id()
            var target = (
                -1
                if scrollbar_handled
                else (captured_target if captured_target != -1 else hover_target)
            )
            routed.set_target(target)
            routed.set_action(self.runtime.action_for(target))
            if not scrollbar_handled and not pointer_intercepted:
                pointer_changed = self.runtime.set_hover(hover_target) or pointer_changed
        elif event.kind == POINTER_UP_KIND:
            var hover_target = self.runtime.hit_test(event.position)
            if self.scrollbar_target_at(event.position) != -1:
                # Releasing over an overlay scrollbar is outside the pressed
                # control, so the click must be cancelled rather than sent
                # through the painted track.
                hover_target = -1
            var captured_target = self.runtime.pressed_view_id()
            var target = (
                -1
                if scrollbar_handled
                else (captured_target if captured_target != -1 else hover_target)
            )
            routed.set_target(target)
            routed.set_action(self.runtime.action_for(target))
            if not scrollbar_handled and not pointer_intercepted:
                pointer_changed = self.runtime.set_hover(hover_target) or pointer_changed
            var activated = False
            if pointer_intercepted:
                # A scene popup is not present in the retained hit-test tree;
                # the underlying target can therefore differ between press
                # and release. Let the popup inspect a synthetic click while
                # suppressing the underlying control's activation.
                _ = self.runtime.cancel_press()
                routed.kind = CLICK_KIND
                pointer_changed = True
            elif captured_target != -1 and hover_target != captured_target:
                # Pointer capture keeps the release routed to the original
                # control, but leaving its bounds cancels activation.
                _ = self.runtime.cancel_press()
                pointer_changed = True
            else:
                activated = self.runtime.release(target)
            if activated:
                routed.kind = CLICK_KIND
                pointer_changed = True
        elif event.kind == POINTER_CANCEL_KIND:
            var target = self.runtime.pressed_view_id()
            routed.set_target(target)
            routed.set_action(self.runtime.action_for(target))
            pointer_changed = self.runtime.set_hover(-1) or pointer_changed
            pointer_changed = self.runtime.cancel_press() or pointer_changed
        elif event.kind == DRAG_BEGIN_KIND:
            # Preserve pointer capture across the transition from a native
            # mouse drag to the backend-neutral drag stream. A drag can begin
            # outside the original control while still belonging to it.
            var target = self.runtime.pressed_view_id()
            if target == -1 and not scrollbar_handled:
                target = self.runtime.hit_test(event.position)
            if scrollbar_handled:
                target = -1
            routed.set_target(target)
            routed.set_action(self.runtime.action_for(target))
            if self.runtime.pressed_view_id() == -1:
                pointer_changed = self.runtime.press(target) or pointer_changed
        elif event.kind == DRAG_UPDATE_KIND:
            var captured_target = self.runtime.pressed_view_id()
            var hover_target = self.runtime.hit_test(event.position)
            if self.scrollbar_target_at(event.position) != -1:
                hover_target = -1
            var target = captured_target
            if target == -1 and not scrollbar_handled:
                target = self.runtime.hit_test(event.position)
            routed.set_target(target)
            routed.set_action(self.runtime.action_for(target))
            if not scrollbar_handled and not pointer_intercepted:
                pointer_changed = self.runtime.set_hover(hover_target) or pointer_changed
        elif event.kind == DROP_KIND:
            var captured_target = self.runtime.pressed_view_id()
            var target = captured_target
            if target == -1 and not scrollbar_handled:
                target = self.runtime.hit_test(event.position)
            routed.set_target(target)
            routed.set_action(self.runtime.action_for(target))
            pointer_changed = self.runtime.cancel_press() or pointer_changed
        elif event.kind == SCROLL_KIND:
            var target = self.runtime.scroll_target(event.position)
            routed.set_target(target)
            routed.set_action(self.runtime.action_for(target))
            # Embedded canvases get first refusal. Moving the outer portal
            # before a child sees its wheel event can make one gesture affect
            # two viewports and invalidate the child's pointer coordinates.
            component_dispatched = True
            updated = self.component.update(routed, self.view)
            if not updated and target != -1:
                var current = self.scroll_offset_for(target)
                var delta = event.scroll_delta.y
                if (
                    self.view.scroll_axis_for(target) == ROW_AXIS
                    and event.scroll_delta.x != 0.0
                ):
                    delta = event.scroll_delta.x
                var next = current + delta
                var maximum = self.view.scroll_max_offset(target)
                if next < 0.0:
                    next = 0.0
                if next > maximum:
                    next = maximum
                if next != current:
                    self.remember_scroll(target, next)
                    self.view.set_scroll_offset(target, next)
                    self.view.layout()
                    self.runtime.reconcile(self.view)
                    pointer_changed = True
        elif event.kind == ACTION_KIND:
            # Application actions may be addressed to a concrete view (for
            # example from accessibility) or to the currently focused view.
            # Preserve the action id; it is not the view's optional action id.
            var target = event.target
            if target == -1:
                target = self.runtime.focus_id()
            routed.set_target(target)
        elif event.kind == KEY_DOWN_KIND:
            if event.key == KEY_TAB:
                var previous_focus = self.runtime.focus_id()
                var moved = self.runtime.move_focus(
                    (event.modifiers & MOD_SHIFT) != 0
                )
                if moved and previous_focus != -1:
                    if self.end_composition(previous_focus):
                        self.rebuild()
                        rebuilt = True
                return moved or rebuilt
            if self.can_move_focus_direction(event.key):
                var previous_focus = self.runtime.focus_id()
                var moved = self.runtime.move_focus_direction(event.key)
                if moved:
                    if previous_focus != -1:
                        if self.end_composition(previous_focus):
                            self.rebuild()
                    return True
            var target = self.runtime.focus_id()
            routed.set_target(target)
            routed.set_action(self.runtime.action_for(target))
        else:
            var target = self.runtime.focus_id()
            routed.set_target(target)
            routed.set_action(self.runtime.action_for(target))

        if not component_dispatched:
            updated = self.component.update(routed, self.view)
        if updated:
            if self.component.intercepts_pointer(routed):
                pointer_changed = self.runtime.set_hover(-1) or pointer_changed
            var reset_id = self.component.scroll_reset_target(routed)
            if reset_id != -1:
                self.reset_scroll(reset_id)
            self.rebuild()
        var changed = focus_changed or pointer_changed or rebuilt or updated
        if changed and not rebuilt and not updated:
            self.pending.invalidate(INVALIDATE_ALL, self.root_bounds)
        return changed

    def end_composition(mut self, target: Int) -> Bool:
        """Cancel marked text when focus leaves a text-input control."""
        if target == -1:
            return False
        var event = Event(CompositionEvent())
        event.set_target(target)
        event.set_action(self.runtime.action_for(target))
        return self.component.update(event, self.view)

    def can_move_focus_direction(self, key: Int) -> Bool:
        """Return whether an arrow key may perform semantic focus navigation."""
        if (
            key != KEY_LEFT
            and key != KEY_RIGHT
            and key != KEY_UP
            and key != KEY_DOWN
        ):
            return False
        if (
            self.runtime.focused_kind() == TEXT_INPUT_VIEW_KIND
            and (key == KEY_LEFT or key == KEY_RIGHT)
        ):
            return False
        return True

    def is_clipboard_command(self, event: Event) -> Bool:
        """Return whether an event is a command/control clipboard shortcut."""
        if (event.modifiers & (MOD_COMMAND | MOD_CONTROL)) == 0:
            return False
        return event.key == KEY_C or event.key == KEY_X or event.key == KEY_V

    def dispatch_clipboard(mut self, event: Event) -> Bool:
        """Apply a portable clipboard command through the component hooks."""
        var target = self.runtime.focus_id()
        if target == -1:
            return False
        var changed = False
        if event.key == KEY_C:
            self.clipboard = self.component.clipboard_copy(target, self.view)
            return False
        if event.key == KEY_X:
            self.clipboard = self.component.clipboard_cut(target, self.view)
            changed = self.clipboard.count_codepoints() > 0
        elif event.key == KEY_V:
            var clipboard = self.clipboard
            changed = self.component.clipboard_paste(target, clipboard, self.view)
        if changed:
            self.rebuild()
        return changed

    def clipboard_text(self) -> String:
        """Return the App-level clipboard contents."""
        return self.clipboard

    def set_clipboard(mut self, text: String):
        """Set the App-level clipboard used by portable paste commands."""
        self.clipboard = text

    def dispatch_with_clipboard[ClipboardType: ClipboardBackend](
        mut self,
        event: Event,
        mut clipboard: ClipboardType,
    ) raises -> Bool:
        """Dispatch an event while synchronizing command shortcuts to a backend."""
        if not (event.kind == KEY_DOWN_KIND and self.is_clipboard_command(event)):
            return self.dispatch(event)
        if event.key == KEY_V:
            self.set_clipboard(clipboard.paste())
        var changed = self.dispatch(event)
        if event.key == KEY_C or event.key == KEY_X:
            var copied = self.clipboard_text()
            if copied.count_codepoints() > 0:
                clipboard.copy(copied)
        return changed

    def resize(mut self, bounds: Rect) -> Bool:
        """Update the root geometry and rebuild if the size changed."""
        if (
            self.root_bounds.x == bounds.x
            and self.root_bounds.y == bounds.y
            and self.root_bounds.width == bounds.width
            and self.root_bounds.height == bounds.height
        ):
            return False
        self.root_bounds = bounds
        self.rebuild()
        return True

    def rebuild(mut self):
        """Rebuild the declarative view and reconcile retained children."""
        _ = self.local_execution.invalidate_scope(0)
        self.view = self.component.build(self.root_bounds)
        self.apply_scroll_offsets()
        self.runtime.reconcile(self.view)
        if (
            self.scrollbar_pointer_id >= 0
            and self.view.scroll_max_offset(self.scrollbar_target_id) <= 0.0
        ):
            # A rebuild can remove or shrink the portal whose thumb owns the
            # pointer. Do not let a later mouse-up get swallowed by a dead
            # capture and leave the next gesture in the wrong state.
            self.scrollbar_pointer_id = -1
            self.scrollbar_target_id = -1
            self.scrollbar_grab_offset = 0.0
            self.scrollbar_dragging = False
        _ = self.local_execution.take_dirty(0)
        self.pending.invalidate(INVALIDATE_ALL, self.root_bounds)

    def scroll_offset_for(self, id: Int) -> Float32:
        """Return the app-owned persistent offset for a scroll container id."""
        for index in range(len(self.scroll_ids)):
            if self.scroll_ids[index] == id:
                return self.scroll_values[index]
        return self.view.scroll_offset_for(id)

    def scrollbar_track_for(self, id: Int) -> Rect:
        """Return the paint-space track used by one retained scrollbar."""
        var bounds = self.root_bounds
        if id != ROOT_SCROLL_ID:
            bounds = self.view.bounds_for(id)
        var axis = self.view.scroll_axis_for(id)
        if axis == ROW_AXIS:
            return Rect(
                bounds.x + 4.0,
                bounds.y + bounds.height - 12.0,
                bounds.width - 8.0,
                8.0,
            )
        return Rect(
            bounds.x + bounds.width - 12.0,
            bounds.y + 4.0,
            8.0,
            bounds.height - 8.0,
        )

    def scrollbar_state_for(self, id: Int) -> ScrollbarState:
        """Build the portable geometry state for one painted scrollbar."""
        var axis = self.view.scroll_axis_for(id)
        var orientation = (
            SCROLLBAR_HORIZONTAL if axis == ROW_AXIS else SCROLLBAR_VERTICAL
        )
        var bounds = self.root_bounds
        if id != ROOT_SCROLL_ID:
            bounds = self.view.bounds_for(id)
        var viewport = bounds.width if axis == ROW_AXIS else bounds.height
        var maximum = self.view.scroll_max_offset(id)
        var state = ScrollbarState(orientation, 18.0)
        state.set_metrics(viewport + maximum, viewport)
        _ = state.set_offset(self.view.scroll_offset_for(id))
        return state

    def scrollbar_target_at(self, position: Point) -> Int:
        """Return the topmost painted scrollbar under a pointer position."""
        var result = -1
        for index in range(self.view.child_count()):
            var node = self.view.child(index)
            if node.kind != CONTAINER_KIND:
                continue
            if self.view.scroll_max_offset(node.id) <= 0.0:
                continue
            if (
                self.view.point_is_visible(node, position)
                and self.scrollbar_track_for(node.id).contains(position)
            ):
                result = node.id
        if (
            self.view.scroll_max_offset(ROOT_SCROLL_ID) > 0.0
            and self.scrollbar_track_for(ROOT_SCROLL_ID).contains(position)
        ):
            result = ROOT_SCROLL_ID
        return result

    def remember_scroll(mut self, id: Int, offset: Float32):
        """Record an offset so a later component rebuild preserves it."""
        for index in range(len(self.scroll_ids)):
            if self.scroll_ids[index] == id:
                self.scroll_values[index] = offset
                return
        self.scroll_ids.append(id)
        self.scroll_values.append(offset)

    def reset_scroll(mut self, id: Int):
        """Reset an app-retained scroll offset before a component rebuild."""
        for index in range(len(self.scroll_ids)):
            if self.scroll_ids[index] == id:
                self.scroll_values[index] = 0.0
        self.view.set_scroll_offset(id, 0.0)

    def apply_scroll_offsets(mut self):
        """Reapply offsets retained independently of declarative component state."""
        # Establish the current viewport/content extents before clamping an
        # offset retained from an earlier declaration.
        self.view.layout()
        for index in range(len(self.scroll_ids)):
            var id = self.scroll_ids[index]
            var maximum = self.view.scroll_max_offset(id)
            var value = self.scroll_values[index]
            if value < 0.0:
                value = 0.0
            if value > maximum:
                value = maximum
            self.scroll_values[index] = value
            self.view.set_scroll_offset(id, value)
        self.view.layout()

    def paint(mut self) -> PaintCommands:
        """Return the current backend-neutral frame command stream."""
        var commands = self.runtime.paint()
        if commands.has_dirty_region():
            var flags = INVALIDATE_CONTENT
            if commands.removed_count() > 0:
                flags |= INVALIDATE_STRUCTURE
            self.pending.invalidate(flags, commands.dirty_region())
        return commands^

    def render[RendererType: Renderer](mut self, mut renderer: RendererType) raises:
        """Paint the current frame through any Moxi renderer."""
        var commands = self.paint()
        renderer.begin_frame()
        if renderer.supports_incremental():
            for index in range(commands.removed_count()):
                renderer.clear_region(commands.removed_region(index))
            for index in range(commands.count()):
                var command = commands.command(index)
                if command.is_changed():
                    renderer.draw(command)
        else:
            for index in range(commands.count()):
                renderer.draw(commands.command(index))
        renderer.update_accessibility(self.accessibility())
        self.clear_invalidation()

    def run[
        WindowType: WindowBackend,
        RendererType: Renderer,
    ](
        mut self,
        mut window: WindowType,
        mut renderer: RendererType,
    ) raises:
        """Render once, then process backend events until the window closes."""
        self.render(renderer)
        while window.is_open():
            window.pump()
            var event = window.poll_event()
            var changed = False
            while event.kind != NONE_KIND:
                changed = self.dispatch(event) or changed
                event = window.poll_event()
            if changed:
                self.render(renderer)

    def run_with_clipboard[
        WindowType: WindowBackend,
        RendererType: Renderer,
        ClipboardType: ClipboardBackend,
    ](
        mut self,
        mut window: WindowType,
        mut renderer: RendererType,
        mut clipboard: ClipboardType,
    ) raises:
        """Run the event loop while synchronizing clipboard shortcuts."""
        self.render(renderer)
        while window.is_open():
            window.pump()
            var event = window.poll_event()
            var changed = False
            while event.kind != NONE_KIND:
                changed = self.dispatch_with_clipboard(event, clipboard) or changed
                event = window.poll_event()
            if changed:
                self.render(renderer)

    def hit_test(self, position: Point) -> Int:
        """Return the focusable view id under a point, or -1."""
        return self.runtime.hit_test(position)

    def focus_id(self) -> Int:
        """Return the currently focused view id, or -1."""
        return self.runtime.focus_id()

    def hover_id(self) -> Int:
        """Return the currently hovered view id, or -1."""
        return self.runtime.hover_id()

    def pressed_id(self) -> Int:
        """Return the currently pressed view id, or -1."""
        return self.runtime.pressed_view_id()

    def action_id(self, target: Int) -> Int:
        """Return the stable action associated with a routed target."""
        return self.runtime.action_for(target)

    def accessibility(self) -> AccessibilitySnapshot:
        """Return backend-neutral semantics for the current view tree."""
        return self.runtime.accessibility()

    def view_is_valid(self) -> Bool:
        """Return whether the currently mounted view passed tree validation."""
        return not self.runtime.validation_failed()

    def pending_invalidation(self) -> Invalidation:
        """Return the merged invalidation awaiting the next render."""
        return self.pending

    def clear_invalidation(mut self):
        """Mark the current invalidation as consumed by a renderer."""
        self.pending.clear()

    def invalidate(mut self, flags: Int, bounds: Rect):
        """Request a redraw for a backend-neutral region and reason set."""
        self.pending.invalidate(flags, bounds)
