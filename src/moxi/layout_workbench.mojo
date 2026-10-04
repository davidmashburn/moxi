"""Candidate acceptance screen composing flow, Kiwi, collection and popup policy."""
from std.collections import List, Dict
from std.ffi import external_call
from .geometry import Rect, Size, Point
from .retained_layout import RetainedLayout, RetainedStyle, RetainedPlacement, RetainedSnapshot, COLUMN, ROW, WRAP, STACK, LEAF, COLLAPSED, FILL, FIXED
from .constraint_layout import ConstraintRegion, LinearConstraint, coordinate, PARENT_WIDTH, AT_LEAST
from .collection_layout import CollectionViewport
from .overlay_layout import place_overlay
from .popup import PopupLayerState, POPUP_MENU, POPUP_DIALOG
from .controls_text import TextInputControl, TextInputState
from .event import Event, TEXT_INPUT_KIND, COMPOSITION_UPDATE_KIND, COMPOSITION_END_KIND
from .view_node import ViewNode, LABEL_KIND, BUTTON_KIND, CANVAS_KIND
from .retained_leaf import declare_leaf, RetainedPresentation
from .accessibility import Semantics, ROLE_CONTAINER, ROLE_DIALOG, ROLE_MENU


def _fixed(key: Int, axis: Int, value: Float64) raises -> LinearConstraint:
    return LinearConstraint([coordinate(key,axis)],[Float64(1)],-value)


