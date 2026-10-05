"""Shared native acceptance screen using portable frames and normalized input."""
from moxi.layout_workbench import LayoutWorkbench
from moxi.layout_workbench_replay import WorkbenchController, layout_workbench_chart
from moxi.frame import submit_frame
from moxi.native_frame import NativeFrameRenderer
from moxi.native_clipboard import NativeClipboard
from moxi.native_window import NativeWindow
from moxi.window import WindowConfig
from moxi.event import NONE_KIND


def run_layout_workbench[backend_kind: Int, invert_scroll_y: Bool = False]() raises:
    var screen = LayoutWorkbench()
    var controller = WorkbenchController()
    var clipboard = NativeClipboard()
    var window = NativeWindow[backend_kind, invert_scroll_y]()
    var renderer = NativeFrameRenderer[backend_kind]()
    var config = WindowConfig("Moxi · Composed layout workbench",1100,800)
    config.set_min_size(500,760)
    window.open(config)
    var presentation = screen.frame(window.size())
    var dirty = True
    while window.is_open():
        if dirty:
            try:
                presentation = screen.frame(window.size())
            except error:
                screen.error = String(error)
                print("Layout rejected; retaining previous publication:",screen.error)
                presentation = screen.recovery()
            var packet = presentation.packet(window.metrics())
            var chart = presentation.snapshot.bounds(22)
            packet.scene = layout_workbench_chart(chart)
            packet.scene_clip = chart.intersection(packet.metrics.bounds())
            packet.custom_layer = 22
            renderer.bind_resources(presentation.snapshot)
            submit_frame(window, renderer, packet)
            dirty = False
        window.wait_for_work(-1)
        window.pump()
        var event = window.poll_event()
        while event.kind != NONE_KIND:
            try:
                dirty = controller.dispatch_with_clipboard(screen, presentation, event, window.size(), clipboard) or dirty
            except error:
                screen.error = String(error)
                print("Input service failed:",screen.error)
                dirty = True
            event = window.poll_event()
    renderer.release_resources()
