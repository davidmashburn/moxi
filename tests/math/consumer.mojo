from std.testing import assert_equal, assert_true
from moxi import App, Rect, WindowConfig
from moxi.macos import MacOSWindow, MacOSRenderer
from moxi_math import MathEditor, MathCommand, open_math_font, close_math_font

def main() raises:
    open_math_font("install/share/moxi_math/STIXTwoMath-Regular.otf")
    var app=App(MathEditor("frac(x, y)"),Rect(0,0,900,700))
    var window=MacOSWindow()
    var renderer=MacOSRenderer()
    window.open(WindowConfig("Moxi Math · Installed consumer",900,700))
    window.pump()
    app.component.state.select(app.component.state.document.root)
    app.component.state.command(MathCommand.ROOT)
    app.rebuild()
    app.component.prepare(app.view)
    app.render(renderer)
    app.component.present()
    assert_equal(app.component.state.document.text(),"root(?, frac(x, y))")
    assert_true(len(app.component.layout.snapshot.glyphs)>0)
    window.close()
    close_math_font()
    # Explicit owned font session can reopen after the host closes.
    open_math_font("install/share/moxi_math/STIXTwoMath-Regular.otf")
    close_math_font()
    var missing=False
    try:
        open_math_font("missing-font.otf")
    except:
        missing=True
    assert_true(missing)
    print("PASS installed public component, actual App/window/render, edit, owned font reopen and missing-font diagnostic; no Python/CAS dependency")
