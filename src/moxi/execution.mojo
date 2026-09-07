"""Dependency-scoped invalidation for localized component execution."""

from std.collections import List

from .accessibility import AccessibilitySnapshot
from .component import Component
from .component import KeyedSubtreeDescriptor
from .event import Event
from .geometry import Rect
from .paint import PaintCommands
from .reactivity import StateScope
from .runtime import ColumnRuntime
from .view import ColumnView


struct ExecutionWorkCounters(ImplicitlyCopyable):
    """Observable work accounting for one localized execution pass."""

    var invalidation_count: Int
    var dependency_visits: Int
    var dirty_marks: Int
    var dirty_consumed: Int
    var component_builds: Int
    var reconciled_nodes: Int
    var paint_commands: Int
    var parent_builds: Int
    var root_fallbacks: Int
    var keyed_insertions: Int
    var keyed_removals: Int
    var keyed_moves: Int

    def __init__(out self):
        self.invalidation_count = 0
        self.dependency_visits = 0
        self.dirty_marks = 0
        self.dirty_consumed = 0
        self.component_builds = 0
        self.reconciled_nodes = 0
        self.paint_commands = 0
        self.parent_builds = 0
        self.root_fallbacks = 0
        self.keyed_insertions = 0
        self.keyed_removals = 0
        self.keyed_moves = 0

    def total_work(self) -> Int:
        """Return a stable aggregate useful for benchmark comparisons."""
        return (
            self.invalidation_count
            + self.dependency_visits
            + self.dirty_marks
            + self.dirty_consumed
            + self.component_builds
            + self.reconciled_nodes
            + self.paint_commands
            + self.parent_builds
            + self.root_fallbacks
            + self.keyed_insertions
            + self.keyed_removals
            + self.keyed_moves
        )

    def child_builds(self) -> Int:
        """Return builder work excluding parent composition work."""
        return self.component_builds

    def record_build(mut self, node_count: Int, command_count: Int):
        self.component_builds += 1
        if node_count > 0:
            self.reconciled_nodes += node_count
        if command_count > 0:
            self.paint_commands += command_count

    def record_parent_build(mut self):
        self.parent_builds += 1

    def record_root_fallback(mut self):
        self.root_fallbacks += 1

    def record_keyed_insertion(mut self):
        self.keyed_insertions += 1

    def record_keyed_removal(mut self):
        self.keyed_removals += 1

    def record_keyed_move(mut self):
        self.keyed_moves += 1


struct DependencyEdge(ImplicitlyCopyable):
    """One component's dependency on a state scope."""

    var component_id: Int
    var scope_id: Int

    def __init__(out self, component_id: Int, scope_id: Int):
        self.component_id = component_id
        self.scope_id = scope_id


