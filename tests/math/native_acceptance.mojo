from std.ffi import external_call
from std.testing import assert_equal, assert_true
from moxi import App, Rect, WindowConfig
from moxi.macos import MacOSWindow, MacOSRenderer
from moxi.geometry import Point
from moxi_math.native import present_math_frame
from moxi_math.model import MathKind
from moxi_math.view import MATH_SOURCE
from moxi.event import Event, KeyEvent, POINTER_DOWN_KIND, POINTER_UP_KIND, NONE_KIND, KEY_DOWN_KIND, KEY_BACKSPACE, KEY_DELETE
from moxi_math import MathEditor, MathEditorState, MathPosition, MathCommand, open_math_font, close_math_font, poll_math_event

def native_key(mut app: App[MathEditor], text: String, modifiers: Int = 0, key_repeat: Bool = False) raises:
    var chars=text
    var ptr=chars.as_c_string_span()
    assert_equal(external_call["moxi_math_probe_key_repeat",Int32](ptr.ptr(),Int32(modifiers),Int32(0),Int32(key_repeat)),1)
    drain(app)

def drain(mut app: App[MathEditor]) raises:
    var event=poll_math_event()
    while event.kind!=0:
        _ = app.component.route(event)
        event=poll_math_event()
    app.rebuild()
    app.component.prepare(app.view)
    app.component.present()

def native_delete(mut app: App[MathEditor], forward: Bool = False, key_repeat: Bool = False) raises:
    var chars=chr(0xf728 if forward else 127)
    var ptr=chars.as_c_string_span()
    assert_equal(external_call["moxi_math_probe_key_repeat",Int32](ptr.ptr(),Int32(0),Int32(0),Int32(key_repeat)),1)
    var event=poll_math_event()
    assert_equal(event.kind,KEY_DOWN_KIND)
    assert_equal(event.key,KEY_DELETE if forward else KEY_BACKSPACE)
    assert_equal(event.key_repeat,key_repeat)
    assert_true(app.component.route(event))
    drain(app)

def fixture(mut app: App[MathEditor], text: String) raises:
    app.component.state=MathEditorState(text)
    app.component.delete_hold.stop()
    drain(app)

def capture(mut app: App[MathEditor], mut renderer: MacOSRenderer, name: String) raises:
    app.rebuild()
    present_math_frame(app,renderer)
    var filename=name
    var ptr=filename.as_c_string_span()
    assert_equal(external_call["moxi_math_probe_capture",Int32](ptr.ptr()),1)

