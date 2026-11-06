"""Native math editor component and shared presentation. No backend dependency."""
from std.ffi import external_call
from moxi import ColumnView, Rect
from moxi.component import Component
from moxi.geometry import Point
from moxi.event import Event, CLICK_KIND, KEY_DOWN_KIND, TEXT_INPUT_KIND, POINTER_DOWN_KIND, POINTER_MOVE_KIND, POINTER_UP_KIND, SCROLL_KIND, COMPOSITION_UPDATE_KIND, COMPOSITION_END_KIND, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_HOME, KEY_END, KEY_BACKSPACE, KEY_DELETE, KEY_ESCAPE, MOD_COMMAND, MOD_SHIFT, MOD_OPTION
from moxi.style import default_surface_style, default_label_style, default_text_input_style
from .editor import MathEditorState, MathCommand, symbol_for
from .commands import MathKeymap
from moxi.controls_text import TextInputState
from .layout import MathLayout, MathSnapshot
from .model import MathKind

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
    var pointer_anchor: Int
    var backend_status: String
    var pending_action: Int
    var workbench_controls: Bool
    var last_caret_id: Int
    var last_caret_offset: Int
    var last_revision: Int
    def __init__(out self, text: String = "?") raises:
        self.keymap=MathKeymap()
        self.search=TextInputState("")
        self.state=MathEditorState(text)
        self.layout=MathLayout()
        self.title="Moxi Math · Native workbench"
        self.viewport=Rect(20,220,1060,310)
        self.zoom=1
        self.scroll_x=0
        self.preferred_x = -1
        self.pointer_down=False
        self.pointer_anchor = -1
        self.backend_status="Computation is optional · editing remains available without it"
        self.pending_action = -1
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
        self.pointer_anchor=copy.pointer_anchor
        self.backend_status=copy.backend_status
        self.pending_action=copy.pending_action
        self.workbench_controls=copy.workbench_controls
        self.last_caret_id=copy.last_caret_id
        self.last_caret_offset=copy.last_caret_offset
        self.last_revision=copy.last_revision
    def build(self, bounds: Rect) -> ColumnView:
        var view=ColumnView(bounds,18,6)
        view.set_surface_style(default_surface_style())
        var small_label=default_label_style()
        small_label.font_size=14
        var heading=default_label_style()
        heading.font_size=25
        view.add_label_styled(1,self.title,34,heading)
        var first=view.add_row(2,0,34,4,0)
        if self.workbench_controls:
            view.add_button_to(first,MATH_MAIN,"Expression",34)
            view.add_button_to(first,MATH_SCRATCH,"Scratch",34)
            view.add_button_to(first,MATH_RESULT,"Result",34)
        view.add_button_to(first,MATH_COMMAND_BASE+MathCommand.TEXT.value,"Text / 2D",34)
        view.add_button_to(first,MATH_SAVE,"Save",34)
        view.add_button_to(first,MATH_OPEN,"Reopen",34)
        view.add_button_to(first,MATH_ZOOM_OUT,"− Zoom",34)
        view.add_button_to(first,MATH_ZOOM_IN,"+ Zoom",34)
        var second=view.add_row(3,0,34,4,0)
        var commands: List[MathCommand]=[MathCommand.FRACTION,MathCommand.ROOT,MathCommand.SUPER,MathCommand.SUB,MathCommand.GROUP,MathCommand.FUNCTION,MathCommand.MATRIX,MathCommand.SUM,MathCommand.INTEGRAL]
        var labels: List[String]=["Fraction","Root","Sup","Sub","( group )","sin( )","Matrix","Sum","Integral"]
        for i in range(len(commands)):
            view.add_button_to(second,MATH_COMMAND_BASE+commands[i].value,labels[i]+" "+self.keymap.hint(commands[i]),34)
        var third=view.add_row(4,0,34,4,0)
        var commands2: List[MathCommand]=[MathCommand.COMPLEMENT,MathCommand.OVER,MathCommand.UNDER,MathCommand.ADD_ROW,MathCommand.ADD_COLUMN,MathCommand.REMOVE_ROW,MathCommand.REMOVE_COLUMN,MathCommand.UNWRAP,MathCommand.EXIT]
        var labels2: List[String]=["Pair","Over","Under","+ Row","+ Col","− Row","− Col","Unwrap","Leave"]
        for i in range(len(commands2)):
            view.add_button_to(third,MATH_COMMAND_BASE+commands2[i].value,labels2[i]+" "+self.keymap.hint(commands2[i]),34)
        view.add_label_styled(5,"Click a slot · Tab visits holes · ⌘. selects enclosing · Escape starts symbols · Option-drag moves to a hole · Search symbols below",26,small_label)
        view.add_text_input_selection(MATH_SEARCH,self.search.text,30,default_text_input_style(),self.search.cursor,self.search.anchor)
        var symbols=view.add_row(9,0,30,4,0)
        var names: List[String]=["alpha","beta","gamma","delta","theta","pi","infinity","times","le","ge"]
        for i in range(len(names)):
            if self.search.text=="" or names[i].find(self.search.text)>=0:
                view.add_button_to(symbols,MATH_SYMBOL_BASE+i,symbol_for(names[i])+" "+names[i],30)
        view.add_canvas(MATH_CANVAS,"",max(Float32(100),bounds.height-507))
        if self.state.text_mode:
            view.add_text_input_selection(MATH_SOURCE,self.state.source.text,42,default_text_input_style(),self.state.source.cursor,self.state.source.anchor)
        else:
            view.add_label_styled(MATH_SOURCE,self.state.document.text(),42,small_label)
        var fourth=view.add_row(6,0,34,4,0)
        view.add_button_to(fourth,MATH_COMMAND_BASE+MathCommand.UNDO.value,"Undo "+self.keymap.hint(MathCommand.UNDO),34)
        view.add_button_to(fourth,MATH_COMMAND_BASE+MathCommand.REDO.value,"Redo "+self.keymap.hint(MathCommand.REDO),34)
        if self.workbench_controls:
            view.add_button_to(fourth,MATH_EVALUATE,"Evaluate",34)
            view.add_button_to(fourth,MATH_EXPAND,"Expand selection",34)
            view.add_button_to(fourth,MATH_DIFFERENTIATE,"Differentiate / x",34)
            view.add_button_to(fourth,MATH_SUBSTITUTE,"x → Scratch",34)
            view.add_button_to(fourth,MATH_APPLY,"Apply result",34)
            view.add_button_to(fourth,MATH_CANCEL,"Cancel worker",34)
        view.add_label_styled(7,self.state.status,28,small_label)
        view.add_label_styled(8,self.backend_status,28,small_label)
        view.set_clip_to_bounds()
        return view^
    def update(mut self, event: Event, view: ColumnView) -> Bool:
        try:
            if event.target==MATH_SEARCH:
                self.state.focused=False
                if event.kind==TEXT_INPUT_KIND:
                    return self.search.insert_text(event.text)
                if event.kind==KEY_DOWN_KIND:
                    return self.search.handle_key(event.key,event.modifiers)
            if event.kind==CLICK_KIND:
                if event.target>=MATH_SYMBOL_BASE and event.target<MATH_SYMBOL_BASE+10:
                    var names: List[String]=["alpha","beta","gamma","delta","theta","pi","infinity","times","le","ge"]
                    self.state.focused=True
                    self.state.insert(symbol_for(names[event.target-MATH_SYMBOL_BASE]))
                    return True
                if event.target>=MATH_COMMAND_BASE+1 and event.target<=MATH_COMMAND_BASE+24:
                    self.state.focused=True
                    self.state.command(MathCommand(event.target-MATH_COMMAND_BASE))
                    return True
                if event.target>=MATH_SAVE and event.target<=MATH_SUBSTITUTE:
                    self.pending_action=event.target
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
    def _route(mut self, event: Event) raises -> Bool:
        if event.kind==POINTER_DOWN_KIND and self.viewport.contains(event.position):
            self.state.focused=True
            var position=self.layout.snapshot.hit(self.local_point(event.position))
            if event.modifiers & MOD_OPTION and self.state.selected>=0:
                self.state.begin_drag()
            else:
                self.state.caret=position
                self.state.selected = -1
            self.pointer_down=True
            self.pointer_anchor=position.id
            self.preferred_x = -1
            return True
        if event.kind==POINTER_DOWN_KIND and not self.viewport.contains(event.position):
            # Keep canvas focus for palette; native text field takes its own focus.
            self.state.focused=False
        if event.kind==POINTER_MOVE_KIND and self.pointer_down:
            var position=self.layout.snapshot.hit(self.local_point(event.position))
            if self.state.drag_id>=0:
                self.state.drag_target=position.id
            elif position.id!=self.pointer_anchor:
                var node=self.state.document.find_id(self.pointer_anchor)
                var other=self.state.document.find_id(position.id)
                var found=False
                while node>=0 and not found:
                    var p=other
                    while p>=0:
                        if p==node:
                            found=True; break
                        p=self.state.document.parent(p)
                    if not found:
                        node=self.state.document.parent(node)
                if node>=0:
                    self.state.select(node)
            return True
        if event.kind==POINTER_UP_KIND and self.pointer_down:
            self.pointer_down=False
            if self.state.drag_id>=0:
                _ = self.state.drop()
            return True
        if event.kind==SCROLL_KIND and self.viewport.contains(event.position):
            self.scroll_x=max(Float32(0),min(self.layout.snapshot.width*self.zoom-self.viewport.width+32,self.scroll_x+event.scroll_delta.x+event.scroll_delta.y))
            return True
        if not self.state.focused:
            return False
        if event.kind==COMPOSITION_UPDATE_KIND:
            self.state.composition=event.text
            return True
        if event.kind==COMPOSITION_END_KIND:
            self.state.composition=""
            return True
        if event.kind==TEXT_INPUT_KIND and not self.state.text_mode:
            self.state.composition=""
            if event.replacement_start>=0 and self.state.document.nodes[self.state.index()].kind==MathKind.TOKEN:
                self.state.begin()
                var i=self.state.index()
                var text=TextInputState(self.state.document.nodes[i].text)
                _ = text.replace_text_range(event.text,event.replacement_start,event.replacement_end)
                self.state.document.nodes[i].text=text.text
                self.state.caret.offset=text.cursor
                self.state.commit()
            else:
                self.state.insert(event.text)
            self.preferred_x = -1
            return True
        if event.kind!=KEY_DOWN_KIND:
            return False
        if self.state.text_mode:
            # Native text editor owns source key routing and composition.
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
                external_call["moxi_math_clipboard", NoneType](ptr.ptr())
                if event.key==120:
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
            self.state.delete(event.key==KEY_DELETE)
            return True
        if event.key==KEY_LEFT or event.key==KEY_RIGHT:
            self.state.horizontal(-1 if event.key==KEY_LEFT else 1,(event.modifiers & MOD_SHIFT)!=0)
            self.preferred_x = -1
            return True
        if event.key==KEY_UP or event.key==KEY_DOWN:
            if self.preferred_x<0:
                self.preferred_x=self.layout.snapshot.caret(self.state.caret).x
            self.state.caret=self.layout.snapshot.vertical(self.state.caret,-1 if event.key==KEY_UP else 1,self.preferred_x)
            if event.modifiers & MOD_SHIFT:
                self.state.command(MathCommand.EXPAND_SELECTION)
            else:
                self.state.selected = -1
            return True
        if event.key==KEY_HOME or event.key==KEY_END:
            self.state.focus(self.state.document.root,event.key==KEY_END)
            return True
        return False
    def prepare(mut self, view: ColumnView) raises:
        self.viewport=view.bounds_for(MATH_CANVAS)
        self.layout.publish(self.state.document)
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
    if state.focused and not state.text_mode:
        var caret=snapshot.caret(state.caret)
        _item(1,0,caret.x,caret.y,1.5,caret.height,3)
    if state.drag_target>=0:
        var target=snapshot.bounds(state.drag_target)
        _item(2,0,target.x-2,target.y-2,target.width+4,target.height+4,3)
    var text=state.composition
    var ptr=text.as_c_string_span()
    var caret=snapshot.caret(state.caret)
    external_call["moxi_math_composition",NoneType](ptr.ptr(),caret.x,caret.y)
    var leaf=state.document.nodes[state.index()].text
    var leaf_ptr=leaf.as_c_string_span()
    external_call["moxi_math_input_state",NoneType](leaf_ptr.ptr(),Int32(state.caret.offset),Int32(state.focused and not state.text_mode),caret.x,caret.y,caret.width,caret.height)
    external_call["moxi_math_scene_end",NoneType]()
