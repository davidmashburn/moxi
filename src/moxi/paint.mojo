"""Backend-neutral paint commands."""

from std.collections import List

from .geometry import Rect
from .style import Style, default_label_style
from .view import BUTTON_KIND, LABEL_KIND


comptime PANEL_KIND = 3
comptime SURFACE_KIND = 4


struct PaintCommand(ImplicitlyCopyable):
    """A text-and-bounds command consumed by a renderer."""

    var kind: Int
    var id: Int
    var slot: Int
    var text: String
    var bounds: Rect
    var style: Style

    def __init__(out self, text: String, bounds: Rect):
        self.kind = LABEL_KIND
        self.id = 0
        self.slot = 0
        self.text = text
        self.bounds = bounds
        self.style = default_label_style()

    def __init__(
        out self,
        kind: Int,
        id: Int,
        slot: Int,
        text: String,
        bounds: Rect,
        style: Style,
    ):
        self.kind = kind
        self.id = id
        self.slot = slot
        self.text = text
        self.bounds = bounds
        self.style = style


struct PaintCommands:
    """An ordered, backend-neutral command stream for one frame."""

    var commands: List[PaintCommand]

    def __init__(out self):
        self.commands = List[PaintCommand]()

    def append(mut self, command: PaintCommand):
        self.commands.append(command)

    def count(self) -> Int:
        return len(self.commands)

    def command(self, index: Int) -> PaintCommand:
        return self.commands[index]


trait Renderer:
    """A platform backend consumes commands without owning view state."""

    def begin_frame(self) raises:
        pass

    def draw(self, command: PaintCommand) raises:
        if command.kind == SURFACE_KIND:
            self.draw_surface(command)
        elif command.kind == PANEL_KIND:
            self.draw_panel(command)
        elif command.kind == LABEL_KIND:
            self.draw_label(command)
        elif command.kind == BUTTON_KIND:
            self.draw_button(command)

    def draw_surface(self, command: PaintCommand) raises:
        pass

    def draw_panel(self, command: PaintCommand) raises:
        pass

    def draw_label(self, command: PaintCommand) raises:
        pass

    def draw_button(self, command: PaintCommand) raises:
        pass
