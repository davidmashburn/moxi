"""Normal entry point. --replay drives this same mounted app, never a mock view."""
from std.sys import argv
from std.time import perf_counter_ns
from moxi.macos import MacOSWindow, MacOSRenderer, MacOSCanvasSceneRenderer
from host import open_app, render, drain, tick
from replay import replay


def main() raises:
    var window = MacOSWindow()
    var app = open_app(window)
    var paint = MacOSRenderer()
    var graph = MacOSCanvasSceneRenderer()
    render(app, window, paint, graph)
    var args = argv()
    if len(args) == 3 and args[1] == "--replay":
        replay(app, window, paint, graph, args[2])
        window.close()
        return
    var previous = perf_counter_ns()
    while window.is_open():
        var changed = drain(app, window)
        var now = perf_counter_ns()
        changed = tick(app, Float32(Float64(now - previous) / 1e9)) or changed
        previous = now
        if changed:
            render(app, window, paint, graph)
        window.wait_for_work(1.0 / 60)
    window.close()
