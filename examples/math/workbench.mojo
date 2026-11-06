"""Real Moxi App/host, optional persistent worker, and executable capture replay."""
from moxi_math.input import poll_math_event
from std.ffi import external_call
from std.python import Python
from moxi import App, Rect, WindowConfig
from moxi.macos import MacOSRenderer, MacOSWindow
from moxi.event import Event, NONE_KIND, KEY_DOWN_KIND, TEXT_INPUT_KIND, MOD_COMMAND
from moxi_math import MathEditor, MathEditorState, MathCommand, open_math_font, close_math_font
from moxi_math.computation import MathComputation, MathOperation
from moxi_math.view import MATH_SAVE, MATH_OPEN, MATH_EXPAND, MATH_DIFFERENTIATE, MATH_EVALUATE, MATH_SUBSTITUTE, MATH_APPLY, MATH_CANCEL, MATH_RESULT, MATH_SCRATCH, MATH_MAIN, MATH_ZOOM_IN, MATH_ZOOM_OUT

comptime SAVE_PATH = "/tmp/moxi-d02-document.moxi"

def key(mut editor: MathEditor, code: Int, modifiers: Int = 0) raises:
    var event=Event()
    event.kind=KEY_DOWN_KIND; event.key=code; event.modifiers=modifiers
    _ = editor.route(event)

def type_text(mut editor: MathEditor, text: String) raises:
    var event=Event()
    event.kind=TEXT_INPUT_KIND; event.text=text
    _ = editor.route(event)

def replay_step(mut editor: MathEditor, mut engine: MathComputation, step: Int) raises -> Bool:
    if step==0:
        return True
    elif step==1:
        type_text(editor,"x")
        key(editor,47,MOD_COMMAND)
        type_text(editor,"y")
        return True
    elif step==2:
        key(editor,32,MOD_COMMAND)
        key(editor,50,MOD_COMMAND)
        key(editor,32,MOD_COMMAND)
        key(editor,54,MOD_COMMAND)
        type_text(editor,"2")
        key(editor,45,MOD_COMMAND)
        type_text(editor,"i")
        return True
    elif step==3:
        editor.state=MathEditorState("matrix(row(a, b), row(c, d))")
        editor.state.command(MathCommand.ADD_ROW)
        type_text(editor,"α")
        editor.state.command(MathCommand.NEXT_HOLE)
        type_text(editor,"β")
        return True
    elif step==4:
        editor.state.command(MathCommand.TEXT)
        _ = editor.state.source.select_all()
        editor.state.insert("frac(x,")
        editor.state.command(MathCommand.TEXT)
        return True
    elif step==5:
        editor.state.command(MathCommand.UNDO)
        editor.state.command(MathCommand.UNDO)
        editor.state.command(MathCommand.TEXT)
        return True
    elif step==6:
        editor.state=MathEditorState('frac(scripts(group("(", ")", row(x, +, 1)), ?, 3, ?, ?), 2)')
        editor.state.select(editor.state.document.nodes[editor.state.document.root].children[0])
        _ = engine.submit(editor.state)
        editor.backend_status=engine.message()
        return True
    elif step==7:
        if String(engine.session.state)!=String(engine.module.State.PENDING):
            raise Error("Capture slow-worker fixture did not remain pending during edit")
        var denominator=editor.state.document.nodes[editor.state.document.root].children[1]
        editor.state.select(denominator)
        editor.state.insert("3")
        editor.state.status="Edited denominator after selected numerator request"
        editor.backend_status="Source revision changed · previous result cannot Apply"
        _ = engine.apply(editor.state,engine.result())
        return True
    elif step==8:
        if String(engine.session.state)==String(engine.module.State.PENDING):
            pass
        elif String(engine.session.state)!=String(engine.module.State.READY) or not Bool(engine.session.eligible(editor.state.document.revision)):
            editor.state.select(editor.state.document.nodes[editor.state.document.root].children[0])
            _ = engine.submit(editor.state)
            editor.backend_status=engine.message()
        elif engine.result()!="":
            editor.backend_status=engine.message()+" · "+engine.result()
            editor.state.status="Current result ready · source notation retained"
            return True
    elif step==9:
        if not engine.apply(editor.state,engine.result()):
            raise Error("Capture: expected current result application")
        return True
    elif step==10:
        editor.state.command(MathCommand.UNDO)
        return True
    elif step==11:
        var saved=editor.state.save_text()
        with open(SAVE_PATH,"w") as file:
            file.write(saved)
        editor.state.select(editor.state.document.root)
        editor.state.insert("temporary")
        with open(SAVE_PATH,"r") as file:
            editor.state.load_text(file.read())
        if editor.state.save_text()!=saved:
            raise Error("Capture persistence mismatch")
        return True
    return False

def replay_host(mut editor: MathEditor, mut blocks: List[MathEditorState], mut active: Int, mut target_block: Int, mut engine: MathComputation, step: Int) raises -> Bool:
    if step==6:
        target_block=active
    if step==9 and active==2:
        blocks[2]=editor.state
        active=target_block
        editor.state=blocks[active]
    var done=replay_step(editor,engine,step)
    if done and step==8:
        blocks[active]=editor.state
        active=2
        editor.state=blocks[2]
    return done

