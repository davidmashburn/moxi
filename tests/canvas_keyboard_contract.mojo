"""Application profile precedence and keyboard-only canvas editing."""
from std.collections import List
from moxi import App, Rect, Event
from moxi.event import *
from moxi_canvas import *
from canvas_demo.fixtures import freeform_graph

comptime MAP_CHILD = CanvasCommand(1000)
comptime MAP_PARENT = CanvasCommand(1001)
comptime MAP_FOLD = CanvasCommand(1002)
comptime MAP_REORDER = CanvasCommand(1003)
comptime MAP_LEVEL = CanvasCommand(1004)
comptime MAP_ROOT = CanvasCommand(1005)

def require(value: Bool, message: String) raises:
    if not value:
        raise Error(message)

def key(code: Int, modifiers: Int = 0) -> Event:
    var event = Event()
    event.kind = KEY_DOWN_KIND
    event.key = code
    event.modifiers = modifiers
    return event

def retained_creation() raises:
    # Use the actual shortcut dispatcher and ordinary retained child content.
    for redo_delete in List[Bool]([False, True]):
        var app = App(freeform_graph(), Rect(0, 0, 1060, 780))
        require(dispatch_canvas(app, key(110)), "first keyboard create")
        var deleted = app.component.state.focus
        var mount = app.component.mount_index(deleted)
        app.component.mounts[mount].child.label.text = "Retained deleted content"
        require(dispatch_canvas(app, key(KEY_DELETE)), "keyboard delete")
        require(app.component.document.object_index.get(deleted, -1) < 0, "deleted node still live")
        require(app.component.mount_index(deleted) >= 0, "delete lost retained mount")
        if redo_delete:
            require(invoke_canvas(app, CanvasCommand.UNDO), "undo delete")
            require(app.component.document.object_index.get(deleted, -1) >= 0, "undo failed to restore identity")
            require(app.component.mounts[app.component.mount_index(deleted)].child.label.text == "Retained deleted content", "undo lost child content")
            require(invoke_canvas(app, CanvasCommand.REDO), "redo delete")
        require(dispatch_canvas(app, key(110)), "create after delete")
        var created = app.component.state.focus
        require(created > deleted and app.component.document.object_index.get(created, -1) >= 0, "new node reused deleted identity")
        require(invoke_canvas(app, CanvasCommand.UNDO), "undo replacement create")
        require(invoke_canvas(app, CanvasCommand.UNDO), "undo prior delete")
        require(app.component.document.object_index.get(deleted, -1) >= 0 and app.component.document.object_index.get(created, -1) < 0, "history identity crossed")
        require(app.component.mounts[app.component.mount_index(deleted)].child.label.text == "Retained deleted content", "history lost retained content")
        require(invoke_canvas(app, CanvasCommand.REDO), "redo prior delete")
        require(invoke_canvas(app, CanvasCommand.REDO), "redo replacement create")
        require(app.component.document.object_index.get(created, -1) >= 0 and app.component.document.object_index.get(deleted, -1) < 0, "redo restored wrong identity")

def main() raises:
    retained_creation()
    var canvas = freeform_graph()
    canvas.bindings.append(CanvasBinding(KEY_TAB, ShortcutModifier.NONE, MAP_CHILD, "New child"))
    canvas.bindings.append(CanvasBinding(KEY_TAB, ShortcutModifier.SHIFT, MAP_PARENT, "Insert parent"))
    canvas.bindings.append(CanvasBinding(KEY_SPACE, ShortcutModifier.NONE, MAP_FOLD, "Fold"))
    canvas.bindings.append(CanvasBinding(KEY_UP, ShortcutModifier.PRIMARY, MAP_REORDER, "Reorder"))
    canvas.bindings.append(CanvasBinding(KEY_LEFT, ShortcutModifier.PRIMARY, MAP_LEVEL, "Change level"))
    canvas.bindings.append(CanvasBinding(KEY_ESCAPE, ShortcutModifier.NONE, MAP_ROOT, "Root"))
    var app = App(canvas, Rect(0, 0, 1060, 780))
    for host in List[HostPlatform]([HostPlatform.MACOS, HostPlatform.WINDOWS, HostPlatform.LINUX]):
        require(not binding_conflict(app.component.bindings, host), "profile conflicts")
        for binding in app.component.bindings:
            _ = dispatch_canvas(app, key(binding.key, resolve_modifier(binding.modifier, host)), host)
            require(app.component.take_application_command() == binding.command, "application key preserved")
    _ = dispatch_canvas(app, key(KEY_RIGHT))
    var original = app.component.document.world_bounds(1)
    _ = dispatch_canvas(app, key(109))
    _ = dispatch_canvas(app, key(KEY_RIGHT, MOD_SHIFT))
    _ = dispatch_canvas(app, key(KEY_ESCAPE))
    require(app.component.state.session == SessionKind.IDLE and app.component.take_application_command() == CanvasCommand.NONE, "preview cancel before idle root")
    require(app.component.document.world_bounds(1).x == original.x, "cancel unchanged")
    _ = dispatch_canvas(app, key(KEY_ENTER))
    _ = dispatch_canvas(app, key(KEY_SPACE))
    require(app.component.take_application_command() == CanvasCommand.NONE, "text owns Space")
    _ = dispatch_canvas(app, key(KEY_ESCAPE))
    _ = dispatch_canvas(app, key(99))
    var source = app.component.state.source
    _ = dispatch_canvas(app, key(91))
    require(app.component.state.source != source, "keyboard source chooser")
    _ = dispatch_canvas(app, key(KEY_DOWN))
    require(app.component.state.target >= 0, "keyboard destination chooser")
    _ = dispatch_canvas(app, key(KEY_ESCAPE))
    _ = dispatch_canvas(app, key(93))
    require(app.component.state.selected_edge == 1, "keyboard edge selection")
    _ = dispatch_canvas(app, key(101))
    require(app.component.state.replacing == 1, "keyboard reconnect")
    _ = dispatch_canvas(app, key(KEY_ESCAPE))
    _ = invoke_canvas(app, CanvasCommand.SEARCH)
    var input = Event()
    input.kind = TEXT_INPUT_KIND
    input.text = "Export"
    _ = dispatch_canvas(app, input)
    _ = dispatch_canvas(app, key(KEY_ENTER))
    require(app.component.state.focus == 4, "search disconnected/offscreen object")
    print("keyboard contract PASS: application profile precedence, native Primary, text/session scopes, source/target/edge selection, object search")
