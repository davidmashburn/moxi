"""F02's real Moxi collection model and frame, shared by native demo and replay.

100,000 stable rows, six mounted rows, edits keyed by row identity. Closing a
window retires native resources but the caller retains this application model.
"""
from std.collections import Dict
from .collection_state import CollectionSelection
from .control_state import MenuState, DialogState
from .controls_text import TextInputState
from .invalidation import INVALIDATE_ALL
from .frame import FramePacket, SurfaceMetrics
from .paint import PaintCommand
from .style import Style, Color
from .geometry import Rect, Size, Point
from .accessibility import Semantics, ROLE_CONTAINER, ROLE_TABLE, ROLE_BUTTON, ROLE_TEXT_INPUT, ACTION_PRESS
from .view_node import LABEL_KIND, BUTTON_KIND, TEXT_INPUT_VIEW_KIND
from .event import Event, CLICK_KIND, ACTION_KIND, TEXT_INPUT_KIND, KEY_DOWN_KIND, FOCUS_KIND, SCROLL_KIND, POINTER_DOWN_KIND, POINTER_UP_KIND, POINTER_CANCEL_KIND, DRAG_BEGIN_KIND, DROP_KIND, KEY_ESCAPE, KEY_TAB, KEY_UP, KEY_DOWN, COMPOSITION_UPDATE_KIND, COMPOSITION_END_KIND

comptime ROOT_ID = 1
comptime TABLE_ID = 2
comptime PREVIOUS_ID = 10
comptime NEXT_ID = 11
comptime MENU_ID = 12
comptime DIALOG_ID = 13
comptime REOPEN_ID = 14
comptime EDITOR_ID = 20
comptime DIALOG_RESULT_ID = 30
comptime ROW_ID_BASE = 1000
comptime VISIBLE_ROWS = 6
comptime DEEP_OFFSET = 50000