def delete_hold_check(mut app: App[MathEditor], mut renderer: MacOSRenderer) raises:
    var logical=Event(KeyEvent(KEY_BACKSPACE,0,True))
    assert_true(logical.key_repeat)
    assert_true(not Event(KeyEvent(KEY_BACKSPACE)).key_repeat)
    fixture(app,"frac(ab, cd)")
    var root=app.component.state.document.root
    var denominator=app.component.state.document.nodes[root].children[1]
    app.component.state.focus(denominator,True)
    drain(app)
    native_delete(app)
    assert_equal(app.component.state.document.text(),"frac(ab, c)")
    native_delete(app,False,True)
    assert_equal(app.component.state.document.text(),"frac(ab, ?)")
    var empty_revision=app.component.state.document.revision
    native_delete(app,False,True)
    assert_equal(app.component.state.document.revision,empty_revision)
    assert_equal(app.component.state.selected,-1)
    capture(app,renderer,"01-empty-denominator-held-delete")
    native_delete(app)
    assert_equal(app.component.state.selected,app.component.state.document.nodes[root].id)
    native_delete(app,False,True)
    assert_equal(app.component.state.document.text(),"frac(ab, ?)")
    assert_equal(app.component.state.document.revision,empty_revision)
    capture(app,renderer,"02-structural-highlight-held-delete")
    native_delete(app)
    assert_equal(app.component.state.document.text(),"?")
    native_delete(app,False,True)
    assert_equal(app.component.state.document.text(),"?")
    native_key(app,"z",2)
    assert_equal(app.component.state.document.text(),"frac(ab, ?)")
    assert_true(app.component.state.selected>=0)
    capture(app,renderer,"03-undo-restored-highlight")

    fixture(app,"frac(ab, cd)")
    denominator=app.component.state.document.nodes[app.component.state.document.root].children[1]
    app.component.state.focus(denominator)
    drain(app)
    native_delete(app,True)
    assert_equal(app.component.state.document.text(),"frac(ab, d)")
    assert_equal(app.component.state.caret.offset,0)
    native_delete(app,True,True)
    assert_equal(app.component.state.document.text(),"frac(ab, ?)")
    native_delete(app,True,True)
    assert_equal(app.component.state.selected,-1)

    fixture(app,"abcdef")
    var token=app.component.state.caret.id
    app.component.state.set_caret(MathPosition(token,2))
    app.component.state.set_caret(MathPosition(token,4),True)
    drain(app)
    native_delete(app)
    assert_equal(app.component.state.document.text(),"abef")
    native_delete(app,False,True)
    assert_equal(app.component.state.document.text(),"abef")
    native_key(app,"z",2)
    assert_equal(app.component.state.selection_anchor.offset,2)
    assert_equal(app.component.state.caret.offset,4)

    fixture(app,"abc")
    app.component.state.focus(app.component.state.document.root,True)
    drain(app)
    native_delete(app)
    native_key(app,chr(0xf702))
    var before=app.component.state.document.text()
    native_delete(app,False,True)
    assert_equal(app.component.state.document.text(),before)

    fixture(app,"row(x, abcd)")
    var row_token=app.component.state.document.nodes[app.component.state.document.root].children[1]
    app.component.state.set_caret(MathPosition(app.component.state.document.nodes[row_token].id,2))
    drain(app)
    native_delete(app)
    native_delete(app,False,True)
    native_delete(app,False,True)
    assert_equal(app.component.state.document.text(),"row(x, cd)")
    assert_equal(app.component.state.caret.offset,0)
    assert_equal(app.component.state.selected,-1)
    fixture(app,"row(abcd, y)")
    row_token=app.component.state.document.nodes[app.component.state.document.root].children[0]
    app.component.state.set_caret(MathPosition(app.component.state.document.nodes[row_token].id,2))
    drain(app)
    native_delete(app,True)
    native_delete(app,True,True)
    native_delete(app,True,True)
    assert_equal(app.component.state.document.text(),"row(ab, y)")
    assert_equal(app.component.state.caret.offset,2)
    assert_equal(app.component.state.selected,-1)

    fixture(app,"row(a, frac(x, y), b)")
    var row=app.component.state.document.root
    var last=app.component.state.document.nodes[row].children[2]
    var fraction=app.component.state.document.nodes[row].children[1]
    app.component.state.focus(last)
    drain(app)
    native_delete(app)
    assert_equal(app.component.state.selected,app.component.state.document.nodes[fraction].id)
    native_delete(app,False,True)
    assert_equal(app.component.state.document.text(),"row(a, frac(x, y), b)")
    capture(app,renderer,"04-adjacent-fraction-highlight")
    native_delete(app)
    assert_equal(app.component.state.document.text(),"row(a, b)")
    capture(app,renderer,"05-adjacent-fraction-removed")
    print("PASS native repeat identity, token-only holds, empty-slot stop, structural confirmation, selected-text stop, interrupted hold, platform forward Delete")

def native_mouse_position(mut app: App[MathEditor], mut window: MacOSWindow, position: MathPosition, phase: Int) raises:
    var bounds=app.component.layout.snapshot.caret(position)
    var x=app.component.viewport.x+16+bounds.x*app.component.zoom-app.component.scroll_x
    var y=app.component.viewport.y+16+(bounds.y+bounds.height/2)*app.component.zoom
    assert_equal(external_call["moxi_math_probe_mouse",Int32](x,y,Int32(phase)),1)
    var event=window.poll_event()
    while event.kind!=NONE_KIND:
        if app.component.route(event):
            app.rebuild()
        else:
            _ = app.dispatch(event)
        event=window.poll_event()
    drain(app)

