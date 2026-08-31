"""A small backend-neutral scene IR for shapes, layers, text, and images."""

from std.collections import List

from .geometry import Point, Rect, Transform
from .resources import RESOURCE_NONE
from .style import Color


comptime SCENE_RECT = 1
comptime SCENE_ROUNDED_RECT = 2
comptime SCENE_LINE = 3
comptime SCENE_TEXT = 4
comptime SCENE_IMAGE = 5
comptime SCENE_CLIP = 6
comptime SCENE_PUSH_LAYER = 7
comptime SCENE_POP_LAYER = 8
comptime SCENE_PATH = 9
comptime SCENE_LINEAR_GRADIENT = 10
comptime SCENE_TRANSFORM = 11
comptime SCENE_POP_CLIP = 12
comptime SCENE_RESET_TRANSFORM = 13


struct SceneCommand(ImplicitlyCopyable):
    """One immutable drawing operation in scene coordinates."""

    var kind: Int
    var id: Int
    var bounds: Rect
    var fill: Color
    var stroke: Color
    var stroke_width: Float32
    var corner_radius: Float32
    var opacity: Float32
    var text: String
    var resource_id: Int
    var point_start: Point
    var point_end: Point
    var path_data: String
    var gradient_start: Point
    var gradient_end: Point
    var gradient_start_color: Color
    var gradient_end_color: Color
    var transform: Transform

    def __init__(out self, kind: Int, id: Int, bounds: Rect, fill: Color):
        self.kind = kind
        self.id = id
        self.bounds = bounds
        self.fill = fill
        self.stroke = Color(0.0, 0.0, 0.0, 0.0)
        self.stroke_width = 0.0
        self.corner_radius = 0.0
        self.opacity = 1.0
        self.text = ""
        self.resource_id = RESOURCE_NONE
        self.point_start = Point(0.0, 0.0)
        self.point_end = Point(0.0, 0.0)
        self.path_data = ""
        self.gradient_start = Point(0.0, 0.0)
        self.gradient_end = Point(0.0, 0.0)
        self.gradient_start_color = fill
        self.gradient_end_color = fill
        self.transform = Transform()

    def set_stroke(mut self, color: Color, width: Float32):
        """Set a stroke used by line and outlined-shape commands."""
        self.stroke = color
        self.stroke_width = width if width > 0.0 else 0.0

    def set_corner_radius(mut self, radius: Float32):
        """Set a rounded-rectangle corner radius."""
        self.corner_radius = radius if radius > 0.0 else 0.0

    def set_opacity(mut self, opacity: Float32):
        """Clamp the command opacity to the unit interval."""
        var value = opacity
        if value < 0.0:
            value = 0.0
        if value > 1.0:
            value = 1.0
        self.opacity = value

    def set_text(mut self, text: String):
        """Attach text content to a text command."""
        self.text = text

    def set_resource(mut self, resource_id: Int):
        """Attach a resource handle to an image command."""
        self.resource_id = resource_id

    def set_line(mut self, start: Point, end: Point):
        """Set line endpoints for a line command."""
        self.point_start = start
        self.point_end = end

    def set_path(mut self, path_data: String):
        """Attach an SVG-style path description.

        ``M`` starts a subpath and ``Z`` closes it. Native Metal fills
        compound paths with a bounded even-odd tessellator; simple polygons
        take a faster path. Renderers may reject malformed or overlarge input
        rather than allocating without a limit.
        """
        self.path_data = path_data

    def set_gradient(
        mut self,
        start: Point,
        end: Point,
        start_color: Color,
        end_color: Color,
    ):
        """Attach linear-gradient geometry and endpoint colors."""
        self.gradient_start = start
        self.gradient_end = end
        self.gradient_start_color = start_color
        self.gradient_end_color = end_color

    def set_transform(mut self, transform: Transform):
        """Attach the transform active for this command."""
        self.transform = transform


