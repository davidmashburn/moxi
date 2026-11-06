"""Keyboard-first application controller consuming only public Moxi/canvas APIs."""
from std.collections import List, Dict
from moxi import App, Rect, Event, Point
from moxi.controls_text import TextInputState
from moxi.event import *
from moxi_canvas import CanvasView, CanvasCommand, CanvasBinding, ShortcutModifier, HostPlatform, dispatch_canvas, invoke_canvas, SessionKind, CanvasHistory, resolve_modifier, CanvasDocument
from .model import *
from .layout import MapLayout
from .history import MapHistory, copy_forest, paste_forest
from .codec import encode
from .commands import MapCommand, bindings
from .topic_control import TopicControl, EditorField
from .reflow import NeighborReflow, MotionPolicy, neighbor_reflow

@fieldwise_init
struct MapMode(Equatable, ImplicitlyCopyable):
    var value: Int
    comptime IDLE = Self(0)
    comptime EDIT = Self(1)
    comptime FIND = Self(2)
    comptime FILTER = Self(3)
    comptime OUTLINE = Self(4)
    comptime MOVE = Self(5)
    comptime PALETTE = Self(6)
    comptime CONNECT = Self(7)
    comptime SPACING = Self(8)
    comptime REPORT = Self(9)

struct MindMapApp:
    var doc: MindMapDocument
    var history: MapHistory
    var layout: MapLayout
    var app: App[CanvasView[TopicControl]]
    var mode: MapMode
    var pending: MapCommand
    var report_text: String
    var query: TextInputState
    var results: List[Int]
    var result_index: Int
    var filter: String
    var reveal: List[Int]
    var partial: Dict[Int, Int]
    var prior_reveal: List[Int]
    var prior: MindMapDocument
    var proposed: MindMapDocument
    var expected: Int
    var destination: Int
    var slot: Int
    var choosing: Bool
    var selection: List[Int]
    var edit_id: Int
    var edit_field: EditorField
    var provisional: Bool
    var multiline: Bool
    var clipboard: String
    var anchor: Int
    var last_children: Dict[Int, Int]
    var pointer_start: Point
    var hover: Int
    var dwell: Float32
    var reflow: NeighborReflow

    def __init__(out self, doc: MindMapDocument, bounds: Rect = Rect(0, 0, 1180, 820)) raises:
        doc.validate()
        self.doc = doc
        self.history = MapHistory(doc)
        self.layout = MapLayout()
        self.layout.compute(doc)
        var canvas = CanvasView[TopicControl](self.layout.project(doc))
        canvas.default_commands = False
        canvas.bindings = bindings()
        canvas.surface_hint = "Mind map. Tab child; Enter sibling; F2 edit; Space fold; F6 toolbar and Commands."
        var toolbar: List[MapCommand] = [MapCommand.PALETTE, MapCommand.CHILD, MapCommand.EDIT, MapCommand.MOVE, MapCommand.FOLD, MapCommand.FIND, MapCommand.OUTLINE, MapCommand.UNDO, MapCommand.SAVE, MapCommand.FIT]
        var titles: List[String] = ["Commands", "Child · Tab", "Edit · F2", "Move branch", "Fold · Space", "Find · ⌘G", "Outline", "Undo · ⌘Z", "Save · ⌘S", "Fit map"]
        for i in range(len(toolbar)):
            canvas.toolbar.append(CanvasBinding(-1, ShortcutModifier.NONE, CanvasCommand(toolbar[i].value), titles[i]))
        for topic in doc.topics:
            canvas.mount(topic.id, TopicControl(topic.text, self.subtitle(doc, topic.id), topic.style))
        canvas.state.select(doc.root)
        self.app = App(canvas, bounds)
        self.mode = MapMode.IDLE
        self.pending = MapCommand.NONE
        self.report_text = ""
        self.query = TextInputState()
        self.results = List[Int]()
        self.result_index = 0
        self.filter = ""
        self.reveal = List[Int]()
        self.partial = Dict[Int, Int]()
        self.prior_reveal = List[Int]()
        self.prior = doc
        self.proposed = doc
        self.expected = 0
        self.destination = -1
        self.slot = 0
        self.choosing = False
        self.selection = List[Int]()
        self.edit_id = -1
        self.edit_field = EditorField.LABEL
        self.provisional = False
        self.multiline = False
        self.clipboard = ""
        self.anchor = doc.root
        self.last_children = Dict[Int, Int]()
        self.pointer_start = Point(0, 0)
        self.hover = -1
        self.dwell = 0
        self.reflow = NeighborReflow()
        _ = invoke_canvas(self.app, CanvasCommand.FIT_ALL)
        self.status("Tab child · Enter sibling · F2 edit · Space fold · F6 toolbar / Commands")

    @staticmethod
    def subtitle(doc: MindMapDocument, id: Int) -> String:
        var topic = doc.topics[doc.at(id)]
        var incident = 0
        for link in doc.links:
            incident += Int(link.source == id or link.target == id)
        return String("▸ " if topic.folded else "▾ ", len(topic.children), " children · ", incident, " links", " · note" if topic.note != "" else "", " · ", topic.tags, " ", topic.icons)

    def status(mut self, message: String):
        self.app.component.state.status = message
        self.app.rebuild_localized()

    def focus(self) -> Int:
        var id = self.app.component.state.focus
        return id if self.doc.contains(id) else self.doc.root

    def selected(self) -> List[Int]:
        var result = List[Int]()
        for id in self.app.component.state.selected:
            if self.doc.contains(id):
                result.append(id)
        if len(result) == 0:
            result.append(self.focus())
        return result^

    def select(mut self, id: Int, extend: Bool = False):
        if self.doc.contains(id):
            self.app.component.state.select(id, extend)
            self.app.component.state.camera.reveal(self.app.component.document.world_bounds(id))
            if not extend:
                self.anchor = id
            self.app.rebuild_localized()

    @no_inline
    def settle_reflow(mut self):
        if self.reflow.active:
            self.reflow.active = False
            self.reflow.apply(self.app.component.document)
            self.app.rebuild_localized()

    def set_motion_policy(mut self, policy: MotionPolicy):
        self.reflow.policy = policy
        if policy == MotionPolicy.REDUCED:
            self.settle_reflow()

    def sync(mut self) raises:
        self.reflow.active = False
        self.layout.compute(self.doc, self.reveal, self.filter, self.partial)
        var projection = self.layout.project(self.doc)
        self.app.component.document = projection
        # Content history belongs to the semantic document. Canvas gestures use
        # its transaction reducer, but never retain a second independent undo log.
        self.app.component.state.history = CanvasHistory()
        self.app.component.content_history.clear()
        self.app.component.content_dirty = False
        var retained = self.app.component.mounts.copy()
        self.app.component.mounts.clear()
        var retained_index = Dict[Int, Int]()
        for i in range(len(retained)):
            retained_index[retained[i].id] = i
        for topic in self.doc.topics:
            var index = retained_index.get(topic.id, -1)
            if index >= 0:
                var item = retained[index]
                var subtitle = Self.subtitle(self.doc, topic.id)
                if self.mode != MapMode.EDIT or self.edit_id != topic.id:
                    if item.child.input.text != topic.text or item.child.subtitle != subtitle or item.child.style != topic.style:
                        item.child = TopicControl(topic.text, subtitle, topic.style)
                        item.refresh(self.app.component.document.world_bounds(topic.id))
                self.app.component.mounts.append(item)
            else:
                self.app.component.mount(topic.id, TopicControl(topic.text, Self.subtitle(self.doc, topic.id), topic.style))
        if not self.doc.contains(self.app.component.state.focus):
            self.app.component.state.select(self.doc.root)
        self.app.rebuild_localized()

    def commit(mut self, candidate: MindMapDocument, title: String) raises -> Bool:
        var changed = self.history.commit(self.doc, candidate, self.expected)
        self.sync()
        self.status(title if changed else "No change; history unchanged")
        return changed

    def begin_edit(mut self, field: EditorField = EditorField.LABEL, provisional: Bool = False) raises:
        self.edit_id = self.focus()
        self.edit_field = field
        if not provisional:
            self.prior = self.doc
        self.expected = self.history.generation
        self.provisional = provisional
        self.mode = MapMode.EDIT
        var topic = self.doc.topics[self.doc.at(self.edit_id)]
        var value = topic.text
        if field == EditorField.NOTE:
            value = topic.note
        elif field == EditorField.LINK:
            value = topic.link
        elif field == EditorField.TAGS:
            value = topic.tags
        elif field == EditorField.ICONS:
            value = topic.icons
        elif field == EditorField.LINK_LABEL:
            for link in self.doc.links:
                if link.source == topic.id or link.target == topic.id:
                    value = link.label
                    break
        var index = self.app.component.mount_index(topic.id)
        self.app.component.mounts[index].child.input = TextInputState(value)
        self.app.component.mounts[index].child.field = field
        self.app.component.mounts[index].refresh(self.app.component.document.world_bounds(topic.id))
        _ = invoke_canvas(self.app, CanvasCommand.ENTER_CONTROLS)
        self.status("Editing · Enter commits · Shift+Enter newline · Escape cancels · composition owns Enter/Escape")

    @no_inline
    def editor_text(self, index: Int) -> String:
        return self.app.component.mounts[index].child.input.text

    def finish_edit(mut self, cancel: Bool = False) raises:
        if self.mode != MapMode.EDIT:
            return
        if self.expected != self.history.generation:
            # Queued input must never restore an older snapshot over newer work.
            self.mode = MapMode.IDLE
            self.provisional = False
            self.app.component.content_dirty = False
            self.app.component.editor = -1
            _ = invoke_canvas(self.app, CanvasCommand.LEAVE_CONTROLS)
            self.sync()
            self.status("Stale editor discarded; newer document retained")
            return
        var id = self.edit_id
        var index = self.app.component.mount_index(id)
        var candidate = self.doc
        var text = self.editor_text(index)
        if self.edit_field == EditorField.LABEL:
            candidate.topics[candidate.at(id)].text = text
        elif self.edit_field == EditorField.NOTE:
            candidate.topics[candidate.at(id)].note = text
        elif self.edit_field == EditorField.LINK:
            candidate.topics[candidate.at(id)].link = text
        elif self.edit_field == EditorField.TAGS:
            candidate.topics[candidate.at(id)].tags = text
        elif self.edit_field == EditorField.ICONS:
            candidate.topics[candidate.at(id)].icons = text
        else:
            for i in range(len(candidate.links)):
                if candidate.links[i].source == id or candidate.links[i].target == id:
                    candidate.links[i].label = text
                    break
        self.mode = MapMode.IDLE
        self.app.component.content_dirty = False
        self.app.component.editor = -1
        _ = invoke_canvas(self.app, CanvasCommand.LEAVE_CONTROLS)
        self.doc = self.prior
        var restored_text = String()
        if self.prior.contains(id):
            restored_text = self.prior.topics[self.prior.at(id)].text
        self.app.component.mounts[index].child = TopicControl(restored_text)
        if not cancel:
            _ = self.commit(candidate, "Topic committed")
        else:
            self.history.highwater = max(self.history.highwater, candidate.next_id)
            self.doc.next_id = max(self.doc.next_id, candidate.next_id)
            self.sync()
            self.status("Edit cancelled; original content restored")
        if self.doc.contains(id):
            self.select(id)
        else:
            self.select(self.doc.root)
        self.provisional = False

    def begin_search(mut self, mode: MapMode):
        self.mode = mode
        self.query = TextInputState()
        self.result_index = 0
        self.prior_reveal = self.reveal.copy()
        self.refresh_results()

    def show_report(mut self, text: String):
        self.report_text = text
        self.begin_search(MapMode.REPORT)

    def refresh_results(mut self):
        self.results.clear()
        self.app.component.search_entries.clear()
        if self.mode == MapMode.REPORT:
            for line in self.report_text.split("\n"):
                self.results.append(len(self.results))
                self.app.component.search_entries.append(String(line))
        elif self.mode == MapMode.PALETTE:
            var seen = Dict[Int, Bool]()
            for entry in bindings():
                if entry.command.value not in seen and (self.query.text == "" or self.query.text.lower() in entry.title.lower()):
                    self.results.append(entry.command.value)
                    self.app.component.search_entries.append(entry.title)
                    seen[entry.command.value] = True
        else:
            for id in self.doc.outline(self.mode == MapMode.OUTLINE):
                var path = self.doc.breadcrumb(id)
                if self.query.text == "" or self.query.text.lower() in path.lower():
                    var valid = True
                    if self.mode == MapMode.MOVE:
                        for root in self.selection:
                            valid = valid and not self.doc.descendant(id, root)
                    if valid:
                        self.results.append(id)
                        self.app.component.search_entries.append(path)
        self.result_index = min(max(0, self.result_index), max(0, len(self.results) - 1))
        # Canvas overlay paints a bounded page. Keep selected result on that page.
        var page = self.result_index // 9 * 9
        var entries = self.app.component.search_entries.copy()
        self.app.component.search_entries.clear()
        for i in range(page, min(page + 9, len(entries))):
            self.app.component.search_entries.append(entries[i])
        self.app.component.search = self.query.text
        self.app.component.search_index = self.result_index - page
        self.app.component.searching = True
        self.status("Import report · ↑↓ scroll · Escape closes · source untouched" if self.mode == MapMode.REPORT else "Outline / search · ↑↓ choose · Enter select · Escape restores reveal; Move branch uses the same destinations")

    def close_search(mut self):
        self.app.component.searching = False
        self.app.component.search_entries.clear()

    def begin_move(mut self, pointer: Bool = False) raises:
        self.settle_reflow()
        self.selection = self.doc.normalized(self.selected())
        for id in self.selection:
            if id == self.doc.root:
                self.status("Cannot move the root")
                _ = invoke_canvas(self.app, CanvasCommand.CANCEL)
                return
        self.prior = self.doc
        self.proposed = self.doc
        self.expected = self.history.generation
        self.destination = -1
        self.slot = 0
        self.prior_reveal = self.reveal.copy()
        self.choosing = not pointer
        if self.app.component.state.session == SessionKind.IDLE:
            _ = invoke_canvas(self.app, CanvasCommand.MOVE)
        # Include descendants in the shared geometric drag preview. Semantic
        # selection remains the normalized forest, so each branch moves once.
        self.app.component.state.selected.clear()
        for topic in self.doc.topics:
            for root in self.selection:
                if self.doc.descendant(topic.id, root):
                    self.app.component.state.selected.append(topic.id)
                    break
        self.mode = MapMode.MOVE
        if not pointer:
            self.begin_search(MapMode.MOVE)
        else:
            self.status("Drag branch header onto parent; top/bottom quarter selects sibling slot · Escape cancels")

    def destination_count(self, parent: Int) -> Int:
        var count = len(self.doc.children(parent))
        for id in self.selection:
            count -= Int(self.doc.topics[self.doc.at(id)].parent == parent)
        return count

    def propose(mut self, parent: Int, slot: Int) raises:
        self.destination = -1
        self.app.component.has_destination = False
        if self.history.generation != self.expected:
            self.cancel()
            self.status("Stale destination discarded")
            return
        var candidate = self.prior
        candidate.move(self.selection, parent, slot)
        self.proposed = candidate
        self.destination = parent
        self.slot = slot
        self.publish_proposal(candidate)
        self.app.rebuild_localized()
        self.status(String("Preview: ", self.doc.breadcrumb(parent), " · slot ", slot, " · Enter commit, ←→ slot, Escape cancel"))

    @no_inline
    def publish_proposal(mut self, candidate: MindMapDocument) raises:
        var layout = self.layout
        var preview_reveal = self.reveal.copy()
        for root in self.selection:
            preview_reveal.append(root)
        layout.compute(candidate, preview_reveal, self.filter, self.partial)
        var projection = layout.project(candidate)
        var drag = self.app.component.state.preview(self.app.component.document)
        # Keep destination hit regions and neighbors stationary during preview.
        # Pointer-owned branches follow the shared drag immediately; keyboard
        # moves show their final destination. Only commit animates neighbors.
        for i in range(len(projection.objects)):
            var moving = False
            for id in self.app.component.state.selected:
                moving = moving or id == projection.objects[i].id
            var old = self.app.component.document.objects[i]
            if not moving and not old.hidden and not projection.objects[i].hidden:
                projection.objects[i].bounds = old.bounds
            elif moving and not self.choosing and self.mode == MapMode.MOVE:
                projection.objects[i].bounds = drag.objects[i].bounds
        _ = self.app.component.propose_destination(projection, String("parent #", self.destination, " / slot ", self.slot), self.app.component.document.revision, semantic_graph=True)
        self.app.rebuild_localized()

    def cancel(mut self) raises:
        self.close_search()
        _ = invoke_canvas(self.app, CanvasCommand.CANCEL)
        _ = self.app.runtime.cancel_press()
        self.reveal = self.prior_reveal.copy()
        self.mode = MapMode.IDLE
        self.destination = -1
        self.hover = -1
        self.sync()
        self.status("Cancelled; hierarchy, folds and history unchanged")

    @no_inline
    def presented_document(self) -> CanvasDocument:
        return self.app.component.presentation_document()

    @no_inline
    def moving_ids(self) -> List[Int]:
        return self.app.component.state.selected.copy()

    @no_inline
    def finish_move(mut self) raises:
        if self.destination < 0:
            self.cancel()
            return
        if self.expected != self.history.generation:
            self.cancel()
            self.status("Stale move discarded")
            return
        var candidate = self.proposed
        var previous = self.presented_document()
        var moving = self.moving_ids()
        self.close_search()
        _ = invoke_canvas(self.app, CanvasCommand.CANCEL)
        _ = self.app.runtime.cancel_press()
        self.mode = MapMode.IDLE
        self.reveal = self.prior_reveal.copy()
        var changed = self.commit(candidate, "Branch move committed · one undo step")
        self.select(self.selection[0])
        if changed:
            var target = self.app.component.document
            var policy = self.reflow.policy
            self.reflow = neighbor_reflow(previous, target, moving, policy)
            self.reflow.apply(self.app.component.document)
            self.app.rebuild_localized()

    def execute(mut self, command: MapCommand) raises:
        self.settle_reflow()
        if self.mode == MapMode.EDIT:
            self.finish_edit()
        if command != MapCommand.EXIT_FOCUS and self.app.component.is_toolbar_target(self.app.runtime.focus_id()):
            _ = invoke_canvas(self.app, CanvasCommand.LEAVE_CONTROLS)
        self.expected = self.history.generation
        var id = self.focus()
        var topic = self.doc.topics[self.doc.at(id)]
        var candidate = self.doc
        if command == MapCommand.CHILD or command == MapCommand.SIBLING or command == MapCommand.PREVIOUS or command == MapCommand.PARENT:
            self.prior = self.doc
            var parent = id
            var slot = len(topic.children)
            if command != MapCommand.CHILD and id != self.doc.root:
                parent = topic.parent
                var siblings = self.doc.children(parent)
                for i in range(len(siblings)):
                    if siblings[i] == id:
                        slot = i + Int(command == MapCommand.SIBLING)
            var created = candidate.create(parent, slot)
            if command == MapCommand.PARENT:
                if id == self.doc.root:
                    self.status("Insert parent is unavailable on the root")
                    return
                candidate.move(List[Int]([id]), created, 0)
            candidate.topics[candidate.at(parent)].folded = False
            candidate.validate()
            self.doc = candidate
            self.sync()
            self.select(created)
            self.begin_edit(provisional=True)
            return
        if command == MapCommand.EDIT or command == MapCommand.MULTILINE or command == MapCommand.NOTES or command == MapCommand.LINK or command == MapCommand.TAGS or command == MapCommand.ICONS or command == MapCommand.LINK_LABEL:
            var field = EditorField.LABEL
            if command == MapCommand.NOTES:
                field = EditorField.NOTE
            elif command == MapCommand.LINK:
                field = EditorField.LINK
            elif command == MapCommand.TAGS:
                field = EditorField.TAGS
            elif command == MapCommand.ICONS:
                field = EditorField.ICONS
            elif command == MapCommand.LINK_LABEL:
                field = EditorField.LINK_LABEL
            self.multiline = command == MapCommand.MULTILINE or command == MapCommand.NOTES
            self.begin_edit(field)
            return
        if command == MapCommand.EDIT_START or command == MapCommand.EDIT_END:
            self.begin_edit()
            var index = self.app.component.mount_index(self.edit_id)
            _ = self.app.component.mounts[index].child.input.handle_key(KEY_HOME if command == MapCommand.EDIT_START else KEY_END, 0)
            self.app.component.mounts[index].refresh(self.app.component.document.world_bounds(self.edit_id))
            self.app.rebuild_localized()
            return
        if command == MapCommand.PAGE_UP or command == MapCommand.PAGE_DOWN or command == MapCommand.SELECT_PAGE_UP or command == MapCommand.SELECT_PAGE_DOWN:
            var up = command == MapCommand.PAGE_UP or command == MapCommand.SELECT_PAGE_UP
            var extend = command == MapCommand.SELECT_PAGE_UP or command == MapCommand.SELECT_PAGE_DOWN
            var bounds = self.app.component.document.world_bounds(id)
            var desired = bounds.y + Float32(-1 if up else 1) * self.app.component.state.camera.viewport.height / Float32(self.app.component.state.camera.zoom)
            var best = id
            var distance = abs(bounds.y - desired)
            for node in self.doc.topics:
                if node.id in self.layout.boxes and self.doc.branch_side(node.id) == self.doc.branch_side(id):
                    var rect = self.layout.boxes[node.id]
                    if abs(rect.y - desired) < distance:
                        best = node.id
                        distance = abs(rect.y - desired)
            self.select(best, extend)
            return
        if command == MapCommand.UNDO or command == MapCommand.REDO:
            _ = self.history.restore(self.doc, command == MapCommand.REDO)
            self.mode = MapMode.IDLE
            self.sync()
            self.select(id if self.doc.contains(id) else self.doc.root)
            self.status("History restored; stable IDs and incident crosslinks retained")
            return
        if command == MapCommand.ROOT:
            if self.mode != MapMode.IDLE:
                self.cancel()
            else:
                self.reveal.clear()
                self.filter = ""
                self.sync()
                self.select(self.doc.root)
            return
        if command == MapCommand.PALETTE or command == MapCommand.FIND or command == MapCommand.FILTER or command == MapCommand.NODE_LIST or command == MapCommand.OUTLINE:
            self.begin_search(MapMode.PALETTE if command == MapCommand.PALETTE else MapMode.FILTER if command == MapCommand.FILTER else MapMode.OUTLINE if command == MapCommand.OUTLINE else MapMode.FIND)
            return
        if command == MapCommand.FIND_NEXT:
            self.mode = MapMode.FIND
            self.result_index += 1
            if len(self.results):
                self.result_index %= len(self.results)
            self.refresh_results()
            if len(self.results):
                var found = self.results[self.result_index]
                self.close_search()
                self.mode = MapMode.IDLE
                self.reveal = List[Int]([found])
                self.sync()
                self.select(found)
            return
        if command == MapCommand.MOVE:
            self.begin_move()
            return
        if command == MapCommand.CONNECT:
            var selected = self.selected()
            if len(selected) == 2:
                candidate.connect(selected[0], selected[1])
                _ = self.commit(candidate, "Crosslink added; ancestry unchanged")
            else:
                self.selection = List[Int]([id])
                self.begin_search(MapMode.CONNECT)
            return
        if command == MapCommand.FOLD or command == MapCommand.FOLD_CHILDREN or command == MapCommand.NEXT_CHILD or command == MapCommand.FOLD_ALL or command == MapCommand.UNFOLD_ALL or command == MapCommand.FOLD_LEVEL or command == MapCommand.UNFOLD_LEVEL:
            var anchor_box = self.app.component.state.camera.rect(self.app.component.document.world_bounds(id))
            if command == MapCommand.FOLD:
                self.doc.topics[self.doc.at(id)].folded = not topic.folded
                if id in self.partial:
                    _ = self.partial.pop(id)
            elif command == MapCommand.NEXT_CHILD:
                self.doc.topics[self.doc.at(id)].folded = False
                if len(topic.children):
                    self.partial[id] = min(len(topic.children), (0 if topic.folded else self.partial.get(id, len(topic.children))) + 1)
            elif command == MapCommand.FOLD_LEVEL or command == MapCommand.UNFOLD_LEVEL:
                var deepest = -1
                if command == MapCommand.FOLD_LEVEL:
                    for node in self.doc.topics:
                        if node.id in self.layout.boxes and self.doc.descendant(node.id, id) and len(node.children) and not node.folded:
                            var depth = 0
                            var cursor = node.id
                            while cursor != id:
                                cursor = self.doc.topics[self.doc.at(cursor)].parent
                                depth += 1
                            deepest = max(deepest, depth)
                for i in range(len(self.doc.topics)):
                    var target = self.doc.topics[i].id
                    if target in self.layout.boxes and self.doc.descendant(target, id) and len(self.doc.topics[i].children):
                        var depth = 0
                        var cursor = target
                        while cursor != id:
                            cursor = self.doc.topics[self.doc.at(cursor)].parent
                            depth += 1
                        if command == MapCommand.UNFOLD_LEVEL or depth == deepest:
                            self.doc.topics[i].folded = command == MapCommand.FOLD_LEVEL
                            if target in self.partial:
                                _ = self.partial.pop(target)
            else:
                var fold = command == MapCommand.FOLD_ALL or command == MapCommand.FOLD_LEVEL or command == MapCommand.FOLD_CHILDREN
                if command == MapCommand.FOLD_CHILDREN:
                    fold = True
                    if not topic.folded:
                        for child in topic.children:
                            if self.doc.topics[self.doc.at(child)].folded:
                                fold = False
                    self.doc.topics[self.doc.at(id)].folded = False
                    if id in self.partial:
                        _ = self.partial.pop(id)
                for i in range(len(self.doc.topics)):
                    var target = self.doc.topics[i].id
                    if self.doc.descendant(target, id) and (command == MapCommand.FOLD_ALL or command == MapCommand.UNFOLD_ALL or self.doc.topics[i].parent == id):
                        self.doc.topics[i].folded = fold
            self.reveal.clear()
            self.sync()
            var moved_box = self.app.component.state.camera.rect(self.app.component.document.world_bounds(id))
            self.app.component.state.camera.pan(anchor_box.x - moved_box.x, anchor_box.y - moved_box.y)
            self.app.rebuild_localized()
            self.status("Fold preference updated; content history unchanged")
            return
        if command == MapCommand.SELECT_ALL or command == MapCommand.SELECT_BRANCH:
            self.app.component.state.selected.clear()
            for target in self.doc.outline(command == MapCommand.SELECT_ALL):
                if command == MapCommand.SELECT_ALL or self.doc.descendant(target, id):
                    self.app.component.state.selected.append(target)
            self.status(String(len(self.selected()), " topics selected; moves normalize selected ancestors"))
            return
        if command == MapCommand.UP or command == MapCommand.DOWN or command == MapCommand.SELECT_UP or command == MapCommand.SELECT_DOWN:
            var order = self.doc.outline(True) if command == MapCommand.SELECT_UP or command == MapCommand.SELECT_DOWN else self.doc.children(topic.parent) if id != self.doc.root else self.doc.outline(True)
            for i in range(len(order)):
                if order[i] == id:
                    var next = order[min(max(i + (-1 if command == MapCommand.UP or command == MapCommand.SELECT_UP else 1), 0), len(order) - 1)]
                    if command == MapCommand.SELECT_UP or command == MapCommand.SELECT_DOWN:
                        var anchor_index = i
                        var next_index = i
                        for j in range(len(order)):
                            if order[j] == self.anchor:
                                anchor_index = j
                            if order[j] == next:
                                next_index = j
                        self.app.component.state.selected.clear()
                        for j in range(min(anchor_index, next_index), max(anchor_index, next_index) + 1):
                            self.app.component.state.selected.append(order[j])
                        self.app.component.state.focus = next
                        self.app.rebuild_localized()
                    else:
                        self.select(next)
                    break
            return
        if command == MapCommand.LEFT or command == MapCommand.RIGHT or command == MapCommand.SELECT_LEFT or command == MapCommand.SELECT_RIGHT:
            var right = command == MapCommand.RIGHT or command == MapCommand.SELECT_RIGHT
            var extend = command == MapCommand.SELECT_LEFT or command == MapCommand.SELECT_RIGHT
            var outward = right == (self.doc.branch_side(id) == Side.RIGHT)
            if id == self.doc.root:
                for child in topic.children:
                    if (self.doc.branch_side(child) == Side.RIGHT) == right:
                        self.select(child, extend)
                        break
            elif outward and len(topic.children):
                self.doc.topics[self.doc.at(id)].folded = False
                self.sync()
                self.select(self.last_children.get(id, topic.children[0]), extend)
            elif not outward:
                self.last_children[topic.parent] = id
                self.select(topic.parent, extend)
            return
        if command == MapCommand.REORDER_UP or command == MapCommand.REORDER_DOWN or command == MapCommand.LEVEL_LEFT or command == MapCommand.LEVEL_RIGHT:
            if id == self.doc.root:
                self.status("Root cannot be moved")
                return
            var siblings = self.doc.children(topic.parent)
            var index = 0
            for i in range(len(siblings)):
                if siblings[i] == id:
                    index = i
            if command == MapCommand.REORDER_UP or command == MapCommand.REORDER_DOWN:
                var target = index + (-1 if command == MapCommand.REORDER_UP else 1)
                if target < 0 or target >= len(siblings):
                    self.status("Already at sibling boundary")
                    return
                candidate.move(List[Int]([id]), topic.parent, target)
            else:
                var outward = (command == MapCommand.LEVEL_RIGHT) == (self.doc.branch_side(id) == Side.RIGHT)
                if not outward and topic.parent == self.doc.root:
                    candidate.topics[candidate.at(id)].side = Side.LEFT if command == MapCommand.LEVEL_LEFT else Side.RIGHT
                elif outward and index > 0:
                    candidate.move(List[Int]([id]), siblings[index - 1], len(candidate.children(siblings[index - 1])))
                elif not outward:
                    var grandparent = candidate.topics[candidate.at(topic.parent)].parent
                    var uncles = candidate.children(grandparent)
                    var slot = 0
                    for i in range(len(uncles)):
                        if uncles[i] == topic.parent:
                            slot = i + 1
                    candidate.move(List[Int]([id]), grandparent, slot)
                else:
                    self.status("No preceding sibling to indent beneath")
                    return
        elif command == MapCommand.DELETE:
            candidate.erase(self.selected())
        elif command == MapCommand.COPY or command == MapCommand.CUT:
            self.clipboard = copy_forest(self.doc, self.selected())
            if command == MapCommand.COPY:
                self.status("Structured branch copied; outbound crosslinks omitted")
                return
            candidate.erase(self.selected())
        elif command == MapCommand.PASTE or command == MapCommand.DUPLICATE:
            var text = self.clipboard if command == MapCommand.PASTE else copy_forest(self.doc, self.selected())
            _ = paste_forest(candidate, id if command == MapCommand.PASTE or id == self.doc.root else topic.parent, text)
        elif command == MapCommand.SIDE:
            var branch = id
            while candidate.topics[candidate.at(branch)].parent != candidate.root and branch != candidate.root:
                branch = candidate.topics[candidate.at(branch)].parent
            candidate.topics[candidate.at(branch)].side = Side.LEFT if candidate.branch_side(branch) == Side.RIGHT else Side.RIGHT
        elif command == MapCommand.ONE_SIDE:
            candidate.arrangement = Arrangement.RIGHT_ONLY if candidate.arrangement == Arrangement.TWO_SIDED else Arrangement.TWO_SIDED
        elif command == MapCommand.SPACE_MORE or command == MapCommand.SPACE_LESS:
            candidate.topics[candidate.at(id)].spacing = min(400, max(-400, topic.spacing + (20 if command == MapCommand.SPACE_MORE else -20)))
        elif command == MapCommand.STYLE:
            candidate.topics[candidate.at(id)].style = TopicStyle((topic.style.value + 1) % 4)
        elif command == MapCommand.UNLINK:
            var links = List[Crosslink]()
            var removed = False
            for link in candidate.links:
                if not removed and (link.source == id or link.target == id):
                    removed = True
                else:
                    links.append(link)
            candidate.links = links^
        elif command == MapCommand.FIT or command == MapCommand.ZOOM_IN or command == MapCommand.ZOOM_OUT:
            _ = invoke_canvas(self.app, CanvasCommand.FIT_ALL if command == MapCommand.FIT else CanvasCommand.ZOOM_IN if command == MapCommand.ZOOM_IN else CanvasCommand.ZOOM_OUT)
            return
        elif command == MapCommand.EXIT_FOCUS:
            _ = invoke_canvas(self.app, CanvasCommand.LEAVE_CONTROLS)
            _ = self.app.runtime.set_focus(self.app.component.toolbar_target(CanvasCommand(MapCommand.PALETTE.value)))
            self.status("Toolbar focus · Tab traverses ordinary buttons · choose a map topic to return")
            return
        elif command == MapCommand.SAVE or command == MapCommand.SAVE_AS or command == MapCommand.OPEN or command == MapCommand.RECOVER or command == MapCommand.IMPORT or command == MapCommand.NEW:
            self.pending = command
            return
        else:
            return
        _ = self.commit(candidate, "Map command committed · one undo step")
        self.select(id if self.doc.contains(id) else self.doc.root)

    def dispatch(mut self, event: Event) -> Bool:
        try:
            return self.handle(event)
        except e:
            self.status(String("Rejected: ", e))
            return True

    def handle(mut self, event: Event) raises -> Bool:
        if event.kind == FRAME_TICK_KIND and self.reflow.active:
            var changed = self.reflow.advance(event.delta_seconds)
            if changed:
                self.reflow.apply(self.app.component.document)
                self.app.rebuild_localized()
            return dispatch_canvas(self.app, event) or changed
        if event.kind == POINTER_CANCEL_KIND or (event.kind == FOCUS_KIND and not event.focused and event.target < 0):
            if self.mode == MapMode.MOVE or self.mode == MapMode.SPACING:
                self.cancel()
            return dispatch_canvas(self.app, event)
        if self.mode == MapMode.EDIT:
            var index = self.app.component.mount_index(self.edit_id)
            var composing = self.app.component.mounts[index].child.input.has_composition()
            if event.kind == KEY_DOWN_KIND and not composing:
                if event.key == KEY_ESCAPE:
                    self.finish_edit(True)
                    return True
                if event.key == KEY_ENTER:
                    if event.modifiers & MOD_SHIFT:
                        var newline = Event()
                        newline.kind = TEXT_INPUT_KIND
                        newline.text = "\n"
                        return dispatch_canvas(self.app, newline)
                    self.finish_edit()
                    return True
            if event.kind == POINTER_DOWN_KIND and self.app.component.control_at(event.position, self.app.view) < 0:
                self.finish_edit()
            else:
                return dispatch_canvas(self.app, event)
        if self.app.component.searching:
            if event.kind == TEXT_INPUT_KIND:
                if self.mode == MapMode.REPORT:
                    return True
                _ = self.query.insert_text(event.text)
                self.result_index = 0
                self.refresh_results()
                return True
            if event.kind == KEY_DOWN_KIND:
                if event.key == KEY_ESCAPE:
                    self.cancel()
                elif event.key == KEY_UP or event.key == KEY_DOWN:
                    self.result_index = min(max(self.result_index + (-1 if event.key == KEY_UP else 1), 0), max(0, len(self.results) - 1))
                    self.refresh_results()
                elif event.key == KEY_ENTER and self.mode == MapMode.REPORT:
                    return True
                elif event.key == KEY_ENTER and len(self.results):
                    var chosen = self.results[self.result_index]
                    var mode = self.mode
                    self.close_search()
                    if mode == MapMode.PALETTE:
                        self.mode = MapMode.IDLE
                        self.execute(MapCommand(chosen))
                    elif mode == MapMode.MOVE:
                        self.choosing = False
                        self.propose(chosen, self.destination_count(chosen))
                    elif mode == MapMode.CONNECT:
                        var candidate = self.doc
                        candidate.connect(self.selection[0], chosen)
                        self.mode = MapMode.IDLE
                        _ = self.commit(candidate, "Crosslink added")
                    else:
                        self.mode = MapMode.IDLE
                        if mode == MapMode.FILTER:
                            self.filter = self.query.text
                        self.reveal = List[Int]([chosen])
                        self.sync()
                        self.select(chosen)
                        self.status("Search reveal is temporary · Escape restores folds/filter · Move branch works from this outline selection")
                else:
                    if self.mode == MapMode.REPORT:
                        return True
                    _ = self.query.handle_key(event.key, event.modifiers)
                    self.refresh_results()
                return True
            return False
        if self.mode == MapMode.MOVE or self.mode == MapMode.SPACING:
            if event.kind == KEY_DOWN_KIND:
                if event.key == KEY_ESCAPE:
                    self.cancel()
                elif event.key == KEY_ENTER:
                    self.finish_move()
                elif self.destination >= 0 and (event.key == KEY_LEFT or event.key == KEY_RIGHT):
                    var count = len(self.doc.children(self.destination))
                    for id in self.selection:
                        count -= Int(self.doc.topics[self.doc.at(id)].parent == self.destination)
                    self.propose(self.destination, min(count, max(0, self.slot + (-1 if event.key == KEY_LEFT else 1))))
                return True
            if event.kind == POINTER_UP_KIND or event.kind == DROP_KIND:
                self.finish_move()
                return True
            if event.kind == POINTER_MOVE_KIND or event.kind == DRAG_UPDATE_KIND:
                # Shared canvas capture/autopan owns pointer mechanics. Semantic
                # hit regions remain the committed layout, never preview reflow.
                _ = dispatch_canvas(self.app, event)
                var hit = -1
                for object in self.app.component.document.objects:
                    if not object.hidden and self.app.component.state.camera.rect(object.bounds).contains(event.position):
                        hit = object.id
                        break
                if self.mode == MapMode.SPACING:
                    var candidate = self.prior
                    var id = self.selection[0]
                    candidate.topics[candidate.at(id)].spacing = min(400, max(-400, self.prior.topics[self.prior.at(id)].spacing + Int((event.position.x - self.pointer_start.x) / Float32(self.app.component.state.camera.zoom))))
                    self.proposed = candidate
                    self.destination = candidate.topics[candidate.at(id)].parent
                    self.publish_proposal(candidate)
                    self.status(String("Spacing preview: ", candidate.topics[candidate.at(id)].spacing, " · release commits; Escape cancels"))
                elif hit >= 0:
                    var parent = hit
                    var slot = self.destination_count(hit)
                    var bounds = self.app.component.state.camera.rect(self.app.component.document.world_bounds(hit))
                    if hit != self.doc.root and (event.position.y < bounds.y + bounds.height * 0.25 or event.position.y > bounds.y + bounds.height * 0.75):
                        parent = self.doc.topics[self.doc.at(hit)].parent
                        var siblings = self.doc.children(parent)
                        slot = 0
                        for sibling in siblings:
                            if sibling == hit:
                                break
                            var moving = False
                            for id in self.selection:
                                moving = moving or id == sibling
                            slot += Int(not moving)
                        slot += Int(event.position.y > bounds.y + bounds.height * 0.75)
                    if hit != self.hover:
                        self.hover = hit
                        self.dwell = 0
                    self.propose(parent, slot)
                    if parent == self.doc.root:
                        self.proposed.topics[self.proposed.at(self.selection[0])].side = Side.LEFT if event.position.x < (self.app.component.state.camera.rect(self.app.component.document.world_bounds(self.doc.root)).x + self.app.component.state.camera.rect(self.app.component.document.world_bounds(self.doc.root)).width / 2) else Side.RIGHT
                        var preview = self.proposed
                        self.publish_proposal(preview)
                else:
                    self.destination = -1
                    self.app.component.has_destination = False
                return True
            if event.kind == FRAME_TICK_KIND:
                self.dwell += event.delta_seconds
                if self.hover >= 0 and self.dwell > 0.6 and self.doc.topics[self.doc.at(self.hover)].folded:
                    var revealed = False
                    for target in self.reveal:
                        revealed = revealed or target == self.hover
                    if not revealed:
                        # Reveal children without changing the stored fold preference.
                        for child in self.doc.children(self.hover):
                            self.reveal.append(child)
                        self.reveal.append(self.hover)
                        self.sync()
                        if self.destination >= 0:
                            var preview = self.proposed
                            self.publish_proposal(preview)
                        self.status("Temporarily revealed folded destination; Escape restores folds")
                return dispatch_canvas(self.app, event)
        if event.kind == KEY_DOWN_KIND and not self.app.component.is_toolbar_target(self.app.runtime.focus_id()):
            for binding in self.app.component.bindings:
                if event.key == binding.key and event.modifiers == resolve_modifier(binding.modifier, HostPlatform.MACOS):
                    self.execute(MapCommand(binding.command.value))
                    return True
        if event.kind == TEXT_INPUT_KIND and self.app.component.editor < 0 and event.text == " ":
            self.execute(MapCommand.FOLD)
            return True
        if event.kind == TEXT_INPUT_KIND and self.mode == MapMode.IDLE and not self.app.component.is_toolbar_target(self.app.runtime.focus_id()):
            self.begin_edit()
            var editor_index = self.app.component.mount_index(self.edit_id)
            _ = self.app.component.mounts[editor_index].child.input.select_all()
            return dispatch_canvas(self.app, event)
        var changed = dispatch_canvas(self.app, event)
        var pending = self.app.component.take_application_command()
        if pending != CanvasCommand.NONE:
            self.execute(MapCommand(pending.value))
            return True
        if event.kind == POINTER_DOWN_KIND:
            if self.app.component.state.session == SessionKind.MOVE:
                self.pointer_start = event.position
                self.begin_move(True)
            elif self.app.component.state.session == SessionKind.RESIZE:
                self.pointer_start = event.position
                _ = invoke_canvas(self.app, CanvasCommand.CANCEL)
                self.begin_move(True)
                if self.mode == MapMode.MOVE:
                    self.mode = MapMode.SPACING
            elif self.app.component.editor >= 0:
                self.select(self.app.component.editor)
                self.begin_edit()
        for i in range(len(self.app.component.mounts)):
            if self.app.component.mounts[i].child.fold_requested:
                self.app.component.mounts[i].child.fold_requested = False
                self.select(self.app.component.mounts[i].id)
                self.execute(MapCommand.FOLD)
                return True
        return changed