def process_actions(mut editor: MathEditor, mut blocks: List[MathEditorState], mut active: Int, mut target_block: Int, mut engine: MathComputation) raises:
    var action=editor.pending_action
    editor.pending_action = -1
    if action==MATH_MAIN or action==MATH_SCRATCH or action==MATH_RESULT:
        blocks[active]=editor.state
        active=0 if action==MATH_MAIN else 1 if action==MATH_SCRATCH else 2
        editor.state=blocks[active]
        editor.scroll_x=0
    elif action==MATH_ZOOM_IN or action==MATH_ZOOM_OUT:
        editor.zoom=max(Float32(.5),min(Float32(2),editor.zoom+(Float32(.1) if action==MATH_ZOOM_IN else Float32(-.1))))
    elif action==MATH_SAVE:
        with open(SAVE_PATH,"w") as file:
            file.write(editor.state.save_text())
        editor.state.status="Saved " + SAVE_PATH
    elif action==MATH_OPEN:
        try:
            with open(SAVE_PATH,"r") as file:
                editor.state.load_text(file.read())
        except e:
            editor.state.status=String(e)
    elif action==MATH_EXPAND or action==MATH_DIFFERENTIATE or action==MATH_EVALUATE or action==MATH_SUBSTITUTE:
        if active==2:
            editor.state.status="Copy the result to Scratch before another computation"
            return
        var operation=MathOperation.EXPAND
        if action==MATH_DIFFERENTIATE:
            operation=MathOperation.DIFFERENTIATE
        elif action==MATH_EVALUATE:
            operation=MathOperation.EVALUATE
        elif action==MATH_SUBSTITUTE:
            if active!=0:
                editor.state.status="Set the replacement in Scratch, then substitute in Expression"
                return
            operation=MathOperation.SUBSTITUTE
        if engine.submit(editor.state,operation,blocks[1].document.text()):
            target_block=active
        editor.backend_status=engine.message()
    elif action==MATH_CANCEL:
        engine.cancel()
        editor.backend_status=engine.message()
    elif action==MATH_APPLY:
        if active==target_block:
            _ = engine.apply(editor.state,blocks[2].document.text())
        else:
            editor.state.status="Return to the source block before Apply"
    var revision=editor.state.document.revision if active==target_block else blocks[target_block].document.revision
    if engine.tick(revision):
        editor.backend_status=engine.message()
        var result=engine.result()
        if result!="" and engine.has_new_result():
            blocks[2]=MathEditorState(result)
            if active==2:
                editor.state=blocks[2]

def main() raises:
    open_math_font("assets/math/STIXTwoMath-Regular.otf")
    var engine=MathComputation()
    var capture_module=Python.import_module("moxi_math.capture")
    var capture=capture_module.Capture()
    var capturing=String(capture.directory)!=""
    capture.configure_worker(engine.session)
    var app=App(MathEditor(),Rect(0,0,1180,820))
    app.component.workbench_controls=True
    app.rebuild()
    var blocks: List[MathEditorState]=[MathEditorState(),MathEditorState(),MathEditorState()]
    var active=0
    var target_block=0
    var window=MacOSWindow()
    var renderer=MacOSRenderer()
    window.open(WindowConfig("Moxi Math · D02 native workbench",1180,820))
    var step=0
    var frame=0
    var capture_frame = -1
    var started=window.clock_nanoseconds()
    try:
        while window.is_open():
            window.pump()
            var math_event=poll_math_event()
            while math_event.kind!=NONE_KIND:
                if app.component.route(math_event):
                    app.rebuild()
                math_event=poll_math_event()
            var event=window.poll_event()
            while event.kind!=NONE_KIND:
                if app.component.route(event):
                    app.rebuild()
                else:
                    _ = app.dispatch(event)
                event=window.poll_event()
            var old_revision=app.component.state.document.revision
            var old_status=app.component.backend_status
            var action=app.component.pending_action
            process_actions(app.component,blocks,active,target_block,engine)
            if action>=0 or old_revision!=app.component.state.document.revision or old_status!=app.component.backend_status:
                app.rebuild()
            if capturing and capture_frame<0 and frame%25==0:
                if replay_host(app.component,blocks,active,target_block,engine,step):
                    capture_frame=frame+3
                app.rebuild()
            app.component.prepare(app.view)
            if app.needs_frame():
                app.render(renderer)
                app.component.present()
            if capturing and frame==capture_frame:
                var path=String(capture.path(step))
                var ptr=path.as_c_string_span()
                if external_call["moxi_math_capture",Int32](ptr.ptr())==0:
                    raise Error("Live native capture failed")
                var state=app.component.state
                capture.record(step,state.document.text(),state.document.revision,state.selected,state.caret.id,app.component.layout.snapshot.generation,app.component.layout.snapshot.measured_nodes,state.status+" | "+app.component.backend_status,window.size().width,window.size().height)
                step+=1; capture_frame = -1
                if step>=12:
                    capture.finish()
                    print("PASS 12 live native capture states")
                    break
            if capturing and window.clock_nanoseconds()-started>60000000000:
                raise Error("Capture deadline exceeded; inspect worker status")
            frame+=1
            external_call["usleep",Int32](UInt32(16000))
    finally:
        engine.close()
        close_math_font()
