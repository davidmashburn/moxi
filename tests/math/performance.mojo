from std.time import perf_counter_ns
from std.testing import assert_equal
from moxi_math import MathEditor, MathEditorState, MathLayout, MathKind, MathCommand, open_math_font, close_math_font, draw_math
from moxi import App, Rect
from moxi.event import Event, TEXT_INPUT_KIND

def measure(name: String, source: String) raises:
    var started=perf_counter_ns()
    var app=App(MathEditor(source),Rect(0,0,1100,800))
    app.component.prepare(app.view)
    var cold=perf_counter_ns()-started
    var times=List[Int]()
    var measurements=0
    var max_cache=0
    var paint_count=0
    for sample in range(65):
        var leaf=app.component.state.document.root
        while len(app.component.state.document.nodes[leaf].children)>0:
            leaf=app.component.state.document.nodes[leaf].children[0]
        started=perf_counter_ns()
        app.component.state.select(leaf)
        var event=Event()
        event.kind=TEXT_INPUT_KIND
        event.text="v"+String(sample)
        _ = app.component.route(event)
        app.root_bounds.width=1100+Float32(sample)*.3
        app.rebuild()
        app.component.prepare(app.view)
        var paint=app.paint()
        app.component.present()
        paint_count=paint.count()
        var elapsed=perf_counter_ns()-started
        if sample>=5:
            times.append(elapsed)
        measurements+=app.component.layout.snapshot.measured_nodes
        max_cache=max(max_cache,len(app.component.layout.cache))
        app.component.state.horizontal(1)
        app.component.layout.publish(app.component.state.document)
        assert_equal(app.component.layout.snapshot.measured_nodes,0)
    # Insertion sort outside the timed region; 60 samples.
    for i in range(1,len(times)):
        var j=i
        while j>0 and times[j]<times[j-1]:
            var t=times[j]; times[j]=times[j-1]; times[j-1]=t; j-=1
    print(name,"nodes",len(app.component.state.document.nodes),"cold_ns",cold,"p95_ns",times[56],"p99_ns",times[59],"worst_ns",times[59],"remeasured_total",measurements,"cache_entries",max_cache,"undo_entries",len(app.component.state.undo_stack),"glyphs",len(app.component.layout.snapshot.glyphs),"paint_commands",paint_count)

def main() raises:
    open_math_font("assets/math/STIXTwoMath-Regular.otf")
    var counts: List[Int] = [100,1000,10000]
    for count in counts:
        var text=String("row(")
        for i in range(count-1):
            if i>0: text+=", "
            text+="x"
        text+=")"
        measure("row",text)
    var matrix=String("matrix(")
    for r in range(20):
        if r>0: matrix+=", "
        matrix+="row("
        for c in range(20):
            if c>0: matrix+=", "
            matrix+="x"
        matrix+=")"
    matrix+=")"
    measure("matrix20",matrix)
    var deep=String("x")
    for _ in range(60): deep="frac("+deep+", y)"
    measure("depth60",deep)
    close_math_font()