def native_click_position(mut app: App[MathEditor], mut window: MacOSWindow, position: MathPosition) raises:
    native_mouse_position(app,window,position,0)
    native_mouse_position(app,window,position,2)
    assert_equal(app.component.state.caret.id,position.id)
    assert_equal(app.component.state.caret.offset,position.offset)

def cross_slot_check(mut app: App[MathEditor], mut window: MacOSWindow, mut renderer: MacOSRenderer) raises:
    for reverse in range(2):
        fixture(app,"frac(ab, cd)")
        var root=app.component.state.document.root
        var numerator=app.component.state.document.nodes[root].children[0]
        var denominator=app.component.state.document.nodes[root].children[1]
        var a=MathPosition(app.component.state.document.nodes[numerator].id,1)
        var b=MathPosition(app.component.state.document.nodes[denominator].id,1)
        var anchor=b if reverse==1 else a
        var focus=a if reverse==1 else b
        native_mouse_position(app,window,anchor,0)
        native_mouse_position(app,window,focus,1)
        native_mouse_position(app,window,focus,2)
        assert_equal(app.component.state.selection_anchor.id,anchor.id)
        assert_equal(app.component.state.selection_anchor.offset,anchor.offset)
        assert_equal(app.component.state.caret.id,focus.id)
        assert_equal(app.component.state.caret.offset,focus.offset)
        assert_true(app.component.state.has_range_selection())
        capture(app,renderer,"14-cross-slot-pointer-range" if reverse==0 else "15-reversed-cross-slot-pointer-range")
        native_delete(app,reverse==1)
        assert_equal(app.component.state.document.text(),"frac(a, d)")
        native_delete(app,reverse==1,True)
        assert_equal(app.component.state.document.text(),"frac(a, d)")
        native_key(app,"z",2)
        assert_equal(app.component.state.document.text(),"frac(ab, cd)")
        assert_equal(app.component.state.selection_anchor.id,anchor.id)
        assert_equal(app.component.state.selection_anchor.offset,anchor.offset)
        assert_equal(app.component.state.caret.id,focus.id)
        assert_equal(app.component.state.caret.offset,focus.offset)
    fixture(app,"row(abc, def)")
    var row=app.component.state.document.root
    var first=app.component.state.document.nodes[row].children[0]
    var second=app.component.state.document.nodes[row].children[1]
    app.component.state.focus(first,True)
    drain(app)
    native_delete(app)
    native_click_position(app,window,MathPosition(app.component.state.document.nodes[second].id,3))
    native_delete(app,False,True)
    assert_equal(app.component.state.document.text(),"row(ab, def)")
    print("PASS native cross-slot pointer range deletion in both directions, directed Undo, repeat stop, pointer hold cancellation")

def selection_signature(state: MathEditorState) -> String:
    var signature=String(state.caret.id)+":"+String(state.caret.offset)+"/"+String(state.selected)
    if state.has_range_selection():
        signature+="/"+String(state.selection_anchor.id)+":"+String(state.selection_anchor.offset)
    return signature

