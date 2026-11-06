from moxi_mindmap.model import *
from moxi_mindmap.codec import encode, decode
from moxi_mindmap.history import MapHistory, copy_forest, paste_forest
from std.collections import List

def check(value: Bool, message: String) raises:
    if not value:
        raise Error(message)

def main() raises:
    var doc = MindMapDocument("思考 · أفكار · ideas")
    var a = doc.create(1, 0, "A")
    var b = doc.create(1, 1, "B")
    var c = doc.create(a, 0, "Child\nline\t\\")
    doc.connect(c, b)
    doc.validate()
    check(encode(decode(encode(doc))) == encode(doc), "round trip")
    var history = MapHistory(doc)
    var candidate = doc
    candidate.move(List[Int]([a, c]), b, 0)
    check(history.commit(doc, candidate, 0), "commit")
    check(len(doc.children(b)) == 1 and doc.topics[doc.at(c)].parent == a, "normalized forest")
    check(history.restore(doc), "undo")
    check(doc.topics[doc.at(a)].parent == 1, "undo topology")
    var clip = copy_forest(doc, List[Int]([a, c]))
    candidate = doc
    var pasted = paste_forest(candidate, b, clip)
    check(len(pasted) == 1 and len(candidate.topics) == 6, "clipboard remaps IDs")
    candidate.erase(List[Int]([a, c]))
    check(len(candidate.links) == 0, "incident link removal")
    var rejected = False
    try:
        candidate = doc
        candidate.move(List[Int]([a]), c, 0)
    except:
        rejected = True
    check(rejected, "cycle rejection")
    print("mindmap model: round trip, ordered normalized moves, undo, clipboard, cycle and incident links PASS")
