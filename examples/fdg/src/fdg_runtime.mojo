"""Standalone native application and deterministic file export entry point."""
from std.sys import argv
from std.ffi import external_call
from moxi import App, Rect, WindowConfig, NONE_KIND
from moxi.backend import BACKEND_MACOS_APPKIT, BACKEND_LINUX
from moxi.paint import SURFACE_KIND
from moxi.frame import FramePacket
from moxi.native_frame import NativeFrameRenderer
from moxi.native_window import NativeWindow, NativeRenderer, NativeCanvasSceneRenderer
from layout import sample_graph
from graph_io import load_graph
from graph_app import GraphApp, CANVAS, dispatch_graph_event
from save_panel import choose_export_path
from graph_export import export_graph
from replay import replay_action, capture_frame

def render[backend: Int](mut app: App[GraphApp], mut renderer: NativeRenderer[backend], mut canvas: NativeCanvasSceneRenderer[backend]) raises:
    # Submit controls and graph together before the
    # single presentation boundary so AppKit never displays a cleared canvas.
    var commands = app.paint()
    var bounds = app.view.bounds_for(CANVAS)
    var scene = app.component.scene(bounds)
    comptime if backend == BACKEND_LINUX:
        # Linux uses the existing ordered frame presenter. Its legacy canvas
        # widget entrypoint deliberately rejects calls; FrameRenderer lowers
        # the canvas to a panel and inserts the graph at that layer.
        var packet = FramePacket()
        for index in range(commands.count()):
            var command = commands.command(index)
            if command.kind == SURFACE_KIND:
                # Legacy App paint carries the host clear color as a command;
                # it is not an ordered retained widget slot.
                renderer.draw_surface(command)
            else:
                packet.commands.append(command)
        packet.scene = scene^
        packet.scene_clip = bounds
        packet.custom_layer = CANVAS
        var frame_renderer = NativeFrameRenderer[backend]()
        frame_renderer.render(packet)
    else:
        renderer.begin_frame()
        for index in range(commands.count()):
            renderer.draw(commands.command(index))
        canvas.set_clip(bounds)
        canvas.render_scene(scene)
    renderer.update_accessibility(app.accessibility())
    renderer.end_frame()
    # Flush the complete frame before waiting.
    external_call["fdg_present_frame", NoneType]()
    app.clear_invalidation()

def save_snapshot(mut state: GraphApp, bounds: Rect):
    state.export_requested = False
    try:
        var path = choose_export_path()
        if path == "":
            state.message = "Export cancelled"
            return
        export_graph(state, Rect(0, 0, bounds.width, bounds.height), path)
        state.message = String("Saved snapshot: ", path)
    except error:
        state.message = String("Export failed: ", String(error))

def run[backend: Int]() raises:
    var args = argv()
    var input = String("")
    var output = String("")
    var smoke = False
    var replay_dir = String("")
    var index = 1
    while index < len(args):
        var arg = args[index]
        if arg == "--export":
            index += 1
            if index >= len(args):
                raise Error("--export requires an SVG, PNG or PDF output path")
            output = args[index]
        elif arg == "--replay":
            index += 1
            if index >= len(args):
                raise Error("--replay requires an existing output directory")
            replay_dir = args[index]
        elif arg == "--smoke":
            smoke = True
        elif arg == "--help":
            print("moxi-fdg [graph.json] [--export output.svg|png|pdf] [--smoke]")
            print("--replay EXISTING_DIRECTORY runs a finite app interaction/export/capture sequence and closes (offscreen content captures).")
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
    if replay_dir != "" and (len(graph.nodes) == 0 or output != "" or smoke):
        raise Error("--replay requires a nonempty graph and cannot combine with --export or --smoke")
    var state = GraphApp(graph^)
    if output != "":
        for _ in range(400):
            _ = state.graph.step()
        var bounds = Rect(0, 0, 1100, 720)
        state.fit(bounds)
        export_graph(state, bounds, output)
        return
    # Start with a fully framed graph; Reheat animates further exploration.
    for _ in range(400):
        _ = state.graph.step()
    var window = NativeWindow[backend, backend == BACKEND_MACOS_APPKIT]()
    var renderer = NativeRenderer[backend]()
    var canvas = NativeCanvasSceneRenderer[backend]()
    var config = WindowConfig("Moxi Force Graph", 1100, 800)
    config.set_min_size(800, 500)
    window.open(config)
    var size = window.size()
    var app = App[GraphApp](state^, Rect(0, 0, size.width, size.height))
    app.component.fit(app.view.bounds_for(CANVAS))
    render(app, renderer, canvas)
    var frames = 0
    while window.is_open():
        # AppKit's pump waits; GTK separates waiting from event pumping.
        comptime if backend == BACKEND_LINUX:
            window.wait_for_work(1.0 / 60.0)
        window.pump()
        if not window.is_open():
            break
        var changed = app.tick(1.0 / 60.0)
        var event = window.poll_event()
        while event.kind != NONE_KIND:
            changed = dispatch_graph_event(app, event) or changed
            event = window.poll_event()
        if app.component.export_requested:
            save_snapshot(app.component, app.view.bounds_for(CANVAS))
            app.rebuild()
            changed = True
        if replay_dir != "" and frames >= 10 and frames <= 40 and frames % 10 == 0:
            replay_action(app, (frames - 10) // 10, replay_dir)
            changed = True
        if changed:
            render(app, renderer, canvas)
        if window.command_overflow_count() > 0:
            raise Error("Native scene capacity exceeded; refusing an incomplete graph")
        if replay_dir != "" and frames >= 15 and frames <= 45 and frames % 10 == 5:
            capture_frame(String(replay_dir, "/phase-", (frames - 15) // 10, ".png"))
            if frames == 45:
                external_call["fdg_close_window", NoneType]()
        frames += 1
        if smoke and frames >= 15:
            print("native smoke: window, frames, scene submission, no overflow")
            external_call["fdg_close_window", NoneType]()
