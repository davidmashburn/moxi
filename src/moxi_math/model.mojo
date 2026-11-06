"""Lossless notation v1. Flat value-owned arena; runtime IDs never enter text."""
from std.collections import List, Dict

struct MathKind(ImplicitlyCopyable):
    var value: Int
    comptime TOKEN = Self(0)
    comptime HOLE = Self(1)
    comptime ERROR = Self(2)
    comptime ROW = Self(3)
    comptime FRACTION = Self(4)
    comptime ROOT = Self(5)
    comptime SCRIPTS = Self(6)
    comptime GROUP = Self(7)
    comptime FUNCTION = Self(8)
    comptime MATRIX = Self(9)
    comptime SUM = Self(10)
    comptime INTEGRAL = Self(11)
    def __init__(out self, value: Int):
        self.value = value
    def __eq__(self, other: Self) -> Bool:
        return self.value == other.value
    def __ne__(self, other: Self) -> Bool:
        return self.value != other.value

comptime MAX_NODES = 20000
comptime MAX_DEPTH = 64
comptime MAX_TEXT = 1048576
comptime MAX_TOKEN_BYTES = 4096

struct MathNode(ImplicitlyCopyable):
    var kind: MathKind
    var text: String
    var extra: String
    var children: List[Int]
    var id: Int
    var start: Int
    var end: Int
    def __init__(out self, *, copy: Self):
        self.kind = copy.kind
        self.text = copy.text
        self.extra = copy.extra
        self.children = copy.children.copy()
        self.id = copy.id
        self.start = copy.start
        self.end = copy.end
    def __init__(out self, kind: MathKind, text: String = "", id: Int = 0):
        self.kind = kind
        self.text = text
        self.extra = ""
        self.children = List[Int]()
        self.id = id
        self.start = 0
        self.end = 0

def quoted(text: String) -> String:
    var result = String('"')
    for c in text.codepoints():
        var s = String(c)
        if s == "\\" or s == '"':
            result += "\\" + s
        elif s == "\n":
            result += "\\n"
        elif s == "\r":
            result += "\\r"
        elif s == "\t":
            result += "\\t"
        else:
            result += s
    return result + '"'

