"""Bounded JSON adapter for the original nodes/links data shape."""
from std.collections import List
from moxi.json import json_document_is_valid, json_char, json_skip_whitespace, json_parse_value
from layout import Layout

struct Reader:
    var text: String
    var pos: Int
    def __init__(out self, text: String):
        self.text = text
        self.pos = 0
    def peek(mut self) -> String:
        self.pos = json_skip_whitespace(self.text, self.pos)
        return json_char(self.text, self.pos)
    def take(mut self, expected: String) raises:
        if self.peek() != expected:
            raise Error(String("Expected ", expected, " at character ", self.pos))
        self.pos += 1
    def hex4(mut self) -> Int:
        var code = 0
        for _ in range(4):
            var glyph = ord(json_char(self.text, self.pos))
            self.pos += 1
            var digit = glyph - 48
            if glyph >= 97:
                digit = glyph - 87
            elif glyph >= 65:
                digit = glyph - 55
            code = code * 16 + digit
        return code
    def string(mut self) raises -> String:
        self.take(chr(34))
        var result = String("")
        while json_char(self.text, self.pos) != chr(34):
            var glyph = json_char(self.text, self.pos)
            self.pos += 1
            if glyph == chr(92):
                glyph = json_char(self.text, self.pos)
                self.pos += 1
                if glyph == "u":
                    var code = self.hex4()
                    if code >= 0xD800 and code <= 0xDBFF:
                        if json_char(self.text, self.pos) != chr(92) or json_char(self.text, self.pos + 1) != "u":
                            raise Error("Unpaired Unicode surrogate")
                        self.pos += 2
                        var low = self.hex4()
                        if low < 0xDC00 or low > 0xDFFF:
                            raise Error("Invalid Unicode surrogate pair")
                        code = 0x10000 + (code - 0xD800) * 1024 + low - 0xDC00
                    elif code >= 0xDC00 and code <= 0xDFFF:
                        raise Error("Unpaired Unicode surrogate")
                    if code < 32:
                        raise Error("Control characters are not supported in graph labels")
                    result += chr(code)
                elif glyph == "n" or glyph == "r" or glyph == "t" or glyph == "b" or glyph == "f":
                    raise Error("Control characters are not supported in graph labels")
                else:
                    result += glyph
            else:
                result += glyph
        self.pos += 1
        return result
    def scalar(mut self) raises -> String:
        if self.peek() == chr(34):
            return self.string()
        var start = self.pos
        if not json_parse_value(self.text, self.pos):
            raise Error("Invalid scalar")
        var value = String(self.text[codepoint=start:self.pos])
        if value == "null" or value == "true" or value == "false" or value.startswith("[") or value.startswith("{"):
            raise Error("Node IDs and groups must be strings or numbers")
        return value
    def skip(mut self) raises:
        _ = self.peek()
        if not json_parse_value(self.text, self.pos):
            raise Error("Invalid JSON value")

struct PendingLink(ImplicitlyCopyable):
    var source: String
    var target: String
    var weight: Float64
    def __init__(out self, source: String, target: String, weight: Float64):
        self.source = source
        self.target = target
        self.weight = weight

def parse_graph(text: String) raises -> Layout:
    if text.count_codepoints() > 262144:
        raise Error("Graph JSON exceeds 256K characters")
    if not json_document_is_valid(text):
        raise Error("Invalid JSON document")
    var reader = Reader(text)
    var graph = Layout()
    var pending = List[PendingLink]()
    var groups = List[String]()
    var saw_nodes = False
    var saw_links = False
    reader.take("{")
    while reader.peek() != "}":
        var field = reader.string()
        reader.take(":")
        if field == "nodes":
            if saw_nodes:
                raise Error("Duplicate nodes member")
            saw_nodes = True
            reader.take("[")
            while reader.peek() != "]":
                reader.take("{")
                var id = String("")
                var group = String("0")
                var has_id = False
                var has_group = False
                while reader.peek() != "}":
                    var key = reader.string()
                    reader.take(":")
                    if key == "id":
                        if has_id:
                            raise Error("Duplicate id member")
                        id = reader.scalar()
                        has_id = True
                    elif key == "group":
                        if has_group:
                            raise Error("Duplicate group member")
                        group = reader.scalar()
                        has_group = True
                    else:
                        reader.skip()
                    if reader.peek() == "}":
                        break
                    reader.take(",")
                reader.take("}")
                if not has_id:
                    raise Error("Node is missing id")
                var group_index = -1
                for i in range(len(groups)):
                    if groups[i] == group:
                        group_index = i
                if group_index < 0:
                    group_index = len(groups)
                    groups.append(group)
                graph.add_node(id, group_index)
                if reader.peek() == "]":
                    break
                reader.take(",")
            reader.take("]")
        elif field == "links":
            if saw_links:
                raise Error("Duplicate links member")
            saw_links = True
            reader.take("[")
            while reader.peek() != "]":
                reader.take("{")
                var source = String("")
                var target = String("")
                var weight: Float64 = 1
                var has_source = False
                var has_target = False
                var has_value = False
                while reader.peek() != "}":
                    var key = reader.string()
                    reader.take(":")
                    if key == "source":
                        if has_source:
                            raise Error("Duplicate source member")
                        source = reader.scalar()
                        has_source = True
                    elif key == "target":
                        if has_target:
                            raise Error("Duplicate target member")
                        target = reader.scalar()
                        has_target = True
                    elif key == "value":
                        if has_value:
                            raise Error("Duplicate value member")
                        if reader.peek() == chr(34):
                            raise Error("Link value must be a number")
                        weight = Float64(reader.scalar())
                        has_value = True
                    else:
                        reader.skip()
                    if reader.peek() == "}":
                        break
                    reader.take(",")
                reader.take("}")
                if not has_source or not has_target:
                    raise Error("Link is missing source or target")
                if len(pending) >= 1024:
                    raise Error("This first version supports at most 1024 links")
                pending.append(PendingLink(source, target, weight))
                if reader.peek() == "]":
                    break
                reader.take(",")
            reader.take("]")
        else:
            reader.skip()
        if reader.peek() == "}":
            break
        reader.take(",")
    reader.take("}")
    if not saw_nodes or not saw_links:
        raise Error("Graph requires nodes and links arrays")
    for edge in pending:
        graph.add_link(edge.source, edge.target, edge.weight)
    return graph^

def load_graph(path: String) raises -> Layout:
    with open(path, "r") as file:
        var text = file.read(1048577)
        if text.byte_length() > 1048576:
            raise Error("Graph file exceeds 1 MiB")
        return parse_graph(text)
