"""Original synthetic fixture shared by replay, documentation and tests."""
from .model import *

def useful_map() raises -> MindMapDocument:
    var doc = MindMapDocument("A useful local map")
    var research = doc.create(doc.root, 0, "Research · 日本語")
    doc.topics[doc.at(research)].side = Side.LEFT
    var field = doc.create(research, 0, "Field notes · العربية")
    doc.topics[doc.at(field)].note = "Local notes; never interpreted as HTML."
    var draft = doc.create(doc.root, 1, "Draft · café é")
    _ = doc.create(draft, 0, "Test an idea")
    var ship = doc.create(doc.root, 2, "Share findings 🙂")
    doc.connect(field, ship, "informs")
    doc.validate()
    return doc^

def large_map(count: Int, folded: Bool = False, deep: Bool = False) raises -> MindMapDocument:
    var doc = MindMapDocument("Large synthetic fixture")
    var parent = doc.root
    for i in range(1, count):
        if not deep or i % 200 == 0:
            parent = doc.root
        var id = doc.create(parent, len(doc.children(parent)), String("Topic ", i, " · 日本語 café"))
        if deep:
            parent = id
    if folded:
        doc.topics[0].folded = True
    doc.validate()
    return doc^
