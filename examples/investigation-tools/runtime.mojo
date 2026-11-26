"""The normal event/render loop shared with native UI replay."""
from std.ffi import external_call
from moxi import App
from moxi.event import NONE_KIND
from moxi.macos import MacOSWindow, MacOSRenderer, MacOSCanvasSceneRenderer, MacOSClipboard
from screen import InvestigationScreen, C0_ID, C1_ID, C2_ID


def render(mut app: App[InvestigationScreen], mut renderer: MacOSRenderer, mut plots: MacOSCanvasSceneRenderer) raises:
    app.render(renderer)
    plots.set_clip(app.root_bounds)
    plots.render_scene(app.component.combined_scene(app.view))
    var coefficient_focus = app.focus_id() == C0_ID or app.focus_id() == C1_ID or app.focus_id() == C2_ID
    external_call["investigation_coefficient_editor", NoneType](Int32(coefficient_focus))


def dispatch_pending(mut app: App[InvestigationScreen], mut window: MacOSWindow, mut clipboard: MacOSClipboard) raises -> Bool:
    window.pump()
    var changed = False
    var event = window.poll_event()
    while event.kind != NONE_KIND:
        changed = app.dispatch_with_clipboard(event, clipboard) or changed
        event = window.poll_event()
    return changed
