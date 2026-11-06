from std.collections import List
from moxi_mindmap import MindMapDocument
from moxi_mindmap.model import MAX_DEPTH, MAX_TEXT
from moxi_mindmap.codec import encode, decode
from moxi_mindmap.history import MapHistory

def reject(text: String) raises:
    var rejected = False
    try:
        _ = decode(text)
    except:
        rejected = True
    if not rejected:
        raise Error("Malformed input accepted")

def main() raises:
    reject("MOXI-MINDMAP\t2\t1\t2\t0\n")
    reject("MOXI-MINDMAP\t1\t1\t2\t0\nT\t1\t0\t1\t0\t0\t0\tbad\\q\t\t\t\t\n")
    reject("MOXI-MINDMAP\t1\t1\t2\t0\nT\t1\t0\t1\t0\t0\t0\troot\t\t\t\t\nT\t1\t1\t1\t0\t0\t0\tduplicate\t\t\t\t\n")
    var doc = MindMapDocument()
    var a = doc.create(1, 0, "a")
    var b = doc.create(a, 0, "b")
    var history = MapHistory(doc)
    var candidate = doc
    candidate.move(List[Int]([a]), 1, 0)
    if history.commit(doc, candidate, 0) or history.generation != 0:
        raise Error("No-op history")
    var failed = False
    try:
        candidate.move(List[Int]([a]), b, 0)
    except:
        failed = True
    if not failed:
        raise Error("Cycle accepted")
    candidate = doc
    failed = False
    try:
        candidate.move(List[Int]([1]), a, 0)
    except:
        failed = True
    if not failed:
        raise Error("Root accepted")
    candidate = doc
    candidate.topics[1].text = "changed"
    _ = history.commit(doc, candidate, 0)
    failed = False
    try:
        _ = history.commit(doc, candidate, 0)
    except:
        failed = True
    if not failed:
        raise Error("Stale work accepted")
    doc.topics[1].folded = True
    _ = history.restore(doc)
    if not doc.topics[1].folded:
        raise Error("Content undo changed current fold preference")
    var extreme = MindMapDocument()
    extreme.topics[0].spacing = Int("-9223372036854775808")
    failed = False
    try:
        extreme.validate()
    except:
        failed = True
    if not failed:
        raise Error("Minimum integer spacing bypassed bounds")
    var deep = MindMapDocument()
    var parent = 1
    for _ in range(MAX_DEPTH + 1):
        parent = deep.create(parent, 0, "deep")
    failed = False
    try:
        deep.validate()
    except:
        failed = True
    if not failed:
        raise Error("Depth bound accepted")
    print("PASS malformed codec/version/escape/duplicate, no-op, cycle/root, stale generation, folds and depth bounds")
