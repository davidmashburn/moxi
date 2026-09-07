"""Typed, renderer-neutral path operations for the Scene IR.

The legacy ``SceneCommand.path_data`` field remains for compatibility with
serialized scenes. New producers should use ``ScenePath``: it records the
operation kind and points as values, computes conservative bounds, and can be
replayed directly by Canvas or serialized by SVG/Metal without guessing at a
caller-owned grammar.
"""

from .geometry import Point, Rect


comptime SCENE_PATH_MOVE_TO = 1
comptime SCENE_PATH_LINE_TO = 2
comptime SCENE_PATH_QUAD_TO = 3
comptime SCENE_PATH_CUBIC_TO = 4
comptime SCENE_PATH_CLOSE = 5


struct ScenePathCommand(ImplicitlyCopyable):
    var kind: Int
    var point1: Point
    var point2: Point
    var point3: Point

    def __init__(
        out self,
        kind: Int,
        point1: Point = Point(0.0, 0.0),
        point2: Point = Point(0.0, 0.0),
        point3: Point = Point(0.0, 0.0),
    ):
        self.kind = kind
        self.point1 = point1
        self.point2 = point2
        self.point3 = point3


struct ScenePath(ImplicitlyCopyable):
    """A bounded typed path value suitable for a SceneCommand.

    The inline capacity is deliberate: scene paths are small retained values,
    and a bounded command count keeps the renderer boundary allocation-free.
    Longer paths should be split into multiple commands.
    """

    comptime MAX_COMMANDS = 16

    var command_0: ScenePathCommand
    var command_1: ScenePathCommand
    var command_2: ScenePathCommand
    var command_3: ScenePathCommand
    var command_4: ScenePathCommand
    var command_5: ScenePathCommand
    var command_6: ScenePathCommand
    var command_7: ScenePathCommand
    var command_8: ScenePathCommand
    var command_9: ScenePathCommand
    var command_10: ScenePathCommand
    var command_11: ScenePathCommand
    var command_12: ScenePathCommand
    var command_13: ScenePathCommand
    var command_14: ScenePathCommand
    var command_15: ScenePathCommand
    var command_count: Int
    var bounds: Rect
    var current: Point
    var subpath_start: Point
    var has_current: Bool
    var valid: Bool

    def __init__(out self):
        var empty = ScenePathCommand(SCENE_PATH_CLOSE)
        self.command_0 = empty
        self.command_1 = empty
        self.command_2 = empty
        self.command_3 = empty
        self.command_4 = empty
        self.command_5 = empty
        self.command_6 = empty
        self.command_7 = empty
        self.command_8 = empty
        self.command_9 = empty
        self.command_10 = empty
        self.command_11 = empty
        self.command_12 = empty
        self.command_13 = empty
        self.command_14 = empty
        self.command_15 = empty
        self.command_count = 0
        self.bounds = Rect(0.0, 0.0, 0.0, 0.0)
        self.current = Point(0.0, 0.0)
        self.subpath_start = Point(0.0, 0.0)
        self.has_current = False
        self.valid = True

    def _store(mut self, command: ScenePathCommand) -> Bool:
        if self.command_count >= Self.MAX_COMMANDS:
            self.valid = False
            return False
        if self.command_count == 0:
            self.command_0 = command
        elif self.command_count == 1:
            self.command_1 = command
        elif self.command_count == 2:
            self.command_2 = command
        elif self.command_count == 3:
            self.command_3 = command
        elif self.command_count == 4:
            self.command_4 = command
        elif self.command_count == 5:
            self.command_5 = command
        elif self.command_count == 6:
            self.command_6 = command
        elif self.command_count == 7:
            self.command_7 = command
        elif self.command_count == 8:
            self.command_8 = command
        elif self.command_count == 9:
            self.command_9 = command
        elif self.command_count == 10:
            self.command_10 = command
        elif self.command_count == 11:
            self.command_11 = command
        elif self.command_count == 12:
            self.command_12 = command
        elif self.command_count == 13:
            self.command_13 = command
        elif self.command_count == 14:
            self.command_14 = command
        else:
            self.command_15 = command
        self.command_count += 1
        return True

    def _include(mut self, point: Point):
        if self.command_count == 1:
            self.bounds = Rect(point.x, point.y, 0.0, 0.0)
            return
        var left = self.bounds.x
        var top = self.bounds.y
        var right = self.bounds.x + self.bounds.width
        var bottom = self.bounds.y + self.bounds.height
        if point.x < left:
            left = point.x
        if point.y < top:
            top = point.y
        if point.x > right:
            right = point.x
        if point.y > bottom:
            bottom = point.y
        self.bounds = Rect(left, top, right - left, bottom - top)

    def move_to(mut self, point: Point):
        if self._store(ScenePathCommand(SCENE_PATH_MOVE_TO, point)):
            self.current = point
            self.subpath_start = point
            self.has_current = True
            self._include(point)

    def line_to(mut self, point: Point):
        if not self.has_current:
            self.valid = False
            return
        if self._store(ScenePathCommand(SCENE_PATH_LINE_TO, point)):
            self.current = point
            self._include(point)

    def quad_to(mut self, control: Point, point: Point):
        if not self.has_current:
            self.valid = False
            return
        if self._store(ScenePathCommand(SCENE_PATH_QUAD_TO, control, point)):
            self.current = point
            self._include(control)
            self._include(point)

    def cubic_to(mut self, control1: Point, control2: Point, point: Point):
        if not self.has_current:
            self.valid = False
            return
        if self._store(ScenePathCommand(SCENE_PATH_CUBIC_TO, control1, control2, point)):
            self.current = point
            self._include(control1)
            self._include(control2)
            self._include(point)

    def close(mut self):
        if not self.has_current:
            self.valid = False
            return
        _ = self._store(ScenePathCommand(SCENE_PATH_CLOSE))
        self.current = self.subpath_start

    def count(self) -> Int:
        return self.command_count

    def command(self, index: Int) -> ScenePathCommand:
        if index == 0:
            return self.command_0
        if index == 1:
            return self.command_1
        if index == 2:
            return self.command_2
        if index == 3:
            return self.command_3
        if index == 4:
            return self.command_4
        if index == 5:
            return self.command_5
        if index == 6:
            return self.command_6
        if index == 7:
            return self.command_7
        if index == 8:
            return self.command_8
        if index == 9:
            return self.command_9
        if index == 10:
            return self.command_10
        if index == 11:
            return self.command_11
        if index == 12:
            return self.command_12
        if index == 13:
            return self.command_13
        if index == 14:
            return self.command_14
        if index == 15:
            return self.command_15
        return ScenePathCommand(SCENE_PATH_CLOSE)

    def is_valid(self) -> Bool:
        return self.valid and self.command_count > 0 and self.has_current

    def svg_data(self) -> String:
        var result = String("")
        for index in range(self.command_count):
            var command = self.command(index)
            if index > 0:
                result += " "
            if command.kind == SCENE_PATH_MOVE_TO:
                result += String("M ", command.point1.x, " ", command.point1.y)
            elif command.kind == SCENE_PATH_LINE_TO:
                result += String("L ", command.point1.x, " ", command.point1.y)
            elif command.kind == SCENE_PATH_QUAD_TO:
                result += String("Q ", command.point1.x, " ", command.point1.y, " ", command.point2.x, " ", command.point2.y)
            elif command.kind == SCENE_PATH_CUBIC_TO:
                result += String("C ", command.point1.x, " ", command.point1.y, " ", command.point2.x, " ", command.point2.y, " ", command.point3.x, " ", command.point3.y)
            elif command.kind == SCENE_PATH_CLOSE:
                result += "Z"
        return result
