"""Version 1 line format: UTF-8, tab-separated fields, reversible text escaping.

No parser evaluation, HTML, URL fetching or scripting. Row order is sibling order.
"""
from std.collections import List
from .model import *

comptime FORMAT_NAME = "MOXI-MINDMAP"
comptime FORMAT_VERSION = "1"
comptime TOPIC_ROW = "T"
comptime LINK_ROW = "L"

def escape(text: String) -> String:
    return text.replace("\\", "\\\\").replace("\t", "\\t").replace("\n", "\\n").replace("\r", "\\r")

def unescape(text: String) raises -> String:
    var result = String()
    var escaped = False
    for cp in text.codepoints():
        var char = String(cp)
        if escaped:
            if char == "n":
                result += "\n"
            elif char == "t":
                result += "\t"
            elif char == "r":
                result += "\r"
            elif char == "\\":
                result += "\\"
            else:
                raise Error("Invalid text escape")
            escaped = False
        elif char == "\\":
            escaped = True
        else:
            result += char
    if escaped:
        raise Error("Truncated text escape")
    return result

def encode(doc: MindMapDocument) -> String:
    var result = String(FORMAT_NAME, "\t", FORMAT_VERSION, "\t", doc.root, "\t", doc.next_id, "\t", doc.arrangement.value, "\n")
    for id in doc.outline():
        var t = doc.topics[doc.at(id)]
        result += String(TOPIC_ROW, "\t", t.id, "\t", t.parent, "\t", t.side.value, "\t", t.spacing, "\t", t.style.value, "\t", Int(t.folded), "\t", escape(t.text), "\t", escape(t.note), "\t", escape(t.link), "\t", escape(t.tags), "\t", escape(t.icons), "\n")
    for link in doc.links:
        result += String(LINK_ROW, "\t", link.id, "\t", link.source, "\t", link.target, "\t", escape(link.label), "\n")
    return result

def decode(text: String) raises -> MindMapDocument:
    if text.byte_length() > MAX_BYTES or "\x00" in text:
        raise Error("File byte limit or NUL")
    var lines = text.split("\n")
    if len(lines) < 2 or len(lines) > MAX_TOPICS * 3 + 3:
        raise Error("Invalid record count")
    var head = lines[0].split("\t")
    if len(head) != 5 or String(head[0]) != FORMAT_NAME or String(head[1]) != FORMAT_VERSION:
        raise Error("Unsupported native format/version")
    var doc = MindMapDocument()
    doc.topics = List[Topic]()
    doc.root = Int(head[2])
    doc.next_id = Int(head[3])
    doc.arrangement = Arrangement(Int(head[4]))
    for n in range(1, len(lines)):
        var line = String(lines[n])
        if line == "" and n == len(lines) - 1:
            continue
        var fields = line.split("\t")
        if String(fields[0]) == TOPIC_ROW and len(fields) == 12:
            if len(doc.topics) >= MAX_TOPICS:
                raise Error("Topic count limit")
            var topic = Topic(Int(fields[1]), Int(fields[2]), unescape(String(fields[7])))
            topic.side = Side(Int(fields[3]))
            topic.spacing = Int(fields[4])
            topic.style = TopicStyle(Int(fields[5]))
            if String(fields[6]) != "0" and String(fields[6]) != "1":
                raise Error("Invalid fold preference")
            topic.folded = String(fields[6]) == "1"
            topic.note = unescape(String(fields[8]))
            topic.link = unescape(String(fields[9]))
            topic.tags = unescape(String(fields[10]))
            topic.icons = unescape(String(fields[11]))
            doc.topics.append(topic)
        elif String(fields[0]) == LINK_ROW and len(fields) == 5:
            doc.links.append(Crosslink(Int(fields[1]), Int(fields[2]), Int(fields[3]), unescape(String(fields[4]))))
        else:
            raise Error("Unknown or malformed record")
    doc.reindex()
    for i in range(len(doc.topics)):
        var parent = doc.topics[i].parent
        if parent != -1:
            if not doc.contains(parent):
                raise Error("Missing parent")
            doc.topics[doc.at(parent)].children.append(doc.topics[i].id)
    doc.validate()
    return doc^
