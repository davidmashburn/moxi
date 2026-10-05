"""Native frame resource leases reject stale and malformed publications."""
from moxi import test_check, Size
from moxi.backend import BACKEND_MACOS_APPKIT, BACKEND_LINUX
from moxi.frame import SurfaceMetrics, FramePacket
from moxi.native_frame import NativeFrameRenderer
from moxi.layout_workbench import LayoutWorkbench


def rejected[kind: Int](mut renderer: NativeFrameRenderer[kind], packet: FramePacket) raises -> Bool:
    try:
        renderer.render(packet)
    except:
        return True
    return False


def check_native_frame[kind: Int]() raises:
    var screen = LayoutWorkbench(128)
    screen.focused = -1
    var publication = screen.frame(Size(1100,800))
    var old = publication.packet(SurfaceMetrics(Size(1100,800)))
    var renderer = NativeFrameRenderer[kind]()
    test_check(len(old.resources) > 0)
    test_check(rejected(renderer, old))
    renderer.bind_resources(publication.snapshot)
    renderer.render(old)
    var next = screen.frame(Size(540,900))
    var current = next.packet(SurfaceMetrics(Size(540,900)))
    test_check(rejected(renderer, current))
    renderer.bind_resources(next.snapshot)
    test_check(rejected(renderer, old))
    renderer.render(current)
    current.resources[0].mount += 1
    test_check(rejected(renderer, current))
    current.resources[0].mount -= 1
    current.commands[current.resources[0].command_index].resource_id = -1
    test_check(rejected(renderer, current))
    current.commands[current.resources[0].command_index].resource_id = current.resources[0].id
    var binding = current.resources.pop()
    test_check(rejected(renderer, current))
    current.resources.append(binding)
    current.resources.append(current.resources[0])
    test_check(rejected(renderer, current))
    renderer.release_resources()
    test_check(rejected(renderer, old))


def main() raises:
    # Both adapters share resource validation and the same native C ABI.
    check_native_frame[BACKEND_MACOS_APPKIT]()
    check_native_frame[BACKEND_LINUX]()
    print("Moxi native frame resource validation passed")
