"""Full-scope wxPython-style browser for Moxi's runnable examples."""

from std.ffi import external_call
from moxi import (
    App,
    NONE_KIND,
    Rect,
    WindowConfig,
)
from moxi_demo import (
    DemoBrowserState,
    DemoWalkthroughDriver,
)
from moxi_demo.live_editor_host import live_surface_clip, sync_live_editor
from moxi.macos import (
    MacOSCanvasSceneRenderer,
    MacOSClipboard,
    MacOSLiveEditor,
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
        var clip = live_surface_clip(app)
        if clip.width > 0.0 and clip.height > 0.0:
            _ = live_script.render(surface)
            # The live ABI establishes its own full-canvas clip. Constrain the
            # resulting commands to the same viewport as the retained canvas.
            external_call["moxi_window_set_custom_clip", NoneType](
                clip.x, clip.y, clip.width, clip.height,
            )
    else:
        scene_renderer.set_clip(surface)
        var scene = app.component.selected_scene(app.view)
        scene_renderer.render_scene(scene)


def run_demo(
    automated: Bool = False,
    catalog_sweep: Bool = False,
) raises:
    """Run the normal Playground, optionally driven through CapabilityBus."""
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
    var live_editor = MacOSLiveEditor()
    var live_script = MacOSLiveScript()
    var walkthrough = DemoWalkthroughDriver()
    if automated:
        walkthrough.start(catalog_sweep)

    render_frame(app, renderer, scene_renderer, live_script)
    while window.is_open():
        window.wait_for_work(1.0 / 60.0)
        window.pump()
        app.component.begin_input_batch()
        var event = window.poll_event()
        var changed = app.tick(1.0 / 60.0)
        if automated:
            changed = walkthrough.tick(app, 1.0 / 60.0) or changed
        while event.kind != NONE_KIND:
            changed = app.dispatch_with_clipboard(event, clipboard) or changed
            event = window.poll_event()
        if app.component.finish_input_batch():
            app.rebuild()
            changed = True
        changed = sync_live_editor(app, live_editor, live_script) or changed

        if changed:
            render_frame(app, renderer, scene_renderer, live_script)

    live_script.clear()


def main() raises:
    """Keep `pixi run demo` as the ordinary manual Playground."""
    run_demo(False)
