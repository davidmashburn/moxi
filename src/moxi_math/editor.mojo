"""Structural commands and reversible transactions, independent of any CAS/host."""
from std.collections import List
from moxi.controls_text import TextInputState
from moxi.text_boundary import previous_text_boundary, next_text_boundary
from moxi.event import KEY_LEFT, KEY_RIGHT, KEY_HOME, KEY_END, KEY_BACKSPACE, KEY_DELETE, KEY_TAB, KEY_ESCAPE, KEY_ENTER, KEY_SPACE, MOD_SHIFT, MOD_COMMAND, MOD_CONTROL
from .model import MAX_TEXT, MathDocument, MathKind, parse_math, MAX_NODES

from .commands import MathCommand, math_binding

struct MathPosition(ImplicitlyCopyable):
    var id: Int
    var offset: Int
    def __init__(out self, id: Int = 1, offset: Int = 0):
        self.id = id
        self.offset = offset

struct _History(ImplicitlyCopyable):
    var doc: MathDocument
    var caret: MathPosition
    var selected: Int
    var text_mode: Bool
    var source: TextInputState
    def __init__(out self, doc: MathDocument, caret: MathPosition, selected: Int, text_mode: Bool, source: TextInputState):
        self.doc = doc
        self.caret = caret
        self.selected = selected
        self.text_mode = text_mode
        self.source = source

