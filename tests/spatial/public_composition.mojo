"""Direct public composition consumer: existing Moxi window lifetime + surface."""
from moxi.native_instance import MacOSWindowInstance
from moxi.window import WindowConfig
from moxi_spatial import CompositionSurface
from std.collections import List
from std.testing import assert_true


def main() raises:
    var window = MacOSWindowInstance()
    window.open(WindowConfig("D06 public composition contract",200,160),0,0)
    var surface = CompositionSurface(window.handle)
    var pixels: List[UInt8] = [255,0,0,255]
    assert_true(surface.publish(1,pixels,1,1,4))
    pixels[0] = 0
    assert_true(surface.compose(0,0,0,100,100))
    assert_true(not surface.publish(1,pixels,1,1,4))
    assert_true(not surface.compose(1,0,0,100,100))
    assert_true(surface.publish(2,pixels,1,1,4))
    surface.close()
    assert_true(not surface.compose(0,0,0,100,100))
    window.close()
    print("PASS public Mojo CompositionSurface (owned copy, serial, slot, release)")
