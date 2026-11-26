"""Export identical Scene inputs to the existing backends and the Cairo probe."""
from moxi import (
    CanvasSceneRenderer,
    Color,
    Point,
    RasterImage,
    Rect,
    Scene,
    ScenePath,
    SoftwareSceneRenderer,
    SvgSceneRenderer,
    Transform,
    canonical_canvas_scene_fixtures,
    test_check,
)
from moxi.scene import *
from moxi_plot.fixtures import make_canvas_scene


def color(c: Color) -> String:
    return String(c.red, " ", c.green, " ", c.blue, " ", c.alpha)


def point(p: Point) -> String:
    return String(p.x, " ", p.y)


def encode(c: SceneCommand) raises -> String:
    var b = c.bounds
    var rect = String(b.x, " ", b.y, " ", b.width, " ", b.height)
    if c.kind == SCENE_RECT or c.kind == SCENE_ROUNDED_RECT:
        return String("rect ", rect, " ", c.corner_radius, " ", color(c.fill))
    if c.kind == SCENE_CLIP:
        return String("clip ", rect)
    if c.kind == SCENE_POP_CLIP:
        return "unclip"
    if c.kind == SCENE_PUSH_LAYER and not c.offscreen:
        return String("layer ", c.opacity)
    if c.kind == SCENE_POP_LAYER:
        return "endlayer"
    if c.kind == SCENE_LINE:
        return String(
            "line ",
            point(c.point_start),
            " ",
            point(c.point_end),
            " ",
            c.stroke_width,
            " ",
            color(c.stroke),
        )
    if c.kind == SCENE_LINEAR_GRADIENT:
        return String(
            "gradient ",
            rect,
            " ",
            point(c.gradient_start),
            " ",
            point(c.gradient_end),
            " ",
            color(c.gradient_start_color),
            " ",
            color(c.gradient_end_color),
        )
    if c.kind == SCENE_TRANSFORM:
        var t = c.transform
        return String(
            "transform ",
            t.m11,
            " ",
            t.m12,
            " ",
            t.m21,
            " ",
            t.m22,
            " ",
            t.tx,
            " ",
            t.ty,
        )
    if c.kind == SCENE_RESET_TRANSFORM:
        return "reset"
    if c.kind == SCENE_PATH and c.has_typed_path:
        return String(
            "path ",
            color(c.fill),
            " ",
            color(c.stroke),
            " ",
            c.stroke_width,
            " ",
            c.typed_path.svg_data(),
        )
    if c.kind == SCENE_TEXT and not c.has_text_style:
        test_check(c.text.find("\n") < 0)
        return String("text ", rect, " ", color(c.fill), " ", c.text)
    if c.kind == SCENE_BITMAP:
        var result = String(
            "bitmap ", rect, " ", c.raster.width, " ", c.raster.height
        )
        for i in range(len(c.raster.pixels)):
            result += String(" ", Int(c.raster.pixels[i]))
        return result
    if c.kind == SCENE_IMAGE:
        return String("missing-resource ", rect, " ", c.resource_id)
    raise Error(String("Unsupported Scene command ", c.kind))


def export_scene(name: String, scene: Scene, w: Int, h: Int, bg: Color) raises:
    var software = SoftwareSceneRenderer(w, h, bg)
    var canvas = CanvasSceneRenderer(w, h, bg)
    var svg = SvgSceneRenderer(w, h)
    software.render_scene(scene)
    canvas.render_scene(scene)
    svg.render_scene(scene)
    test_check(canvas.error_count() == 0)
    canvas.write_png(name + "-canvas.png")
    with open(name + "-software.ppm", "w") as f:
        f.write(software.ppm())
    with open(name + ".svg", "w") as f:
        f.write(svg.markup())
    with open(name + ".scene", "w") as f:
        f.write(String(w, " ", h, " ", color(bg), "\n"))
        for i in range(scene.count()):
            var c = scene.command(i)
            var alpha = c.opacity
            if c.kind == SCENE_PUSH_LAYER:
                alpha = 1.0
            f.write(String(alpha, " ", encode(c), "\n"))
    print(
        name,
        scene.count(),
        canvas.fallback_count,
        software.checksum(),
        canvas.checksum(),
    )


def main() raises:
    var fixtures = canonical_canvas_scene_fixtures()
    for fixture in fixtures:
        export_scene(
            fixture.name,
            make_canvas_scene(fixture.id),
            fixture.width,
            fixture.height,
            fixture.background,
        )
    var scene = Scene()
    var white = Color(1, 1, 1, 1)
    var ink = Color(0, 0, 0, 1)
    scene.append_rect(1, Rect(0, 0, 120, 24), white)
    var path = ScenePath()
    path.move_to(Point(2, 2))
    path.line_to(Point(20, 20))
    path.line_to(Point(2, 20))
    path.close()
    scene.append_typed_path(2, path, ink, ink, 0)
    scene.push_clip(3, Rect(26, 4, 9, 12))
    scene.append_rect(4, Rect(24, 0, 20, 20), ink)
    scene.pop_clip()
    scene.append_transform(5, Transform().translated(12, 0))
    scene.append_rect(6, Rect(38, 4, 10, 12), ink)
    scene.reset_transform()
    scene.append_text(7, "A", Rect(65, 2, 14, 16), ink)
    var raster = RasterImage(2, 1)
    raster.pixels[0] = 255
    raster.pixels[3] = 255
    raster.pixels[6] = 255
    raster.pixels[7] = 255
    scene.append_bitmap(8, Rect(84, 4, 16, 12), raster)
    scene.append_image(9, 17, Rect(104, 4, 12, 12))
    export_scene("feature-cells", scene, 120, 24, white)
