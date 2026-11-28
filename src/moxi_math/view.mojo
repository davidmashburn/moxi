"""Native math editor component and shared presentation. No backend dependency."""
from std.ffi import external_call
from moxi import ColumnView, Rect
from moxi.component import Component
from moxi.geometry import Point
from moxi.event import Event, DRAG_BEGIN_KIND, DRAG_UPDATE_KIND, DROP_KIND, POINTER_CANCEL_KIND, KEY_DOWN_KIND, TEXT_INPUT_KIND, POINTER_DOWN_KIND, POINTER_MOVE_KIND, POINTER_UP_KIND, SCROLL_KIND, COMPOSITION_UPDATE_KIND, COMPOSITION_END_KIND, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_HOME, KEY_END, KEY_BACKSPACE, KEY_DELETE, KEY_ESCAPE, MOD_COMMAND, MOD_SHIFT, MOD_OPTION
from moxi.style import Color, default_surface_style, default_label_style, default_text_input_style
from .editor import MathEditorState, MathPosition, MathCommand, symbol_for
from .commands import MathKeymap
from moxi.controls_text import TextInputState
from .layout import MathLayout, MathSnapshot
from .model import MathKind
from .input import MathDeleteHold

comptime MATH_CANVAS = 500
comptime MATH_SOURCE = 501
comptime MATH_SEARCH = 502
comptime MATH_SYMBOL_BASE = 600
comptime MATH_COMMAND_BASE = 1000
comptime MATH_SAVE = 2000
comptime MATH_OPEN = 2001
comptime MATH_EXPAND = 2002
comptime MATH_DIFFERENTIATE = 2003
comptime MATH_APPLY = 2004
comptime MATH_CANCEL = 2005
comptime MATH_RESULT = 2006
comptime MATH_SCRATCH = 2007
comptime MATH_MAIN = 2008
comptime MATH_ZOOM_IN = 2009
comptime MATH_ZOOM_OUT = 2010
comptime MATH_EVALUATE = 2011
comptime MATH_SUBSTITUTE = 2012

@fieldwise_init
struct MathToolPanel(ImplicitlyCopyable):
    var id: Int
    comptime CLOSED = Self(-1)
    comptime INSERT = Self(2100)
    comptime STRUCTURE = Self(2101)
    comptime SYMBOLS = Self(2102)
    comptime DOCUMENT = Self(2103)
    comptime COMPUTE = Self(2104)

comptime MATH_IDLE_BACKEND = "Computation is optional · editing remains available without it"

