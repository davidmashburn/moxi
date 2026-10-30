"""Same editor contract with explicit document identity and separate settings."""
from std.collections import List

struct Settings(ImplicitlyCopyable):
    var max_length: Int
    var writable: Bool
    var unrelated: Int
    def __init__(out self):
        self.max_length = 24
        self.writable = True
        self.unrelated = 0

struct Document(ImplicitlyCopyable):
    var identity: Int
    var name: String
    var revision: Int
    var commits: Int
    var history: List[String]
    def __init__(out self, identity: Int = 1, name: String = "Ada"):
        self.identity = identity
        self.name = name
        self.revision = 0
        self.commits = 0
        self.history = List[String]()

    def __init__(out self, *, copy: Self):
        self.identity = copy.identity
        self.name = copy.name
        self.revision = copy.revision
        self.commits = copy.commits
        self.history = copy.history.copy()

    def rename(mut self, proposed: String, identity: Int, revision: Int, settings: Settings) -> String:
        if not settings.writable:
            return "Document is read-only"
        if identity != self.identity or revision != self.revision:
            return "Document changed; reload before applying"
        var normalized = String(proposed.strip())
        if normalized == "":
            return "Name required"
        if normalized.count_codepoints() > settings.max_length:
            return "Name is too long"
        if normalized != self.name:
            self.history.append(self.name)
            self.name = normalized
            self.revision += 1
            self.commits += 1
        return ""

    def undo(mut self, settings: Settings):
        if settings.writable and len(self.history) > 0:
            self.name = self.history.pop()
            self.revision += 1

struct Services(ImplicitlyCopyable):
    var document: Document
    var settings: Settings
    def __init__(out self):
        self.document = Document()
        self.settings = Settings()

    def replace_document(mut self, identity: Int, name: String):
        self.document = Document(identity, name)
