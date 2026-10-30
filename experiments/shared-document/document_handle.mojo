"""Shared owner operations. Underscored storage is a convention, not a security boundary."""
from std.memory import ArcPointer
from document import Document


struct DocumentHandle(ImplicitlyCopyable):
    var _storage: ArcPointer[Document]

    def __init__(out self):
        self._storage = ArcPointer(Document())

    def name(self) -> String:
        return self._storage[].name

    def revision(self) -> Int:
        return self._storage[].revision

    def commits(self) -> Int:
        return self._storage[].commits

    def history_count(self) -> Int:
        return len(self._storage[].history)

    def snapshot(self) -> Document:
        return self._storage[]

    def rename(self, proposed: String, expected_revision: Int) -> String:
        return self._storage[].rename(proposed, expected_revision)

    def set_max_length(self, limit: Int):
        self._storage[].set_max_length(limit)

    def set_writable(self, writable: Bool):
        self._storage[].set_writable(writable)

    def undo(self):
        self._storage[].undo()
