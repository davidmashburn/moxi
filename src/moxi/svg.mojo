"""SVG scene serializer for Web-compatible previews and visual docs."""

from .scene import (
    SCENE_CLIP,
    SCENE_IMAGE,
    SCENE_LINEAR_GRADIENT,
    SCENE_LINE,
    SCENE_PATH,
    SCENE_POP_CLIP,
    SCENE_POP_LAYER,
    SCENE_PUSH_LAYER,
    SCENE_RECT,
    SCENE_ROUNDED_RECT,
    SCENE_TEXT,
    Scene,
    SceneCommand,
    SceneRenderer,
)
from .style import Color


def _svg_escape(value: String) -> String:
    """Escape text nodes so arbitrary plot labels remain valid XML."""
    var result = String("")
    for index in range(value.count_codepoints()):
        var glyph = String(value[codepoint=index:index + 1])
        if glyph == "&":
            result += "&amp;"
        elif glyph == "<":
            result += "&lt;"
        elif glyph == ">":
            result += "&gt;"
        elif glyph == chr(34):
            result += "&quot;"
        elif glyph == chr(39):
            result += "&apos;"
        else:
            result += glyph
    return result


def _svg_color(color: Color) -> String:
    return String(
        "rgba(",
        Int(color.red * 255.0),
        ",",
        Int(color.green * 255.0),
        ",",
        Int(color.blue * 255.0),
        ",",
        color.alpha,
        ")",
    )


struct SvgSceneRenderer(SceneRenderer):
    """Serialize portable scene commands to SVG without a browser dependency."""

    var width: Int
    var height: Int
    var output: String
    var frame_count: Int
    var clip_depth: Int
    var layer_depth: Int

    def __init__(out self, width: Int = 640, height: Int = 480):
        self.width = width if width > 0 else 1
        self.height = height if height > 0 else 1
        self.output = ""
        self.frame_count = 0
        self.clip_depth = 0
        self.layer_depth = 0

    def begin_scene(mut self) raises:
        self.output = String(
            "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"",
            self.width,
            "\" height=\"",
            self.height,
            "\" viewBox=\"0 0 ",
            self.width,
            " ",
            self.height,
            "\">",
        )
        self.clip_depth = 0
        self.layer_depth = 0

    def draw_scene_command(mut self, command: SceneCommand) raises:
        if command.kind == SCENE_RECT or command.kind == SCENE_LINEAR_GRADIENT:
            self.output += String(
                "<rect x=\"",
                command.bounds.x,
                "\" y=\"",
                command.bounds.y,
                "\" width=\"",
                command.bounds.width,
                "\" height=\"",
                command.bounds.height,
                "\" fill=\"",
                _svg_color(command.fill),
                "\" opacity=\"",
                command.opacity,
                "\"/> ",
            )
        elif command.kind == SCENE_ROUNDED_RECT:
            self.output += String(
                "<rect x=\"",
                command.bounds.x,
                "\" y=\"",
                command.bounds.y,
                "\" width=\"",
                command.bounds.width,
                "\" height=\"",
                command.bounds.height,
                "\" rx=\"",
                command.corner_radius,
                "\" fill=\"",
                _svg_color(command.fill),
                "\" opacity=\"",
                command.opacity,
                "\"/> ",
            )
        elif command.kind == SCENE_LINE:
            self.output += String(
                "<line x1=\"",
                command.point_start.x,
                "\" y1=\"",
                command.point_start.y,
                "\" x2=\"",
                command.point_end.x,
                "\" y2=\"",
                command.point_end.y,
                "\" stroke=\"",
                _svg_color(command.stroke),
                "\" stroke-width=\"",
                command.stroke_width,
                "\" opacity=\"",
                command.opacity,
                "\"/> ",
            )
        elif command.kind == SCENE_TEXT:
            self.output += String(
                "<text x=\"",
                command.bounds.x,
                "\" y=\"",
                command.bounds.y + command.bounds.height,
                "\" fill=\"",
                _svg_color(command.fill),
                "\" opacity=\"",
                command.opacity,
                "\">",
                _svg_escape(command.text),
                "</text>",
            )
        elif command.kind == SCENE_PATH:
            self.output += String(
                "<path d=\"",
                command.path_data,
                "\" fill=\"",
                _svg_color(command.fill),
                "\" fill-rule=\"evenodd\" clip-rule=\"evenodd\" stroke=\"",
                _svg_color(command.stroke),
                "\" stroke-width=\"",
                command.stroke_width,
                "\" opacity=\"",
                command.opacity,
                "\"/> ",
            )
        elif command.kind == SCENE_IMAGE:
            # Keep an observable placeholder until image resources have a
            # shared serialization contract.
            self.output += String(
                "<rect x=\"",
                command.bounds.x,
                "\" y=\"",
                command.bounds.y,
                "\" width=\"",
                command.bounds.width,
                "\" height=\"",
                command.bounds.height,
                "\" fill=\"",
                _svg_color(command.fill),
                "\" opacity=\"",
                command.opacity * 0.35,
                "\"/> ",
            )
        elif command.kind == SCENE_CLIP:
            self.clip_depth += 1
            self.output += String(
                "<clipPath id=\"moxi-clip-",
                self.clip_depth,
                "\"><rect x=\"",
                command.bounds.x,
                "\" y=\"",
                command.bounds.y,
                "\" width=\"",
                command.bounds.width,
                "\" height=\"",
                command.bounds.height,
                "\"/></clipPath><g clip-path=\"url(#moxi-clip-",
                self.clip_depth,
                ")\">")
        elif command.kind == SCENE_POP_CLIP:
            if self.clip_depth > 0:
                self.output += "</g>"
                self.clip_depth -= 1
        elif command.kind == SCENE_PUSH_LAYER:
            self.layer_depth += 1
            self.output += String("<g opacity=\"", command.opacity, "\">")
        elif command.kind == SCENE_POP_LAYER:
            if self.layer_depth > 0:
                self.output += "</g>"
                self.layer_depth -= 1

    def end_scene(mut self) raises:
        self.output += "</svg>"
        self.frame_count += 1

    def render_scene(mut self, scene: Scene) raises:
        self.begin_scene()
        for index in range(scene.count()):
            self.draw_scene_command(scene.command(index))
        self.end_scene()

    def markup(self) -> String:
        return self.output
