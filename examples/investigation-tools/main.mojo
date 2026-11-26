"""Normal native entry point. The replay only supplies native input callbacks."""
from std.ffi import external_call
from moxi import App, Rect, WindowConfig
from moxi.macos import MacOSWindow, MacOSRenderer, MacOSCanvasSceneRenderer, MacOSClipboard
from screen import InvestigationScreen
from runtime import render, dispatch_pending
from replay import replay, REOPEN_MODE
from layout_replay import replay_layout


def main() raises:
    var config = WindowConfig("Moxi | Investigation tools", 1140, 860)
    config.set_min_size(980, 800)
    var window = MacOSWindow()
    window.open(config)
    var size = window.size()
    var app = App(InvestigationScreen(), Rect(0, 0, size.width, size.height))
    var renderer = MacOSRenderer()
    var plots = MacOSCanvasSceneRenderer()
    var clipboard = MacOSClipboard()
    render(app, renderer, plots)
    var mode = external_call["investigation_replay_mode", Int32]()
    if external_call["investigation_layout_check", Int32]():
        replay_layout(app, window, renderer, plots, mode == REOPEN_MODE)
        return
    if mode:
        replay(app, window, renderer, plots, mode)
        return
    while window.is_open():
        window.wait_for_work(1.0 / 60.0)
        var changed = app.tick(1.0 / 60.0)
        changed = dispatch_pending(app, window, clipboard) or changed
        if changed:
            render(app, renderer, plots)