def navigation_check(mut app: App[MathEditor], mut window: MacOSWindow, mut renderer: MacOSRenderer) raises:
    var source=String("frac(frac(a, b), c)")
    fixture(app,source)
    var root=app.component.state.document.root
    var root_id=app.component.state.document.nodes[root].id
    var inner=app.component.state.document.nodes[root].children[0]
    var inner_id=app.component.state.document.nodes[inner].id
    app.component.state.set_caret(MathPosition(root_id,0))
    drain(app)
    var revision=app.component.state.document.revision
    var history=len(app.component.state.undo_stack)
    var stops=List[MathPosition]()
    stops.append(app.component.state.caret)
    while app.component.state.caret.id!=root_id or app.component.state.caret.offset!=1:
        native_key(app,chr(0xf703))
        assert_equal(app.component.state.document.text(),source)
        assert_equal(app.component.state.document.revision,revision)
        assert_equal(len(app.component.state.undo_stack),history)
        assert_true(len(stops)<50)
        var last=stops[len(stops)-1]
        assert_true(last.id!=app.component.state.caret.id or last.offset!=app.component.state.caret.offset)
        stops.append(app.component.state.caret)
    var inner_before=False
    var inner_after=False
    for position in stops:
        if position.id==inner_id:
            if position.offset==0:
                inner_before=True
            if position.offset==1:
                inner_after=True
    assert_true(inner_before and inner_after)
    capture(app,renderer,"06-after-outer-fraction")
    for step in range(len(stops)-1):
        native_key(app,chr(0xf702))
        var expected=stops[len(stops)-step-2]
        assert_equal(app.component.state.caret.id,expected.id)
        assert_equal(app.component.state.caret.offset,expected.offset)
    capture(app,renderer,"07-before-outer-fraction")
    for direction in range(2):
        var from_right=direction==1
        app.component.state.set_caret(MathPosition(root_id,1 if from_right else 0))
        drain(app)
        var ranges=List[String]()
        ranges.append(selection_signature(app.component.state))
        for step in range(len(stops)-1):
            native_key(app,chr(0xf702 if from_right else 0xf703),1)
            ranges.append(selection_signature(app.component.state))
            assert_equal(app.component.state.document.text(),source)
            assert_equal(app.component.state.document.revision,revision)
        assert_equal(app.component.state.selected,root_id)
        capture(app,renderer,"08-whole-formula-shift-selection" if not from_right else "09-whole-formula-reverse-selection")
        for step in range(len(stops)-1):
            native_key(app,chr(0xf703 if from_right else 0xf702),1)
            assert_equal(selection_signature(app.component.state),ranges[len(ranges)-step-2])
        assert_true(not app.component.state.has_range_selection())
        assert_equal(app.component.state.selected,-1)
    for side in range(2):
        fixture(app,source)
        root_id=app.component.state.document.nodes[app.component.state.document.root].id
        native_click_position(app,window,MathPosition(root_id,side))
        native_key(app,"R" if side==1 else "L")
        assert_equal(app.component.state.document.text(),"row("+source+", R)" if side==1 else "row(L, "+source+")")
        capture(app,renderer,"10-insert-after-outer-fraction" if side==1 else "11-insert-before-outer-fraction")
    print("PASS native exterior edges, symmetric caret walk, reverse Shift selection from both ends, outer-edge insertion")

def no_op_and_reverse_check(mut app: App[MathEditor]) raises:
    fixture(app,"abc")
    var token=app.component.state.caret.id
    app.component.state.set_caret(MathPosition(token,1))
    drain(app)
    native_key(app,chr(0xf703),1)
    native_key(app,chr(0xf703),1)
    assert_equal(app.component.state.copy_text(),"bc")
    for _ in range(3):
        native_key(app,chr(0xf702),1)
    assert_equal(app.component.state.copy_text(),"a")
    assert_equal(app.component.state.selection_anchor.offset,1)
    assert_equal(app.component.state.caret.offset,0)
    native_delete(app)
    assert_equal(app.component.state.document.text(),"bc")
    native_key(app,"z",2)
    assert_equal(app.component.state.copy_text(),"a")
    assert_equal(app.component.state.selection_anchor.offset,1)
    assert_equal(app.component.state.caret.offset,0)

    fixture(app,"abc")
    app.component.state.focus(app.component.state.document.root,True)
    drain(app)
    native_delete(app)
    native_key(app,"z",2)
    var revision=app.component.state.document.revision
    var redo=len(app.component.state.redo_stack)
    var caret=app.component.state.caret
    assert_true(redo>0)
    native_delete(app,True)
    assert_equal(app.component.state.document.text(),"abc")
    assert_equal(app.component.state.document.revision,revision)
    assert_equal(len(app.component.state.redo_stack),redo)
    assert_equal(app.component.state.caret.id,caret.id)
    assert_equal(app.component.state.caret.offset,caret.offset)
    fixture(app,"a")
    app.component.state.focus(app.component.state.document.root,True)
    drain(app)
    native_delete(app)
    native_key(app,"x")
    native_key(app,"z",2)
    assert_equal(app.component.state.document.text(),"?")
    revision=app.component.state.document.revision
    redo=len(app.component.state.redo_stack)
    assert_true(redo>0)
    native_delete(app)
    native_delete(app,True)
    assert_equal(app.component.state.document.text(),"?")
    assert_equal(app.component.state.document.revision,revision)
    assert_equal(len(app.component.state.redo_stack),redo)
    print("PASS native Shift reversal across anchor, no-op forward Delete and empty-root deletion preserve revision/redo")

