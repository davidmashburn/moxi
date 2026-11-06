"""Remappable editor-scoped command table; palette identity is the same as keys."""
from std.collections import List
from moxi.event import MOD_COMMAND, MOD_SHIFT, KEY_TAB, KEY_SPACE, KEY_ENTER

struct MathCommand(ImplicitlyCopyable):
    var value: Int
    comptime FRACTION = Self(1)
    comptime ROOT = Self(2)
    comptime SUPER = Self(3)
    comptime SUB = Self(4)
    comptime OVER = Self(5)
    comptime UNDER = Self(6)
    comptime COMPLEMENT = Self(7)
    comptime EXIT = Self(8)
    comptime EXPAND_SELECTION = Self(9)
    comptime MATRIX = Self(10)
    comptime ADD_ROW = Self(11)
    comptime ADD_COLUMN = Self(12)
    comptime REMOVE_ROW = Self(13)
    comptime REMOVE_COLUMN = Self(14)
    comptime GROUP = Self(15)
    comptime FUNCTION = Self(16)
    comptime SUM = Self(17)
    comptime INTEGRAL = Self(18)
    comptime UNWRAP = Self(19)
    comptime UNDO = Self(20)
    comptime REDO = Self(21)
    comptime TEXT = Self(22)
    comptime NEXT_HOLE = Self(23)
    comptime PREVIOUS_HOLE = Self(24)
    def __init__(out self, value: Int):
        self.value = value
    def __eq__(self, other: Self) -> Bool:
        return self.value == other.value

struct MathBinding(ImplicitlyCopyable):
    var key: Int
    var modifiers: Int
    var command: MathCommand
    var hint: String
    def __init__(out self, key: Int, modifiers: Int, command: MathCommand, hint: String):
        self.key=key
        self.modifiers=modifiers
        self.command=command
        self.hint=hint

struct MathKeymap(ImplicitlyCopyable):
    var bindings: List[MathBinding]
    def __init__(out self):
        self.bindings=List[MathBinding]()
        self.bindings.append(MathBinding(47,MOD_COMMAND,MathCommand.FRACTION,"⌘/"))
        self.bindings.append(MathBinding(54,MOD_COMMAND,MathCommand.SUPER,"⌘6"))
        self.bindings.append(MathBinding(94,MOD_COMMAND,MathCommand.SUPER,"⌘^"))
        self.bindings.append(MathBinding(45,MOD_COMMAND,MathCommand.SUB,"⌘-"))
        self.bindings.append(MathBinding(95,MOD_COMMAND,MathCommand.SUB,"⌘_"))
        self.bindings.append(MathBinding(50,MOD_COMMAND,MathCommand.ROOT,"⌘2"))
        self.bindings.append(MathBinding(64,MOD_COMMAND,MathCommand.ROOT,"⌘@"))
        self.bindings.append(MathBinding(53,MOD_COMMAND,MathCommand.COMPLEMENT,"⌘5"))
        self.bindings.append(MathBinding(37,MOD_COMMAND,MathCommand.COMPLEMENT,"⌘%"))
        self.bindings.append(MathBinding(55,MOD_COMMAND,MathCommand.OVER,"⌘7"))
        self.bindings.append(MathBinding(38,MOD_COMMAND,MathCommand.OVER,"⌘&"))
        self.bindings.append(MathBinding(44,MOD_COMMAND | MOD_SHIFT,MathCommand.UNDER,"⇧⌘,"))
        self.bindings.append(MathBinding(60,MOD_COMMAND,MathCommand.UNDER,"⌘<"))
        self.bindings.append(MathBinding(KEY_SPACE,MOD_COMMAND,MathCommand.EXIT,"⌘Space"))
        self.bindings.append(MathBinding(46,MOD_COMMAND,MathCommand.EXPAND_SELECTION,"⌘."))
        self.bindings.append(MathBinding(KEY_ENTER,MOD_COMMAND,MathCommand.ADD_ROW,"⌘Return"))
        self.bindings.append(MathBinding(44,MOD_COMMAND,MathCommand.ADD_COLUMN,"⌘,"))
        self.bindings.append(MathBinding(122,MOD_COMMAND | MOD_SHIFT,MathCommand.REDO,"⇧⌘Z"))
        self.bindings.append(MathBinding(122,MOD_COMMAND,MathCommand.UNDO,"⌘Z"))
    def __init__(out self, *, copy: Self):
        self.bindings=copy.bindings.copy()
    def bind(mut self, command: MathCommand, key: Int, modifiers: Int, hint: String):
        """Replace all aliases for a command; latest binding wins collisions."""
        var kept=List[MathBinding]()
        kept.append(MathBinding(key,modifiers,command,hint))
        for binding in self.bindings:
            if binding.command.value!=command.value:
                kept.append(binding)
        self.bindings=kept^
    def resolve(self, key: Int, modifiers: Int) -> MathCommand:
        if key==KEY_TAB:
            return MathCommand.PREVIOUS_HOLE if modifiers & MOD_SHIFT else MathCommand.NEXT_HOLE
        for binding in self.bindings:
            if key==binding.key and modifiers==binding.modifiers:
                return binding.command
        # Native shifted punctuation can retain the shift modifier.
        if key==94 or key==95 or key==64 or key==37 or key==38 or key==60:
            for binding in self.bindings:
                if key==binding.key and (modifiers & ~MOD_SHIFT)==binding.modifiers:
                    return binding.command
        return MathCommand(0)
    def hint(self, command: MathCommand) -> String:
        for binding in self.bindings:
            if binding.command==command:
                return binding.hint
        return ""

def math_binding(key: Int, modifiers: Int, primary: Int = MOD_COMMAND) -> MathCommand:
    var map=MathKeymap()
    if primary!=MOD_COMMAND and modifiers & primary:
        return map.resolve(key,(modifiers & ~primary) | MOD_COMMAND)
    return map.resolve(key,modifiers)
