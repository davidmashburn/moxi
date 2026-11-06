"""Content transactions and revision-checked work. Views/preview are not content."""
from std.collections import List, Dict
from .model import *
from .codec import encode, decode

struct MapHistory(ImplicitlyCopyable):
    var versions: List[MindMapDocument]
    var cursor: Int
    var highwater: Int
    var generation: Int

    def __init__(out self, doc: MindMapDocument):
        self.versions = List[MindMapDocument]([doc])
        self.cursor = 0
        self.highwater = doc.next_id
        self.generation = 0

    def __init__(out self, *, copy: Self):
        self.versions = copy.versions.copy()
        self.cursor = copy.cursor
        self.highwater = copy.highwater
        self.generation = copy.generation

    def commit(mut self, mut doc: MindMapDocument, candidate: MindMapDocument, expected: Int) raises -> Bool:
        if expected != self.generation:
            raise Error("Stale queued work discarded")
        candidate.validate()
        if encode(doc) == encode(candidate):
            return False
        while len(self.versions) > self.cursor + 1:
            _ = self.versions.pop()
        self.highwater = max(self.highwater, candidate.next_id)
        self.generation += 1
        doc = candidate
        doc.revision = self.generation
        doc.next_id = self.highwater
        self.versions.append(doc)
        if len(self.versions) > 33:
            _ = self.versions.pop(0)
        self.cursor = len(self.versions) - 1
        return True

    def restore(mut self, mut doc: MindMapDocument, redo: Bool = False) -> Bool:
        var next = self.cursor + (1 if redo else -1)
        if next < 0 or next >= len(self.versions):
            return False
        self.cursor = next
        self.generation += 1
        var folds = Dict[Int, Bool]()
        for topic in doc.topics:
            folds[topic.id] = topic.folded
        doc = self.versions[next]
        for i in range(len(doc.topics)):
            doc.topics[i].folded = folds.get(doc.topics[i].id, doc.topics[i].folded)
        doc.next_id = max(doc.next_id, self.highwater)
        doc.revision = self.generation
        return True


def copy_forest(doc: MindMapDocument, selected: List[Int]) raises -> String:
    var result = MindMapDocument("Clipboard forest")
    var mapping = Dict[Int, Int]()
    for root in doc.normalized(selected):
        for id in doc.outline():
            if doc.descendant(id, root):
                var original = doc.topics[doc.at(id)]
                var parent = mapping.get(original.parent, result.root)
                var new_id = result.create(parent, len(result.children(parent)), original.text)
                var copied = original
                copied.id = new_id
                copied.parent = parent
                copied.children = List[Int]()
                result.topics[result.at(new_id)] = copied
                mapping[id] = new_id
    for link in doc.links:
        if link.source in mapping and link.target in mapping:
            result.connect(mapping[link.source], mapping[link.target], link.label)
    result.validate()
    return encode(result)


def paste_forest(mut doc: MindMapDocument, parent: Int, text: String) raises -> List[Int]:
    var incoming = decode(text)
    var result = List[Int]()
    var mapping = Dict[Int, Int]()
    mapping[incoming.root] = parent
    for id in incoming.outline():
        if id == incoming.root:
            continue
        var topic = incoming.topics[incoming.at(id)]
        var target = mapping[topic.parent]
        var new_id = doc.create(target, len(doc.children(target)), topic.text)
        topic.id = new_id
        topic.parent = target
        topic.children = List[Int]()
        doc.topics[doc.at(new_id)] = topic
        mapping[id] = new_id
        if target == parent:
            result.append(new_id)
    for link in incoming.links:
        if link.source != incoming.root and link.target != incoming.root:
            doc.connect(mapping[link.source], mapping[link.target], link.label)
    doc.validate()
    return result^
