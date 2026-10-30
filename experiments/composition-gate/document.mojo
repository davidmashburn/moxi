"""The policy owner. UI components do not decide which edits are accepted."""
from std.collections import List


struct Document(ImplicitlyCopyable):
    var name: String
    var revision: Int
    var commits: Int
    var max_length: Int
    var writable: Bool
    var history: List[String]

    def __init__(out self):
        self.name = "Ada"
        self.revision = 0
        self.commits = 0
        self.max_length = 24
        self.writable = True
        self.history = List[String]()

    def __init__(out self, *, copy: Self):
        self.name = copy.name
        self.revision = copy.revision
        self.commits = copy.commits
        self.max_length = copy.max_length
        self.writable = copy.writable
        self.history = copy.history.copy()

    def rename(mut self, proposed: String, expected_revision: Int) -> String:
        if not self.writable:
            return "Document is read-only"
        if expected_revision != self.revision:
            return "Document changed; reload before applying"
        var normalized = String(proposed.strip())
        if normalized == "":
            return "Name required"
        if normalized.count_codepoints() > self.max_length:
            return "Name is too long"
        if normalized == self.name:
            return ""
        self.history.append(self.name)
        self.name = normalized
        self.revision += 1
        self.commits += 1
        return ""

    def set_max_length(mut self, limit: Int):
        self.max_length = limit

    def set_writable(mut self, writable: Bool):
        self.writable = writable

    def undo(mut self):
        if self.writable and len(self.history) > 0:
            self.name = self.history.pop()
            self.revision += 1