struct Scene:
    """Ordered scene operations independent of a window or graphics API."""

    var commands: List[SceneCommand]

    def __init__(out self):
        self.commands = List[SceneCommand]()

    def append(mut self, command: SceneCommand):
        """Append an already configured scene operation."""
        self.commands.append(command)

    def append_rect(mut self, id: Int, bounds: Rect, fill: Color):
        """Append a filled rectangle."""
        self.commands.append(SceneCommand(SCENE_RECT, id, bounds, fill))

    def append_rounded_rect(
        mut self,
        id: Int,
        bounds: Rect,
        fill: Color,
        radius: Float32,
    ):
        """Append a filled rounded rectangle."""
        var command = SceneCommand(SCENE_ROUNDED_RECT, id, bounds, fill)
        command.set_corner_radius(radius)
        self.commands.append(command)

    def append_line(
        mut self,
        id: Int,
        start: Point,
        end: Point,
        color: Color,
        width: Float32,
    ):
        """Append a stroked line."""
        var command = SceneCommand(
            SCENE_LINE,
            id,
            Rect(0.0, 0.0, 0.0, 0.0),
            Color(0.0, 0.0, 0.0, 0.0),
        )
        command.set_stroke(color, width)
        command.set_line(start, end)
        self.commands.append(command)

    def append_text(
        mut self,
        id: Int,
        text: String,
        bounds: Rect,
        color: Color,
    ):
        """Append a text operation without prescribing a text engine."""
        var command = SceneCommand(SCENE_TEXT, id, bounds, color)
        command.set_text(text)
        self.commands.append(command)

    def append_image(
        mut self,
        id: Int,
        resource_id: Int,
        bounds: Rect,
    ):
        """Append an image operation referencing a resource handle."""
        var command = SceneCommand(
            SCENE_IMAGE,
            id,
            bounds,
            Color(1.0, 1.0, 1.0, 1.0),
        )
        command.set_resource(resource_id)
        self.commands.append(command)

    def append_path(
        mut self,
        id: Int,
        path_data: String,
        bounds: Rect,
        fill: Color,
        stroke: Color,
        stroke_width: Float32,
    ):
        """Append a path using the shared SVG-style/even-odd fill contract."""
        var command = SceneCommand(SCENE_PATH, id, bounds, fill)
        command.set_path(path_data)
        command.set_stroke(stroke, stroke_width)
        self.commands.append(command)

    def append_linear_gradient(
        mut self,
        id: Int,
        bounds: Rect,
        start: Point,
        end: Point,
        start_color: Color,
        end_color: Color,
    ):
        """Append a linear gradient operation."""
        var command = SceneCommand(SCENE_LINEAR_GRADIENT, id, bounds, start_color)
        command.set_gradient(start, end, start_color, end_color)
        self.commands.append(command)

    def append_transform(mut self, id: Int, transform: Transform):
        """Append a transform scope marker."""
        var command = SceneCommand(
            SCENE_TRANSFORM,
            id,
            Rect(0.0, 0.0, 0.0, 0.0),
            Color(0.0, 0.0, 0.0, 0.0),
        )
        command.set_transform(transform)
        self.commands.append(command)

    def reset_transform(mut self, id: Int = 0):
        """Append a marker that restores the identity transform."""
        self.commands.append(
            SceneCommand(
                SCENE_RESET_TRANSFORM,
                id,
                Rect(0.0, 0.0, 0.0, 0.0),
                Color(0.0, 0.0, 0.0, 0.0),
            )
        )

    def push_clip(mut self, id: Int, bounds: Rect):
        """Append a clip scope marker."""
        self.commands.append(
            SceneCommand(
                SCENE_CLIP,
                id,
                bounds,
                Color(0.0, 0.0, 0.0, 0.0),
            )
        )

    def pop_clip(mut self, id: Int = 0):
        """Append a clip scope close marker."""
        self.commands.append(
            SceneCommand(
                SCENE_POP_CLIP,
                id,
                Rect(0.0, 0.0, 0.0, 0.0),
                Color(0.0, 0.0, 0.0, 0.0),
            )
        )

    def push_layer(mut self, id: Int, bounds: Rect, opacity: Float32 = 1.0):
        """Append a compositing layer marker."""
        var command = SceneCommand(
            SCENE_PUSH_LAYER,
            id,
            bounds,
            Color(0.0, 0.0, 0.0, 0.0),
        )
        command.set_opacity(opacity)
        self.commands.append(command)

    def pop_layer(mut self, id: Int = 0):
        """Append a layer close marker."""
        self.commands.append(
            SceneCommand(
                SCENE_POP_LAYER,
                id,
                Rect(0.0, 0.0, 0.0, 0.0),
                Color(0.0, 0.0, 0.0, 0.0),
            )
        )

    def count(self) -> Int:
        return len(self.commands)

    def command(self, index: Int) -> SceneCommand:
        return self.commands[index]


trait SceneRenderer:
    """Renderer boundary for the richer scene IR."""

    def begin_scene(mut self) raises:
        pass

    def draw_scene_command(mut self, command: SceneCommand) raises:
        pass

    def end_scene(mut self) raises:
        pass

    def render_scene(mut self, scene: Scene) raises:
        """Submit an ordered scene to a platform implementation."""
        self.begin_scene()
        for index in range(scene.count()):
            self.draw_scene_command(scene.command(index))
        self.end_scene()


struct SceneRecorder(SceneRenderer):
    """Deterministic scene renderer used by tests and backend adapters."""

    var commands: List[SceneCommand]
    var frame_count: Int

    def __init__(out self):
        self.commands = List[SceneCommand]()
        self.frame_count = 0

    def begin_scene(mut self) raises:
        self.commands = List[SceneCommand]()

    def draw_scene_command(mut self, command: SceneCommand) raises:
        self.commands.append(command)

    def end_scene(mut self) raises:
        self.frame_count += 1

    def count(self) -> Int:
        return len(self.commands)

    def command(self, index: Int) -> SceneCommand:
        return self.commands[index]
