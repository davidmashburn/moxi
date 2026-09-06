"""Dependency-scoped invalidation for localized component execution."""

from std.collections import List

from .accessibility import AccessibilitySnapshot
from .component import Component
from .event import Event
from .geometry import Rect
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

    def __init__(out self):
        self.invalidation_count = 0
        self.dependency_visits = 0
        self.dirty_marks = 0
        self.dirty_consumed = 0
        self.component_builds = 0
        self.reconciled_nodes = 0
        self.paint_commands = 0

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
        )


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

    def work_counters(self) -> ExecutionWorkCounters:
        """Return a copy of the accumulated localized work counters."""
        return self.counters

    def reset_work_counters(mut self):
        """Reset measurements while retaining scope/dependency topology."""
        self.counters = ExecutionWorkCounters()


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

    def paint(mut self):
        """Return the current retained paint stream and account for it."""
        var commands = self.runtime.paint()
        self.execution.record_paint(commands.count())
        return commands^

    def accessibility(mut self) -> AccessibilitySnapshot:
        """Return the current semantic snapshot for host publication."""
        return self.runtime.accessibility()

    def work_counters(self) -> ExecutionWorkCounters:
        return self.execution.work_counters()