struct MathEditor(Component):
    var keymap: MathKeymap
    var search: TextInputState
    var state: MathEditorState
    var layout: MathLayout
    var title: String
    var viewport: Rect
    var zoom: Float32
    var scroll_x: Float32
    var preferred_x: Float32
    var pointer_down: Bool
    var delete_hold: MathDeleteHold
    var backend_status: String
    var pending_action: Int
    var panel: MathToolPanel
    var block_label: String
    var workbench_controls: Bool
    var last_caret_id: Int
    var last_caret_offset: Int
    var last_revision: Int
    def __init__(out self, text: String = "?") raises:
        self.keymap=MathKeymap()
        self.search=TextInputState("")
        self.state=MathEditorState(text)
        self.layout=MathLayout()
        self.title="Formula Editor"
        self.viewport=Rect(20,220,1060,310)
        self.zoom=1
        self.scroll_x=0
        self.preferred_x = -1
        self.pointer_down=False
        self.delete_hold=MathDeleteHold()
        self.backend_status=MATH_IDLE_BACKEND
        self.pending_action = -1
        self.panel = MathToolPanel.CLOSED
        self.block_label = "Expression"
        self.workbench_controls=False
        self.last_caret_id = -1
        self.last_caret_offset = -1
        self.last_revision = -1
        self.layout.publish(self.state.document)
    def __init__(out self, *, copy: Self):
        self.keymap=copy.keymap
        self.search=copy.search
        self.state=copy.state
        self.layout=copy.layout
        self.title=copy.title
        self.viewport=copy.viewport
        self.zoom=copy.zoom
        self.scroll_x=copy.scroll_x
        self.preferred_x=copy.preferred_x
        self.pointer_down=copy.pointer_down
        self.delete_hold=copy.delete_hold
        self.backend_status=copy.backend_status
        self.pending_action=copy.pending_action
        self.panel = copy.panel
        self.block_label = copy.block_label
        self.workbench_controls=copy.workbench_controls
        self.last_caret_id=copy.last_caret_id
        self.last_caret_offset=copy.last_caret_offset
        self.last_revision=copy.last_revision
    def build(self, bounds: Rect) -> ColumnView:
        var view = ColumnView(bounds, 18, 6)
        view.set_surface_style(default_surface_style())
        var heading = default_label_style()
        heading.font_size = 26
        var small = default_label_style()
        small.font_size = 14
        view.add_label_styled(1, self.title, 36, heading)
        var compact = bounds.width < 560
        var toolbar = view.add_grid(2, 74, 3, 0, 6) if compact else view.add_row(2, 0, 36, 0, 6)
        var panels = [MathToolPanel.INSERT, MathToolPanel.STRUCTURE, MathToolPanel.SYMBOLS, MathToolPanel.DOCUMENT, MathToolPanel.COMPUTE]
        var titles: List[String] = ["Insert", "Structure", "Symbols", "Document", "Compute"]
        for i in range(len(panels)):
            var id = panels[i].id
            if id == MathToolPanel.COMPUTE.id and not self.workbench_controls:
                continue
            view.add_button_to(toolbar, id, titles[i], 34)
            if bounds.width >= 680:
                view.set_fixed_width(id, 98)
            view.set_expanded(id, self.panel.id == id)
            view.set_selected(id, self.panel.id == id)
            view.set_accessibility_value(id, "Open" if self.panel.id == id else "Closed")
        var mode_id = MATH_COMMAND_BASE + MathCommand.TEXT.value
        view.add_button_to(toolbar, mode_id, "Edit in 2D" if self.state.text_mode else "Edit as text", 34)
        if bounds.width >= 680:
            view.set_fixed_width(mode_id, 118)
        var panel_height: Float32 = 0
        var cols = 2 if compact else 3 if bounds.width < 900 else 5
        if self.panel.id == MathToolPanel.INSERT.id or self.panel.id == MathToolPanel.STRUCTURE.id:
            var commands: List[MathCommand] = [MathCommand.FRACTION, MathCommand.ROOT, MathCommand.SUPER, MathCommand.SUB, MathCommand.GROUP, MathCommand.FUNCTION, MathCommand.MATRIX, MathCommand.SUM, MathCommand.INTEGRAL]
            var labels: List[String] = ["Fraction", "Root", "Superscript", "Subscript", "Group ( )", "Function sin( )", "Matrix", "Sum", "Integral"]
            if self.panel.id == MathToolPanel.STRUCTURE.id:
                commands = [MathCommand.COMPLEMENT, MathCommand.ADD_COMPLEMENT, MathCommand.OVER, MathCommand.UNDER, MathCommand.ADD_ROW, MathCommand.ADD_COLUMN, MathCommand.REMOVE_ROW, MathCommand.REMOVE_COLUMN, MathCommand.UNWRAP, MathCommand.EXIT]
                labels = ["Pair", "Add pair", "Over", "Under", "Add row", "Add column", "Remove row", "Remove column", "Unwrap", "Leave slot"]
            panel_height = Float32((len(commands) + cols - 1) // cols) * 38
            var grid = view.add_grid(3, panel_height - 6, cols, 0, 6)
            for i in range(len(commands)):
                view.add_button_to(grid, MATH_COMMAND_BASE + commands[i].value, labels[i] + " " + self.keymap.hint(commands[i]), 32)
        elif self.panel.id == MathToolPanel.SYMBOLS.id:
            view.add_label_styled(5, "Find a symbol by name", 22, small)
            view.add_text_input_selection(MATH_SEARCH, self.search.text, 32, default_text_input_style(), self.search.cursor, self.search.anchor)
            view.set_accessibility_label(MATH_SEARCH, "Find a symbol")
            var names: List[String] = ["alpha", "beta", "gamma", "delta", "theta", "pi", "infinity", "times", "le", "ge"]
            var matches = List[Int]()
            for i in range(len(names)):
                if self.search.text == "" or names[i].find(self.search.text) >= 0:
                    matches.append(i)
            panel_height = 66
            if len(matches) > 0:
                var rows = (len(matches) + cols - 1) // cols
                var grid = view.add_grid(9, Float32(rows * 38 - 6), cols, 0, 6)
                panel_height += Float32(rows * 38)
                for i in matches:
                    view.add_button_to(grid, MATH_SYMBOL_BASE + i, symbol_for(names[i]) + "  " + names[i], 32)
            else:
                view.add_label_styled(9, "No matching symbols", 26, small)
                panel_height += 32
        elif self.panel.id == MathToolPanel.DOCUMENT.id or self.panel.id == MathToolPanel.COMPUTE.id:
            var ids = List[Int]()
            var labels = List[String]()
            if self.panel.id == MathToolPanel.COMPUTE.id:
                ids = [MATH_EVALUATE, MATH_EXPAND, MATH_DIFFERENTIATE, MATH_SUBSTITUTE, MATH_APPLY, MATH_CANCEL]
                labels = ["Evaluate", "Expand selection", "Differentiate / x", "x → Scratch", "Apply result", "Cancel worker"]
            else:
                if self.workbench_controls:
                    ids = [MATH_MAIN, MATH_SCRATCH, MATH_RESULT]
                    labels = ["Expression", "Scratch", "Result"]
                ids.extend([MATH_SAVE, MATH_OPEN, MATH_ZOOM_OUT, MATH_ZOOM_IN, MATH_COMMAND_BASE + MathCommand.UNDO.value, MATH_COMMAND_BASE + MathCommand.REDO.value])
                labels.extend(["Save", "Reopen", "Zoom out", "Zoom in", "Undo " + self.keymap.hint(MathCommand.UNDO), "Redo " + self.keymap.hint(MathCommand.REDO)])
            panel_height = Float32((len(ids) + cols - 1) // cols) * 38
            var grid = view.add_grid(4, panel_height - 6, cols, 0, 6)
            for i in range(len(ids)):
                view.add_button_to(grid, ids[i], labels[i], 32)

        var caption = small
        caption.text = Color(0.60, 0.80, 0.98, 1.0)
        view.add_label_styled(10, self.block_label + "   ·   " + ("Text editing" if self.state.text_mode else "2D editing"), 24, caption)
        var source = self.state.source.text if self.state.text_mode else self.state.document.text()
        var show_backend = self.workbench_controls and (self.panel.id == MathToolPanel.COMPUTE.id or self.backend_status != MATH_IDLE_BACKEND)
        var footer: Float32 = 28 if show_backend else 0
        view.add_canvas(MATH_CANVAS, "", max(Float32(60), bounds.height - 272 - panel_height - footer - Float32(38 if compact else 0)))
        view.add_label_styled(11, "Source notation", 20, caption)
        view.add_text_input_selection(MATH_SOURCE, source, 38, default_text_input_style(), self.state.source.cursor, self.state.source.anchor)
        view.set_accessibility_label(MATH_SOURCE, "Source notation")
        view.add_label_styled(7, self.state.status, 24, small)
        if show_backend:
            view.add_label_styled(8, self.backend_status, 22, small)
        view.set_clip_to_bounds()
        return view^
    def update(mut self, event: Event, view: ColumnView) -> Bool:
        try:
            if event.target==MATH_SEARCH:
                if event.kind==POINTER_DOWN_KIND:
                    self.state.focused=False
                    return True
                if event.kind==TEXT_INPUT_KIND:
                    if event.replacement_start>=0:
                        return self.search.replace_text_range(event.text,event.replacement_start,event.replacement_end)
                    return self.search.insert_text(event.text)
                if event.kind==KEY_DOWN_KIND:
                    return self.search.handle_key(event.key,event.modifiers)
            if event.is_activation():
                if MathToolPanel.INSERT.id <= event.target <= MathToolPanel.COMPUTE.id:
                    self.panel = MathToolPanel.CLOSED if self.panel.id == event.target else MathToolPanel(event.target)
                    return True
                if event.target>=MATH_SYMBOL_BASE and event.target<MATH_SYMBOL_BASE+10:
                    var names: List[String]=["alpha","beta","gamma","delta","theta","pi","infinity","times","le","ge"]
                    self.state.focused=True
                    self.panel = MathToolPanel.CLOSED
                    self.state.insert(symbol_for(names[event.target-MATH_SYMBOL_BASE]))
                    return True
                if event.target>=MATH_COMMAND_BASE+1 and event.target<=MATH_COMMAND_BASE+MathCommand.ADD_COMPLEMENT.value:
                    self.sync_source_selection()
                    self.state.focused=True
                    self.panel = MathToolPanel.CLOSED
                    self.state.command(MathCommand(event.target-MATH_COMMAND_BASE))
                    return True
                if event.target>=MATH_SAVE and event.target<=MATH_SUBSTITUTE:
                    self.state.focused=True
                    self.panel = MathToolPanel.CLOSED
                    self.pending_action=event.target
                    return True
            if event.target==MATH_SOURCE and event.kind==POINTER_DOWN_KIND:
                if not self.state.text_mode:
                    self.state.command(MathCommand.TEXT)
                if self.state.document.nodes[self.state.document.root].kind!=MathKind.HOLE:
                    external_call["moxi_math_source_click",NoneType](event.position.x,event.position.y)
                self.state.focused=True
                return True
            if self.state.text_mode and event.target==MATH_SOURCE:
                if event.kind==COMPOSITION_UPDATE_KIND:
                    self.state.source.set_composition(event.text,event.selection_start,event.selection_end)
                    return True
                if event.kind==COMPOSITION_END_KIND:
                    self.state.source.clear_composition()
                    return True
                if event.kind==KEY_DOWN_KIND:
                    if event.modifiers & MOD_COMMAND and event.key==122:
                        self.state.command(MathCommand.REDO if event.modifiers & MOD_SHIFT else MathCommand.UNDO)
                        return True
                    var before=self.state.source
                    var changed=self.state.source.handle_key(event.key,event.modifiers)
                    if before.text!=self.state.source.text:
                        var after=self.state.source
                        self.state.source=before
                        self.state.begin()
                        self.state.source=after
                        self.state.parse_source()
                        self.state.commit()
                    return changed
            if event.kind==TEXT_INPUT_KIND and self.state.text_mode and event.target==MATH_SOURCE:
                self.state.begin()
                if event.replacement_start>=0:
                    _ = self.state.source.replace_text_range(event.text,event.replacement_start,event.replacement_end)
                else:
                    _ = self.state.source.insert_text(event.text)
                self.state.parse_source()
                self.state.commit()
                return True
        except e:
            self.state.status=String(e)
            return True
        return False
    def local_point(self, point: Point) -> Point:
        return Point((point.x-self.viewport.x-16+self.scroll_x)/self.zoom,(point.y-self.viewport.y-16)/self.zoom)
    def route(mut self, event: Event) raises -> Bool:
        """Call before outer App dispatch; errors preserve the committed document."""
        try:
            return self._route(event)
        except e:
            self.state.status=String(e)
            return True
    def sync_source_selection(mut self):
        if self.state.text_mode and self.state.focused:
            var source=self.state.source.text.as_c_string_span()
            var start=Int(external_call["moxi_math_source_endpoint",Int32](source.ptr(),Int32(0)))
            var end=Int(external_call["moxi_math_source_endpoint",Int32](source.ptr(),Int32(1)))
            if start>=0 and end>=start and (start!=self.state.source.selection_start() or end!=self.state.source.selection_end()):
                self.state.source.anchor=start if start!=end else -1
                self.state.source.cursor=end

    def _route(mut self, event: Event) raises -> Bool:
        if event.kind==POINTER_DOWN_KIND or event.kind==TEXT_INPUT_KIND or event.kind==COMPOSITION_UPDATE_KIND or (event.kind==KEY_DOWN_KIND and event.key!=KEY_BACKSPACE and event.key!=KEY_DELETE):
            self.delete_hold.stop()
        if event.kind==POINTER_DOWN_KIND:
            self.sync_source_selection()
        if event.kind==POINTER_DOWN_KIND and self.viewport.contains(event.position):
            self.state.focused=True
            if self.state.text_mode:
                self.state.command(MathCommand.TEXT)
            var position=self.layout.snapshot.hit(self.local_point(event.position))
            if event.modifiers & MOD_OPTION and self.state.selected>=0:
                self.state.begin_drag()
            else:
                self.state.set_caret(position,(event.modifiers & MOD_SHIFT)!=0)
            self.pointer_down=True
            self.preferred_x = -1
            return True
        if event.kind==POINTER_DOWN_KIND and self.state.text_mode:
            self.state.focused=False
        if self.pointer_down:
            if event.kind==POINTER_CANCEL_KIND:
                self.pointer_down=False
                self.state.drag_id = -1
                self.state.drag_target = -1
                return True
            if event.kind==DRAG_BEGIN_KIND or event.kind==DRAG_UPDATE_KIND or event.kind==DROP_KIND or event.kind==POINTER_MOVE_KIND:
                var position=self.layout.snapshot.hit(self.local_point(event.position))
                if self.state.drag_id>=0:
                    self.state.drag_target=position.id if self.viewport.contains(event.position) else -1
                else:
                    self.state.set_caret(position,True)
                if event.kind!=DROP_KIND:
                    return True
            if event.kind==POINTER_UP_KIND or event.kind==DROP_KIND:
                self.pointer_down=False
                if self.state.drag_id>=0:
                    _ = self.state.drop()
                return True
        if event.kind==SCROLL_KIND and self.viewport.contains(event.position):
            self.scroll_x=max(Float32(0),min(self.layout.snapshot.width*self.zoom-self.viewport.width+32,self.scroll_x+event.scroll_delta.x+event.scroll_delta.y))
            return True
        if not self.state.focused or self.state.text_mode:
            return False
        if event.kind==COMPOSITION_UPDATE_KIND:
            self.state.composition=event.text
            return True
        if event.kind==COMPOSITION_END_KIND:
            self.state.composition=""
            return True
        if event.kind==TEXT_INPUT_KIND and not self.state.text_mode:
            self.state.composition=""
            if event.replacement_start>=0 and self.state.selected<0 and not self.state.symbol_entry and self.state.document.nodes[self.state.index()].kind==MathKind.TOKEN and (not self.state.has_range_selection() or self.state.has_text_selection()):
                var i=self.state.index()
                var text=TextInputState(self.state.document.nodes[i].text)
                if text.replace_text_range(event.text,event.replacement_start,event.replacement_end):
                    self.state.begin()
                    if text.text == "":
                        self.state._erase_text(i, 0, self.state.document.nodes[i].text.count_codepoints())
                    else:
                        self.state.document.nodes[i].text=text.text
                        self.state.clear_selection()
                        self.state.caret.offset=text.cursor
                    self.state.commit()
            else:
                self.state.insert(event.text)
            self.preferred_x = -1
            return True
        if event.kind!=KEY_DOWN_KIND:
            return False
        if event.key==KEY_ESCAPE:
            self.state.escape()
            return True
        if self.state.composition!="":
            return False
        var command=self.keymap.resolve(event.key,event.modifiers)
        if command.value!=0:
            self.state.command(command)
            return True
        if event.modifiers & MOD_COMMAND:
            if event.key==97:
                self.state.select(self.state.document.root)
                return True
            if event.key==99 or event.key==120:
                var text=self.state.copy_text()
                var ptr=text.as_c_string_span()
                var fragment=self.state.copy_fragment_text()
                var fragment_ptr=fragment.as_c_string_span()
                external_call["moxi_math_clipboard", NoneType](ptr.ptr(),fragment_ptr.ptr())
                if event.key==120:
                    if not self.state.has_range_selection():
                        self.state.select(self.state.target())
                    self.state.delete()
                return True
            if event.key==118:
                var count=Int(external_call["moxi_math_paste_begin",Int32]())
                if count<0:
                    raise Error("Clipboard exceeds the 1 MiB math text limit")
                var text=String("")
                for i in range(count):
                    text+=chr(Int(external_call["moxi_math_paste_codepoint",Int32](Int32(i))))
                self.state.paste(text)
                return True
        if event.key==KEY_BACKSPACE or event.key==KEY_DELETE:
            self.delete_hold.delete(self.state,event.key,event.key_repeat)
            return True
        if event.key==KEY_LEFT or event.key==KEY_RIGHT:
            self.state.horizontal(-1 if event.key==KEY_LEFT else 1,(event.modifiers & MOD_SHIFT)!=0)
            self.preferred_x = -1
            return True
        if event.key==KEY_UP or event.key==KEY_DOWN:
            if self.preferred_x<0:
                self.preferred_x=self.layout.snapshot.caret(self.state.caret).x
            var next=self.layout.snapshot.vertical(self.state.caret,-1 if event.key==KEY_UP else 1,self.preferred_x)
            self.state.set_caret(next,(event.modifiers & MOD_SHIFT)!=0)
            return True
        if event.key==KEY_HOME or event.key==KEY_END:
            self.state.set_caret(self.state.edge_position(event.key==KEY_END),(event.modifiers & MOD_SHIFT)!=0)
            self.preferred_x = -1
            return True
        return False
    def prepare(mut self, view: ColumnView) raises:
        self.viewport=view.bounds_for(MATH_CANVAS)
        self.layout.publish(self.state.document,32,self.state.caret.id if self.state.focused and not self.state.text_mode else -1)
        var caret=self.layout.snapshot.caret(self.state.caret)
        var x=caret.x*self.zoom-self.scroll_x
        var moved=self.state.caret.id!=self.last_caret_id or self.state.caret.offset!=self.last_caret_offset or self.state.document.revision!=self.last_revision
        if moved and x<0:
            self.scroll_x=max(Float32(0),caret.x*self.zoom-8)
        elif moved and x>self.viewport.width-40:
            self.scroll_x=caret.x*self.zoom-self.viewport.width+40
        self.last_caret_id=self.state.caret.id
        self.last_caret_offset=self.state.caret.offset
        self.last_revision=self.state.document.revision
        self.scroll_x=max(Float32(0),min(self.scroll_x,max(Float32(0),self.layout.snapshot.width*self.zoom-self.viewport.width+40)))
    def present(self):
        external_call["moxi_math_keymap_begin",NoneType]()
        for binding in self.keymap.bindings:
            external_call["moxi_math_keymap_add",NoneType](Int32(binding.key),Int32(binding.modifiers))
        draw_math(self.layout.snapshot,self.state,self.viewport,self.zoom,self.scroll_x)

def _item(kind: Int, glyph: Int, x: Float32, y: Float32, width: Float32, height: Float32, tone: Int = 0):
    external_call["moxi_math_scene_item",NoneType](Int32(kind),Int32(glyph),x,y,width,height,Int32(tone))

def draw_math(snapshot: MathSnapshot, state: MathEditorState, viewport: Rect, zoom: Float32 = 1, scroll_x: Float32 = 0):
    external_call["moxi_math_scene_begin",NoneType](viewport.x,viewport.y,viewport.width,viewport.height,viewport.x+16-scroll_x,viewport.y+16,zoom)
    if state.selected>=0:
        var bounds=snapshot.bounds(state.selected)
        _item(1,0,bounds.x,bounds.y,bounds.width,bounds.height,1)
    elif state.has_range_selection():
        for span in state.range_spans():
            if span.whole:
                var bounds=snapshot.bounds(span.id)
                _item(1,0,bounds.x,bounds.y,bounds.width,bounds.height,1)
            else:
                var anchor=snapshot.caret(MathPosition(span.id,span.start))
                var end=snapshot.caret(MathPosition(span.id,span.end))
                _item(1,0,min(anchor.x,end.x),end.y,abs(end.x-anchor.x),end.height,1)
    for region in snapshot.regions:
        if region.label=="empty slot" or region.diagnostic:
            _item(2,0,region.bounds.x,region.bounds.y,region.bounds.width,region.bounds.height,2 if region.diagnostic else 3)
        var label=region.label
        var value=region.value
        if region.id==state.caret.id:
            label+=" · focused"
        if region.id==state.selected:
            label+=" · selected"
        var label_ptr=label.as_c_string_span()
        var value_ptr=value.as_c_string_span()
        external_call["moxi_math_semantic",NoneType](label_ptr.ptr(),value_ptr.ptr(),region.bounds.x,region.bounds.y,region.bounds.width,region.bounds.height)
    for glyph in snapshot.glyphs:
        _item(0,glyph.id,glyph.x,glyph.y,0,glyph.size,2 if glyph.id==0 else 0)
    for rule in snapshot.rules:
        _item(1,0,rule.x,rule.y,rule.width,rule.height)
    if state.focused and not state.text_mode and (state.selected < 0 or state.has_range_selection()):
        var caret=snapshot.caret(state.caret)
        _item(1,0,caret.x,caret.y,1.5,caret.height,3)
    if state.drag_target>=0:
        var target=snapshot.bounds(state.drag_target)
        _item(2,0,target.x-2,target.y-2,target.width+4,target.height+4,3)
    var text=state.composition
    var ptr=text.as_c_string_span()
    var caret=snapshot.caret(state.caret)
    external_call["moxi_math_composition",NoneType](ptr.ptr(),caret.x,caret.y)
    var node=state.document.nodes[state.index()]
    var token=node.kind==MathKind.TOKEN or node.kind==MathKind.ERROR
    var leaf=node.text if token else String("")
    var leaf_ptr=leaf.as_c_string_span()
    external_call["moxi_math_input_state",NoneType](leaf_ptr.ptr(),Int32(state.selection_start() if token else 0),Int32(state.selection_end() if token else 0),Int32(state.focused and not state.text_mode),caret.x,caret.y,caret.width,caret.height)
    external_call["moxi_math_scene_end",NoneType]()
    external_call["moxi_math_track_source_selection",NoneType](Int32(state.focused and state.text_mode))
