"""Extended paths preserve inline rejection, own copies and render continuous fills."""
from moxi import ScenePath, ScenePathStorage, Scene, Point, Color, CanvasSceneRenderer, SoftwareSceneRenderer, test_check


def main() raises:
    var bounded = ScenePath()
    bounded.move_to(Point(2,2))
    for i in range(16):
        bounded.line_to(Point(Float32(i),20))
    test_check(not bounded.is_valid() and bounded.command_count == 16)
    var path = ScenePath(ScenePathStorage.EXTENDED)
    path.move_to(Point(2,2))
    for i in range(20):
        path.line_to(Point(Float32(3+i),2))
    path.line_to(Point(22,22))
    path.line_to(Point(2,22))
    path.close()
    test_check(path.is_valid() and path.command_count == 24)
    test_check(path.command(20).point1.x == 22)
    var copied = path
    copied.line_to(Point(30,30))
    test_check(path.command_count == 24 and copied.command_count == 25)
    test_check(path.bounds.width == 20 and copied.bounds.width == 28)
    var scene = Scene()
    scene.append_typed_path(1,path,Color(1,0,0,1),Color(0,0,0,0),0)
    var canvas = CanvasSceneRenderer(32,32,Color(1,1,1,1))
    canvas.render_scene(scene)
    test_check(canvas.error_count() == 0)
    canvas.write_png("/tmp/moxi-e02-extended-path.png")
    var software = SoftwareSceneRenderer(32,32,Color(1,1,1,1))
    software.render_scene(scene)
    with open("/tmp/moxi-e02-extended-path.ppm","w") as f:
        f.write(software.ppm())
    var limit = ScenePath(ScenePathStorage.EXTENDED)
    limit.move_to(Point(0,0))
    for i in range(ScenePath.MAX_EXTENDED_COMMANDS):
        limit.line_to(Point(Float32(i),0))
    test_check(not limit.is_valid() and limit.command_count == ScenePath.MAX_EXTENDED_COMMANDS)
    var invalid = ScenePath(ScenePathStorage(99))
    invalid.move_to(Point(0,0))
    test_check(not invalid.is_valid())
    print("Extended path copy, inline/extended limits, Canvas/software passed")