def authored_script_check(mut app: App[MathEditor], mut renderer: MacOSRenderer) raises:
    fixture(app,"scripts(x, ?, n, ?, ?)")
    var root=app.component.state.document.root
    var exponent=app.component.state.document.nodes[root].children[2]
    var exponent_id=app.component.state.document.nodes[exponent].id
    app.component.state.focus(exponent,True)
    drain(app)
    native_delete(app)
    var source=app.component.state.document.text()
    assert_equal(source,"scripts(x, ?, empty(), ?, ?)")
    native_key(app,"z",2)
    assert_equal(app.component.state.document.text(),"scripts(x, ?, n, ?, ?)")
    assert_equal(external_call["moxi_math_probe_clear_first_character",Int32](),1)
    drain(app)
    assert_equal(app.component.state.document.text(),source)
    var revision=app.component.state.document.revision
    assert_true(app.component.state.document.slot_exists(root,2))
    assert_true(not app.component.state.document.slot_exists(root,1))
    var regions=len(app.component.layout.snapshot.regions)
    var width=app.component.layout.snapshot.width
    var height=app.component.layout.snapshot.height
    native_key(app," ",2)
    for key in [0xf702,0xf703,0xf700,0xf701,9]:
        native_key(app,chr(key))
        assert_equal(app.component.state.document.text(),source)
        assert_equal(app.component.state.document.revision,revision)
        assert_equal(len(app.component.layout.snapshot.regions),regions)
        assert_equal(app.component.layout.snapshot.width,width)
        assert_equal(app.component.layout.snapshot.height,height)
    native_key(app,chr(9),1)
    native_key(app,chr(0xf703),1)
    native_key(app,chr(0xf702),1)
    assert_equal(app.component.state.document.text(),source)
    assert_equal(app.component.state.document.revision,revision)
    app.component.state.set_caret(app.component.state.edge_position())
    drain(app)
    var seen=False
    for step in range(30):
        if app.component.state.caret.id==exponent_id and app.component.state.caret.offset==0:
            seen=True
        native_key(app,chr(0xf703))
    assert_true(seen)
    app.component.state.focus(exponent)
    drain(app)
    capture(app,renderer,"12-authored-empty-exponent")
    var saved=app.component.state.save_text()
    app.component.state.load_text(saved)
    drain(app)
    assert_equal(app.component.state.document.text(),source)
    root=app.component.state.document.root
    exponent=app.component.state.document.nodes[root].children[2]
    app.component.state.select(exponent)
    drain(app)
    native_delete(app)
    assert_equal(app.component.state.document.text(),"scripts(x, ?, ?, ?, ?)")
    assert_true(not app.component.state.document.slot_exists(root,2))
    capture(app,renderer,"13-explicitly-removed-empty-exponent")
    print("PASS native authored-empty exponent persists through navigation and save/reopen, absent sibling stays absent, explicit annotation deletion")

def clipboard_check(mut app: App[MathEditor]) raises:
    _ = external_call["moxi_math_probe_clipboard",Int32](Int32(0))
    try:
        app.component.state.select(app.component.state.document.root)
        var before=app.component.state.document.text()
        var identity=app.component.state.selected
        native_key(app,"c",2)
        assert_equal(external_call["moxi_math_probe_clipboard",Int32](Int32(1)),1)
        native_key(app,"v",2)
        assert_equal(app.component.state.document.text(),before)
        assert_true(app.component.state.document.nodes[app.component.state.document.root].id!=identity)
        assert_equal(external_call["moxi_math_probe_clipboard_limits",Int32](),1)
    finally:
        _ = external_call["moxi_math_probe_clipboard",Int32](Int32(2))

