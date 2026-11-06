from std.testing import assert_equal, assert_true
from moxi import Rect, Color, Scene
from moxi.scene import SCENE_IMAGE, SCENE_LINEAR_GRADIENT, SceneCommand
from graph_app import GraphApp
from graph_export import scene_svg, export_graph, ExportFormat
from layout import sample_graph

def main() raises:
    var state = GraphApp(sample_graph())
    var bounds = Rect(0, 0, 700, 450)
    state.fit(bounds)
    state.query.set_text("node-12")
    state.find_next()
    state.neighbors_only = True
    var original_x = state.graph.nodes[0].x
    var original_zoom = state.zoom
    export_graph(state, bounds, "/tmp/moxi-p06-state.svg")
    assert_equal(state.selected, 12)
    assert_true(state.neighbors_only)
    assert_equal(state.zoom, original_zoom)
    assert_equal(state.graph.nodes[0].x, original_x)
    var rejected = False
    try:
        var format = ExportFormat("no.jpg")
    except:
        rejected = True
    assert_true(rejected)
    for index in range(2):
        var kind = SCENE_IMAGE if index == 0 else SCENE_LINEAR_GRADIENT
        var scene = Scene()
        var command = SceneCommand(kind, 1, bounds, Color(1, 0, 0, 1))
        command.kind = kind
        scene.commands.append(command)
        rejected = False
        try:
            _ = scene_svg(scene, bounds)
        except:
            rejected = True
        assert_true(rejected)
    export_graph(state, bounds, "/tmp/moxi-p06-recovery.svg")
    print("Export: live state preserved; unsupported format/image/gradient rejected; recovery passed")
