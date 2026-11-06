"""Scoped logical bindings shared by native input, hints and replay."""
from std.collections import List
from moxi.event import MOD_COMMAND, MOD_CONTROL, MOD_SHIFT, MOD_OPTION, KEY_ESCAPE, KEY_ENTER, KEY_DELETE, KEY_BACKSPACE
from .interaction import CanvasCommand


@fieldwise_init
struct HostPlatform(Equatable, ImplicitlyCopyable):
    var value: Int
    comptime MACOS = Self(0)
    comptime WINDOWS = Self(1)
    comptime LINUX = Self(2)


@fieldwise_init
struct ShortcutModifier(Equatable, ImplicitlyCopyable):
    var value: Int
    comptime NONE = Self(0)
    comptime PRIMARY = Self(1)
    comptime PRIMARY_SHIFT = Self(2)
    comptime CONTROL = Self(3)
    comptime COMMAND = Self(4)
    comptime SHIFT = Self(5)
    comptime PRIMARY_OPTION = Self(6)
    comptime OPTION = Self(7)


def resolve_modifier(modifier: ShortcutModifier, host: HostPlatform) -> Int:
    var primary = MOD_COMMAND if host == HostPlatform.MACOS else MOD_CONTROL
    if modifier == ShortcutModifier.PRIMARY:
        return primary
    if modifier == ShortcutModifier.PRIMARY_SHIFT:
        return primary | MOD_SHIFT
    if modifier == ShortcutModifier.CONTROL:
        return MOD_CONTROL
    if modifier == ShortcutModifier.COMMAND:
        return MOD_COMMAND
    if modifier == ShortcutModifier.SHIFT:
        return MOD_SHIFT
    if modifier == ShortcutModifier.PRIMARY_OPTION:
        return primary | MOD_OPTION
    if modifier == ShortcutModifier.OPTION:
        return MOD_OPTION
    return 0


@fieldwise_init
struct CanvasBinding(ImplicitlyCopyable):
    var key: Int
    var modifier: ShortcutModifier
    var command: CanvasCommand
    var title: String

    def hint(self, host: HostPlatform) -> String:
        var prefix = ""
        if self.modifier == ShortcutModifier.PRIMARY or self.modifier == ShortcutModifier.PRIMARY_SHIFT:
            prefix = "Cmd+" if host == HostPlatform.MACOS else "Ctrl+"
        if self.modifier == ShortcutModifier.PRIMARY_SHIFT:
            prefix += "Shift+"
        if self.modifier == ShortcutModifier.CONTROL:
            prefix = "Ctrl+"
        elif self.modifier == ShortcutModifier.COMMAND:
            prefix = "Cmd+"
        return prefix + self.title


def canvas_bindings(host: HostPlatform) -> List[CanvasBinding]:
    var result = List[CanvasBinding]()
    result.append(CanvasBinding(93, ShortcutModifier.NONE, CanvasCommand.NEXT_EDGE, "]"))
    result.append(CanvasBinding(91, ShortcutModifier.NONE, CanvasCommand.NEXT_SOURCE, "["))
    result.append(CanvasBinding(109, ShortcutModifier.NONE, CanvasCommand.MOVE, "M"))
    result.append(CanvasBinding(114, ShortcutModifier.NONE, CanvasCommand.RESIZE, "R"))
    result.append(CanvasBinding(99, ShortcutModifier.NONE, CanvasCommand.CONNECT, "C"))
    result.append(CanvasBinding(101, ShortcutModifier.NONE, CanvasCommand.RECONNECT, "E"))
    result.append(CanvasBinding(102, ShortcutModifier.NONE, CanvasCommand.FIT_ALL, "F"))
    result.append(CanvasBinding(110, ShortcutModifier.NONE, CanvasCommand.CREATE, "N"))
    result.append(CanvasBinding(103, ShortcutModifier.NONE, CanvasCommand.GROUP, "G"))
    result.append(CanvasBinding(117, ShortcutModifier.NONE, CanvasCommand.UNGROUP, "U"))
    result.append(CanvasBinding(47, ShortcutModifier.NONE, CanvasCommand.SEARCH, "/"))
    result.append(CanvasBinding(43, ShortcutModifier.NONE, CanvasCommand.ZOOM_IN, "+"))
    result.append(CanvasBinding(61, ShortcutModifier.NONE, CanvasCommand.ZOOM_IN, "="))
    result.append(CanvasBinding(45, ShortcutModifier.NONE, CanvasCommand.ZOOM_OUT, "-"))
    result.append(CanvasBinding(48, ShortcutModifier.NONE, CanvasCommand.RESET_ZOOM, "0"))
    result.append(CanvasBinding(97, ShortcutModifier.PRIMARY, CanvasCommand.SELECT_ALL, "A"))
    result.append(CanvasBinding(122, ShortcutModifier.PRIMARY, CanvasCommand.UNDO, "Z"))
    result.append(CanvasBinding(122, ShortcutModifier.PRIMARY_SHIFT, CanvasCommand.REDO, "Z"))
    if host != HostPlatform.MACOS:
        result.append(CanvasBinding(121, ShortcutModifier.PRIMARY, CanvasCommand.REDO, "Y"))
    result.append(CanvasBinding(KEY_ESCAPE, ShortcutModifier.NONE, CanvasCommand.CANCEL, "Escape"))
    result.append(CanvasBinding(KEY_DELETE, ShortcutModifier.NONE, CanvasCommand.DELETE, "Delete"))
    result.append(CanvasBinding(KEY_BACKSPACE, ShortcutModifier.NONE, CanvasCommand.DELETE, "Backspace"))
    return result^


def binding_conflict(bindings: List[CanvasBinding], host: HostPlatform) -> Bool:
    for i in range(len(bindings)):
        for j in range(i):
            if bindings[i].key == bindings[j].key and resolve_modifier(bindings[i].modifier, host) == resolve_modifier(bindings[j].modifier, host):
                return True
    return False