struct LifecycleWorkbench:
    var name: String
    var rows: CollectionSelection
    var edits: Dict[Int, String]
    var editor: TextInputState
    var menu: MenuState
    var dialog: DialogState
    var offset: Int
    var selected: Int
    var pressed: Int
    var drag_key: Int
    var focused: Bool
    var menu_requested: Bool
    var dialog_requested: Bool
    var reopen_requested: Bool
    var input_reset: Bool
    var status: String

    def __init__(out self, name: String, count: Int = 100000) raises:
        self.name = name
        if count < VISIBLE_ROWS or count > 100000:
            raise Error("Lifecycle fixture supports 6 to 100000 rows")
        self.rows = CollectionSelection()
        # This synthetic source generates unique nonnegative keys by construction.
        # Avoid the generic set_keys duplicate scan for this large fixed fixture.
        for key in range(count):
            self.rows.keys.append(key)
        self.edits = Dict[Int, String]()
        self.editor = TextInputState("")
        self.menu = MenuState(3)
        self.dialog = DialogState()
        self.offset = min(DEEP_OFFSET, max(0, count - VISIBLE_ROWS))
        self.selected = -1
        self.pressed = -1
        self.drag_key = -1
        self.focused = False
        self.menu_requested = False
        self.dialog_requested = False
        self.reopen_requested = False
        self.input_reset = False
        self.status = "Independent model · drag a row to reorder"
        self.select(self.rows.key_at(self.offset))
        self.focused = False

    def value(self, key: Int) raises -> String:
        if key in self.edits:
            return self.edits[key]
        return String(self.name, " observation ", key + 1)

    def select(mut self, key: Int) raises:
        if self.rows.index_of_key(key) < 0:
            return
        _ = self.rows.select_key(key)
        self.selected = key
        self.editor = TextInputState(self.value(key))
        self.focused = True
        self.input_reset = True

    def page(mut self, offset: Int) raises:
        self.offset = max(0, min(max(0, self.rows.item_count()-VISIBLE_ROWS), offset))
        self.select(self.rows.key_at(self.offset))

    def retire_native(mut self) raises:
        """Discard only transient native interaction; retain selection and edits."""
        _ = self.menu.dismiss()
        if self.dialog.open:
            _ = self.dialog.resolve(0)
        self.editor.clear_composition()
        self.pressed = -1
        self.drag_key = -1
        self.menu_requested = False
        self.dialog_requested = False
        self.reopen_requested = False
        self.input_reset = False
        self.status = "Reopened · retained edits and selection"

    def menu_result(mut self, result: Int) raises:
        if result == 0:
            self.page(0)
        elif result == 1:
            self.page(DEEP_OFFSET)
        elif result == 2:
            self.focused = True
            _ = self.editor.select_all()
            self.input_reset = True

    def row_at(self, point: Point) raises -> Int:
        if point.x < 24 or point.x >= 536 or point.y < 160 or point.y >= 160+VISIBLE_ROWS*42:
            return -1
        return self.rows.key_at(self.offset + Int((point.y-160)/42))

    def hit(self, point: Point) raises -> Int:
        var row = self.row_at(point)
        if row >= 0:
            return ROW_ID_BASE + row
        if Rect(24,460,512,40).contains(point):
            return EDITOR_ID
        if point.y >= 110 and point.y < 144:
            if point.x >= 24 and point.x < 130: return PREVIOUS_ID
            if point.x >= 140 and point.x < 246: return NEXT_ID
            if point.x >= 256 and point.x < 386: return MENU_ID
            if point.x >= 396 and point.x < 536: return DIALOG_ID
        if Rect(24,530,250,38).contains(point):
            return REOPEN_ID
        return -1

    def dispatch(mut self, event: Event) raises -> Bool:
        if event.kind == ACTION_KIND and event.target == DIALOG_RESULT_ID:
            if not self.dialog.open:
                return False
            _ = self.dialog.resolve(event.action_id)
            if event.action_id == 1:
                if self.selected in self.edits:
                    _ = self.edits.pop(self.selected)
                self.select(self.selected)
                self.status = "Dialog applied · selected label reset"
            else:
                self.status = "Dialog cancelled · edits retained"
            return True
        if self.dialog.open:
            return False
        var target = event.target if event.kind == ACTION_KIND else self.hit(event.position)
        if event.kind == POINTER_CANCEL_KIND:
            self.pressed = -1
            self.drag_key = -1
            return True
        if event.kind == POINTER_DOWN_KIND:
            self.pressed = target
            self.drag_key = self.row_at(event.position)
            return False
        if event.kind == DRAG_BEGIN_KIND:
            return self.drag_key >= 0
        if event.kind == DROP_KIND:
            var destination = self.row_at(event.position)
            if self.drag_key >= 0 and destination >= 0:
                var moved = self.rows.reorder(self.rows.index_of_key(self.drag_key), self.rows.index_of_key(destination))
                if moved.changed:
                    self.status = String("Moved row ", self.drag_key+1, " · stable selection retained")
            self.drag_key = -1
            return True
        if event.kind == SCROLL_KIND:
            if event.scroll_delta.y != 0:
                self.page(self.offset + (1 if event.scroll_delta.y > 0 else -1))
            return True
        if event.kind == POINTER_UP_KIND and target != self.pressed:
            target = -1
        if event.kind == CLICK_KIND or event.kind == ACTION_KIND or event.kind == POINTER_UP_KIND:
            self.pressed = -1
            if target >= ROW_ID_BASE:
                self.select(target-ROW_ID_BASE)
            elif target == PREVIOUS_ID: self.page(self.offset-VISIBLE_ROWS)
            elif target == NEXT_ID: self.page(self.offset+VISIBLE_ROWS)
            elif target == MENU_ID: self.menu_requested = True
            elif target == DIALOG_ID: self.dialog_requested = True
            elif target == REOPEN_ID: self.reopen_requested = True
            elif target == EDITOR_ID: self.focused = True
            else: self.focused = False
            return True
        if event.kind == FOCUS_KIND and event.target == EDITOR_ID:
            self.focused = event.focused
            return True
        if event.kind == TEXT_INPUT_KIND and (self.focused or event.target == EDITOR_ID) and (event.target < 0 or event.target == EDITOR_ID):
            self.focused = True
            if event.replacement_start < 0:
                _ = self.editor.insert_text(event.text)
            else:
                _ = self.editor.replace_text_range(event.text, event.replacement_start, event.replacement_end)
            self.edits[self.selected] = self.editor.text
            self.status = String("Saved row ", self.selected+1, " · ", len(self.edits), " edited rows")
            return True
        if event.kind == COMPOSITION_UPDATE_KIND and self.focused:
            self.editor.set_composition(event.text,event.selection_start,event.selection_end)
            return True
        if event.kind == COMPOSITION_END_KIND:
            self.editor.clear_composition()
            return True
        if event.kind == KEY_DOWN_KIND:
            if event.key == KEY_ESCAPE:
                self.focused = False
                self.drag_key = -1
            elif event.key == KEY_TAB:
                self.focused = not self.focused
            elif self.focused:
                _ = self.editor.handle_key(event.key,event.modifiers)
                self.edits[self.selected] = self.editor.text
            elif event.key == KEY_UP or event.key == KEY_DOWN:
                self.page(self.offset + (-1 if event.key == KEY_UP else 1))
            return True
        return False

    def _command(self, mut frame: FramePacket, kind: Int, id: Int, text: String, bounds: Rect, selected: Bool = False) raises:
        var style = Style(Color(0.16,0.21,0.29,1),Color(0.92,0.95,1,1),6,14)
        if selected:
            style.fill = Color(0.12,0.38,0.48,1)
        var command = PaintCommand(kind,id,len(frame.commands),text,bounds,style)
        command.semantics.parent_id = ROOT_ID
        if id >= ROW_ID_BASE:
            command.semantics.parent_id = TABLE_ID
            command.semantics.selected = selected
        if id == EDITOR_ID:
            command.focused = self.focused and not self.dialog.open
            command.cursor = self.editor.cursor
            command.selection_start = self.editor.selection_start()
            command.selection_end = self.editor.selection_end()
            command.composition = self.editor.composition
            command.composition_selection_start = self.editor.composition_selection_start
            command.composition_selection_end = self.editor.composition_selection_end
            command.semantics.parent_id = ROW_ID_BASE+self.selected
            command.semantics.label = String("Edit row ",self.selected+1)
            command.semantics.value = self.editor.text
            command.semantics.focused = command.focused
        frame.semantics.append(command.semantics)
        frame.commands.append(command)

    def frame(self, size: Size) raises -> FramePacket:
        var frame = FramePacket(SurfaceMetrics(size))
        frame.invalidation.invalidate(INVALIDATE_ALL,Rect(0,0,size.width,size.height))
        var root = Semantics(ROOT_ID,ROLE_CONTAINER,String("Lifecycle ",self.name))
        root.bounds = Rect(0,0,size.width,size.height)
        frame.semantics.append(root)
        var table = Semantics(TABLE_ID,ROLE_TABLE,"100000 stable rows")
        table.parent_id = ROOT_ID
        table.bounds = Rect(24,160,512,252)
        frame.semantics.append(table)
        self._command(frame,LABEL_KIND,3,String("MOXI / LIFECYCLE / ",self.name),Rect(24,24,512,32))
        self._command(frame,LABEL_KIND,4,String("Rows ",self.offset+1,"–",self.offset+VISIBLE_ROWS," of ",self.rows.item_count()),Rect(24,64,512,26))
        self._command(frame,BUTTON_KIND,PREVIOUS_ID,"Previous",Rect(24,110,106,34))
        self._command(frame,BUTTON_KIND,NEXT_ID,"Next",Rect(140,110,106,34))
        self._command(frame,BUTTON_KIND,MENU_ID,"Actions ▾",Rect(256,110,130,34))
        self._command(frame,BUTTON_KIND,DIALOG_ID,"Reset label…",Rect(396,110,140,34))
        for i in range(VISIBLE_ROWS):
            var key = self.rows.key_at(self.offset+i)
            if key >= 0:
                self._command(frame,BUTTON_KIND,ROW_ID_BASE+key,String(key+1,"   ",self.value(key)),Rect(24,Float32(160+i*42),512,36),key==self.selected)
        self._command(frame,LABEL_KIND,5,String("Editing stable row ",self.selected+1),Rect(24,426,512,26))
        # Keep the selected row mounted as a semantic parent even after a reorder
        # moves it beyond the visible page. Its editor remains explicitly owned.
        var selected_index = self.rows.index_of_key(self.selected)
        if selected_index < self.offset or selected_index >= self.offset+VISIBLE_ROWS:
            var parent = Semantics(ROW_ID_BASE+self.selected,ROLE_CONTAINER,"Selected row")
            parent.parent_id = TABLE_ID
            frame.semantics.append(parent)
        self._command(frame,TEXT_INPUT_VIEW_KIND,EDITOR_ID,self.editor.text,Rect(24,460,512,40))
        self._command(frame,BUTTON_KIND,REOPEN_ID,"Reopen other window",Rect(24,530,250,38))
        self._command(frame,LABEL_KIND,6,self.status,Rect(24,588,512,28))
        return frame^
