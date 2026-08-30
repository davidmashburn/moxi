"""Small value-oriented reactivity contracts for Moxi components.

Moxi intentionally does not hide state mutation behind a dynamic callback
registry. These types make the useful parts of a view-driven reactive model
explicit: versions, scoped invalidation, a concrete string lens, memo keys,
and typed action messages. Applications may layer richer domain state on top.
"""

from std.collections import List


struct StateVersion(ImplicitlyCopyable):
    """Monotonic version used as a dependency token."""

    var value: Int

    def __init__(out self, value: Int = 0):
        self.value = value if value >= 0 else 0

    def advance(mut self):
        self.value += 1

    def changed_since(self, previous: StateVersion) -> Bool:
        return self.value != previous.value


struct StateScope(ImplicitlyCopyable):
    """A named invalidation scope with an optional parent scope."""

    var id: Int
    var parent_id: Int
    var version: StateVersion
    var dirty: Bool

    def __init__(out self, id: Int, parent_id: Int = -1):
        self.id = id
        self.parent_id = parent_id
        self.version = StateVersion()
        self.dirty = False

    def invalidate(mut self):
        self.version.advance()
        self.dirty = True

    def clear(mut self):
        self.dirty = False


struct StringLens(ImplicitlyCopyable):
    """A concrete slice lens useful for form fields and small state records."""

    var id: Int
    var start: Int
    var end: Int

    def __init__(out self, id: Int, start: Int, end: Int):
        self.id = id
        self.start = start if start >= 0 else 0
        self.end = end if end >= self.start else self.start

    def read(self, source: String) -> String:
        var length = source.count_codepoints()
        var left = self.start if self.start <= length else length
        var right = self.end if self.end <= length else length
        if right < left:
            right = left
        return String(source[codepoint=left:right])

    def write(self, source: String, value: String) -> String:
        var length = source.count_codepoints()
        var left = self.start if self.start <= length else length
        var right = self.end if self.end <= length else length
        if right < left:
            right = left
        var result = String(source[codepoint=0:left])
        result += value
        result += source[codepoint=right:]
        return result


struct MemoKey(ImplicitlyCopyable):
    """Identity plus dependency version for a memoized computation."""

    var id: Int
    var dependency: StateVersion

    def __init__(out self, id: Int, dependency: StateVersion):
        self.id = id
        self.dependency = dependency

    def matches(self, other: MemoKey) -> Bool:
        return self.id == other.id and self.dependency.value == other.dependency.value


struct StringMemo(ImplicitlyCopyable):
    """A caller-populated memo slot with explicit dependency validation."""

    var key: MemoKey
    var value: String
    var valid: Bool

    def __init__(out self, id: Int = 0):
        self.key = MemoKey(id, StateVersion())
        self.value = ""
        self.valid = False

    def is_valid(self, dependency: StateVersion) -> Bool:
        return self.valid and self.key.dependency.value == dependency.value

    def remember(mut self, id: Int, dependency: StateVersion, value: String):
        self.key = MemoKey(id, dependency)
        self.value = value
        self.valid = True

    def invalidate(mut self):
        self.valid = False


struct ActionMessage(ImplicitlyCopyable):
    """A typed-by-id action payload crossing a component boundary."""

    var id: Int
    var payload: String

    def __init__(out self, id: Int = -1, payload: String = ""):
        self.id = id
        self.payload = payload


struct ActionQueue:
    """Bounded FIFO for explicit application actions."""

    var messages: List[ActionMessage]
    var head: Int
    var count_value: Int
    var capacity_value: Int
    var dropped_value: Int

    def __init__(out self, capacity: Int = 32):
        self.messages = List[ActionMessage]()
        self.head = 0
        self.count_value = 0
        self.capacity_value = capacity if capacity > 0 else 1
        self.dropped_value = 0

    def enqueue(mut self, message: ActionMessage) -> Bool:
        if self.count_value >= self.capacity_value:
            self.dropped_value += 1
            return False
        self.compact()
        self.messages.append(message)
        self.count_value += 1
        return True

    def compact(mut self):
        """Reclaim dequeued storage before the next bounded append."""
        if self.head == 0:
            return
        var active = List[ActionMessage]()
        for index in range(self.head, len(self.messages)):
            active.append(self.messages[index])
        self.messages = active^
        self.head = 0

    def capacity(self) -> Int:
        return self.capacity_value

    def set_capacity(mut self, capacity: Int) -> Bool:
        """Change the queue limit without discarding pending messages."""
        if capacity <= 0 or capacity < self.count_value:
            return False
        self.capacity_value = capacity
        return True

    def has_next(self) -> Bool:
        return self.count_value > 0

    def dequeue(mut self) -> ActionMessage:
        if self.count_value == 0:
            return ActionMessage()
        var message = self.messages[self.head]
        self.head += 1
        self.count_value -= 1
        if self.count_value == 0:
            self.messages = List[ActionMessage]()
            self.head = 0
        return message

    def count(self) -> Int:
        return self.count_value

    def dropped_count(self) -> Int:
        return self.dropped_value
