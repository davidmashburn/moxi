"""The normal event/render loop shared with native UI replay."""
from moxi import App
from moxi.event import NONE_KIND
from moxi.macos import MacOSWindow, MacOSRenderer, MacOSCanvasSceneRenderer, MacOSClipboard
from screen import InvestigationScreen


def render(mut app: App[InvestigationScreen], mut renderer: MacOSRenderer, mut plots: MacOSCanvasSceneRenderer) raises:
    app.render(renderer)
    plots.set_clip(app.root_bounds)
    plots.render_scene(app.component.combined_scene(app.view))


def dispatch_pending(mut app: App[InvestigationScreen], mut window: MacOSWindow, mut clipboard: MacOSClipboard) raises -> Bool:
    window.pump()
    var changed = False
    var event = window.poll_event()
    while event.kind != NONE_KIND:
        changed = app.dispatch_with_clipboard(event, clipboard) or changed
        event = window.poll_event()
    return changed