struct LocalizedExecution:
    """Track dirty components without rebuilding unrelated scopes.

    The executor records dependency topology but does not store callbacks.
    Callers run their typed component/build functions after `take_dirty()`;
    this keeps execution local and preserves Mojo's static ownership boundary.
    """

    var scopes: List[StateScope]
    var dependencies: List[DependencyEdge]
    var dirty_components: List[Int]
    var build_counts: List[Int]
    var counters: ExecutionWorkCounters

    def __init__(out self):
        self.scopes = List[StateScope]()
        self.dependencies = List[DependencyEdge]()
        self.dirty_components = List[Int]()
        self.build_counts = List[Int]()
        self.counters = ExecutionWorkCounters()

    def add_scope(mut self, id: Int, parent_id: Int = -1) -> Bool:
        if id < 0 or self.scope_index(id) != -1:
            return False
        if parent_id != -1 and self.scope_index(parent_id) == -1:
            return False
        self.scopes.append(StateScope(id, parent_id))
        return True

    def add_dependency(mut self, component_id: Int, scope_id: Int) -> Bool:
        if component_id < 0 or self.scope_index(scope_id) == -1:
            return False
        for index in range(len(self.dependencies)):
            var edge = self.dependencies[index]
            if edge.component_id == component_id and edge.scope_id == scope_id:
                return False
        self.dependencies.append(DependencyEdge(component_id, scope_id))
        return True

    def scope_index(self, id: Int) -> Int:
        for index in range(len(self.scopes)):
            if self.scopes[index].id == id:
                return index
        return -1

    def component_is_dirty(self, id: Int) -> Bool:
        for index in range(len(self.dirty_components)):
            if self.dirty_components[index] == id:
                return True
        return False

    def _mark_dirty(mut self, component_id: Int):
        if self.component_is_dirty(component_id):
            return
        self.dirty_components.append(component_id)
        self.counters.dirty_marks += 1
        while len(self.build_counts) <= component_id:
            self.build_counts.append(0)

    def _depends_on_scope(self, scope_id: Int, ancestor_id: Int) -> Bool:
        """Return whether a scope is the ancestor or descendant of another."""
        var current = scope_id
        var hops = 0
        while current != -1 and hops <= len(self.scopes):
            if current == ancestor_id:
                return True
            var index = self.scope_index(current)
            if index == -1:
                return False
            current = self.scopes[index].parent_id
            hops += 1
        return False

    def invalidate_scope(mut self, scope_id: Int) -> Bool:
        var index = self.scope_index(scope_id)
        if index == -1:
            return False
        self.counters.invalidation_count += 1
        self.scopes[index].invalidate()
        for dependency_index in range(len(self.dependencies)):
            var edge = self.dependencies[dependency_index]
            self.counters.dependency_visits += 1
            if self._depends_on_scope(edge.scope_id, scope_id):
                self._mark_dirty(edge.component_id)
        return True

    def take_dirty(mut self, component_id: Int) -> Bool:
        """Consume one component invalidation and return whether it was dirty."""
        var found = -1
        for index in range(len(self.dirty_components)):
            if self.dirty_components[index] == component_id:
                found = index
                break
        if found == -1:
            return False
        var remaining = List[Int]()
        for index in range(len(self.dirty_components)):
            if index != found:
                remaining.append(self.dirty_components[index])
        self.dirty_components = remaining^
        while len(self.build_counts) <= component_id:
            self.build_counts.append(0)
        self.build_counts[component_id] += 1
        self.counters.dirty_consumed += 1
        return True

    def clear_scope(mut self, scope_id: Int) -> Bool:
        var index = self.scope_index(scope_id)
        if index == -1:
            return False
        self.scopes[index].clear()
        return True

    def dirty_count(self) -> Int:
        return len(self.dirty_components)

    def build_count(self, component_id: Int) -> Int:
        if component_id < 0 or component_id >= len(self.build_counts):
            return 0
        return self.build_counts[component_id]

    def record_build(mut self, node_count: Int, command_count: Int):
        """Record actual typed-subtree build/reconcile work."""
        self.counters.component_builds += 1
        if node_count > 0:
            self.counters.reconciled_nodes += node_count
        if command_count > 0:
            self.counters.paint_commands += command_count

    def record_paint(mut self, command_count: Int):
        """Record a paint request without claiming another component build."""
        if command_count > 0:
            self.counters.paint_commands += command_count

    def record_parent_build(mut self):
        """Record composition of a parent without attributing child builds."""
        self.counters.parent_builds += 1

    def record_root_fallback(mut self):
        """Record work that still requires rebuilding the root parent."""
        self.counters.root_fallbacks += 1

    def record_keyed_insertion(mut self):
        self.counters.keyed_insertions += 1

    def record_keyed_removal(mut self):
        self.counters.keyed_removals += 1

    def record_keyed_move(mut self):
        self.counters.keyed_moves += 1

    def work_counters(self) -> ExecutionWorkCounters:
        """Return a copy of the accumulated localized work counters."""
        return self.counters

    def reset_work_counters(mut self):
        """Reset measurements while retaining scope/dependency topology."""
        self.counters = ExecutionWorkCounters()


