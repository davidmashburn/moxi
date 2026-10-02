from std.testing import assert_true, assert_equal, assert_almost_equal
from moxi.overlay_layout import place_overlay
from moxi.geometry import Rect, Size, Point, Transform
from moxi.popup import POPUP_PLACE_ABOVE


def main() raises:
    var viewport = Rect(10,20,300,200)
    var placed = place_overlay(Rect(50,190,40,20),Size(120,80),viewport)
    assert_equal(placed.placement,POPUP_PLACE_ABOVE)
    assert_almost_equal(placed.bounds.y,Float32(110))
    assert_true(not placed.needs_scroll)
    placed = place_overlay(Rect(280,200,20,10),Size(500,400),viewport)
    assert_true(placed.needs_scroll)
    assert_almost_equal(placed.bounds.x,Float32(10))
    assert_almost_equal(placed.bounds.width,Float32(300))
    assert_almost_equal(placed.bounds.height,Float32(200))
    assert_true(not place_overlay(Rect(0,0,10,10),Size(20,20),viewport,anchor_present=False).present)
    var nested = Transform(tx=40,ty=50).composed(Transform(2,0,0,2,-10,-20))
    var anchor = Rect(10,30,20,10).transformed(nested)
    assert_almost_equal(anchor.x,Float32(50))
    assert_almost_equal(anchor.y,Float32(90))
    var roundtrip = nested.inverse().apply(nested.apply(Point(11,19)))
    assert_almost_equal(roundtrip.x,Float32(11))
    assert_almost_equal(roundtrip.y,Float32(19))
    var rejected = False
    try:
        _ = Transform(0,0,0,0).inverse()
    except:
        rejected = True
    assert_true(rejected)
    print("Overlay placement and transform contracts passed")
