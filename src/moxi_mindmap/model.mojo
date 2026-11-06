"""Application-owned ordered tree. No canvas ancestry and no executable content."""
from std.collections import List, Dict

comptime MAX_TOPICS = 10000
comptime MAX_DEPTH = 256
comptime MAX_TEXT = 65536
comptime MAX_BYTES = 8388608
comptime MAX_ID = 900000

@fieldwise_init
struct Side(Equatable, ImplicitlyCopyable):
    var value: Int
    comptime LEFT = Self(-1)
    comptime RIGHT = Self(1)

@fieldwise_init
struct TopicStyle(Equatable, ImplicitlyCopyable):
    var value: Int
    comptime DEFAULT = Self(0)
    comptime IDEA = Self(1)
    comptime QUESTION = Self(2)
    comptime EMPHASIS = Self(3)

@fieldwise_init
struct Arrangement(Equatable, ImplicitlyCopyable):
    var value: Int
    comptime TWO_SIDED = Self(0)
    comptime RIGHT_ONLY = Self(1)

struct Topic(ImplicitlyCopyable):
    var id: Int
    var parent: Int
    var children: List[Int]
    var text: String
    var note: String
    var link: String
    var tags: String
    var icons: String
    var side: Side
    var spacing: Int
    var style: TopicStyle
    var folded: Bool

    def __init__(out self, id: Int, parent: Int, text: String):
        self.id = id
        self.parent = parent
        self.children = List[Int]()
        self.text = text
        self.note = ""
        self.link = ""
        self.tags = ""
        self.icons = ""
        self.side = Side.RIGHT
        self.spacing = 0
        self.style = TopicStyle.DEFAULT
        self.folded = False

    def __init__(out self, *, copy: Self):
        self.id = copy.id
        self.parent = copy.parent
        self.children = copy.children.copy()
        self.text = copy.text
        self.note = copy.note
        self.link = copy.link
        self.tags = copy.tags
        self.icons = copy.icons
        self.side = copy.side
        self.spacing = copy.spacing
        self.style = copy.style
        self.folded = copy.folded

@fieldwise_init
struct Crosslink(ImplicitlyCopyable):
    var id: Int
    var source: Int
    var target: Int
    var label: String

