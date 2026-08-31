"""Full-scope wxPython-style browser for Moxi's runnable examples."""

from moxi import App, DemoBrowserState, NONE_KIND, Rect, WindowConfig
from moxi.macos import (
    MacOSCanvasSceneRenderer,
    MacOSClipboard,
    MacOSFileWatcher,
    MacOSLiveScript,
    MacOSRenderer,
    MacOSWindow,
)


def render_frame(
    mut app: App[DemoBrowserState],
    mut renderer: MacOSRenderer,
    mut scene_renderer: MacOSCanvasSceneRenderer,
    mut live_script: MacOSLiveScript,
) raises:
    """Render retained widgets and the selected component canvas together."""
    app.render(renderer)
    var surface = app.component.selected_surface_bounds(app.view)
    if app.component.has_live_script():
        # Clear the previous in-process scene before letting the dynamic
        # module repaint the same component-owned canvas.
        scene_renderer.set_clip(Rect(0.0, 0.0, 0.0, 0.0))
        var empty = app.component.selected_scene(app.view)
        scene_renderer.render_scene(empty)
        _ = live_script.render(surface)
    else:
        scene_renderer.set_clip(surface)
        var scene = app.component.selected_scene(app.view)
        scene_renderer.render_scene(scene)


def sync_live_script(
    mut app: App[DemoBrowserState],
    mut watcher: MacOSFileWatcher,
    mut live_script: MacOSLiveScript,
) -> Bool:
    """Build and atomically swap the selected editable module when it changes."""
    if not app.component.has_live_script():
        if watcher.path.count_codepoints() > 0:
            watcher.clear()
            live_script.clear()
        return False

    var source = app.component.selected_source_path()
    var source_changed: Bool
    if watcher.path != source:
        source_changed = watcher.watch(source)
        if not source_changed:
            app.component.set_live_reload_status(
                String("Cannot watch ", source, ".")
            )
            app.rebuild()
            return True
    else:
        source_changed = watcher.changed()

    if not source_changed:
        return False

    var loaded = live_script.reload(source, watcher.last_mtime)
    if loaded:
        app.component.set_live_reload_status(
            "Live module ready · saved Mojo source is running in this window."
        )
    elif live_script.loaded:
        app.component.set_live_reload_status(
            "Live reload failed · the previous module is still running."
        )
    else:
        app.component.set_live_reload_status(
            "Live reload failed · see the compiler diagnostics in the terminal."
        )
    app.rebuild()
    return True


def main() raises:
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    var clipboard = MacOSClipboard()
    window.open(WindowConfig("Moxi Playground", 1180.0, 760.0))
    var size = window.size()
    var app = App[DemoBrowserState](
        DemoBrowserState(),
        Rect(0.0, 0.0, size.width, size.height),
    )
    var scene_renderer = MacOSCanvasSceneRenderer()
    var live_watcher = MacOSFileWatcher()
    var live_script = MacOSLiveScript()

    render_frame(app, renderer, scene_renderer, live_script)
    while window.is_open():
        window.pump()
        var event = window.poll_event()
        var changed = app.tick(1.0 / 60.0)
        if event.kind != NONE_KIND:
            changed = app.dispatch_with_clipboard(event, clipboard) or changed
        changed = sync_live_script(app, live_watcher, live_script) or changed

        if changed:
            render_frame(app, renderer, scene_renderer, live_script)
