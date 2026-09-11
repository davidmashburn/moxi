"""Dependency-scoped invalidation for localized component execution."""

from std.collections import List

from .accessibility import AccessibilitySnapshot
from .component import Component
from .component import KeyedSubtreeDescriptor
from .event import Event
from .geometry import Rect
from .paint import PaintCommands
from .reactivity import StateScope
from .column_runtime import ColumnRuntime
from .column_view import ColumnView


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


struct DependencyBucket(ImplicitlyCopyable):
    """A contiguous fanout range for one state scope."""

    var scope_id: Int
    var start: Int
    var count: Int

    def __init__(out self, scope_id: Int, start: Int = 0, count: Int = 0):
        self.scope_id = scope_id
        self.start = start
        self.count = count


struct DependencyFanoutIndex:
    """Deterministic scope-to-component fanout without edge-wide scans.

    ``LocalizedExecution.dependencies`` remains the source of truth and keeps
    insertion order for diagnostics. This derived index groups component ids
    by scope so invalidation visits only the fanout of the invalidated scope
    and its descendants. Rebuilding the compact index when topology changes is
    intentionally simple; invalidation is the hot path and dependency
    registration is comparatively rare.
    """

    var buckets: List[DependencyBucket]
    var bucket_lookup: IntIndex
    var components: List[Int]

    def __init__(out self):
        self.buckets = List[DependencyBucket]()
        self.bucket_lookup = IntIndex()
        self.components = List[Int]()

    def clear(mut self):
        self.buckets = List[DependencyBucket]()
        self.bucket_lookup.clear()
        self.components = List[Int]()

    def rebuild(mut self, dependencies: List[DependencyEdge]):
        """Regroup the current dependency topology deterministically."""
        self.clear()
        for index in range(len(dependencies)):
            var scope_id = dependencies[index].scope_id
            if self.bucket_lookup.find(scope_id) == -1:
                self.buckets.append(DependencyBucket(scope_id))
                _ = self.bucket_lookup.set(
                    scope_id,
                    len(self.buckets) - 1,
                )

        # Build each bucket as one contiguous range. The dependency list stays
        # in caller insertion order within a scope, which keeps diagnostics and
        # dirty-mark ordering stable.
        for bucket_index in range(len(self.buckets)):
            var bucket = self.buckets[bucket_index]
            bucket.start = len(self.components)
            bucket.count = 0
            for dependency_index in range(len(dependencies)):
                var edge = dependencies[dependency_index]
                if edge.scope_id == bucket.scope_id:
                    self.components.append(edge.component_id)
                    bucket.count += 1
            self.buckets[bucket_index] = bucket

    def bucket_index(self, scope_id: Int) -> Int:
        return self.bucket_lookup.find(scope_id)

    def bucket(self, scope_id: Int) -> DependencyBucket:
        var index = self.bucket_index(scope_id)
        if index == -1:
            return DependencyBucket(-1)
        return self.buckets[index]

    def component(self, index: Int) -> Int:
        if index < 0 or index >= len(self.components):
            return -1
        return self.components[index]


struct IntIndexEntry(ImplicitlyCopyable):
    """One stable integer key and its current dense position."""

    var key: Int
    var value: Int

    def __init__(out self, key: Int, value: Int):
        self.key = key
        self.value = value


struct IntIndex:
    """Deterministic sorted index for stable non-negative integer identities.

    The topology containers keep their dense storage in ordinary lists because
    order and ownership are observable. This companion index keeps identity
    lookup bounded by binary search while allowing positions to be rebuilt
    after insertion, removal, or reorder. It deliberately has no hash-table
    seed or host-dependent behavior.
    """

    var entries: List[IntIndexEntry]

    def __init__(out self):
        self.entries = List[IntIndexEntry]()

    def _position(self, key: Int) -> Int:
        if key < 0:
            return -1
        var low = 0
        var high = len(self.entries)
        while low < high:
            var middle = (low + high) // 2
            if self.entries[middle].key < key:
                low = middle + 1
            else:
                high = middle
        return low if low < len(self.entries) and self.entries[low].key == key else -1

    def find(self, key: Int) -> Int:
        var position = self._position(key)
        if position == -1:
            return -1
        return self.entries[position].value

    def set(mut self, key: Int, value: Int) -> Bool:
        if key < 0 or value < 0:
            return False
        var position = self._position(key)
        if position != -1:
            self.entries[position].value = value
            return True
        if len(self.entries) == 0 or key > self.entries[len(self.entries) - 1].key:
            self.entries.append(IntIndexEntry(key, value))
            return True
        var low = 0
        var high = len(self.entries)
        while low < high:
            var middle = (low + high) // 2
            if self.entries[middle].key < key:
                low = middle + 1
            else:
                high = middle
        var next = List[IntIndexEntry](capacity=len(self.entries) + 1)
        for index in range(len(self.entries) + 1):
            if index == low:
                next.append(IntIndexEntry(key, value))
            else:
                var source = index if index < low else index - 1
                next.append(self.entries[source])
        self.entries = next^
        return True

    def remove(mut self, key: Int) -> Bool:
        var position = self._position(key)
        if position == -1:
            return False
        if position == len(self.entries) - 1:
            _ = self.entries.pop(position)
            return True
        var next = List[IntIndexEntry](capacity=len(self.entries) - 1)
        for index in range(len(self.entries)):
            if index != position:
                next.append(self.entries[index])
        self.entries = next^
        return True

    def clear(mut self):
        self.entries = List[IntIndexEntry]()

    def count(self) -> Int:
        return len(self.entries)