struct MindMapDocument(ImplicitlyCopyable):
    var topics: List[Topic]
    var index: Dict[Int, Int]
    var links: List[Crosslink]
    var root: Int
    var next_id: Int
    var revision: Int
    var arrangement: Arrangement

    def __init__(out self, text: String = "New map"):
        self.topics = List[Topic]()
        self.index = Dict[Int, Int]()
        self.links = List[Crosslink]()
        self.root = 1
        self.next_id = 2
        self.revision = 0
        self.arrangement = Arrangement.TWO_SIDED
        self.topics.append(Topic(1, -1, text))
        self.index[1] = 0

    def __init__(out self, *, copy: Self):
        self.topics = copy.topics.copy()
        self.index = copy.index.copy()
        self.links = copy.links.copy()
        self.root = copy.root
        self.next_id = copy.next_id
        self.revision = copy.revision
        self.arrangement = copy.arrangement

    def contains(self, id: Int) -> Bool:
        return id in self.index

    def at(self, id: Int) -> Int:
        return self.index.get(id, -1)

    def reindex(mut self) raises:
        self.index = Dict[Int, Int]()
        for i in range(len(self.topics)):
            var id = self.topics[i].id
            if id <= 0 or id >= MAX_ID or id in self.index:
                raise Error("Invalid or duplicate topic ID")
            self.index[id] = i

    def descendant(self, id: Int, ancestor: Int) -> Bool:
        var current = id
        for _ in range(MAX_DEPTH + 1):
            if current == ancestor:
                return True
            var i = self.at(current)
            if i < 0:
                return False
            current = self.topics[i].parent
        return True

    def validate(self) raises:
        if len(self.topics) == 0 or len(self.topics) > MAX_TOPICS or not self.contains(self.root):
            raise Error("Topic count/root limit")
        if self.topics[self.at(self.root)].parent != -1:
            raise Error("Root has a parent")
        if self.arrangement != Arrangement.TWO_SIDED and self.arrangement != Arrangement.RIGHT_ONLY:
            raise Error("Unsupported arrangement")
        var seen = Dict[Int, Bool]()
        var stack = List[Int]([self.root])
        var depths = List[Int]([0])
        var total = 0
        while len(stack):
            var id = stack.pop()
            var depth = depths.pop()
            if depth > MAX_DEPTH or id in seen or not self.contains(id):
                raise Error("Cycle, missing child or excessive depth")
            seen[id] = True
            var topic = self.topics[self.at(id)]
            if topic.side != Side.LEFT and topic.side != Side.RIGHT:
                raise Error("Unsupported side")
            if topic.style.value < 0 or topic.style.value > 3 or (topic.spacing < -400 or topic.spacing > 400):
                raise Error("Unsupported style or spacing")
            for text in List[String]([topic.text, topic.note, topic.link, topic.tags, topic.icons]):
                if text.byte_length() > MAX_TEXT or "\x00" in text:
                    raise Error("Topic text limit or NUL")
                total += text.byte_length()
            for child in topic.children:
                if not self.contains(child) or self.topics[self.at(child)].parent != id:
                    raise Error("Parent/order mismatch")
                stack.append(child)
                depths.append(depth + 1)
        if len(seen) != len(self.topics) or total > MAX_BYTES or self.next_id >= MAX_ID:
            raise Error("Disconnected tree or resource limit")
        var link_ids = Dict[Int, Bool]()
        if len(self.links) > MAX_TOPICS * 2:
            raise Error("Crosslink count limit")
        for link in self.links:
            if link.id in link_ids or link.id <= 0 or link.id >= MAX_ID or not self.contains(link.source) or not self.contains(link.target) or link.source == link.target or link.label.byte_length() > MAX_TEXT or "\x00" in link.label:
                raise Error("Invalid crosslink")
            link_ids[link.id] = True
            total += link.label.byte_length()
        if total > MAX_BYTES:
            raise Error("Crosslink text resource limit")
        for topic in self.topics:
            if topic.id >= self.next_id:
                raise Error("ID allocator precedes content")

    def children(self, id: Int) -> List[Int]:
        return self.topics[self.at(id)].children.copy()

    def branch_side(self, id: Int) -> Side:
        var current = id
        for _ in range(MAX_DEPTH + 1):
            var i = self.at(current)
            if i < 0 or current == self.root:
                return Side.RIGHT
            if self.topics[i].parent == self.root:
                return self.topics[i].side
            current = self.topics[i].parent
        return Side.RIGHT

    def outline(self, visible_only: Bool = False) -> List[Int]:
        var result = List[Int]()
        var stack = List[Int]([self.root])
        while len(stack):
            var id = stack.pop()
            result.append(id)
            var topic = self.topics[self.at(id)]
            if not visible_only or not topic.folded:
                for i in range(len(topic.children) - 1, -1, -1):
                    stack.append(topic.children[i])
        return result^

    def breadcrumb(self, id: Int) -> String:
        var result = ""
        var current = id
        for _ in range(MAX_DEPTH + 1):
            if not self.contains(current):
                break
            var topic = self.topics[self.at(current)]
            result = topic.text + (" / " + result if result != "" else "")
            current = topic.parent
        return String(result, " (#", id, ")")

    def normalized(self, selected: List[Int]) -> List[Int]:
        var result = List[Int]()
        for id in self.outline():
            var include = False
            var covered = False
            for choice in selected:
                include = include or choice == id
                covered = covered or (choice != id and self.descendant(id, choice))
            if include and not covered:
                result.append(id)
        return result^

    def create(mut self, parent: Int, slot: Int, text: String = "") raises -> Int:
        if not self.contains(parent) or len(self.topics) >= MAX_TOPICS or self.next_id >= MAX_ID - 1:
            raise Error("Invalid parent or topic limit")
        var id = self.next_id
        self.next_id += 1
        var topic = Topic(id, parent, text)
        topic.side = self.branch_side(parent)
        var p = self.at(parent)
        self.topics[p].children.insert(min(max(slot, 0), len(self.topics[p].children)), id)
        self.index[id] = len(self.topics)
        self.topics.append(topic)
        return id

    def move(mut self, selected: List[Int], parent: Int, slot: Int) raises:
        var roots = self.normalized(selected)
        if len(roots) == 0 or not self.contains(parent):
            raise Error("Choose topics and a destination")
        for id in roots:
            if id == self.root or self.descendant(parent, id):
                raise Error("Cannot move root or create a cycle")
        # Slot is in the destination list after removing the selected forest.
        for id in roots:
            var p = self.at(self.topics[self.at(id)].parent)
            var children = List[Int]()
            for child in self.topics[p].children:
                if child != id:
                    children.append(child)
            self.topics[p].children = children^
        var p = self.at(parent)
        if slot < 0 or slot > len(self.topics[p].children):
            raise Error("Invalid insertion slot")
        for i in range(len(roots)):
            self.topics[p].children.insert(slot + i, roots[i])
            self.topics[self.at(roots[i])].parent = parent
        self.validate()

    def erase(mut self, selected: List[Int]) raises:
        var roots = self.normalized(selected)
        var remove = Dict[Int, Bool]()
        for id in roots:
            if id == self.root:
                raise Error("Cannot delete root")
        for topic in self.topics:
            for id in roots:
                if self.descendant(topic.id, id):
                    remove[topic.id] = True
        var topics = List[Topic]()
        for topic in self.topics:
            if topic.id not in remove:
                var kept = topic
                kept.children = List[Int]()
                for child in topic.children:
                    if child not in remove:
                        kept.children.append(child)
                topics.append(kept)
        var links = List[Crosslink]()
        for link in self.links:
            if link.source not in remove and link.target not in remove:
                links.append(link)
        self.topics = topics^
        self.links = links^
        self.reindex()

    def connect(mut self, source: Int, target: Int, label: String = "Related") raises:
        if source == target or not self.contains(source) or not self.contains(target):
            raise Error("Select two different topics")
        var id = 1
        for link in self.links:
            id = max(id, link.id + 1)
        self.links.append(Crosslink(id, source, target, label))
        self.validate()
