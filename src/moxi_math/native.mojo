"""Small reusable editor host. Backend-free consumer needs no Python imports."""
from moxi_math.input import poll_math_event
from std.ffi import external_call
from moxi import App, Rect, WindowConfig
from moxi.event import NONE_KIND
from moxi.macos import MacOSWindow, MacOSRenderer
from .font import open_math_font, close_math_font
from .view import MathEditor, MATH_SAVE, MATH_OPEN, MATH_ZOOM_IN, MATH_ZOOM_OUT

def _local_action(mut editor: MathEditor) raises:
    var action=editor.pending_action
    editor.pending_action = -1
    if action==MATH_ZOOM_IN or action==MATH_ZOOM_OUT:
        editor.zoom=max(Float32(.5),min(Float32(2),editor.zoom+(Float32(.1) if action==MATH_ZOOM_IN else Float32(-.1))))
    elif action==MATH_SAVE or action==MATH_OPEN:
        try:
            if action==MATH_SAVE:
                with open("/tmp/moxi-math-consumer.moxi","w") as file:
                    file.write(editor.state.save_text())
                editor.state.status="Saved /tmp/moxi-math-consumer.moxi"
            else:
                with open("/tmp/moxi-math-consumer.moxi","r") as file:
                    editor.state.load_text(file.read())
        except e:
            editor.state.status=String(e)

def run_math_editor(title: String, text: String, font_path: String) raises:
    open_math_font(font_path)
    try:
        var editor=MathEditor(text)
        editor.title=title
        var app=App(editor,Rect(0,0,1100,760))
        var window=MacOSWindow()
        var renderer=MacOSRenderer()
        window.open(WindowConfig(title,1100,760))
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
            if app.component.pending_action>=0:
                _local_action(app.component)
                app.rebuild()
            app.component.prepare(app.view)
            if app.needs_frame():
                app.render(renderer)
                app.component.present()
            external_call["usleep",Int32](UInt32(16000))
    finally:
        close_math_font()