struct LocalizedExecution:
    """Track dirty components without rebuilding unrelated scopes.

    The executor records dependency topology but does not store callbacks.
    Callers run their typed component/build functions after `take_dirty()`;
    this keeps execution local and preserves Mojo's static ownership boundary.
    """

    var scopes: List[StateScope]
    var scope_lookup: IntIndex
    var dependencies: List[DependencyEdge]
    var dependency_fanout: DependencyFanoutIndex
    var dirty_components: List[Int]
    var dirty_lookup: IntIndex
    var build_counts: List[Int]
    var counters: ExecutionWorkCounters

    def __init__(out self):
        self.scopes = List[StateScope]()
        self.scope_lookup = IntIndex()
        self.dependencies = List[DependencyEdge]()
        self.dependency_fanout = DependencyFanoutIndex()
        self.dirty_components = List[Int]()
        self.dirty_lookup = IntIndex()
        self.build_counts = List[Int]()
        self.counters = ExecutionWorkCounters()

    def add_scope(mut self, id: Int, parent_id: Int = -1) -> Bool:
        if id < 0 or self.scope_index(id) != -1:
            return False
        if parent_id != -1 and self.scope_index(parent_id) == -1:
            return False
        self.scopes.append(StateScope(id, parent_id))
        _ = self.scope_lookup.set(id, len(self.scopes) - 1)
        return True

    def add_dependency(mut self, component_id: Int, scope_id: Int) -> Bool:
        if component_id < 0 or self.scope_index(scope_id) == -1:
            return False
        for index in range(len(self.dependencies)):
            var edge = self.dependencies[index]
            if edge.component_id == component_id and edge.scope_id == scope_id:
                return False
        self.dependencies.append(DependencyEdge(component_id, scope_id))
        self.dependency_fanout.rebuild(self.dependencies)
        return True

    def scope_index(self, id: Int) -> Int:
        return self.scope_lookup.find(id)

    def component_is_dirty(self, id: Int) -> Bool:
        return self.dirty_lookup.find(id) != -1

    def _mark_dirty(mut self, component_id: Int):
        if self.component_is_dirty(component_id):
            return
        self.dirty_components.append(component_id)
        _ = self.dirty_lookup.set(
            component_id,
            len(self.dirty_components) - 1,
        )
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
        # Walk the scope tree, then consume only the indexed fanout for each
        # matching scope. This avoids visiting unrelated dependency edges.
        for scope_index in range(len(self.scopes)):
            var candidate = self.scopes[scope_index]
            if not self._depends_on_scope(candidate.id, scope_id):
                continue
            var fanout = self.dependency_fanout.bucket(candidate.id)
            for offset in range(fanout.count):
                self.counters.dependency_visits += 1
                self._mark_dirty(
                    self.dependency_fanout.component(fanout.start + offset)
                )
        return True

    def _remove_dirty(mut self, component_id: Int) -> Bool:
        """Drop one dirty entry and report whether it was present."""
        var found = self.dirty_lookup.find(component_id)
        if found == -1:
            return False
        var last = len(self.dirty_components) - 1
        if found != last:
            var moved = self.dirty_components[last]
            self.dirty_components[found] = moved
            _ = self.dirty_lookup.set(moved, found)
        _ = self.dirty_components.pop(last)
        _ = self.dirty_lookup.remove(component_id)
        self.counters.dirty_consumed += 1
        return True

    def take_dirty(mut self, component_id: Int) -> Bool:
        """Consume one component invalidation ahead of a rebuild."""
        if not self._remove_dirty(component_id):
            return False
        while len(self.build_counts) <= component_id:
            self.build_counts.append(0)
        self.build_counts[component_id] += 1
        return True

    def discard_dirty(mut self, component_id: Int) -> Bool:
        """Consume one component invalidation that no rebuild will follow.

        Retained updates settle their own output, so the per-component build
        count must not advance for work that never ran a builder.
        """
        return self._remove_dirty(component_id)

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
    var descriptor_lookup: IntIndex
    var order: List[Int]
    var order_lookup: IntIndex
    var dirty_keys: List[Int]
    var dirty_lookup: IntIndex
    var parent_fallback_pending: Bool
    var counters: ExecutionWorkCounters

    def __init__(out self, parent_scope_id: Int = 0):
        self.parent_scope_id = parent_scope_id
        self.descriptors = List[KeyedSubtreeDescriptor]()
        self.descriptor_lookup = IntIndex()
        self.order = List[Int]()
        self.order_lookup = IntIndex()
        self.dirty_keys = List[Int]()
        self.dirty_lookup = IntIndex()
        self.parent_fallback_pending = False
        self.counters = ExecutionWorkCounters()

    def descriptor_index(self, key: Int) -> Int:
        return self.descriptor_lookup.find(key)

    def order_index(self, key: Int) -> Int:
        return self.order_lookup.find(key)

    def _reindex_descriptors(mut self):
        for index in range(len(self.descriptors)):
            _ = self.descriptor_lookup.set(
                self.descriptors[index].key,
                index,
            )

    def _reindex_order(mut self):
        self.order_lookup.clear()
        for index in range(len(self.order)):
            _ = self.order_lookup.set(self.order[index], index)

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
        _ = self.descriptor_lookup.set(
            descriptor.key,
            len(self.descriptors) - 1,
        )
        self.order.append(descriptor.key)
        _ = self.order_lookup.set(descriptor.key, len(self.order) - 1)
        self.counters.record_keyed_insertion()
        return True

    def remove(mut self, key: Int) -> Bool:
        var descriptor_index = self.descriptor_index(key)
        var order_index = self.order_index(key)
        if descriptor_index == -1 or order_index == -1:
            return False
        _ = self.descriptors.pop(descriptor_index)
        _ = self.order.pop(order_index)
        _ = self.descriptor_lookup.remove(key)
        _ = self.order_lookup.remove(key)
        self._reindex_descriptors()
        self._reindex_order()
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
        self._reindex_order()
        for _ in range(moved):
            self.counters.record_keyed_move()
        return True

    def invalidate_child(mut self, key: Int) -> Bool:
        if self.descriptor_index(key) == -1:
            return False
        if self.dirty_lookup.find(key) != -1:
            return True
        self.dirty_keys.append(key)
        _ = self.dirty_lookup.set(key, len(self.dirty_keys) - 1)
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
        return self.dirty_lookup.find(key) != -1

    def take_dirty(mut self, key: Int) -> Bool:
        var found = self.dirty_lookup.find(key)
        if found == -1:
            return False
        var remaining = List[Int](capacity=len(self.dirty_keys) - 1)
        for index in range(len(self.dirty_keys)):
            if index != found:
                remaining.append(self.dirty_keys[index])
        self.dirty_keys = remaining^
        self.dirty_lookup.clear()
        for index in range(len(self.dirty_keys)):
            _ = self.dirty_lookup.set(self.dirty_keys[index], index)
        return True

    def remove_dirty(mut self, key: Int):
        _ = self.take_dirty(key)

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
    var child_lookup: IntIndex

    def __init__(out self, parent_scope_id: Int = 0):
        self.schedule = KeyedSubtreeSchedule(parent_scope_id)
        self.children = List[KeyedChildExecutor[Self.Child]]()
        self.child_lookup = IntIndex()

    def child_index(self, key: Int) -> Int:
        return self.child_lookup.find(key)

    def _reindex_children(mut self):
        for index in range(len(self.children)):
            _ = self.child_lookup.set(
                self.children[index].descriptor.key,
                index,
            )

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
        _ = self.child_lookup.set(descriptor.key, len(self.children) - 1)
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
        _ = self.child_lookup.remove(key)
        self._reindex_children()
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
        var retained = self.component.update_retained(event, self.view)
        if retained:
            _ = self.invalidate()
            _ = self.execution.discard_dirty(self.component_id)
            _ = self.execution.clear_scope(self.scope_id)
            return True
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