struct KeyedSubtreeSchedule:
    """Key-indexed parent/child scheduling and structural diff accounting.

    The schedule deliberately stores descriptors, not erased callbacks. A
    typed owner (``KeyedSubtreeExecutor`` below) supplies the child builder and
    retains the child state. This keeps the scheduling contract deterministic
    while preserving Mojo's static ownership boundary.
    """

    var parent_scope_id: Int
    var descriptors: List[KeyedSubtreeDescriptor]
    var order: List[Int]
    var dirty_keys: List[Int]
    var parent_fallback_pending: Bool
    var counters: ExecutionWorkCounters

    def __init__(out self, parent_scope_id: Int = 0):
        self.parent_scope_id = parent_scope_id
        self.descriptors = List[KeyedSubtreeDescriptor]()
        self.order = List[Int]()
        self.dirty_keys = List[Int]()
        self.parent_fallback_pending = False
        self.counters = ExecutionWorkCounters()

    def descriptor_index(self, key: Int) -> Int:
        for index in range(len(self.descriptors)):
            if self.descriptors[index].key == key:
                return index
        return -1

    def order_index(self, key: Int) -> Int:
        for index in range(len(self.order)):
            if self.order[index] == key:
                return index
        return -1

    def descriptor(self, key: Int) -> KeyedSubtreeDescriptor:
        var index = self.descriptor_index(key)
        if index == -1:
            return KeyedSubtreeDescriptor(-1, -1, -1, -1, 0)
        return self.descriptors[index]

    def active_key(self, index: Int) -> Int:
        if index < 0 or index >= len(self.order):
            return -1
        return self.order[index]

    def active_count(self) -> Int:
        return len(self.order)

    def register(mut self, descriptor: KeyedSubtreeDescriptor) -> Bool:
        if descriptor.key < 0 or self.descriptor_index(descriptor.key) != -1:
            return False
        if (
            descriptor.slot_id < 0
            or descriptor.scope_id < 0
            or descriptor.component_id < 0
            or descriptor.id_offset < 0
        ):
            return False
        self.descriptors.append(descriptor)
        self.order.append(descriptor.key)
        self.counters.record_keyed_insertion()
        return True

    def remove(mut self, key: Int) -> Bool:
        var descriptor_index = self.descriptor_index(key)
        var order_index = self.order_index(key)
        if descriptor_index == -1 or order_index == -1:
            return False
        _ = self.descriptors.pop(descriptor_index)
        _ = self.order.pop(order_index)
        self.remove_dirty(key)
        self.counters.record_keyed_removal()
        return True

    def reorder(mut self, next_order: List[Int]) -> Bool:
        if len(next_order) != len(self.order):
            return False
        for left in range(len(next_order)):
            if self.descriptor_index(next_order[left]) == -1:
                return False
            for right in range(left):
                if next_order[left] == next_order[right]:
                    return False
        var moved = 0
        for index in range(len(next_order)):
            if next_order[index] != self.order[index]:
                moved += 1
        self.order = next_order.copy()
        for _ in range(moved):
            self.counters.record_keyed_move()
        return True

    def invalidate_child(mut self, key: Int) -> Bool:
        if self.descriptor_index(key) == -1:
            return False
        for index in range(len(self.dirty_keys)):
            if self.dirty_keys[index] == key:
                return True
        self.dirty_keys.append(key)
        return True

    def invalidate_parent(mut self) -> Bool:
        """Mark all active children dirty and count the root fallback once."""
        self.parent_fallback_pending = True
        self.counters.record_root_fallback()
        for index in range(len(self.order)):
            _ = self.invalidate_child(self.order[index])
        return True

    def root_fallback_pending(self) -> Bool:
        return self.parent_fallback_pending

    def consume_parent_fallback(mut self) -> Bool:
        if not self.parent_fallback_pending:
            return False
        self.parent_fallback_pending = False
        self.counters.record_parent_build()
        return True

    def is_dirty(self, key: Int) -> Bool:
        for index in range(len(self.dirty_keys)):
            if self.dirty_keys[index] == key:
                return True
        return False

    def take_dirty(mut self, key: Int) -> Bool:
        for index in range(len(self.dirty_keys)):
            if self.dirty_keys[index] == key:
                _ = self.dirty_keys.pop(index)
                return True
        return False

    def remove_dirty(mut self, key: Int):
        for index in range(len(self.dirty_keys)):
            if self.dirty_keys[index] == key:
                _ = self.dirty_keys.pop(index)
                return

    def dirty_count(self) -> Int:
        return len(self.dirty_keys)

    def record_child_build(mut self, node_count: Int, command_count: Int):
        self.counters.record_build(node_count, command_count)

    def record_parent_build(mut self):
        self.counters.record_parent_build()

    def work_counters(self) -> ExecutionWorkCounters:
        return self.counters