struct MathEditorState(ImplicitlyCopyable):
    var document: MathDocument
    var caret: MathPosition
    var selected: Int
    var text_mode: Bool
    var source: TextInputState
    var composition: String
    var symbol_entry: Bool
    var abbreviation: String
    var status: String
    var undo_stack: List[_History]
    var redo_stack: List[_History]
    var drag_id: Int
    var drag_target: Int
    var focused: Bool
    def __init__(out self):
        self.document = MathDocument()
        self.caret = MathPosition()
        self.selected = -1
        self.text_mode = False
        self.source = TextInputState("?")
        self.composition = ""
        self.symbol_entry = False
        self.abbreviation = ""
        self.status = "Ready · Tab visits holes · Leave button exits nesting"
        self.undo_stack = List[_History]()
        self.redo_stack = List[_History]()
        self.drag_id = -1
        self.drag_target = -1
        self.focused = True
    def __init__(out self, *, copy: Self):
        self.document = copy.document
        self.caret = copy.caret
        self.selected = copy.selected
        self.text_mode = copy.text_mode
        self.source = copy.source
        self.composition = copy.composition
        self.symbol_entry = copy.symbol_entry
        self.abbreviation = copy.abbreviation
        self.status = copy.status
        self.undo_stack = copy.undo_stack.copy()
        self.redo_stack = copy.redo_stack.copy()
        self.drag_id = copy.drag_id
        self.drag_target = copy.drag_target
        self.focused = copy.focused
    def __init__(out self, text: String) raises:
        self = Self()
        self.document = parse_math(text)
        self.caret = MathPosition(self.document.nodes[self.document.root].id)
        self.source = TextInputState(self.document.text())
        self.focus(self.document.root)

    def _snapshot(self) -> _History:
        return _History(self.document, self.caret, self.selected, self.text_mode, self.source)
    def _restore(mut self, state: _History):
        var revision = self.document.revision + 1
        var next_id = self.document.next_id
        self.document = state.doc
        self.document.revision = revision
        self.document.next_id = max(next_id, self.document.next_id)
        self.caret = state.caret
        self.selected = state.selected
        self.text_mode = state.text_mode
        self.source = state.source
        self.composition = ""
    def begin(mut self):
        if len(self.undo_stack) >= 100:
            _ = self.undo_stack.pop(0)
        self.undo_stack.append(self._snapshot())
        self.redo_stack.clear()
    def commit(mut self) raises:
        try:
            self.document.validate()
            self.document.compact()
            self.document.revision += 1
            if not self.text_mode:
                self.source.set_text(self.document.text())
            self.status = "Edited · revision " + String(self.document.revision)
        except e:
            if len(self.undo_stack) > 0:
                self._restore(self.undo_stack.pop())
            raise e
    def parse_source(mut self) raises:
        """Parse a text mutation after begin(), restoring the transaction on rejection."""
        try:
            self.document.edit_text(self.source.text)
        except e:
            if len(self.undo_stack)>0:
                self._restore(self.undo_stack.pop())
            raise e
    def index(self) -> Int:
        var i = self.document.find_id(self.caret.id)
        return self.document.root if i < 0 else i
    def target(self) -> Int:
        var i = self.document.find_id(self.selected)
        return self.index() if i < 0 else i
    def focus(mut self, i: Int, end: Bool = False):
        var leaf = i
        while len(self.document.nodes[leaf].children) > 0:
            var children = self.document.nodes[leaf].children.copy()
            leaf = children[len(children) - 1] if end else children[0]
        self.caret = MathPosition(self.document.nodes[leaf].id, self.document.nodes[leaf].text.count_codepoints() if end else 0)
        self.selected = -1
    def select(mut self, i: Int):
        self.selected = self.document.nodes[i].id
        self.caret = MathPosition(self.selected)
    def _leaves(self, i: Int, mut result: List[Int]):
        if len(self.document.nodes[i].children) == 0:
            result.append(i)
        else:
            for c in self.document.nodes[i].children:
                self._leaves(c, result)
    def next_hole(mut self, backwards: Bool = False):
        var leaves = List[Int]()
        self._leaves(self.document.root, leaves)
        var current = 0
        for j in range(len(leaves)):
            if leaves[j] == self.index():
                current = j
        for step in range(1, len(leaves) + 1):
            var j = (current + (len(leaves) - step if backwards else step)) % len(leaves)
            if self.document.nodes[leaves[j]].kind == MathKind.HOLE:
                self.focus(leaves[j])
                return
        self.status = "No placeholders · use Leave to exit editor nesting"
    def ancestor(self, kind: MathKind) -> Int:
        var i = self.index()
        while i >= 0:
            if self.document.nodes[i].kind == kind:
                return i
            i = self.document.parent(i)
        return -1
    def _hole(mut self) -> Int:
        return self.document.add(MathKind.HOLE)
    def _wrap(mut self, kind: MathKind, count: Int, slot: Int, focus_slot: Int):
        var base = self.target()
        # Detach first: parent lookup must not see the wrapper's new child.
        var wrapper = self.document.add(kind)
        self.document.replace(base, wrapper)
        for j in range(count):
            var child = base if j == slot else self._hole()
            self.document.nodes[wrapper].children.append(child)
        self.focus(self.document.nodes[wrapper].children[focus_slot])
    def _scripts(mut self, slot: Int):
        var script = self.ancestor(MathKind.SCRIPTS)
        if script < 0 or self.selected >= 0:
            self._wrap(MathKind.SCRIPTS, 5, 0, slot)
        else:
            self.focus(self.document.nodes[script].children[slot])
    def _matrix(mut self):
        var base = self.target()
        var matrix = self.document.add(MathKind.MATRIX)
        self.document.replace(base, matrix)
        var row = base
        if self.document.nodes[base].kind != MathKind.ROW:
            row = self.document.add(MathKind.ROW)
            self.document.nodes[row].children.append(base)
        self.document.nodes[matrix].children.append(row)
        self.focus(base)
    def _resize_matrix(mut self, row_axis: Bool, remove: Bool):
        var matrix = self.ancestor(MathKind.MATRIX)
        if matrix < 0:
            self.status = "Place caret in a matrix first"
            return
        var cell = self.index()
        while self.document.parent(cell) >= 0 and self.document.parent(self.document.parent(cell)) != matrix:
            cell = self.document.parent(cell)
        var row = self.document.parent(cell)
        var row_index = 0
        var column_index = 0
        for j in range(len(self.document.nodes[matrix].children)):
            if self.document.nodes[matrix].children[j] == row:
                row_index = j
        for j in range(len(self.document.nodes[row].children)):
            if self.document.nodes[row].children[j] == cell:
                column_index = j
        if row_axis:
            if remove:
                if len(self.document.nodes[matrix].children) == 1:
                    self.status = "A matrix retains at least one row"
                    return
                _ = self.document.nodes[matrix].children.pop(row_index)
                self.focus(self.document.nodes[matrix].children[min(row_index, len(self.document.nodes[matrix].children)-1)])
            else:
                var new_row = self.document.add(MathKind.ROW)
                for _ in range(len(self.document.nodes[row].children)):
                    var h = self._hole()
                    self.document.nodes[new_row].children.append(h)
                self.document.nodes[matrix].children.insert(row_index + 1, new_row)
                self.focus(new_row)
        else:
            var rows = self.document.nodes[matrix].children.copy()
            if remove and len(self.document.nodes[row].children) == 1:
                self.status = "A matrix retains at least one column"
                return
            for r in rows:
                if remove:
                    _ = self.document.nodes[r].children.pop(column_index)
                else:
                    var h = self._hole()
                    self.document.nodes[r].children.insert(column_index + 1, h)
            self.focus(self.document.nodes[row].children[min(column_index if remove else column_index+1, len(self.document.nodes[row].children)-1)])
    def command(mut self, command: MathCommand) raises:
        if self.composition != "":
            self.status = "Finish or cancel composition before a structural command"
            return
        if command == MathCommand.UNDO:
            if len(self.undo_stack) > 0:
                self.redo_stack.append(self._snapshot())
                self._restore(self.undo_stack.pop())
            return
        if command == MathCommand.REDO:
            if len(self.redo_stack) > 0:
                self.undo_stack.append(self._snapshot())
                self._restore(self.redo_stack.pop())
            return
        if command == MathCommand.TEXT:
            self.begin()
            self.text_mode = not self.text_mode
            if self.text_mode:
                var target_id=self.document.nodes[self.target()].id
                self.document.edit_text(self.document.text())
                self.source = TextInputState(self.document.text())
                var target=self.document.find_id(target_id)
                if target>=0:
                    self.source.anchor=self.document.nodes[target].start
                    self.source.cursor=self.document.nodes[target].end
            else:
                var anchor=self.source.cursor if self.source.anchor<0 else self.source.anchor
                var target=self.document.node_at_source(min(anchor,self.source.cursor),max(anchor,self.source.cursor))
                self.focus(target)
                self.selected=self.document.nodes[target].id
            self.commit()
            return
        if command == MathCommand.NEXT_HOLE or command == MathCommand.PREVIOUS_HOLE:
            self.next_hole(command == MathCommand.PREVIOUS_HOLE)
            return
        if command == MathCommand.EXPAND_SELECTION:
            var index = self.target()
            if self.selected >= 0:
                var parent = self.document.parent(index)
                if parent >= 0:
                    index = parent
            self.select(index)
            return
        if command == MathCommand.EXIT:
            var parent = self.document.parent(self.target())
            if parent >= 0:
                self.caret = MathPosition(self.document.nodes[parent].id, 1)
                self.selected = -1
            else:
                self.focused = False
                self.status = "Math focus released · click an expression to return"
            return
        if command == MathCommand.COMPLEMENT:
            var child = self.index()
            var parent = self.document.parent(child)
            while parent >= 0:
                var n = self.document.nodes[parent]
                if n.kind != MathKind.ROW and len(n.children) > 1:
                    for j in range(len(n.children)):
                        if n.children[j] == child:
                            var next = (j + 1) % len(n.children)
                            if n.kind == MathKind.SCRIPTS:
                                next = 4 if j == 3 else 3 if j == 4 else 2 if j == 1 else 1
                            elif n.kind == MathKind.SUM or n.kind == MathKind.INTEGRAL:
                                next = 2 if j == 1 else 1
                            self.focus(n.children[next])
                            return
                child = parent
                parent = self.document.parent(parent)
            return
        if self.text_mode:
            self.status = "Use ordinary text editing in text mode"
            return
        self.begin()
        if command == MathCommand.FRACTION:
            self._wrap(MathKind.FRACTION, 2, 0, 1)
        elif command == MathCommand.ROOT:
            self._wrap(MathKind.ROOT, 2, 1, 1)
        elif command == MathCommand.SUPER:
            self._scripts(2)
        elif command == MathCommand.SUB:
            self._scripts(1)
        elif command == MathCommand.UNDER or command == MathCommand.OVER:
            var binder = self.ancestor(MathKind.SUM)
            if binder < 0:
                binder = self.ancestor(MathKind.INTEGRAL)
            if binder >= 0:
                self.focus(self.document.nodes[binder].children[1 if command == MathCommand.UNDER else 2])
            else:
                self._scripts(3 if command == MathCommand.UNDER else 4)
        elif command == MathCommand.MATRIX:
            self._matrix()
        elif command == MathCommand.ADD_ROW or command == MathCommand.ADD_COLUMN or command == MathCommand.REMOVE_ROW or command == MathCommand.REMOVE_COLUMN:
            self._resize_matrix(command == MathCommand.ADD_ROW or command == MathCommand.REMOVE_ROW, command == MathCommand.REMOVE_ROW or command == MathCommand.REMOVE_COLUMN)
        elif command == MathCommand.GROUP or command == MathCommand.FUNCTION:
            self._wrap(MathKind.GROUP if command == MathCommand.GROUP else MathKind.FUNCTION, 1, 0, 0)
            var wrapper = self.document.parent(self.index())
            self.document.nodes[wrapper].text = "(" if command == MathCommand.GROUP else "sin"
            self.document.nodes[wrapper].extra = ")" if command == MathCommand.GROUP else ""
        elif command == MathCommand.SUM or command == MathCommand.INTEGRAL:
            self._wrap(MathKind.SUM if command == MathCommand.SUM else MathKind.INTEGRAL, 4, 3, 0)
        elif command == MathCommand.UNWRAP:
            var target = self.target()
            if len(self.document.nodes[target].children) == 0:
                target = self.document.parent(target)
            if target >= 0 and len(self.document.nodes[target].children) > 0:
                var children = self.document.nodes[target].children.copy()
                var row = self.document.add(MathKind.ROW)
                self.document.replace(target, row)
                for child in children:
                    if self.document.nodes[child].kind != MathKind.HOLE:
                        self.document.nodes[row].children.append(child)
                if len(self.document.nodes[row].children) == 0:
                    var h = self._hole()
                    self.document.nodes[row].children.append(h)
                self.focus(row)
        self.commit()

    def insert(mut self, text: String) raises:
        if text.byte_length()>MAX_TEXT or "\x00" in text:
            raise Error("Math text size/NUL limit")
        if self.symbol_entry:
            self.abbreviation += text
            self.status = "Symbol: " + self.abbreviation + " · Escape commits · Backspace corrects · a alpha, b beta, pi, inf"
            return
        self.begin()
        if self.text_mode:
            _ = self.source.insert_text(text)
            self.parse_source()
        else:
            var index = self.target()
            var n = self.document.nodes[index]
            if self.selected >= 0 or n.kind == MathKind.HOLE:
                self.document.nodes[index].kind = MathKind.TOKEN
                self.document.nodes[index].children.clear()
                self.document.nodes[index].text = text
                self.caret = MathPosition(n.id, text.count_codepoints())
            elif n.kind == MathKind.TOKEN or n.kind == MathKind.ERROR:
                var at = min(self.caret.offset, n.text.count_codepoints())
                if text.count_codepoints() == 1 and text in "+−-*×=<>" and at == n.text.count_codepoints() and at > 0:
                    var row = self.document.add(MathKind.ROW)
                    self.document.replace(index, row)
                    var op = self.document.token(text)
                    var hole = self._hole()
                    self.document.nodes[row].children.append(index)
                    self.document.nodes[row].children.append(op)
                    self.document.nodes[row].children.append(hole)
                    self.focus(hole)
                else:
                    self.document.nodes[index].text = String(n.text[codepoint=0:at]) + text + String(n.text[codepoint=at:])
                    self.caret.offset = at + text.count_codepoints()
            else:
                var row = self.document.add(MathKind.ROW)
                self.document.replace(index, row)
                var token = self.document.token(text)
                self.document.nodes[row].children.append(index)
                self.document.nodes[row].children.append(token)
                self.focus(token, True)
            self.selected = -1
        self.commit()

    def delete(mut self, forward: Bool = False) raises:
        if self.symbol_entry:
            var end = previous_text_boundary(self.abbreviation, self.abbreviation.count_codepoints())
            var shortened = String(self.abbreviation[codepoint=0:end])
            self.abbreviation = shortened
            self.status = "Symbol: " + self.abbreviation
            return
        if self.composition != "":
            return
        if not self.text_mode and self.selected < 0:
            var n = self.document.nodes[self.index()]
            if n.kind == MathKind.HOLE or (self.caret.offset == 0 and not forward):
                self.command(MathCommand.UNWRAP)
                return
        self.begin()
        if self.text_mode:
            if forward:
                _ = self.source.delete_forward()
            else:
                _ = self.source.delete_backward()
            self.parse_source()
        else:
            var i = self.target()
            var n = self.document.nodes[i]
            if self.selected >= 0 or len(n.children) > 0:
                self.document.nodes[i].kind = MathKind.HOLE
                self.document.nodes[i].children.clear()
                self.document.nodes[i].text = ""
                self.focus(i)
            else:
                var at = min(self.caret.offset, n.text.count_codepoints())
                var start = at if forward else previous_text_boundary(n.text, at)
                var end = next_text_boundary(n.text, at) if forward else at
                self.document.nodes[i].text = String(n.text[codepoint=0:start]) + String(n.text[codepoint=end:])
                self.caret.offset = start
                if self.document.nodes[i].text == "":
                    self.document.nodes[i].kind = MathKind.HOLE
        self.commit()

    def horizontal(mut self, direction: Int, extend: Bool = False):
        if extend:
            self.command_selection_to(direction)
            return
        if self.selected >= 0:
            self.focus(self.target(),direction>0)
            return
        var i = self.index()
        var n = self.document.nodes[i]
        self.selected = -1
        if len(n.children)>0:
            self.focus(i,True)
            if direction>0:
                self.horizontal(1)
            return
        if n.kind == MathKind.TOKEN or n.kind == MathKind.ERROR:
            if direction < 0 and self.caret.offset > 0:
                self.caret.offset = previous_text_boundary(n.text, self.caret.offset)
                return
            if direction > 0 and self.caret.offset < n.text.count_codepoints():
                self.caret.offset = next_text_boundary(n.text, self.caret.offset)
                return
        var leaves = List[Int]()
        self._leaves(self.document.root, leaves)
        for j in range(len(leaves)):
            if leaves[j] == i:
                self.focus(leaves[max(0, min(len(leaves)-1, j+direction))], direction < 0)
                return
        self.focus(i, direction < 0)
    def command_selection_to(mut self, direction: Int):
        var current = self.target()
        var parent = self.document.parent(current)
        self.select(current if parent < 0 else parent)
    def copy_text(self) -> String:
        if self.text_mode:
            return self.source.selected_text()
        return self.document.print_node(self.target())
    def paste(mut self, text: String) raises:
        if self.text_mode:
            self.insert(text)
            return
        var fragment = parse_math(text, self.document.next_id)
        self.begin()
        var i = self.document.clone_from(fragment, fragment.root)
        self.document.replace(self.target(), i)
        self.focus(i, True)
        self.commit()
    def apply_fragment(mut self, text: String, target_id: Int, revision: Int) raises -> Bool:
        if revision != self.document.revision or self.document.find_id(target_id) < 0:
            self.status = "Stale result · original notation retained"
            return False
        var fragment = parse_math(text, self.document.next_id)
        for node in fragment.nodes:
            if node.kind == MathKind.ERROR:
                self.status = "Rejected malformed result"
                return False
        self.begin()
        var target = self.document.find_id(target_id)
        var replacement = self.document.clone_from(fragment, fragment.root)
        self.document.replace(target, replacement)
        self.focus(replacement)
        self.commit()
        return True
    def save_text(self) -> String:
        return "moxi-math/1\n" + self.document.text() + "\n"
    def load_text(mut self, text: String) raises:
        if not text.startswith("moxi-math/1\n"):
            raise Error("Unsupported math document version")
        var parsed = parse_math(String(String(text[codepoint=12:]).strip()), self.document.next_id)
        parsed.revision = self.document.revision
        self.begin()
        self.document = parsed^
        self.focus(self.document.root)
        self.commit()
    def begin_drag(mut self):
        self.drag_id = self.document.nodes[self.target()].id
        self.drag_target = -1
    def drop(mut self) raises -> Bool:
        var from_index = self.document.find_id(self.drag_id)
        var to_index = self.document.find_id(self.drag_target)
        self.drag_id = -1
        self.drag_target = -1
        if from_index < 0 or to_index < 0 or from_index == self.document.root:
            return False
        var p = to_index
        while p >= 0:
            if p == from_index:
                return False
            p = self.document.parent(p)
        if self.document.nodes[to_index].kind != MathKind.HOLE:
            self.status = "Move target must be an empty slot"
            return False
        self.begin()
        var h = self._hole()
        self.document.replace(from_index, h)
        self.document.replace(to_index, from_index)
        self.focus(from_index)
        self.commit()
        return True
    def escape(mut self) raises:
        if self.composition != "":
            self.composition = ""
        elif self.drag_id >= 0:
            self.drag_id = -1
            self.drag_target = -1
        elif self.symbol_entry:
            var value = symbol_for(self.abbreviation)
            if value != "":
                self.symbol_entry = False
                self.abbreviation = ""
                self.insert(value)
            elif self.abbreviation == "":
                self.symbol_entry = False
                self.status = "Symbol entry cancelled"
            else:
                self.status = "Unknown symbol · correct with Backspace or clear then Escape"
        else:
            self.symbol_entry = True
            self.abbreviation = ""
            self.status = "Symbol · a/alpha, b/beta, g/gamma, pi, inf · Escape commits"

def symbol_for(abbreviation: String) -> String:
    if abbreviation == "a" or abbreviation == "alpha":
        return "α"
    if abbreviation == "b" or abbreviation == "beta":
        return "β"
    if abbreviation == "g" or abbreviation == "gamma":
        return "γ"
    if abbreviation == "d" or abbreviation == "delta":
        return "δ"
    if abbreviation == "theta" or abbreviation == "th":
        return "θ"
    if abbreviation == "pi":
        return "π"
    if abbreviation == "inf" or abbreviation == "infinity":
        return "∞"
    if abbreviation == "times":
        return "×"
    if abbreviation == "le":
        return "≤"
    if abbreviation == "ge":
        return "≥"
    return ""
