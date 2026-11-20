"""Nonblocking bridge shared by the native demo host and its regression check."""

from moxi import App, Rect
from moxi.macos import MacOSLiveEditor, MacOSLiveScript, LiveBuildStatus
from moxi.paint import CANVAS_KIND
from moxi.live_script import LIVE_SCRIPT_CANVAS_ID
from .demo_browser import DemoBrowserState, DEMO_LIVE_SCRIPT_ID_OFFSET


def live_surface_clip(app: App[DemoBrowserState]) -> Rect:
    """Reuse the retained canvas clip, including every scrolling ancestor.

    Call after painting the retained frame. The ABI still receives the full
    canvas geometry, while its custom paint stays inside the browser viewport.
    """
    var surface = app.component.selected_surface_bounds(app.view)
    for command in app.runtime.previous_commands:
        if command.kind == CANVAS_KIND and command.id == DEMO_LIVE_SCRIPT_ID_OFFSET + LIVE_SCRIPT_CANVAS_ID:
            if command.has_clip:
                return surface.intersection(command.clip_bounds)
            return surface
    return Rect(0.0, 0.0, 0.0, 0.0)


def sync_live_editor(
    mut app: App[DemoBrowserState],
    mut editor: MacOSLiveEditor,
    mut live_script: MacOSLiveScript,
) -> Bool:
    """Submit a snapshot and consume completion without blocking the UI loop.

    Keep the module and draft across catalog navigation. Only successful poll
    loads a module; a failed compiler or ABI check leaves the last scene intact.
    """
    if app.component.source_editor.pending_run:
        app.component.source_editor.pending_run = False
        if not editor.start(app.component.source_editor.running_source):
            app.component.source_editor.complete(False, "Cannot start draft build. Check the compiler environment and source for NUL bytes.")
            app.component.refresh_editor_status()
            app.rebuild()
            return True
    var result = editor.poll()
    if result.value != LiveBuildStatus.SUCCEEDED.value and result.value != LiveBuildStatus.FAILED.value:
        return False
    var succeeded = result.value == LiveBuildStatus.SUCCEEDED.value
    if succeeded:
        live_script.loaded = True
    app.component.source_editor.complete(succeeded, editor.diagnostics())
    app.component.refresh_editor_status()
    app.rebuild()
    return True
