"""Nonblocking bridge shared by the native demo host and its regression check."""

from moxi import App, Rect
from moxi.macos import MacOSLiveEditor, MacOSLiveScript, LiveBuildStatus
from .demo_browser import DemoBrowserState


def live_surface_clip(app: App[DemoBrowserState]) -> Rect:
    """Reuse the retained canvas clip, including every scrolling ancestor.

    Call after painting the retained frame. The ABI still receives the full
    canvas geometry, while its custom paint stays inside the browser viewport.
    """
    return app.component.selected_surface_clip(app.view, app.runtime.previous_commands)


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