struct KeyedChildExecutor[Child: Component & Deinitable]:
    """One retained typed child paired with its stable subtree descriptor."""

    var descriptor: KeyedSubtreeDescriptor
    var executor: TypedSubtreeExecutor[Self.Child]

    def __init__(
        out self,
        descriptor: KeyedSubtreeDescriptor,
        component: Self.Child,
        bounds: Rect,
    ):
        self.descriptor = descriptor
        self.executor = TypedSubtreeExecutor[Self.Child](
            component,
            bounds,
            descriptor.component_id,
            descriptor.scope_id,
        )


struct KeyedSubtreeExecutor[Child: Component & Deinitable]:
    """Retain typed children by key and rebuild only dirty child builders."""

    var schedule: KeyedSubtreeSchedule
    var children: List[KeyedChildExecutor[Self.Child]]

    def __init__(out self, parent_scope_id: Int = 0):
        self.schedule = KeyedSubtreeSchedule(parent_scope_id)
        self.children = List[KeyedChildExecutor[Self.Child]]()

    def child_index(self, key: Int) -> Int:
        for index in range(len(self.children)):
            if self.children[index].descriptor.key == key:
                return index
        return -1

    def insert(
        mut self,
        descriptor: KeyedSubtreeDescriptor,
        component: Self.Child,
        bounds: Rect,
    ) -> Bool:
        if self.child_index(descriptor.key) != -1:
            return False
        if not self.schedule.register(descriptor):
            return False
        self.children.append(KeyedChildExecutor[Self.Child](descriptor, component, bounds))
        var child_index = len(self.children) - 1
        var child_counters = self.children[child_index].executor.work_counters()
        self.schedule.record_child_build(
            child_counters.reconciled_nodes,
            child_counters.paint_commands,
        )
        return True

    def remove(mut self, key: Int) -> Bool:
        var index = self.child_index(key)
        if index == -1 or not self.schedule.remove(key):
            return False
        _ = self.children.pop(index)
        return True

    def reorder(mut self, next_order: List[Int]) -> Bool:
        return self.schedule.reorder(next_order)

    def invalidate_child(mut self, key: Int) -> Bool:
        return self.schedule.invalidate_child(key)

    def invalidate_parent(mut self) -> Bool:
        return self.schedule.invalidate_parent()

    def rebuild_dirty(mut self) -> Int:
        var rebuilt = 0
        while self.schedule.dirty_count() > 0:
            var key = self.schedule.dirty_keys[0]
            _ = self.schedule.take_dirty(key)
            var index = self.child_index(key)
            if index == -1:
                continue
            _ = self.children[index].executor.invalidate()
            if self.children[index].executor.rebuild_if_dirty():
                rebuilt += 1
                var child_counters = self.children[index].executor.work_counters()
                self.schedule.record_child_build(
                    child_counters.reconciled_nodes,
                    child_counters.paint_commands,
                )
        return rebuilt

    def dispatch_child(mut self, key: Int, event: Event) -> Bool:
        var index = self.child_index(key)
        if index == -1:
            return False
        var changed = self.children[index].executor.dispatch(event)
        if changed:
            self.schedule.record_child_build(
                self.children[index].executor.view.child_count(),
                self.children[index].executor.runtime.paint().count(),
            )
        return changed

    def build_parent(mut self, bounds: Rect, parent_id: Int = -1) -> ColumnView:
        """Compose retained child views without invoking child builders."""
        var parent = ColumnView(bounds, 0.0, 0.0)
        for index in range(self.schedule.active_count()):
            var key = self.schedule.active_key(index)
            var child_index = self.child_index(key)
            if child_index == -1:
                continue
            var descriptor = self.children[child_index].descriptor
            var child_view = self.children[child_index].executor.view.clone()
            parent.add_component_view_to(
                parent_id,
                descriptor.slot_id,
                child_view,
                descriptor.id_offset,
            )
        parent.layout()
        if not self.schedule.consume_parent_fallback():
            self.schedule.record_parent_build()
        return parent^

    def child_build_count(self, key: Int) -> Int:
        var index = self.child_index(key)
        if index == -1:
            return 0
        return self.children[index].executor.work_counters().component_builds

    def child_view(self, key: Int) -> ColumnView:
        var index = self.child_index(key)
        if index == -1:
            return ColumnView(Rect(0.0, 0.0, 0.0, 0.0), 0.0, 0.0)
        return self.children[index].executor.view.clone()

    def active_count(self) -> Int:
        return self.schedule.active_count()

    def active_key(self, index: Int) -> Int:
        return self.schedule.active_key(index)

    def dirty_count(self) -> Int:
        return self.schedule.dirty_count()

    def work_counters(self) -> ExecutionWorkCounters:
        return self.schedule.work_counters()


