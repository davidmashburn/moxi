"""Full-scope wxPython-style browser for Moxi's runnable examples."""

from moxi import App, DemoBrowserState, NONE_KIND, Rect, WindowConfig
from moxi.macos import MacOSClipboard, MacOSDemoRunner, MacOSRenderer, MacOSWindow


def main() raises:
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    var clipboard = MacOSClipboard()
    window.open(WindowConfig("Moxi Demo Browser", 1180.0, 760.0))
    var size = window.size()
    var app = App[DemoBrowserState](
        DemoBrowserState(),
        Rect(0.0, 0.0, size.width, size.height),
    )
    var runner = MacOSDemoRunner()
    var active_task = ""
    var task_was_running = False

    app.render(renderer)
    while window.is_open():
        window.pump()
        var event = window.poll_event()
        var changed = False
        if event.kind != NONE_KIND:
            changed = app.dispatch_with_clipboard(event, clipboard)
            var requested_task = app.component.take_pending_task()
            if requested_task.count_codepoints() > 0:
                var launched = runner.launch(requested_task)
                app.component.set_task_result(requested_task, launched)
                if launched:
                    active_task = requested_task
                    task_was_running = True
                app.rebuild()
                changed = True

        if (
            task_was_running
            and active_task.count_codepoints() > 0
            and not runner.is_running()
        ):
            app.component.set_task_completion(
                active_task,
                runner.exit_status(),
            )
            active_task = ""
            task_was_running = False
            app.rebuild()
            changed = True

        if changed:
            app.render(renderer)