def transformed_hit_check(mut app: App[MathEditor]) raises:
    app.component.state=MathEditorState("row(abcdefghijklmno, +, frac(x, root(?, y)))")
    app.root_bounds.width=480
    app.rebuild()
    app.component.prepare(app.view)
    hit_zoom(app.component)
    app.component.zoom=1
    app.root_bounds.width=1100
    app.rebuild()
    app.component.prepare(app.view)

def hit_zoom(mut editor: MathEditor) raises:
    for scale in range(1,5):
        editor.zoom=Float32(scale)/2
        var stop=editor.layout.snapshot.carets[len(editor.layout.snapshot.carets)-1]
        editor.scroll_x=max(Float32(0),stop.bounds.x*editor.zoom-40)
        var screen=Point(editor.viewport.x+16+stop.bounds.x*editor.zoom-editor.scroll_x,editor.viewport.y+16+(stop.bounds.y+stop.bounds.height/2)*editor.zoom)
        assert_true(editor.viewport.contains(screen))
        var down=Event()
        down.kind=POINTER_DOWN_KIND
        down.position=screen
        assert_true(editor.route(down))
        assert_equal(editor.state.caret.id,stop.position.id)
        assert_equal(editor.state.caret.offset,stop.position.offset)
        down.kind=POINTER_UP_KIND
        _ = editor.route(down)

def drag_selection_check(mut app: App[MathEditor], mut window: MacOSWindow) raises:
    app.component.state=MathEditorState("a😀bc")
    drain(app)
    var id=app.component.state.caret.id
    var offsets=[1,2,4,3]
    for i in range(len(offsets)):
        var stop=app.component.layout.snapshot.caret(MathPosition(id,offsets[i]))
        var x=app.component.viewport.x+16+stop.x
        var y=app.component.viewport.y+16+stop.y+stop.height/2
        var phase=0 if i==0 else 2 if i==len(offsets)-1 else 1
        assert_equal(external_call["moxi_math_probe_mouse",Int32](x,y,Int32(phase)),1)
        var event=window.poll_event()
        while event.kind!=NONE_KIND:
            if app.component.route(event):
                app.rebuild()
            else:
                _ = app.dispatch(event)
            event=window.poll_event()
    app.component.present()
    assert_equal(app.component.state.copy_text(),"😀b")
    assert_equal(external_call["moxi_math_probe_selected_range",Int32](Int32(1),Int32(3)),1)
    assert_true(not app.component.pointer_down)
    native_key(app,"x")
    assert_equal(app.component.state.document.text(),"axc")
    native_key(app,"z",2)
    assert_equal(app.component.state.copy_text(),"😀b")
    native_key(app,"Z",3)
    assert_equal(app.component.state.document.text(),"axc")

def source_selection_check(mut app: App[MathEditor], mut renderer: MacOSRenderer) raises:
    app.component.state=MathEditorState("abcde")
    app.component.state.command(MathCommand.TEXT)
    app.rebuild()
    present_math_frame(app,renderer)
    assert_equal(external_call["moxi_math_probe_select_source_and_blur",Int32](Int32(2),Int32(2)),1)
    app.component.sync_source_selection()
    app.component.state.command(MathCommand.TEXT)
    app.rebuild()
    present_math_frame(app,renderer)
    assert_equal(app.component.state.copy_text(),"cd")
    native_key(app,"z")
    assert_equal(app.component.state.document.text(),"abze")

def click_in_editor(mut app: App[MathEditor], point: Point) raises:
    var event=Event()
    event.position=point
    for kind in [POINTER_DOWN_KIND,POINTER_UP_KIND]:
        event.kind=kind
        if app.component.route(event):
            app.rebuild()
        else:
            _ = app.dispatch(event)

