"""Structural commands and reversible transactions, independent of any CAS/host."""
from std.collections import List
from moxi.controls_text import TextInputState
from moxi.text_boundary import previous_text_boundary, next_text_boundary, clamp_text_boundary, codepoint_at
from moxi.event import KEY_LEFT, KEY_RIGHT, KEY_HOME, KEY_END, KEY_BACKSPACE, KEY_DELETE, KEY_TAB, KEY_ESCAPE, KEY_ENTER, KEY_SPACE, MOD_SHIFT, MOD_COMMAND, MOD_CONTROL
from .model import MAX_TEXT, MathDocument, MathKind, parse_math, quoted, MAX_NODES

from .commands import MathCommand, math_binding

def _word_left(text: String, caret: Int) -> Tuple[Int, Int]:
    """Find the adjacent operand in a token, including pasted math text."""
    var start = 0
    var end = 0
    var pos = 0
    for cp in text.codepoints():
        if pos >= caret:
            break
        var ch = String(cp)
        if ch in " \t\r\n\u00a0":
            if start == end:
                start = pos + 1
                end = start
        elif ch in "+−-*/÷×=<>≤≥≠≈±∓·^,:;!?()[]{}|":
            start = pos + 1
            end = start
        else:
            if pos != end:
                start = pos
            end = pos + 1
        pos += 1
    return (start, end)

struct MathPosition(ImplicitlyCopyable):
    var id: Int
    var offset: Int
    def __init__(out self, id: Int = 1, offset: Int = 0):
        self.id = id
        self.offset = offset

struct _SelectionSpan(ImplicitlyCopyable):
    var id: Int
    var start: Int
    var end: Int
    var whole: Bool
    def __init__(out self, id: Int, start: Int = 0, end: Int = 0, whole: Bool = True):
        self.id = id
        self.start = start
        self.end = end
        self.whole = whole

struct _History(ImplicitlyCopyable):
    var doc: MathDocument
    var caret: MathPosition
    var selected: Int
    var selection_anchor: MathPosition
    var text_mode: Bool
    var source: TextInputState
    def __init__(out self, doc: MathDocument, caret: MathPosition, selected: Int, selection_anchor: MathPosition, text_mode: Bool, source: TextInputState):
        self.doc = doc
        self.caret = caret
        self.selected = selected
        self.selection_anchor = selection_anchor
        self.text_mode = text_mode
        self.source = source

