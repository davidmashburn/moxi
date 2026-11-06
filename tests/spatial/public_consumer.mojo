"""Clean public import: no camera math, native handles, hit tests or lifetime glue."""
from std.testing import assert_true, assert_equal
from std.collections import List
from moxi_spatial import (SpatialViewport, SpatialObject, SpatialPoint, SpatialTool,
    SpatialMetric, SpatialComponent, SpatialState, SpatialCommand, SpatialProjection,
    SpatialAnchorPolicy, SpatialAnchorState)


def main() raises:
    var view = SpatialViewport()
    assert_true(view.state() == SpatialState.READY)
    assert_true(view.viewport(0,0,640,480))
    var camera = view.camera()
    camera.projection = SpatialProjection.ORTHOGRAPHIC
    assert_true(view.set_camera(camera))
    var objects = List[SpatialObject]()
    objects.append(SpatialObject(77,SpatialPoint(0,0,0),0,1,SpatialPoint(1,0.4,0.1)))
    assert_true(view.replace_objects(objects))
    assert_true(view.select(77))
    assert_true(view.operation(SpatialTool.AXIS_X,0.36,snap=True))
    assert_equal(view.transform(77,SpatialComponent.X),Float64(0.25))
    var history = view.metric(SpatialMetric.HISTORY)
    assert_true(not view.operation(SpatialTool.AXIS_X,0))
    assert_equal(view.metric(SpatialMetric.HISTORY),history)
    assert_true(view.command(SpatialCommand.UNDO))
    assert_equal(view.transform(77,SpatialComponent.X),Float64(0))
    var anchor = view.anchor(SpatialPoint(0,0,0),SpatialAnchorPolicy.ALWAYS_VISIBLE)
    assert_true(anchor.state == SpatialAnchorState.VISIBLE)
    assert_true(len(view.overlays(SpatialTool.AXIS_X)) > 0)
    assert_true(not view.mount(0))
    assert_true(view.command(SpatialCommand.DISPOSE))
    assert_true(view.state() == SpatialState.DISPOSED)
    view.close()
    assert_true(view.state() == SpatialState.DISPOSED)
    print("PASS clean public moxi_spatial consumer (packaged module; operations, projection, history, lifecycle)")
