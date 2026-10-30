"""Headless projection work, not a benchmark of the App runtime or of Xilem.

Both paths visit every editor. The memo path compares explicit dependencies
before recomputing an editor's five outputs. This cache is not wired into App.
"""
from std.collections import List
from application import Application
from domain import Services
from editor import Editor
from moxi import test_check

struct Values(ImplicitlyCopyable, Equatable):
    var current: String
    var draft: String
    var note: String
    var error: String
    var enabled: Bool
    def __init__(out self, editor: Editor, services: Services):
        self.current = services.document.name
        self.draft = editor.draft
        self.note = editor.note
        self.error = editor.error
        self.enabled = services.settings.writable

struct Sink(ImplicitlyCopyable):
    var current: String
    var draft: String
    var note: String
    var error: String
    var enabled: Bool
    def __init__(out self):
        self.current = ""
        self.draft = ""
        self.note = ""
        self.error = ""
        self.enabled = False

    def project(mut self, editor: Editor, services: Services) -> Int:
        var writes = 0
        var current = "Current: " + services.document.name
        if self.current != current:
            self.current = current
            writes += 1
        if self.draft != editor.draft:
            self.draft = editor.draft
            writes += 1
        if self.note != editor.note:
            self.note = editor.note
            writes += 1
        if self.error != editor.error:
            self.error = editor.error
            writes += 1
        if self.enabled != services.settings.writable:
            self.enabled = services.settings.writable
            writes += 1
        return writes

    def matches(self, other: Self) -> Bool:
        return self.current == other.current and self.draft == other.draft and self.note == other.note and self.error == other.error and self.enabled == other.enabled

struct Projection(Movable):
    var sinks: List[Sink]
    var keys: List[Values]
    def __init__(out self, app: Application):
        self.sinks = List[Sink]()
        self.keys = List[Values]()
        for entry in app.shell.workspace.group.entries:
            var sink = Sink()
            _ = sink.project(entry.value, app.services)
            self.sinks.append(sink)
            self.keys.append(Values(entry.value, app.services))

    def refresh(mut self, app: Application, memo: Bool, label: String):
        var evaluations = 0
        var writes = 0
        var key_checks = 0
        for i in range(len(app.shell.workspace.group.entries)):
            ref editor = app.shell.workspace.group.entries[i].value
            var should_project = True
            if memo:
                key_checks += 1
                var key = Values(editor, app.services)
                should_project = key != self.keys[i]
                self.keys[i] = key
            if should_project:
                evaluations += 5
                writes += self.sinks[i].project(editor, app.services)
        print("WORK", len(self.sinks), label, memo, key_checks, evaluations, writes)

def compare(mut full: Projection, mut memo: Projection, app: Application, label: String):
    full.refresh(app, False, label)
    memo.refresh(app, True, label)
    for i in range(len(full.sinks)):
        test_check(full.sinks[i].matches(memo.sinks[i]))

def scale(count: Int):
    var app = Application(count)
    var full = Projection(app)
    var memo = Projection(app)
    app.shell.workspace.group.entries[0].value.set_draft("Local")
    compare(full, memo, app, "draft")
    app.shell.workspace.group.entries[0].value.set_note("Note")
    compare(full, memo, app, "note")
    _ = app.services.document.rename("Grace", 1, 0, app.services.settings)
    compare(full, memo, app, "name")
    app.services.settings.writable = False
    compare(full, memo, app, "writable")
    app.services.settings.unrelated = 1
    compare(full, memo, app, "unrelated")

def main():
    scale(2)
    scale(100)
    scale(1000)
    print("PASS full and memo projections agree after all 15 scale mutations")