struct TypedSubtreeExecutor[ComponentType: Component & Deinitable]:
    """Execute one typed component without rebuilding its parent application.

    The executor owns only a component, its projected view, and a retained
    ``ColumnRuntime``. Invalidation travels through ``LocalizedExecution``;
    callers can inspect work counters to prove unrelated scopes were not
    rebuilt.
    """

    var component: Self.ComponentType
    var bounds: Rect
    var view: ColumnView
    var runtime: ColumnRuntime
    var execution: LocalizedExecution
    var component_id: Int
    var scope_id: Int
    var mounted: Bool

    def __init__(
        out self,
        component: Self.ComponentType,
        bounds: Rect,
        component_id: Int = 0,
        scope_id: Int = 0,
    ):
        self.component = component
        self.bounds = bounds
        self.view = ColumnView(bounds, 0.0, 0.0)
        self.runtime = ColumnRuntime()
        self.execution = LocalizedExecution()
        self.component_id = component_id if component_id >= 0 else 0
        self.scope_id = scope_id if scope_id >= 0 else 0
        self.mounted = False
        _ = self.execution.add_scope(self.scope_id)
        _ = self.execution.add_dependency(self.component_id, self.scope_id)
        self.mount()

    def mount(mut self):
        """Build and reconcile the typed subtree once."""
        self.view = self.component.build(self.bounds)
        self.runtime.reconcile(self.view)
        var commands = self.runtime.paint()
        self.execution.record_build(self.view.child_count(), commands.count())
        self.mounted = True

    def invalidate(mut self) -> Bool:
        """Invalidate only this subtree's declared state scope."""
        return self.execution.invalidate_scope(self.scope_id)

    def rebuild_if_dirty(mut self) -> Bool:
        """Rebuild after a matching invalidation, otherwise do no work."""
        if not self.execution.take_dirty(self.component_id):
            return False
        self.mount()
        _ = self.execution.clear_scope(self.scope_id)
        return True

    def dispatch(mut self, event: Event) -> Bool:
        """Update the typed component and rebuild only when it changed."""
        var changed = self.component.update(event, self.view)
        if not changed:
            return False
        _ = self.invalidate()
        return self.rebuild_if_dirty()

    def paint(mut self) -> PaintCommands:
        """Return the current retained paint stream and account for it."""
        var commands = self.runtime.paint()
        self.execution.record_paint(commands.count())
        return commands^

    def accessibility(mut self) -> AccessibilitySnapshot:
        """Return the current semantic snapshot for host publication."""
        return self.runtime.accessibility()

    def work_counters(self) -> ExecutionWorkCounters:
        return self.execution.work_counters()
