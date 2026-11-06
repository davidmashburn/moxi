"""App adapter preserving ordinary text/control ownership before canvas shortcuts."""
from moxi.app_runtime import App
from moxi.component import Component
from moxi.event import *
from moxi.geometry import Point, Rect
from moxi.view_node import TEXT_INPUT_VIEW_KIND
from .surface import CanvasView, PointerPreparation, CONTROL_BASE, ID_STRIDE, SURFACE_FOCUS_ID, TOOLBAR_BASE
from .model import SessionKind, ObjectKind, CanvasObject, Port, PortDirection
from .geometry import WindowPoint
from .interaction import CanvasCommand, command_title
from .commands import HostPlatform, canvas_bindings, resolve_modifier


def dispatch_canvas[Child: Component & Deinitable](mut app: App[CanvasView[Child]], event: Event, host: HostPlatform = HostPlatform.MACOS) -> Bool:
    """Use this at the host boundary. Child events still use ordinary App dispatch.

    This adapter scopes canvas commands before App's generic directional traversal;
    text/IME and clipboard stay in the child scope. Tab enters/leaves the canvas
    once, and only explicitly entered node controls become additional tab stops.
    """
    # Canvas capture retains the raw up event: generic App converts up to click.
    if app.component.state.session != SessionKind.IDLE and (event.kind == POINTER_MOVE_KIND or event.kind == POINTER_UP_KIND or event.kind == DROP_KIND or event.kind == DRAG_UPDATE_KIND):
        var changed = app.component.update(event, app.view)
        if event.kind == POINTER_UP_KIND or event.kind == DROP_KIND:
            _ = app.runtime.cancel_press()
        if changed:
            app.rebuild_localized()
        return changed
    if event.kind == FOCUS_KIND and not event.focused and event.target < 0:
        app.component.state.cancel()
        app.component.control_pointer = -1
        app.component.control_owner = -1
        app.rebuild_localized()
        return True
    if event.kind == POINTER_CANCEL_KIND:
        app.component.state.cancel()
        app.component.control_pointer = -1
        app.component.control_owner = -1
    var prepared = app.component.prepare_pointer(event, app.view)
    if prepared != PointerPreparation.UNCHANGED:
        app.rebuild_localized()
    if prepared == PointerPreparation.CONSUMED:
        return True
    var focus = app.runtime.focus_id()
    var in_controls = focus >= CONTROL_BASE and (focus - CONTROL_BASE) % ID_STRIDE < 998 and app.component.editor >= 0
    if event.kind == KEY_DOWN_KIND:
        if in_controls and not app.component.searching:
            if event.key == KEY_ESCAPE:
                var ended = app.end_composition(focus)
                if not ended:
                    _ = invoke_canvas(app, CanvasCommand.LEAVE_CONTROLS)
                app.rebuild_localized()
                return True
            if event.key == KEY_TAB or app.is_clipboard_command(event):
                return app.dispatch(event)
            var local = event
            local.target = focus
            var changed = app.component.localized_dispatch(local, app.view) == 2
            if changed:
                app.rebuild_localized()
            return changed
        if app.component.state.session == SessionKind.IDLE and not app.component.searching:
            var application = app.component.application_command(event, host)
            if application != CanvasCommand.NONE:
                return invoke_canvas(app, application)
        if event.key == KEY_TAB or (focus >= TOOLBAR_BASE and focus < TOOLBAR_BASE + 50 and (event.key == KEY_ENTER or event.key == KEY_SPACE)):
            return app.dispatch(event)
        var command = app.component.key_command(event, host)
        if command != CanvasCommand.NONE:
            _ = invoke_canvas(app, command)
        else:
            app.rebuild_localized()
        return True
    if event.kind == TEXT_INPUT_KIND and app.component.searching:
        app.component.search += event.text
        app.component.search_index = 0
        app.rebuild_localized()
        return True
    var changed = app.dispatch(event)
    if event.kind == WINDOW_RESIZED_KIND:
        app.rebuild_localized()
    return changed


def invoke_canvas[Child: Component & Deinitable](mut app: App[CanvasView[Child]], command: CanvasCommand) -> Bool:
    app.component.flush_content()
    var changed = True
    if command.value >= 1000:
        app.component.pending_command = command
    elif command == CanvasCommand.SEARCH:
        app.component.searching = True
        app.component.search = ""
        app.component.search_index = 0
    elif command == CanvasCommand.ENTER_CONTROLS:
        var id = app.component.state.focus
        var index = app.component.mount_index(id)
        if index >= 0:
            app.component.editor = id
            app.component.state.camera.reveal(app.component.document.world_bounds(id))
            app.rebuild_localized()
            for node in app.component.mounts[index].nodes:
                if node.focusable:
                    _ = app.runtime.set_focus(app.component.control_id(id, node.id))
                    break
    elif command == CanvasCommand.LEAVE_CONTROLS:
        app.component.editor = -1
        _ = app.runtime.set_focus(SURFACE_FOCUS_ID)
    elif command == CanvasCommand.CREATE:
        if len(app.component.mounts) == 0:
            app.component.state.status = "Mount a prototype component before creating nodes"
            changed = False
        else:
            var before = app.component.document
            var before_mounts = app.component.mounts.copy()
            var cursor = app.component.state.history.cursor
            var id = 1
            for object in app.component.document.objects:
                id = max(id, object.id + 1)
            var camera = app.component.state.camera
            var at = camera.unproject(WindowPoint(camera.viewport.x + camera.viewport.width / 2, camera.viewport.y + camera.viewport.height / 2))
            try:
                app.component.document.add(CanvasObject(id, Rect(Float32(at.x), Float32(at.y), 240, 230), String("Node ", id)))
                app.component.document.add_port(Port(id * 10, id, PortDirection.INPUT, 0, 0.5))
                app.component.document.add_port(Port(id * 10 + 1, id, PortDirection.OUTPUT, 1, 0.5))
                var prototype = app.component.mounts[0].child
                app.component.mount(id, prototype)
                app.component.state.history.record(before, app.component.document, "Create node")
                app.component.remember_content(before_mounts, cursor)
                app.component.state.select(id)
            except e:
                app.component.document = before
                app.component.mounts = before_mounts^
                app.component.state.status = String(e)
                changed = False
    elif command == CanvasCommand.GROUP or command == CanvasCommand.UNGROUP:
        changed = app.component.group_selection(command == CanvasCommand.UNGROUP)
    else:
        changed = app.component.command(command)
    app.rebuild_localized()
    return changed