def typing_focus_check(mut app: App[MathEditor], mut window: MacOSWindow, mut renderer: MacOSRenderer) raises:
    app.component.state=MathEditorState("?")
    app.rebuild()
    present_math_frame(app,renderer)
    var source=app.view.bounds_for(MATH_SOURCE)
    click_in_editor(app,Point(source.x+4,source.y+source.height/2))
    present_math_frame(app,renderer)
    assert_true(app.component.state.text_mode)
    var text=String("a")
    var ptr=text.as_c_string_span()
    assert_equal(external_call["moxi_math_probe_key",Int32](ptr.ptr(),Int32(0),Int32(1)),1)
    var event=window.poll_event()
    while event.kind!=NONE_KIND:
        if app.component.route(event):
            app.rebuild()
        else:
            _ = app.dispatch(event)
        event=window.poll_event()
    present_math_frame(app,renderer)
    assert_equal(app.component.state.document.text(),"a")
    var canvas=app.component.viewport
    click_in_editor(app,Point(canvas.x+17,canvas.y+17))
    present_math_frame(app,renderer)
    assert_true(not app.component.state.text_mode)
    native_key(app,"b")
    assert_equal(app.component.state.document.text(),"ba")
    click_in_editor(app,Point(source.x+source.width-10,source.y+source.height/2))
    present_math_frame(app,renderer)
    app.component.sync_source_selection()
    assert_equal(app.component.state.source.cursor,2)
    assert_equal(app.component.state.source.selected_text(),"")
    click_in_editor(app,Point(canvas.x+17,canvas.y+17))
    present_math_frame(app,renderer)
    click_in_editor(app,Point(source.x+2,source.y+source.height-2))
    present_math_frame(app,renderer)
    app.component.sync_source_selection()
    assert_equal(app.component.state.source.cursor,0)

def main() raises:
    open_math_font("assets/math/STIXTwoMath-Regular.otf")
    var app=App(MathEditor(),Rect(0,0,1100,800))
    var window=MacOSWindow()
    var renderer=MacOSRenderer()
    window.open(WindowConfig("Moxi Math · Native acceptance",1100,800))
    window.pump()
    app.component.prepare(app.view)
    app.render(renderer)
    app.component.present()
    native_key(app,"x")
    native_key(app,"/",2)
    native_key(app,"y")
    assert_equal(app.component.state.document.text(),"frac(x, y)")
    native_key(app," ",2)
    native_key(app,"6",2)
    native_key(app,"2")
    assert_true(app.component.state.document.text().startswith("scripts(frac(x, y)"))
    native_key(app,"z",2)
    native_key(app,"z",3)
    assert_true(app.component.state.document.text().find("2")>=0)
    assert_true(external_call["moxi_math_probe_semantics",Int32]()>4)
    var before=app.component.state.document.text()
    var marked=String("日本")
    var ptr=marked.as_c_string_span()
    assert_equal(external_call["moxi_math_probe_marked",Int32](ptr.ptr(),Int32(0)),1)
    drain(app)
    assert_equal(app.component.state.document.text(),before)
    # A structural command cannot mutate the document during native preedit.
    app.component.state.command(MathCommand.FRACTION)
    assert_equal(app.component.state.document.text(),before)
    assert_equal(external_call["moxi_math_probe_marked",Int32](ptr.ptr(),Int32(1)),1)
    drain(app)
    assert_true(app.component.state.document.text().find("日本")>=0)
    app.component.state=MathEditorState("matrix(row(a, b), row(c, d))")
    drain(app)
    native_key(app,",",2)
    assert_equal(len(app.component.state.document.nodes[app.component.state.document.nodes[app.component.state.document.root].children[0]].children),3)
    assert_true(external_call["moxi_math_probe_semantics",Int32]()>6)
    delete_hold_check(app,renderer)
    navigation_check(app,window,renderer)
    cross_slot_check(app,window,renderer)
    authored_script_check(app,renderer)
    no_op_and_reverse_check(app)
    clipboard_check(app)
    transformed_hit_check(app)
    drag_selection_check(app,window)
    source_selection_check(app,renderer)
    typing_focus_check(app,window,renderer)
    window.close()
    close_math_font()
    print("PASS AppKit NSEvent interpretation, structural chords, native marked text commit, caret candidate rectangle, semantic bounds, structured native clipboard; synthetic events, no physical keyboard/VoiceOver assertion")