struct MathDocument(ImplicitlyCopyable):
    var nodes: List[MathNode]
    var root: Int
    var next_id: Int
    var revision: Int
    def __init__(out self):
        self.nodes = List[MathNode]()
        self.root = 0
        self.next_id = 1
        self.revision = 0
        self.nodes.append(MathNode(MathKind.HOLE, "", self.next_id))
        self.next_id += 1

    def __init__(out self, *, copy: Self):
        self.nodes = copy.nodes.copy()
        self.root = copy.root
        self.next_id = copy.next_id
        self.revision = copy.revision

    def add(mut self, kind: MathKind, text: String = "") -> Int:
        var index = len(self.nodes)
        self.nodes.append(MathNode(kind, text, self.next_id))
        self.next_id += 1
        return index

    def token(mut self, text: String) -> Int:
        return self.add(MathKind.TOKEN, text)

    def parent(self, child: Int) -> Int:
        for i in range(len(self.nodes)):
            for c in self.nodes[i].children:
                if c == child:
                    return i
        return -1

    def find_id(self, id: Int) -> Int:
        for i in range(len(self.nodes)):
            if self.nodes[i].id == id:
                return i
        return -1

    def print_node(self, i: Int) -> String:
        var n = self.nodes[i]
        if n.kind == MathKind.HOLE:
            return "?"
        if n.kind == MathKind.TOKEN:
            var plain = n.text.count_codepoints() > 0
            for c in n.text.codepoints():
                if String(c) in "(),?\"\\ \n\r\t":
                    plain = False
            if plain:
                return n.text
            return quoted(n.text)
        var name = String("")
        if n.kind == MathKind.ERROR:
            return "error(" + quoted(n.text) + ")"
        elif n.kind == MathKind.ROW:
            name = "row"
        elif n.kind == MathKind.FRACTION:
            name = "frac"
        elif n.kind == MathKind.ROOT:
            name = "root"
        elif n.kind == MathKind.SCRIPTS:
            name = "scripts"
        elif n.kind == MathKind.GROUP:
            name = "group"
        elif n.kind == MathKind.FUNCTION:
            name = "fn"
        elif n.kind == MathKind.MATRIX:
            name = "matrix"
        elif n.kind == MathKind.SUM:
            name = "sum"
        elif n.kind == MathKind.INTEGRAL:
            name = "integral"
        var result = name + "("
        if n.kind == MathKind.GROUP:
            result += quoted(n.text) + ", " + quoted(n.extra) + ", "
        elif n.kind == MathKind.FUNCTION:
            result += quoted(n.text) + ", "
        for j in range(len(n.children)):
            if j > 0:
                result += ", "
            result += self.print_node(n.children[j])
        return result + ")"

    def text(self) -> String:
        return self.print_node(self.root)

    def _validate(self, i: Int, depth: Int, mut seen: List[Bool], mut ids: Dict[Int, Bool]) raises:
        if depth > MAX_DEPTH or i < 0 or i >= len(self.nodes):
            raise Error("Math depth or child index limit")
        if seen[i]:
            raise Error("Cycle or shared mutable child")
        seen[i] = True
        var n = self.nodes[i]
        if n.kind.value < MathKind.TOKEN.value or n.kind.value > MathKind.INTEGRAL.value:
            raise Error("Unsupported math node kind")
        if n.id in ids:
            raise Error("Duplicate math ID")
        ids[n.id]=True
        if n.kind == MathKind.TOKEN and n.text.byte_length()>MAX_TOKEN_BYTES:
            raise Error("Math token byte limit")
        var count = len(n.children)
        if ((n.kind == MathKind.TOKEN or n.kind == MathKind.HOLE or n.kind == MathKind.ERROR) and count != 0) or (n.kind == MathKind.FRACTION and count != 2) or (n.kind == MathKind.ROOT and count != 2) or (n.kind == MathKind.SCRIPTS and count != 5) or (n.kind == MathKind.GROUP and count != 1) or (n.kind == MathKind.FUNCTION and count != 1) or ((n.kind == MathKind.SUM or n.kind == MathKind.INTEGRAL) and count != 4):
            raise Error("Invalid math child roles")
        if n.kind == MathKind.MATRIX:
            if count < 1 or count > 100:
                raise Error("Matrix row limit")
            var width = -1
            for child in n.children:
                if child < 0 or child >= len(self.nodes):
                    raise Error("Invalid matrix row")
                if self.nodes[child].kind != MathKind.ROW:
                    raise Error("Matrix requires rows")
                var columns = len(self.nodes[child].children)
                if columns < 1 or columns > 100 or (width >= 0 and width != columns):
                    raise Error("Matrix must be rectangular")
                width = columns
        for child in n.children:
            self._validate(child, depth + 1, seen, ids)

    def validate(self) raises:
        if len(self.nodes) > MAX_NODES:
            raise Error("Math node limit")
        var seen = List[Bool]()
        var ids = Dict[Int, Bool]()
        for _ in range(len(self.nodes)):
            seen.append(False)
        self._validate(self.root, 0, seen, ids)
        if self.text().byte_length()>MAX_TEXT:
            raise Error("Canonical math text byte limit")

    def clone_from(mut self, other: Self, index: Int) -> Int:
        var n = other.nodes[index]
        var target = self.add(n.kind, n.text)
        self.nodes[target].extra = n.extra
        for child in n.children:
            var copied = self.clone_from(other, child)
            self.nodes[target].children.append(copied)
        return target

    def replace(mut self, target: Int, replacement: Int):
        if target == self.root:
            self.root = replacement
            return
        var parent = self.parent(target)
        if parent >= 0:
            for i in range(len(self.nodes[parent].children)):
                if self.nodes[parent].children[i] == target:
                    self.nodes[parent].children[i] = replacement
                    return

    def compact(mut self):
        var clean = Self()
        clean.nodes.clear()
        clean.next_id = self.next_id
        clean.revision = self.revision
        clean.root = clean._copy_ids(self, self.root)
        self = clean^

    def _copy_ids(mut self, other: Self, index: Int) -> Int:
        var n = other.nodes[index]
        var target = len(self.nodes)
        var copy = n
        copy.children.clear()
        self.nodes.append(copy)
        for child in n.children:
            var copied = self._copy_ids(other, child)
            self.nodes[target].children.append(copied)
        return target

    def _reconcile(mut self, here: Int, old: Self, there: Int):
        if self.nodes[here].kind != old.nodes[there].kind:
            return
        self.nodes[here].id = old.nodes[there].id
        var children = self.nodes[here].children.copy()
        var previous = old.nodes[there].children.copy()
        # Preserve unchanged siblings around an insertion/deletion before aligning
        # changed slots. Avoid assigning a shifted sibling another node's ID.
        var prefix=0
        while prefix<min(len(children),len(previous)):
            if self.print_node(children[prefix])!=old.print_node(previous[prefix]): break
            self._reconcile(children[prefix],old,previous[prefix])
            prefix+=1
        var suffix=0
        while suffix<min(len(children),len(previous))-prefix:
            var a=len(children)-suffix-1
            var b=len(previous)-suffix-1
            if self.print_node(children[a])!=old.print_node(previous[b]): break
            self._reconcile(children[a],old,previous[b])
            suffix+=1
        if len(children)==len(previous):
            for i in range(prefix,len(children)-suffix):
                self._reconcile(children[i],old,previous[i])

    def node_at_source(self, start: Int, end: Int) -> Int:
        var chosen=self.root
        var length=self.nodes[chosen].end-self.nodes[chosen].start+1
        for i in range(len(self.nodes)):
            var n=self.nodes[i]
            if n.start<=start and n.end>=end and n.end-n.start<length:
                chosen=i
                length=n.end-n.start
        return chosen

    def edit_text(mut self, source: String) raises:
        if source.byte_length() > MAX_TEXT or "\x00" in source:
            raise Error("Math text size/NUL limit")
        var parsed = parse_math(source, self.next_id)
        parsed._reconcile(parsed.root, self, self.root)
        parsed.revision = self.revision + 1
        self = parsed^

