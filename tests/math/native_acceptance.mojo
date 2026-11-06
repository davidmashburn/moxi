from std.ffi import external_call
from std.testing import assert_equal, assert_true
from moxi import App, Rect, WindowConfig
from moxi.macos import MacOSWindow, MacOSRenderer
from moxi.geometry import Point
from moxi.event import Event, POINTER_DOWN_KIND, POINTER_UP_KIND
from moxi_math import MathEditor, MathEditorState, MathCommand, open_math_font, close_math_font, poll_math_event

def native_key(mut app: App[MathEditor], text: String, modifiers: Int = 0) raises:
    var chars=text
    var ptr=chars.as_c_string_span()
    assert_equal(external_call["moxi_math_probe_key",Int32](ptr.ptr(),Int32(modifiers)),1)
    drain(app)

def drain(mut app: App[MathEditor]) raises:
    var event=poll_math_event()
    while event.kind!=0:
        _ = app.component.route(event)
        event=poll_math_event()
    app.rebuild()
    app.component.prepare(app.view)
    app.component.present()

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
    clipboard_check(app)
    transformed_hit_check(app)
    window.close()
    close_math_font()
    print("PASS AppKit NSEvent interpretation, structural chords, native marked text commit, caret candidate rectangle, semantic bounds, structured native clipboard; synthetic events, no physical keyboard/VoiceOver assertion")
