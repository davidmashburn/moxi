"""Standalone native application and deterministic SVG export entry point."""
from std.sys import argv
from std.ffi import external_call
from moxi import App, Rect, WindowConfig, NONE_KIND, SvgSceneRenderer
from moxi.macos import MacOSWindow, MacOSRenderer, MacOSCanvasSceneRenderer
from layout import Layout, sample_graph
from graph_io import load_graph
from graph_app import GraphApp, CANVAS, dispatch_graph_event
from save_panel import choose_svg_path

def export_svg(state: GraphApp, bounds: Rect, path: String) raises:
    var renderer = SvgSceneRenderer(Int(bounds.width), Int(bounds.height))
    renderer.render_scene(state.scene(bounds))
    with open(path, "w") as file:
        file.write(renderer.markup())
    print("Exported ", path)

def render(mut app: App[GraphApp], mut renderer: MacOSRenderer, mut canvas: MacOSCanvasSceneRenderer) raises:
    # Submit controls and graph together before the
    # single presentation boundary so AppKit never displays a cleared canvas.
    var commands = app.paint()
    var bounds = app.view.bounds_for(CANVAS)
    var scene = app.component.scene(bounds)
    renderer.begin_frame()
    for index in range(commands.count()):
        renderer.draw(commands.command(index))
    canvas.set_clip(bounds)
    canvas.render_scene(scene)
    renderer.update_accessibility(app.accessibility())
    # The accessibility update finishes the frame; flush it before waiting.
    external_call["fdg_present_frame", NoneType]()
    app.clear_invalidation()

def save_snapshot(mut state: GraphApp, bounds: Rect):
    state.export_requested = False
    try:
        var path = choose_svg_path()
        if path == "":
            state.message = "Export cancelled"
            return
        export_svg(state, Rect(0, 0, bounds.width, bounds.height), path)
        state.message = String("Saved SVG: ", path)
    except error:
        state.message = String("Export failed: ", String(error))

def main() raises:
    var args = argv()
    var input = String("")
    var output = String("")
    var smoke = False
    var index = 1
    while index < len(args):
        var arg = args[index]
        if arg == "--export":
            index += 1
            if index >= len(args):
                raise Error("--export requires an SVG output path")
            output = args[index]
        elif arg == "--smoke":
            smoke = True
        elif arg == "--help":
            print("moxi-fdg [graph.json] [--export output.svg] [--smoke]")
            print("Without a file, open the included deterministic sample. Export runs 400 layout steps without opening a window.")
            return
        elif arg.startswith("--") or input != "":
            raise Error(String("Unexpected argument: ", arg))
        else:
            input = arg
        index += 1
    var graph = sample_graph()
    if input != "":
        graph = load_graph(input)
    var state = GraphApp(graph^)
    if output != "":
        for _ in range(400):
            _ = state.graph.step()
        var bounds = Rect(0, 0, 1100, 720)
        state.fit(bounds)
        export_svg(state, bounds, output)
        return
    # Start with a fully framed graph; Reheat animates further exploration.
    for _ in range(400):
        _ = state.graph.step()
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    var canvas = MacOSCanvasSceneRenderer()
    var config = WindowConfig("Moxi Force Graph", 1100, 800)
    config.set_min_size(800, 500)
    window.open(config)
    var size = window.size()
    var app = App[GraphApp](state^, Rect(0, 0, size.width, size.height))
    app.component.fit(app.view.bounds_for(CANVAS))
    render(app, renderer, canvas)
    var frames = 0
    while window.is_open():
        # main's pump waits up to 16 ms for native input.
        window.pump()
        var changed = app.tick(1.0 / 60.0)
        var event = window.poll_event()
        while event.kind != NONE_KIND:
            changed = dispatch_graph_event(app, event) or changed
            event = window.poll_event()
        if app.component.export_requested:
            save_snapshot(app.component, app.view.bounds_for(CANVAS))
            app.rebuild()
            changed = True
        if changed:
            render(app, renderer, canvas)
        if window.command_overflow_count() > 0:
            raise Error("Native scene capacity exceeded; refusing an incomplete graph")
        frames += 1
        if smoke and frames >= 15:
            print("native smoke: window, frames, scene submission, no overflow")
            external_call["fdg_close_window", NoneType]()