struct LayoutWorkbench:
    var tree: RetainedLayout
    var form: ConstraintRegion
    var table: CollectionViewport
    var popups: PopupLayerState
    var editor: TextInputState
    var cell_editor: TextInputState
    var editing_row: Int
    var focused: Int
    var summary: Bool
    var rtl: Bool
    var text_scale: Float32
    var form_width: Float32
    var offset_x: Float64
    var offset_y: Float64
    var conflict: Bool
    var modal: Bool
    var error: String
    var _cells: Dict[Int,Bool]
    var _leaves: List[ViewNode]
    var _published_leaves: List[ViewNode]
    var _published_focus: Int
    var _published_accessibility_root: Int
    var _snapshot: RetainedSnapshot
    var _size: Size
    var _phase_ns: List[Int64]

    def __init__(out self, row_count: Int = 100000) raises:
        self.tree = RetainedLayout()
        self.form = ConstraintRegion()
        self.table = CollectionViewport()
        self.popups = PopupLayerState()
        self.editor = TextInputState("Annual observations 日本語")
        self.cell_editor = TextInputState("Edit this retained row")
        self.editing_row = -1
        self.focused = 13
        self.summary = False
        self.rtl = False
        self.text_scale = 1
        self.form_width = 320
        self.offset_x = 0
        self.offset_y = 0
        self.conflict = False
        self.modal = False
        self.error = ""
        self._cells = Dict[Int,Bool]()
        self._leaves = List[ViewNode]()
        self._published_leaves = List[ViewNode]()
        self._published_focus = -1
        self._published_accessibility_root = -1
        self._snapshot = RetainedSnapshot()
        self._size = Size(0,0)
        self._phase_ns = List[Int64]()
        self.set_rows(row_count)
        self.table.columns.sync([1,2,3,4],[Float64(180),180,180,180])

    def set_rows(mut self, count: Int) raises:
        if count < 0 or count > 100000:
            raise Error("Workbench source count outside the acceptance profile")
        var keys = List[Int]()
        var heights = List[Float64]()
        for i in range(count):
            keys.append(i+1)
            heights.append(Float64(32 + Int(i%7==0)*16))
        self.table.sync_rows(keys,heights)
        # Source removal is authoritative even if a later strategy rejects layout.
        var retired = List[Int]()
        for key in self._cells.keys():
            if self.table.rows.index((key-1000)//10)<0:
                retired.append(key)
        for key in retired:
            self.tree.remove(key)
            _ = self._cells.pop(key)
        if self.table.rows.index(self.editing_row)<0:
            self.editing_row = -1
            if self.focused>=1000:
                self.focused = 13

    def _leaf(mut self, node: ViewNode, style: RetainedStyle) raises:
        declare_leaf(self.tree,node,style)
        self._leaves.append(node)

    def _declare(mut self, size: Size) raises:
        self._leaves = List[ViewNode]()
        self.tree.set_region(1,RetainedStyle(STACK))
        self.tree.set_region(2,RetainedStyle(COLUMN,width_kind=FILL,height_kind=FILL,padding=16,gap=12))
        self.tree.set_region(3,RetainedStyle(WRAP,gap=8,align=4,rtl=self.rtl))
        var names: List[String] = ["Summary","RTL","Columns","Conflict","Empty / 100k","Text size","Dialog"]
        for i in range(len(names)):
            var button = ViewNode(BUTTON_KIND,40+i,names[i],36)
            button.style.font_size = 15*self.text_scale
            self._leaf(button,RetainedStyle(LEAF,width_kind=FIXED,width=Float32(72+names[i].count_codepoints()*4)*self.text_scale,height_kind=FIXED,height=36*self.text_scale))
        self.tree.children(3,[40,41,42,43,44,45,46])
        var narrow = size.width < 760
        self.tree.set_region(8,RetainedStyle(COLUMN if narrow else ROW,grow=1,gap=12,rtl=self.rtl))
        self.tree.set_region(10,RetainedStyle(COLUMN,width_kind=FILL if narrow else FIXED,width=min(self.form_width,max(Float32(240),size.width-250)),height_kind=FIXED if narrow else FILL,height=220*self.text_scale))
        self.tree.set_region(20,RetainedStyle(COLUMN,grow=1,min_width=180,gap=12))
        self.tree.set_region(21,RetainedStyle(STACK,grow=1,min_height=140,overflow=1),"Results")
        var table_semantics = Semantics(21,ROLE_CONTAINER,"Results table")
        table_semantics.value = String(self.table.rows.count()," rows, ",self.table.columns.count()," columns")
        self.tree.set_semantics(21,table_semantics)
        self._leaf(ViewNode(CANVAS_KIND,22,"Temperature chart",160),RetainedStyle(LEAF,height_kind=FIXED,height=160,min_height=160))
        self.tree.children(20,[21,22])
        self.tree.set_region(30,RetainedStyle(COLUMN if self.summary else COLLAPSED))
        var summary = ViewNode(LABEL_KIND,31,"Localized summary: 日本語 العربية. Stable settings and editors survive adaptive layout, scrolling and summary insertion.",40)
        summary.style.font_size = 17*self.text_scale
        self._leaf(summary,RetainedStyle(LEAF))
        self.tree.children(30,[31])
        self.tree.children(2,[3,30,8])
        self._leaf(ViewNode(CANVAS_KIND,18,"Resize settings pane",20),RetainedStyle(COLLAPSED if narrow else LEAF,width_kind=FIXED,width=6))
        self.tree.children(8,[10,20,18])
        if narrow:
            self.tree.clear_placement(18)
        var title = ViewNode(LABEL_KIND,11,"Settings",30)
        title.style.font_size = 22*self.text_scale
        self._leaf(title,RetainedStyle(LEAF))
        var label = ViewNode(LABEL_KIND,12,"Dataset",30)
        label.style.font_size = 15*self.text_scale
        self._leaf(label,RetainedStyle(LEAF))
        var editor = TextInputControl(13,self.editor.text,self.editor.cursor,self.editor.anchor,36*self.text_scale)
        editor.style.font_size = 17*self.text_scale
        editor.set_composition(self.editor.composition,self.editor.composition_selection_start,self.editor.composition_selection_end)
        var editor_node = editor.node()
        editor_node.set_accessibility_label("Dataset")
        self._leaf(editor_node,RetainedStyle(LEAF))
        var description = ViewNode(LABEL_KIND,14,"Resize the pane or window. Scroll results; double-click is not required: select a cell to keep its editor alive.",80)
        description.style.font_size = 17*self.text_scale
        self._leaf(description,RetainedStyle(LEAF))
        self.tree.children(10,[11,12,13,14])
        self._leaf(ViewNode(CANVAS_KIND,90,"Popup background",160),RetainedStyle(STACK if self.popups.is_open() else COLLAPSED,overflow=1))
        var popup_semantics = Semantics(90,ROLE_DIALOG if self.modal else ROLE_MENU,"Layout dialog" if self.modal else "Columns")
        popup_semantics.expanded = self.popups.is_open()
        self.tree.set_semantics(90,popup_semantics)
        if not self.popups.is_open():
            self.tree.clear_placement(90)
        self.tree.set_region(91,RetainedStyle(COLUMN,gap=8,padding=12))
        for i in range(3):
            var item = ViewNode(BUTTON_KIND,92+i, String("Close dialog" if self.modal else "Column ",i+1),36)
            self._leaf(item,RetainedStyle(LEAF,height_kind=FIXED,height=36))
        self.tree.children(91,[92,93,94])
        self.tree.children(90,[91])
        self.tree.children(1,[2,90])

    def _record_phase[profile: Bool](mut self):
        if profile:
            self._phase_ns.append(external_call["moxi_benchmark_time_ns", Int64]())

    def frame[profile: Bool = False](mut self, size: Size) raises -> RetainedPresentation:
        # Profiling is compiled out for ordinary frames. The acceptance benchmark
        # supplies the clock and reads ten boundary timestamps (nine phases).
        if profile:
            self._phase_ns = List[Int64]()
        self._record_phase[profile]()
        self._declare(size)
        self._record_phase[profile]()
        var allocation = self.tree.stage(1,size)
        self._record_phase[profile]()
        var form_rect = allocation.snapshot.bounds(10)
        var constraints = List[LinearConstraint]()
        for key in [11,12,13,14]:
            constraints.append(_fixed(key,0,Float64(12 if key!=13 else 104)*Float64(self.text_scale)))
        for key in [11,14]:
            constraints.append(LinearConstraint([coordinate(key,2),PARENT_WIDTH],[Float64(1),-1],24*Float64(self.text_scale)))
        constraints.append(_fixed(11,1,12*Float64(self.text_scale)))
        constraints.append(_fixed(11,3,32*Float64(self.text_scale)))
        var label_baseline = allocation.snapshot.output(12).paragraph.metrics().first_baseline
        var field_baseline = allocation.snapshot.output(14).paragraph.metrics().first_baseline
        constraints.append(_fixed(12,1,60*Float64(self.text_scale)+8+Float64(field_baseline-label_baseline)))
        constraints.append(_fixed(12,2,80*Float64(self.text_scale)))
        constraints.append(_fixed(12,3,32*Float64(self.text_scale)))
        constraints.append(_fixed(13,1,60*Float64(self.text_scale)))
        constraints.append(LinearConstraint([coordinate(13,2),PARENT_WIDTH],[Float64(1),-1],116*Float64(self.text_scale)))
        constraints.append(_fixed(13,3,36*Float64(self.text_scale)))
        constraints.append(_fixed(14,1,112*Float64(self.text_scale)))
        constraints.append(_fixed(14,3,92*Float64(self.text_scale)))
        if self.conflict:
            constraints.append(LinearConstraint([coordinate(13,2)],[Float64(1)],-10000,AT_LEAST))
        self.form.model([11,12,13,14],constraints)
        var form_plan = self.form.stage(Size(form_rect.width,form_rect.height))
        self._record_phase[profile]()
        var placements = List[RetainedPlacement]()
        for key in [11,12,13,14]:
            placements.append(RetainedPlacement(key,form_plan.rectangles[key]))
        if size.width>=760:
            var body = allocation.snapshot.bounds(8)
            var pane = allocation.snapshot.bounds(10)
            placements.append(RetainedPlacement(18,Rect(pane.x-body.x-9 if self.rtl else pane.x-body.x+pane.width+3,pane.y-body.y,6,pane.height)))
        var viewport = allocation.snapshot.bounds(21)
        var collection = self.table.stage(viewport,self.offset_x,self.offset_y,overscan=1,frozen_rows=min(1,self.table.rows.count()),frozen_columns=1,rtl=self.rtl)
        self._record_phase[profile]()
        var cells = Dict[Int,Bool]()
        var children = List[Int]()
        var popup_anchor = allocation.snapshot.bounds(42)
        var anchor_present = self.popups.top_owner_id()!=1011
        for cell in collection.cells:
            var key = 1000+cell.row_key*10+cell.column_key
            cells[key] = True
            children.append(key)
            if key==self.popups.top_owner_id():
                popup_anchor = cell.rect
                anchor_present = cell.clip.width>0 and cell.clip.height>0
            var text = String("Region ",cell.row_key) if cell.column_key==1 else String("Value ",cell.row_key," · ",cell.column_key)
            var node = ViewNode(LABEL_KIND,key,text,32)
            node.style.font_size = 14*self.text_scale
            if cell.row_key==self.editing_row and cell.column_key==2:
                var editor = TextInputControl(key,self.cell_editor.text,self.cell_editor.cursor,self.cell_editor.anchor,32)
                editor.set_composition(self.cell_editor.composition,self.cell_editor.composition_selection_start,self.cell_editor.composition_selection_end)
                node = editor.node()
                node.set_accessibility_label(String("Value, region ",cell.row_key,", column ",cell.column_key))
            self._leaf(node,RetainedStyle(LEAF))
            var local = cell.rect
            local.x -= viewport.x
            local.y -= viewport.y
            placements.append(RetainedPlacement(key,local))
            var clip = cell.clip
            clip.x -= viewport.x
            clip.y -= viewport.y
            self.tree.clip(key,clip)
        for key in self._cells:
            if key not in cells:
                self.tree.remove(key)
        self._cells = cells^
        self.tree.children(21,children)
        if self.popups.is_open():
            var popup = place_overlay(popup_anchor,Size(240,160),Rect(0,0,size.width,size.height),anchor_present=anchor_present)
            if popup.present:
                placements.append(RetainedPlacement(90,popup.bounds))
            else:
                self.tree.set_region(90,RetainedStyle(COLLAPSED))
                self.tree.clear_placement(90)
        self.tree.place(placements)
        self._record_phase[profile]()
        var ready = self.tree.stage(1,size)
        self._record_phase[profile]()
        self.form.validate(form_plan)
        self.table.validate(collection)
        # Capacity and adapter validation precede every publication.
        _ = RetainedPresentation(ready.snapshot,self._leaves,self.focused,90 if self.popups.traps_focus() else -1)
        self._record_phase[profile]()
        var published = self.tree.commit(ready)
        self.form.commit(form_plan)
        self.offset_x = collection.offset_x
        self.offset_y = collection.offset_y
        self.table.commit(collection^)
        if self.popups.is_open():
            if anchor_present:
                var restore = self.popups.entries[0].restore_focus_id
                _ = self.popups.open(90,POPUP_DIALOG if self.modal else POPUP_MENU,self.popups.top_owner_id(),popup_anchor,published.bounds(90),modal=self.modal,focus_scope_id=92,restore_focus_id=restore)
            else:
                self.close_popup()
        self._snapshot = published
        self._published_leaves = self._leaves.copy()
        self._size = size
        self.error = ""
        self._record_phase[profile]()
        var presentation = RetainedPresentation(published,self._leaves,self.focused,90 if self.popups.traps_focus() else -1)
        self._published_focus = presentation.focused
        self._published_accessibility_root = presentation.accessibility_root
        self._record_phase[profile]()
        return presentation^

    def recovery(self) raises -> RetainedPresentation:
        var snapshot = self.tree.snapshot()
        var leaves = List[ViewNode]()
        var focus_present = False
        var dataset_present = False
        for output in snapshot._outputs[]:
            focus_present = focus_present or output.key==self._published_focus
            dataset_present = dataset_present or output.key==13
        for leaf in self._published_leaves:
            for output in snapshot._outputs[]:
                if output.key == leaf.id:
                    leaves.append(leaf)
                    break
        var published_focus = self._published_focus if focus_present else (13 if dataset_present else -1)
        return RetainedPresentation(snapshot,leaves,published_focus,self._published_accessibility_root)

    def open_popup(mut self, modal: Bool = False):
        self.modal = modal
        _ = self.popups.open_root(90,POPUP_DIALOG if modal else POPUP_MENU,1011 if self.table.rows.count()>0 else 42,Rect(0,0,0,0),Rect(0,0,0,0),modal=modal,focus_scope_id=92,restore_focus_id=self.focused)
        self.focused = 92

    def close_popup(mut self):
        _ = self.popups.dismiss_all()
        var restored = self.popups.restored_focus_target()
        if restored>=1000 and self.table.rows.index((restored-1000)//10)<0:
            restored = 13
        if restored==18 and self._size.width<760:
            restored = 13
        self.focused = restored if restored>=0 else 13

    def edit_row(mut self, row_key: Int) raises:
        if self.editing_row!=row_key:
            self.cell_editor.set_composition("",0,0)
        if self.editing_row>0:
            self.table.unpin_editor(self.editing_row)
        self.table.pin_editor(row_key)
        self.editing_row = row_key
        self.focused = 1000+row_key*10+2

    def handle_text_input(mut self, event: Event) -> Bool:
        """Route addressed accessibility edits and focused keyboard/IME input."""
        if event.kind!=TEXT_INPUT_KIND and event.kind!=COMPOSITION_UPDATE_KIND and event.kind!=COMPOSITION_END_KIND:
            return False
        var target = event.target if event.target>=0 else self.focused
        # Cancellation belongs to the editor which owned the preedit, including
        # one hidden behind a newly opened modal. Other input remains scoped.
        if event.kind!=COMPOSITION_END_KIND and not self.popups.allows_focus(target):
            return False
        if target==13:
            if event.kind==TEXT_INPUT_KIND:
                if event.replacement_start>=0:
                    return self.editor.replace_text_range(event.text,event.replacement_start,event.replacement_end)
                return self.editor.insert_text(event.text)
            self.editor.set_composition(event.text,event.selection_start,event.selection_end)
            return True
        if self.editing_row>0 and target==1000+self.editing_row*10+2:
            if event.kind==TEXT_INPUT_KIND:
                if event.replacement_start>=0:
                    return self.cell_editor.replace_text_range(event.text,event.replacement_start,event.replacement_end)
                return self.cell_editor.insert_text(event.text)
            self.cell_editor.set_composition(event.text,event.selection_start,event.selection_end)
            return True
        return False
