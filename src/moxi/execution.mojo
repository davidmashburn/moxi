"""Dependency-scoped invalidation for localized component execution."""

from std.collections import List

from .reactivity import StateScope


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

    def __init__(out self):
        self.scopes = List[StateScope]()
        self.dependencies = List[DependencyEdge]()
        self.dirty_components = List[Int]()
        self.build_counts = List[Int]()

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
        self.scopes[index].invalidate()
        for dependency_index in range(len(self.dependencies)):
            var edge = self.dependencies[dependency_index]
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
