"""Installed-package boundary test; no private native or source imports."""
from std.testing import assert_true
from std.collections import List
from moxi_spatial import (SpatialViewport,SpatialPoint,SpatialObject,SpatialCommand,WorldPanel,PanelPhase,PanelResult,PanelMode)

def main() raises:
    var view = SpatialViewport()
    var empty = List[SpatialObject]()
    assert_true(view.replace_objects(empty))
    var panel = WorldPanel(view)
    assert_true(panel.configure(SpatialPoint(-2,1.2,0),SpatialPoint(4,0,0),SpatialPoint(0,-2.4,0)))
    assert_true(not panel.configure(SpatialPoint(0,0,0),SpatialPoint(0,0,0),SpatialPoint(0,1,0)))
    var x = panel.project_x(200,100)
    var y = panel.project_y(200,100)
    assert_true(panel.route(PanelPhase.DOWN,x,y) == PanelResult.HIT)
    assert_true(panel.route(PanelPhase(999),x,y) == PanelResult.INVALID)
    assert_true(PanelMode.parse(0) == PanelMode.WORLD)
    var rejected = False
    try:
        _ = PanelMode.parse(42)
    except:
        rejected = True
    assert_true(rejected)
    _ = view.command(SpatialCommand.DISPOSE)
    assert_true(panel.route(PanelPhase.MOVE,x,y) == PanelResult.STALE)
    view.close()
    assert_true(panel.route(PanelPhase.DOWN,x,y) == PanelResult.INVALID)
    print("PASS D08 clean public panel boundary / invalid wire mode / stale handle")