struct MathEditorState(ImplicitlyCopyable):
    var document: MathDocument
    var caret: MathPosition
    var selected: Int
    var selection_anchor: MathPosition
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
        self.selection_anchor = MathPosition(-1)
        self.text_mode = False
        self.source = TextInputState("?")
        self.composition = ""
        self.symbol_entry = False
        self.abbreviation = ""
        self.status = "Click a slot to type. Tab moves to the next empty slot."
        self.undo_stack = List[_History]()
        self.redo_stack = List[_History]()
        self.drag_id = -1
        self.drag_target = -1
        self.focused = True
    def __init__(out self, *, copy: Self):
        self.document = copy.document
        self.caret = copy.caret
        self.selected = copy.selected
        self.selection_anchor = copy.selection_anchor
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
        return _History(self.document, self.caret, self.selected, self.selection_anchor, self.text_mode, self.source)
    def _restore(mut self, state: _History):
        var revision = self.document.revision + 1
        var next_id = self.document.next_id
        self.document = state.doc
        self.document.revision = revision
        self.document.next_id = max(next_id, self.document.next_id)
        self.caret = state.caret
        self.selected = state.selected
        self.selection_anchor = state.selection_anchor
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
    def edge_position(self, end: Bool = False) -> MathPosition:
        return self._node_edge(self.document.root, end)
    def focus(mut self, i: Int, end: Bool = False):
        var leaf = i
        while self.position_order(self._node_edge(leaf, False)) < 0:
            leaf = self.document.parent(leaf)
            if leaf < 0:
                leaf = self.document.root
                break
        while len(self.document.nodes[leaf].children) > 0:
            var children = self.document.nodes[leaf].children.copy()
            var next = -1
            for step in range(len(children)):
                var slot = len(children)-step-1 if end else step
                if self.document.slot_exists(leaf, slot):
                    next = children[slot]
                    break
            if next < 0:
                break
            leaf = next
        var n = self.document.nodes[leaf]
        self.caret = MathPosition(n.id, 0) if n.kind == MathKind.HOLE else self._node_edge(leaf, end)
        self.clear_selection()
    def select(mut self, i: Int):
        self.selected = self.document.nodes[i].id
        self.caret = MathPosition(self.selected)
        self.selection_anchor = MathPosition(-1)
    def clear_selection(mut self):
        self.selected = -1
        self.selection_anchor = MathPosition(-1)
    def has_text_selection(self) -> Bool:
        if self.selected >= 0 or self.selection_anchor.id != self.caret.id or self.selection_anchor.offset == self.caret.offset:
            return False
        var kind = self.document.nodes[self.index()].kind
        return kind == MathKind.TOKEN or kind == MathKind.ERROR
    def has_range_selection(self) -> Bool:
        return self.selection_anchor.id >= 0 and (self.selection_anchor.id != self.caret.id or self.selection_anchor.offset != self.caret.offset)
    def selection_first(self) -> MathPosition:
        if self.has_range_selection() and self.position_order(self.selection_anchor) < self.position_order(self.caret):
            return self.selection_anchor
        return self.caret
    def selection_last(self) -> MathPosition:
        if self.has_range_selection() and self.position_order(self.selection_anchor) > self.position_order(self.caret):
            return self.selection_anchor
        return self.caret
    def selection_start(self) -> Int:
        return min(self.selection_anchor.offset, self.caret.offset) if self.has_text_selection() else self.caret.offset
    def selection_end(self) -> Int:
        return max(self.selection_anchor.offset, self.caret.offset) if self.has_text_selection() else self.caret.offset
    def set_caret(mut self, position: MathPosition, extend: Bool = False):
        """Keep the original anchor while the focus moves through existing blocks."""
        if self.position_order(position) < 0:
            return
        var normalized = position
        var n = self.document.nodes[self.document.find_id(position.id)]
        if n.kind == MathKind.TOKEN or n.kind == MathKind.ERROR:
            normalized.offset = clamp_text_boundary(n.text, position.offset)
        elif n.kind == MathKind.HOLE:
            normalized.offset = position.offset if position.offset == -1 or position.offset == -2 else 0
        else:
            normalized.offset = 1 if position.offset == 1 else 0
        if not extend:
            self.caret = normalized
            self.clear_selection()
            return
        if self.selection_anchor.id < 0:
            self.selection_anchor = self.caret
        self.caret = normalized
        self.selected = -1
        if self.selection_anchor.id == normalized.id:
            var i = self.index()
            var n = self.document.nodes[i]
            if n.kind == MathKind.HOLE and self.selection_anchor.offset != normalized.offset:
                self.selected = n.id
            elif n.kind != MathKind.TOKEN and n.kind != MathKind.ERROR:
                var first = self._node_edge(i, False)
                var last = self._node_edge(i, True)
                if (self.selection_anchor.offset == first.offset and normalized.offset == last.offset) or (self.selection_anchor.offset == last.offset and normalized.offset == first.offset):
                    self.selected = n.id

    def _node_width(self, i: Int) -> Int:
        var n = self.document.nodes[i]
        if n.kind == MathKind.TOKEN or n.kind == MathKind.ERROR:
            return n.text.count_codepoints()+1
        if n.kind == MathKind.HOLE:
            return 3
        var width = 2
        for slot in range(len(n.children)):
            if self.document.slot_exists(i, slot):
                width += self._node_width(n.children[slot])
        return width
    def _position_order(self, i: Int, position: MathPosition, mut cursor: Int) -> Int:
        var n = self.document.nodes[i]
        var before = cursor
        if n.kind == MathKind.TOKEN or n.kind == MathKind.ERROR:
            cursor += n.text.count_codepoints()+1
            return before+clamp_text_boundary(n.text, position.offset) if n.id == position.id else -1
        if n.kind == MathKind.HOLE:
            cursor += 3
            return before+(2 if position.offset == -2 else 0 if position.offset == -1 else 1) if n.id == position.id else -1
        cursor += 1
        var found = -1
        for slot in range(len(n.children)):
            if self.document.slot_exists(i, slot):
                var candidate = self._position_order(n.children[slot], position, cursor)
                if candidate >= 0:
                    found = candidate
        var after = cursor
        cursor += 1
        return (after if position.offset == 1 else before) if n.id == position.id else found
    def position_order(self, position: MathPosition) -> Int:
        """Order structural exteriors, token boundaries, and hole interiors alike."""
        var cursor = 0
        return self._position_order(self.document.root, position, cursor)
    def _token_source_offset(self, index: Int, offset: Int) -> Int:
        var n = self.document.nodes[index]
        var decoded = clamp_text_boundary(n.text,offset)
        var source = n.start
        if codepoint_at(self.source.text,source) != ord('"'):
            return source+decoded
        source += 1
        for _ in range(decoded):
            source += 2 if codepoint_at(self.source.text,source) == ord("\\") else 1
        return source
    def _source_token_offset(self, index: Int, offset: Int) -> Int:
        var n = self.document.nodes[index]
        var source = n.start
        if codepoint_at(self.source.text,source) != ord('"'):
            return clamp_text_boundary(n.text,offset-source)
        source += 1
        var decoded = 0
        while decoded<n.text.count_codepoints():
            var width = 2 if codepoint_at(self.source.text,source) == ord("\\") else 1
            if offset<source+width:
                if offset-source>source+width-offset:
                    decoded += 1
                return clamp_text_boundary(n.text,decoded)
            source += width
            decoded += 1
        return n.text.count_codepoints()
    def _source_position(self, position: MathPosition) -> Int:
        var i = self.document.find_id(position.id)
        if i < 0:
            return -1
        var n = self.document.nodes[i]
        if n.kind == MathKind.TOKEN:
            return self._token_source_offset(i, position.offset)
        return n.end if position.offset == 1 or position.offset == -2 else n.start

    def _focus_source_caret(mut self, offset: Int):
        var leaves = List[Int]()
        self._leaves(self.document.root,leaves)
        var closest = self.document.root
        var distance = self.source.text.count_codepoints()+1
        for leaf in leaves:
            var n = self.document.nodes[leaf]
            var gap = max(0,max(n.start-offset,offset-n.end))
            if gap<distance:
                closest = leaf
                distance = gap
        var n = self.document.nodes[closest]
        if n.kind == MathKind.TOKEN:
            self.set_caret(MathPosition(n.id,self._source_token_offset(closest,offset)))
        else:
            self.focus(closest,offset>n.start)
    def _leaves(self, i: Int, mut result: List[Int]):
        var count = len(result)
        for slot in range(len(self.document.nodes[i].children)):
            if self.document.slot_exists(i, slot):
                self._leaves(self.document.nodes[i].children[slot], result)
        if len(result) == count:
            result.append(i)
    def _hole_orders(self, i: Int, mut cursor: Int, mut holes: List[Int], mut orders: List[Int]):
        var n = self.document.nodes[i]
        if n.kind == MathKind.HOLE:
            holes.append(i)
            orders.append(cursor+1)
            cursor += 3
        elif n.kind == MathKind.TOKEN or n.kind == MathKind.ERROR:
            cursor += n.text.count_codepoints()+1
        else:
            cursor += 1
            for slot in range(len(n.children)):
                if self.document.slot_exists(i, slot):
                    self._hole_orders(n.children[slot], cursor, holes, orders)
            cursor += 1
    def next_hole(mut self, backwards: Bool = False):
        var holes = List[Int]()
        var orders = List[Int]()
        var cursor = 0
        self._hole_orders(self.document.root, cursor, holes, orders)
        var current = self.position_order(self.caret)
        var chosen = -1
        var wrapped = -1
        for j in range(len(holes)):
            var order = orders[j]
            if backwards:
                if order < current:
                    chosen = holes[j]
                wrapped = holes[j]
            else:
                if order > current and chosen < 0:
                    chosen = holes[j]
                if wrapped < 0:
                    wrapped = holes[j]
        if chosen < 0:
            chosen = wrapped
        if chosen >= 0:
            self.focus(chosen)
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
    def _expression_row(self, node: Int) -> Bool:
        if node < 0 or self.document.nodes[node].kind != MathKind.ROW:
            return False
        var parent = self.document.parent(node)
        return parent < 0 or self.document.nodes[parent].kind != MathKind.MATRIX

    def _slot_number(self, parent: Int, child: Int) -> Int:
        for slot in range(len(self.document.nodes[parent].children)):
            if self.document.nodes[parent].children[slot] == child:
                return slot
        return -1

    def _insert_beside(mut self, index: Int, item: Int, after: Bool):
        var parent = self.document.parent(index)
        if parent >= 0 and self.document.nodes[parent].kind == MathKind.MATRIX:
            # A matrix row cannot acquire a sibling expression or a new column here.
            var cells = self.document.nodes[index].children.copy()
            self._insert_beside(cells[len(cells)-1] if after else cells[0], item, after)
        elif self._expression_row(parent):
            var slot = self._slot_number(parent, index)
            self.document.nodes[parent].children.insert(slot + Int(after), item)
        else:
            var row = self.document.add(MathKind.ROW)
            self.document.replace(index, row)
            self.document.nodes[row].children.append(index if after else item)
            self.document.nodes[row].children.append(item if after else index)

    def _clear_node(mut self, index: Int, keep_optional: Bool = False):
        self.document.nodes[index].kind = MathKind.HOLE
        self.document.nodes[index].text = ""
        self.document.nodes[index].extra = ""
        self.document.nodes[index].children.clear()
        self.document.nodes[index].authored_empty = keep_optional

    def _erase_item(mut self, index: Int):
        var parent = self.document.parent(index)
        if parent >= 0 and self.document.nodes[parent].kind == MathKind.MATRIX:
            var cells = self.document.nodes[index].children.copy()
            for cell in cells:
                self._clear_node(cell)
            self.focus(cells[0])
        elif self._expression_row(parent) and len(self.document.nodes[parent].children) > 1:
            var slot = self._slot_number(parent, index)
            _ = self.document.nodes[parent].children.pop(slot)
            var adjacent = self.document.nodes[parent].children[max(0, slot-1)]
            self.set_caret(self._node_edge(adjacent, slot > 0))
        elif parent >= 0 and self.document.is_optional_slot(parent, self._slot_number(parent, index)):
            self._clear_node(index)
            self.set_caret(MathPosition(self.document.nodes[parent].id, 1))
        else:
            self._clear_node(index)
            self.focus(index)

    def _node_edge(self, index: Int, after: Bool) -> MathPosition:
        var n = self.document.nodes[index]
        if n.kind == MathKind.HOLE:
            return MathPosition(n.id, -2 if after else -1)
        if len(n.children) > 0 or n.kind == MathKind.ROW:
            return MathPosition(n.id, Int(after))
        return MathPosition(n.id, n.text.count_codepoints() if after else 0)

    def _template_base(mut self) -> Int:
        if self.selected < 0 and self.has_range_selection() and not self.has_text_selection():
            return self.extract_range()
        var target = self.target()
        var parent = self.document.parent(target)
        # A matrix owns rectangular rows. Wrap a whole row as one
        # expression in its first cell, keeping its outer grid intact.
        if parent >= 0 and self.document.nodes[parent].kind == MathKind.MATRIX and (self.selected >= 0 or self.caret.offset == 1):
            var row = self.document.add(MathKind.ROW)
            self.document.replace(target, row)
            self.document.nodes[row].children.append(target)
            for _ in range(1, len(self.document.nodes[target].children)):
                var hole = self._hole()
                self.document.nodes[row].children.append(hole)
            return target
        if self.selected >= 0:
            return target

        var node = self.document.nodes[target]
        if (len(node.children) > 0 and self.caret.offset == 0) or (node.kind == MathKind.HOLE and self.caret.offset < 0):
            var after = node.kind == MathKind.HOLE and self.caret.offset == -2
            if after:
                return target
            if self._expression_row(parent):
                var slot = self._slot_number(parent, target)
                if slot > 0:
                    var left = self.document.nodes[parent].children[slot-1]
                    self.set_caret(self._node_edge(left, True))
                    return self._template_base()
            var base = self._hole()
            self._insert_beside(target, base, False)
            return base

        var start = self.selection_start()
        var end = self.selection_end()
        if start == end and end == 0 and self._expression_row(parent):
            ref siblings = self.document.nodes[parent].children
            for j in range(1, len(siblings)):
                if siblings[j] == target and self.document.nodes[target].kind == MathKind.TOKEN:
                    target = siblings[j-1]
                    end = self.document.nodes[target].text.count_codepoints()
                    break
        var n = self.document.nodes[target]
        if n.kind != MathKind.TOKEN and n.kind != MathKind.ERROR:
            return target
        if not self.has_text_selection():
            var word = _word_left(n.text, end)
            start = word[0]
            end = word[1]
        if start == 0 and end == n.text.count_codepoints():
            return target
        var row = parent
        var insert_at = 0
        if self._expression_row(parent):
            while self.document.nodes[row].children[insert_at] != target:
                insert_at += 1
            _ = self.document.nodes[row].children.pop(insert_at)
        else:
            row = self.document.add(MathKind.ROW)
            self.document.replace(target, row)
        if start > 0:
            var before = self.document.token(String(n.text[codepoint=0:start]))
            self.document.nodes[row].children.insert(insert_at, before)
            insert_at += 1
        self.document.nodes[target].text = String(n.text[codepoint=start:end])
        if start == end:
            self.document.nodes[target].kind = MathKind.HOLE
        self.document.nodes[row].children.insert(insert_at, target)
        if end < n.text.count_codepoints():
            var after = self.document.token(String(n.text[codepoint=end:]))
            self.document.nodes[row].children.insert(insert_at + 1, after)
        return target

    def _wrap(mut self, kind: MathKind, count: Int, slot: Int, focus_slot: Int, text: String = "", extra: String = "") raises:
        var base = self._template_base()
        var wrapper = self.document.add(kind, text)
        self.document.nodes[wrapper].extra = extra
        self.document.replace(base, wrapper)
        for j in range(count):
            var child = base if j == slot else self._hole()
            self.document.nodes[wrapper].children.append(child)
        if self.document.is_optional_slot(wrapper, focus_slot):
            _ = self.document.create_optional_slot(wrapper, focus_slot)
        self.focus(self.document.nodes[wrapper].children[focus_slot])
    def _matrix(mut self):
        var base = self._template_base()
        var matrix = self.document.add(MathKind.MATRIX)
        self.document.replace(base, matrix)
        var row = base
        if self.document.nodes[base].kind != MathKind.ROW:
            row = self.document.add(MathKind.ROW)
            self.document.nodes[row].children.append(base)
        self.document.nodes[matrix].children.append(row)
        self.focus(base)
    def _resize_matrix(mut self, row_axis: Bool, remove: Bool) raises:
        var matrix = self.ancestor(MathKind.MATRIX)
        if matrix < 0:
            self.status = "Place caret in a matrix first"
            return
        var cell = self.index()
        var after = self.caret.offset == 1
        if cell == matrix:
            var rows = self.document.nodes[matrix].children.copy()
            cell = rows[len(rows)-1] if after else rows[0]
        if self.document.parent(cell) == matrix:
            var cells = self.document.nodes[cell].children.copy()
            cell = cells[len(cells)-1] if after else cells[0]
        while self.document.parent(self.document.parent(cell)) != matrix:
            cell = self.document.parent(cell)
        var row = self.document.parent(cell)
        var row_index = self._slot_number(matrix, row)
        var column_index = self._slot_number(row, cell)
        var count = len(self.document.nodes[matrix if row_axis else row].children)
        if remove and count == 1:
            self.status = "A matrix retains at least one row and column"
            return
        self.begin()
        if row_axis:
            if remove:
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
            for r in rows:
                if remove:
                    _ = self.document.nodes[r].children.pop(column_index)
                else:
                    var h = self._hole()
                    self.document.nodes[r].children.insert(column_index + 1, h)
            self.focus(self.document.nodes[row].children[min(column_index if remove else column_index+1, len(self.document.nodes[row].children)-1)])
        self.commit()

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
                var structural=self.selected>=0
                self.document.edit_text(self.document.text())
                self.source = TextInputState(self.document.text())
                var target=self.document.find_id(target_id)
                if target>=0:
                    var n=self.document.nodes[target]
                    if self.has_range_selection():
                        self.source.anchor = self._source_position(self.selection_anchor)
                        self.source.cursor = self._source_position(self.caret)
                    elif structural or (n.kind == MathKind.HOLE and self.caret.offset == 0):
                        self.source.anchor=n.start
                        self.source.cursor=n.end
                    else:
                        self.source.cursor = self._source_position(self.caret)
                        self.source.anchor = -1
            else:
                var anchor=self.source.cursor if self.source.anchor<0 else self.source.anchor
                var target=self.document.node_at_source(min(anchor,self.source.cursor),max(anchor,self.source.cursor))
                var n=self.document.nodes[target]
                if anchor == self.source.cursor:
                    if self._source_position(self.caret) != self.source.cursor or self.selected >= 0 or self.has_range_selection():
                        self._focus_source_caret(self.source.cursor)
                    self.clear_selection()
                elif self.has_range_selection() and anchor == self._source_position(self.selection_anchor) and self.source.cursor == self._source_position(self.caret):
                    pass  # Both endpoints survived the source-mode round trip.
                elif min(anchor,self.source.cursor) == n.start and max(anchor,self.source.cursor) == n.end:
                    self.select(target)
                else:
                    self._focus_source_caret(anchor)
                    var start = self.caret
                    self._focus_source_caret(self.source.cursor)
                    var end = self.caret
                    self.set_caret(start)
                    self.set_caret(end, True)
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
                self.clear_selection()
            else:
                self.focused = False
                self.status = "Math focus released · click an expression to return"
            return
        if command == MathCommand.COMPLEMENT or command == MathCommand.ADD_COMPLEMENT:
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
                            if not self.document.slot_exists(parent, next):
                                if command == MathCommand.COMPLEMENT or self.text_mode:
                                    return
                                self.begin()
                                _ = self.document.create_optional_slot(parent, next)
                                self.focus(n.children[next])
                                self.commit()
                                return
                            self.focus(n.children[next])
                            return
                child = parent
                parent = self.document.parent(parent)
            return
        if self.text_mode:
            self.status = "Use ordinary text editing in text mode"
            return
        if command == MathCommand.ADD_ROW or command == MathCommand.ADD_COLUMN or command == MathCommand.REMOVE_ROW or command == MathCommand.REMOVE_COLUMN:
            self._resize_matrix(command == MathCommand.ADD_ROW or command == MathCommand.REMOVE_ROW, command == MathCommand.REMOVE_ROW or command == MathCommand.REMOVE_COLUMN)
            return
        if command == MathCommand.UNWRAP:
            var owner = self.target()
            if len(self.document.nodes[owner].children) == 0:
                owner = self.document.parent(owner)
            if owner < 0 or len(self.document.nodes[owner].children) == 0:
                return
            var parent = self.document.parent(owner)
            if parent >= 0 and self.document.nodes[parent].kind == MathKind.MATRIX:
                return
            self.begin()
            var children = self.document.nodes[owner].children.copy()
            var row = self.document.add(MathKind.ROW)
            self.document.replace(owner, row)
            for slot in range(len(children)):
                if self.document.slot_exists(owner, slot):
                    self.document.nodes[row].children.append(children[slot])
            self.focus(row)
            self.commit()
            return
        self.begin()
        if command == MathCommand.FRACTION:
            self._wrap(MathKind.FRACTION, 2, 0, 1)
        elif command == MathCommand.ROOT:
            self._wrap(MathKind.ROOT, 2, 1, 1)
        elif command == MathCommand.SUPER:
            self._wrap(MathKind.SCRIPTS, 5, 0, 2)
        elif command == MathCommand.SUB:
            self._wrap(MathKind.SCRIPTS, 5, 0, 1)
        elif command == MathCommand.UNDER or command == MathCommand.OVER:
            self._wrap(MathKind.SCRIPTS, 5, 0, 3 if command == MathCommand.UNDER else 4)
        elif command == MathCommand.MATRIX:
            self._matrix()
        elif command == MathCommand.GROUP:
            self._wrap(MathKind.GROUP, 1, 0, 0, "(", ")")
        elif command == MathCommand.FUNCTION:
            self._wrap(MathKind.FUNCTION, 1, 0, 0, "sin")
        elif command == MathCommand.SUM or command == MathCommand.INTEGRAL:
            self._wrap(MathKind.SUM if command == MathCommand.SUM else MathKind.INTEGRAL, 4, 3, 0)
        self.commit()

    def insert(mut self, text: String) raises:
        if text.byte_length()>MAX_TEXT or "\x00" in text:
            raise Error("Math text size/NUL limit")
        if text == "":
            return
        if self.symbol_entry:
            self.abbreviation += text
            self.status = "Symbol: " + self.abbreviation + " · Escape commits · Backspace corrects · a alpha, b beta, pi, inf"
            return
        self.begin()
        if self.text_mode:
            _ = self.source.insert_text(text)
            self.parse_source()
        else:
            if self.selected < 0 and self.has_range_selection() and not self.has_text_selection():
                _ = self.delete_range(True)
            var index = self.target()
            var n = self.document.nodes[index]
            var parent = self.document.parent(index)
            if self.selected >= 0 and parent >= 0 and self.document.nodes[parent].kind == MathKind.MATRIX:
                self._erase_item(index)
                index = self.index()
                n = self.document.nodes[index]
            if self.selected >= 0 or (n.kind == MathKind.HOLE and self.caret.offset == 0):
                self.document.nodes[index].kind = MathKind.TOKEN
                self.document.nodes[index].authored_empty = False
                self.document.nodes[index].children.clear()
                self.document.nodes[index].text = text
                self.caret = MathPosition(n.id, text.count_codepoints())
            elif n.kind == MathKind.TOKEN or n.kind == MathKind.ERROR:
                var at = min(self.selection_start(), n.text.count_codepoints())
                var end = min(self.selection_end(), n.text.count_codepoints())
                if not self.has_text_selection() and text.count_codepoints() == 1 and text in "+−-*×=<>" and at == n.text.count_codepoints() and at > 0:
                    var row = self.document.add(MathKind.ROW)
                    self.document.replace(index, row)
                    var op = self.document.token(text)
                    var hole = self._hole()
                    self.document.nodes[row].children.append(index)
                    self.document.nodes[row].children.append(op)
                    self.document.nodes[row].children.append(hole)
                    self.focus(hole)
                else:
                    self.document.nodes[index].text = String(n.text[codepoint=0:at]) + text + String(n.text[codepoint=end:])
                    self.caret.offset = at + text.count_codepoints()
            else:
                var token = self.document.token(text)
                self._insert_beside(index, token, self.caret.offset == 1 or self.caret.offset == -2)
                self.focus(token, True)
            self.clear_selection()
        self.commit()

    def _erase_text(mut self, index: Int, start: Int, end: Int):
        var n = self.document.nodes[index]
        self.document.nodes[index].text = String(n.text[codepoint=0:start]) + String(n.text[codepoint=end:])
        self.set_caret(MathPosition(n.id, start))
        if self.document.nodes[index].text == "":
            var parent = self.document.parent(index)
            if self._expression_row(parent):
                self._erase_item(index)
            else:
                var optional = parent >= 0 and self.document.is_optional_slot(parent, self._slot_number(parent, index))
                self._clear_node(index, optional)

    def delete(mut self, forward: Bool = False) raises:
        if self.composition != "":
            return
        if self.symbol_entry:
            if not forward:
                var end = previous_text_boundary(self.abbreviation, self.abbreviation.count_codepoints())
                var shortened = String(self.abbreviation[codepoint=0:end])
                self.abbreviation = shortened^
                self.status = "Symbol: " + self.abbreviation
            return
        if self.text_mode:
            if not self.source.has_selection() and self.source.cursor == (self.source.text.count_codepoints() if forward else 0):
                return
            self.begin()
            if forward:
                _ = self.source.delete_forward()
            else:
                _ = self.source.delete_backward()
            self.parse_source()
            self.commit()
            return
        var index = self.target()
        var n = self.document.nodes[index]
        var parent = self.document.parent(index)
        if self.selected >= 0:
            if n.kind == MathKind.HOLE and (parent < 0 or (not self._expression_row(parent) and not n.authored_empty)):
                return
            self.begin()
            self._erase_item(index)
        elif self.has_text_selection():
            self.begin()
            self._erase_text(index, self.selection_start(), self.selection_end())
        elif self.has_range_selection():
            if not self._range_deletes_content():
                self.set_caret(self.selection_first())
                return
            self.begin()
            _ = self.delete_range()
        else:
            var at = self.caret.offset
            if n.kind == MathKind.HOLE and parent < 0:
                return
            if n.kind == MathKind.HOLE and at == 0:
                if parent >= 0:
                    if self._expression_row(parent) or n.authored_empty:
                        self.select(index)
                    elif self.document.nodes[parent].kind != MathKind.ROW:
                        self.select(parent)
                return
            if (len(n.children) > 0 or n.kind == MathKind.HOLE or n.kind == MathKind.ROW) and ((at == 0 or at == -1) == forward):
                self.select(index)
                return
            var length = n.text.count_codepoints()
            var in_text = n.kind == MathKind.TOKEN or n.kind == MathKind.ERROR
            if not in_text or (at == length if forward else at == 0):
                if parent < 0:
                    return
                if not self._expression_row(parent):
                    if self.document.nodes[parent].kind != MathKind.ROW and self.document.nodes[parent].kind != MathKind.MATRIX:
                        self.select(parent)
                    return
                var slot = self._slot_number(parent, index) + (1 if forward else -1)
                if slot < 0 or slot >= len(self.document.nodes[parent].children):
                    self.select(parent)
                    return
                index = self.document.nodes[parent].children[slot]
                n = self.document.nodes[index]
                if n.kind != MathKind.TOKEN and n.kind != MathKind.ERROR:
                    self.select(index)
                    return
                at = 0 if forward else n.text.count_codepoints()
            var start = at if forward else previous_text_boundary(n.text, at)
            var end = next_text_boundary(n.text, at) if forward else at
            if start == end:
                return
            self.begin()
            self._erase_text(index, start, end)
        self.commit()

    def horizontal(mut self, direction: Int, extend: Bool = False):
        if not extend and self.has_range_selection():
            self.set_caret(self.selection_first() if direction < 0 else self.selection_last())
            return
        if self.selected >= 0 and self.selection_anchor.id < 0:
            var target = self.target()
            if not extend:
                self.set_caret(self._node_edge(target, direction > 0))
                return
            # A whole-node command starts with the focus at its trailing edge.
            self.selection_anchor = self._node_edge(target, False)
            self.caret = self._node_edge(target, True)
        var i = self.index()
        var n = self.document.nodes[i]
        var position = self.caret
        if n.kind == MathKind.HOLE:
            if direction > 0 and position.offset != -2:
                self.set_caret(MathPosition(n.id, 0 if position.offset == -1 else -2), extend)
                return
            if direction < 0 and position.offset != -1:
                self.set_caret(MathPosition(n.id, 0 if position.offset == -2 else -1), extend)
                return
        if n.kind == MathKind.TOKEN or n.kind == MathKind.ERROR:
            if direction < 0 and position.offset > 0:
                self.set_caret(MathPosition(n.id,previous_text_boundary(n.text, position.offset)),extend)
                return
            if direction > 0 and position.offset < n.text.count_codepoints():
                self.set_caret(MathPosition(n.id,next_text_boundary(n.text, position.offset)),extend)
                return
        elif n.kind != MathKind.HOLE and ((direction > 0 and position.offset == 0) or (direction < 0 and position.offset == 1)):
            for step in range(len(n.children)):
                var slot = len(n.children)-step-1 if direction < 0 else step
                if self.document.slot_exists(i, slot):
                    self.set_caret(self._node_edge(n.children[slot], direction < 0), extend)
                    return
            self.set_caret(self._node_edge(i, direction > 0), extend)
            return
        var parent = self.document.parent(i)
        if parent >= 0:
            var slot = self._slot_number(parent, i)+direction
            while slot >= 0 and slot < len(self.document.nodes[parent].children):
                if self.document.slot_exists(parent, slot):
                    self.set_caret(self._node_edge(self.document.nodes[parent].children[slot], direction < 0), extend)
                    return
                slot += direction
            self.set_caret(self._node_edge(parent, direction > 0), extend)
    def _common_range_ancestor(self) -> Int:
        var node = self.document.find_id(self.selection_anchor.id)
        var other = self.index()
        while node >= 0:
            var ancestor = other
            while ancestor >= 0:
                if ancestor == node:
                    return node
                ancestor = self.document.parent(ancestor)
            node = self.document.parent(node)
        return self.document.root
    def _range_fragment(self, i: Int, start: Int, end: Int, mut cursor: Int, mut output: MathDocument, pad_row: Bool = False) -> Int:
        var n = self.document.nodes[i]
        var before = cursor
        var after = before+self._node_width(i)-1
        cursor = after+1
        if end <= before or start >= after:
            return -1
        if start <= before and end >= after:
            return output.clone_from(self.document, i)
        if n.kind == MathKind.TOKEN or n.kind == MathKind.ERROR:
            var left = max(0, start-before)
            var right = min(n.text.count_codepoints(), end-before)
            return output.token(String(n.text[codepoint=left:right])) if right > left else -1
        if n.kind == MathKind.HOLE:
            return output.clone_from(self.document, i)
        var result = output.add(n.kind, n.text)
        output.nodes[result].extra = n.extra
        var child_cursor = before+1
        var any = False
        for slot in range(len(n.children)):
            var child = -1
            if self.document.slot_exists(i, slot):
                child = self._range_fragment(n.children[slot], start, end, child_cursor, output, n.kind == MathKind.MATRIX)
            if child >= 0:
                any = True
                output.nodes[result].children.append(child)
            elif n.kind != MathKind.ROW and n.kind != MathKind.MATRIX or pad_row:
                var hole = output.add(MathKind.HOLE)
                output.nodes[result].children.append(hole)
        return result if any else -1
    def _range_document(self) -> MathDocument:
        var fragment = MathDocument()
        fragment.nodes.clear()
        var root = self._common_range_ancestor()
        var cursor = self.position_order(self._node_edge(root, False))
        fragment.root = self._range_fragment(root, self.position_order(self.selection_first()), self.position_order(self.selection_last()), cursor, fragment)
        return fragment
    def _range_spans(self, i: Int, start: Int, end: Int, mut cursor: Int, mut result: List[_SelectionSpan]):
        var n = self.document.nodes[i]
        var before = cursor
        var after = before+self._node_width(i)-1
        cursor = after+1
        if end <= before or start >= after:
            return
        if start <= before and end >= after:
            result.append(_SelectionSpan(n.id))
            return
        if n.kind == MathKind.TOKEN or n.kind == MathKind.ERROR:
            var left = max(0, start-before)
            var right = min(n.text.count_codepoints(), end-before)
            if right > left:
                result.append(_SelectionSpan(n.id, left, right, False))
        elif n.kind == MathKind.HOLE:
            result.append(_SelectionSpan(n.id))
        else:
            var child_cursor = before+1
            for slot in range(len(n.children)):
                if self.document.slot_exists(i, slot):
                    self._range_spans(n.children[slot], start, end, child_cursor, result)
    def range_spans(self) -> List[_SelectionSpan]:
        var result = List[_SelectionSpan]()
        if self.has_range_selection():
            var cursor = 0
            self._range_spans(self.document.root, self.position_order(self.selection_first()), self.position_order(self.selection_last()), cursor, result)
        return result^
    def _range_deletes_content(self) -> Bool:
        for span in self.range_spans():
            var index = self.document.find_id(span.id)
            var n = self.document.nodes[index]
            if n.kind != MathKind.HOLE:
                return True
            var parent = self.document.parent(index)
            if n.authored_empty or self._expression_row(parent):
                return True
        return False
    def _delete_interval(mut self, i: Int, start: Int, end: Int, mut cursor: Int) -> Bool:
        var n = self.document.nodes[i]
        var before = cursor
        var after = before+self._node_width(i)-1
        cursor = after+1
        if end <= before or start >= after:
            return False
        if start <= before and end >= after:
            return True
        if n.kind == MathKind.TOKEN or n.kind == MathKind.ERROR:
            var left = max(0, start-before)
            var right = min(n.text.count_codepoints(), end-before)
            if right > left:
                self.document.nodes[i].text = String(n.text[codepoint=0:left])+String(n.text[codepoint=right:])
                if self.document.nodes[i].text == "":
                    self._clear_node(i)
            return False
        if n.kind == MathKind.HOLE:
            # A placeholder is atomic even when one endpoint is its inside stop.
            return True
        var child_cursor = before+1
        var kept = List[Int]()
        for slot in range(len(n.children)):
            var child = n.children[slot]
            var removed = False
            if self.document.slot_exists(i, slot):
                removed = self._delete_interval(child, start, end, child_cursor)
            if removed and self._expression_row(i):
                continue
            if removed:
                if n.kind == MathKind.MATRIX:
                    var cells = self.document.nodes[child].children.copy()
                    for cell in cells:
                        self._clear_node(cell)
                else:
                    self._clear_node(child)
            kept.append(child)
        self.document.nodes[i].children = kept^
        if self._expression_row(i) and len(self.document.nodes[i].children) == 0:
            self._clear_node(i)
        return False
    def delete_range(mut self, keep_start_slot: Bool = False) -> Int:
        """Remove precisely the directed range, without starting a transaction."""
        if not self.has_range_selection():
            return self.index()
        var first = self.selection_first()
        var original = self.document.find_id(first.id)
        var original_kind = self.document.nodes[original].kind
        var parent = self.document.parent(original)
        var slot = self._slot_number(parent, original) if parent >= 0 else -1
        var path = List[Int]()
        var ancestor = original
        while ancestor >= 0:
            path.append(ancestor)
            ancestor = self.document.parent(ancestor)
        var cursor = 0
        var removed = self._delete_interval(self.document.root, self.position_order(first), self.position_order(self.selection_last()), cursor)
        if removed:
            self._clear_node(self.document.root)
        self.clear_selection()
        if keep_start_slot:
            # A replacement still belongs in its first optional slot, including
            # a row slot that became empty after all its children were removed.
            for candidate in path:
                var owner = self.document.parent(candidate)
                if owner < 0 or self.document.nodes[candidate].kind != MathKind.HOLE:
                    continue
                var role = self._slot_number(owner, candidate)
                if self.document.is_optional_slot(owner, role) and not self.document.slot_exists(owner, role):
                    self.document.nodes[candidate].authored_empty = True
                    self.focus(candidate)
                    return candidate
        if self.position_order(first) >= 0:
            var n = self.document.nodes[original]
            if n.kind == MathKind.HOLE and (original_kind != MathKind.HOLE or first.offset != -2):
                self.caret = MathPosition(n.id)
            elif n.kind == MathKind.TOKEN or n.kind == MathKind.ERROR:
                self.caret = MathPosition(n.id, min(first.offset, n.text.count_codepoints()))
            else:
                self.caret = first
            return self.index()
        if parent >= 0:
            var children = self.document.nodes[parent].children.copy()
            for step in range(slot):
                var previous = slot-step-1
                if previous < len(children) and self.document.slot_exists(parent, previous):
                    self.set_caret(self._node_edge(children[previous], True))
                    return self.index()
            for next in range(max(0, slot), len(children)):
                if self.document.slot_exists(parent, next):
                    self.set_caret(self._node_edge(children[next], False))
                    return self.index()
            self.focus(parent)
        else:
            self.focus(self.document.root)
        return self.index()
    def _place_fragment(mut self, item: Int):
        var target = self.target()
        var parent = self.document.parent(target)
        if self.selected >= 0 and parent >= 0 and self.document.nodes[parent].kind == MathKind.MATRIX:
            self._erase_item(target)
            target = self.index()
        var n = self.document.nodes[target]
        if self.selected >= 0 or (n.kind == MathKind.HOLE and self.caret.offset == 0):
            self.document.replace(target, item)
        elif n.kind == MathKind.TOKEN or n.kind == MathKind.ERROR:
            var offset = self.caret.offset
            if offset == 0 or offset == n.text.count_codepoints():
                self._insert_beside(target, item, offset > 0)
            else:
                var tail = self.document.token(String(n.text[codepoint=offset:]))
                self.document.nodes[target].text = String(n.text[codepoint=0:offset])
                self._insert_beside(target, tail, True)
                self._insert_beside(target, item, True)
        else:
            self._insert_beside(target, item, self.caret.offset == 1 or self.caret.offset == -2)

    def extract_range(mut self) -> Int:
        """Attach the selected operand at its exact start for a new template."""
        var fragment = self._range_document()
        _ = self.delete_range(True)
        var item = self.document.clone_from(fragment, fragment.root) if fragment.root >= 0 else self._hole()
        self._place_fragment(item)
        self.set_caret(self._node_edge(item, True))
        return item
    def command_selection_to(mut self, direction: Int):
        self.horizontal(direction,True)
    def copy_text(self) -> String:
        if self.text_mode:
            return self.source.selected_text()
        if self.has_text_selection():
            return String(self.document.nodes[self.index()].text[codepoint=self.selection_start():self.selection_end()])
        if self.selected < 0 and self.has_range_selection():
            var fragment = self._range_document()
            return fragment.text() if fragment.root >= 0 else ""
        return self.document.print_node(self.target())
    def copy_fragment_text(self) -> String:
        """Keep token substrings literal when pasted through the fragment format."""
        return quoted(self.copy_text()) if self.has_text_selection() else self.copy_text()
    def paste(mut self, text: String) raises:
        if text == "":
            return
        if self.text_mode:
            self.insert(text)
            return
        var fragment = parse_math(text, self.document.next_id)
        if self.selected < 0 and fragment.nodes[fragment.root].kind == MathKind.TOKEN:
            self.insert(fragment.nodes[fragment.root].text)
            return
        self.begin()
        if self.selected < 0 and self.has_range_selection():
            _ = self.delete_range(True)
        var item = self.document.clone_from(fragment, fragment.root)
        self._place_fragment(item)
        self.focus(item, True)
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