struct _Parser:
    var source: String
    var chars: List[String]
    var pos: Int
    var doc: MathDocument
    def __init__(out self, source: String, next_id: Int):
        self.source = source
        self.chars = List[String]()
        for c in source.codepoints():
            self.chars.append(String(c))
        self.pos = 0
        self.doc = MathDocument()
        self.doc.nodes.clear()
        self.doc.next_id = next_id
    def peek(self) -> String:
        if self.pos >= len(self.chars):
            return ""
        return self.chars[self.pos]
    def space(mut self):
        while self.peek() != "" and self.peek() in " \n\r\t":
            self.pos += 1
    def expect(mut self, value: String) raises:
        self.space()
        if self.peek() != value:
            raise Error("Expected " + value)
        self.pos += 1
    def string(mut self) raises -> String:
        self.expect('"')
        var result = String("")
        while self.peek() != '"':
            if self.peek() == "":
                raise Error("Unclosed string")
            var c = self.peek()
            self.pos += 1
            if c == "\\":
                c = self.peek()
                self.pos += 1
                if c == "n":
                    c = "\n"
                elif c == "r":
                    c = "\r"
                elif c == "t":
                    c = "\t"
                elif c != "\\" and c != '"':
                    raise Error("Unknown escape")
            result += c
        self.pos += 1
        return result
    def node(mut self, depth: Int = 0) raises -> Int:
        if depth > MAX_DEPTH or len(self.doc.nodes) >= MAX_NODES:
            raise Error("Notation budget exceeded")
        self.space()
        var start = self.pos
        var index: Int
        if self.peek() == "?":
            self.pos += 1
            index = self.doc.add(MathKind.HOLE)
        elif self.peek() == '"':
            var text = self.string()
            index = self.doc.token(text)
        else:
            var word = String("")
            while self.peek() != "" and not (self.peek() in "(), \n\r\t"):
                word += self.peek()
                self.pos += 1
            if word == "":
                raise Error("Expected notation")
            self.space()
            if self.peek() != "(":
                index = self.doc.token(word)
            else:
                self.pos += 1
                var kind: MathKind
                if word == "row":
                    kind = MathKind.ROW
                elif word == "frac":
                    kind = MathKind.FRACTION
                elif word == "root":
                    kind = MathKind.ROOT
                elif word == "scripts":
                    kind = MathKind.SCRIPTS
                elif word == "group":
                    kind = MathKind.GROUP
                elif word == "fn":
                    kind = MathKind.FUNCTION
                elif word == "matrix":
                    kind = MathKind.MATRIX
                elif word == "sum":
                    kind = MathKind.SUM
                elif word == "integral":
                    kind = MathKind.INTEGRAL
                elif word == "error":
                    kind = MathKind.ERROR
                else:
                    raise Error("Unknown notation constructor")
                index = self.doc.add(kind)
                if kind == MathKind.ERROR or kind == MathKind.FUNCTION or kind == MathKind.GROUP:
                    var text = self.string()
                    self.doc.nodes[index].text = text
                    if kind == MathKind.GROUP:
                        self.expect(",")
                        var extra = self.string()
                        self.doc.nodes[index].extra = extra
                    if kind != MathKind.ERROR:
                        self.expect(",")
                self.space()
                if kind != MathKind.ERROR and self.peek() != ")":
                    while True:
                        var child = self.node(depth + 1)
                        self.doc.nodes[index].children.append(child)
                        self.space()
                        if self.peek() != ",":
                            break
                        self.pos += 1
                self.expect(")")
        self.doc.nodes[index].start = start
        self.doc.nodes[index].end = self.pos
        return index

def parse_math(source: String, next_id: Int = 1) raises -> MathDocument:
    """Syntax errors become literal error nodes; resource violations reject atomically."""
    if source.byte_length() > MAX_TEXT or "\x00" in source:
        raise Error("Math text size/NUL limit")
    var parser = _Parser(source, next_id)
    try:
        parser.doc.root = parser.node()
        parser.space()
        if parser.pos != len(parser.chars):
            raise Error("Trailing text")
        parser.doc.validate()
        return parser.doc
    except:
        var doc = MathDocument()
        doc.nodes.clear()
        doc.next_id = next_id
        doc.root = doc.add(MathKind.ERROR, source)
        doc.validate()
        return doc^
