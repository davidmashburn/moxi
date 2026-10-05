"""Portable frame publication order, semantic-only updates and failures."""

from std.collections import List
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true
from moxi.accessibility import AccessibilitySnapshot, Semantics, ROLE_TEXT_INPUT
from moxi.frame import FramePacket, FrameHost, FrameRenderer, FrameResource, SurfaceMetrics, submit_frame
from moxi.geometry import Rect, Size
from moxi.invalidation import INVALIDATE_ACCESSIBILITY, INVALIDATE_CONTENT
from moxi.paint import PaintCommand


struct Trace:
    var calls: List[Int]
    var rendered_generation: UInt64
    var rendered_resource: Int
    var semantic_value: String
    var fail_render: Bool
    var fail_publish: Bool

    def __init__(out self):
        self.calls = List[Int]()
        self.rendered_generation = 0
        self.rendered_resource = -1
        self.semantic_value = ""
        self.fail_render = False
        self.fail_publish = False


struct RecordingRenderer(FrameRenderer):
    var trace: ArcPointer[Trace]

    def __init__(out self, trace: ArcPointer[Trace]):
        self.trace = trace

    def render(mut self, packet: FramePacket) raises:
        self.trace[].calls.append(1)
        if self.trace[].fail_render:
            raise Error("Injected renderer rejection")
        self.trace[].rendered_generation = packet.generation
        if len(packet.resources)>0:
            self.trace[].rendered_resource = packet.resources[0].id


struct RecordingHost(FrameHost):
    var trace: ArcPointer[Trace]

    def __init__(out self, trace: ArcPointer[Trace]):
        self.trace = trace

    def publish_accessibility(mut self, snapshot: AccessibilitySnapshot) raises:
        self.trace[].calls.append(2)
        if self.trace[].fail_publish:
            raise Error("Injected semantic publication rejection")
        self.trace[].semantic_value = snapshot.node_for_id(13).value

    def present(mut self) raises:
        self.trace[].calls.append(3)

    def metrics(self) raises -> SurfaceMetrics:
        return SurfaceMetrics(Size(540,900),2)


def _assert_calls(trace: ArcPointer[Trace], expected: List[Int]) raises:
    assert_equal(len(trace[].calls),len(expected))
    for index in range(len(expected)):
        assert_equal(trace[].calls[index],expected[index])
    trace[].calls = List[Int]()


def main() raises:
    var trace = ArcPointer(Trace())
    var host = RecordingHost(trace)
    var renderer = RecordingRenderer(trace)
    var packet = FramePacket(SurfaceMetrics(Size(540,900),2),37)
    assert_equal(packet.metrics.pixel_width(),1080)
    assert_equal(packet.metrics.pixel_height(),1800)
    assert_equal(SurfaceMetrics(Size(0,0),0).pixel_width(),1)
    var node = Semantics(13,ROLE_TEXT_INPUT,"Dataset")
    node.value = "日本語"
    node.focused = True
    packet.semantics.append(node)
    var command = PaintCommand("日本語",Rect(10,20,200,36))
    command.id = 13
    command.resource_id = 13
    packet.commands.append(command)
    packet.resources.append(FrameResource(13,4,0))

    # A prepared publication without invalidation must not wake any consumer.
    submit_frame(host,renderer,packet)
    _assert_calls(trace,List[Int]())
    assert_true(not packet.needs_paint())

    # Focus/value updates may reach the native accessibility bridge without a
    # render or presentation, even when commands/resources accompany the IR.
    packet.invalidation.invalidate(INVALIDATE_ACCESSIBILITY,Rect(10,20,200,36))
    submit_frame(host,renderer,packet)
    _assert_calls(trace,[2])
    assert_equal(trace[].semantic_value,String("日本語"))
    assert_equal(trace[].rendered_generation,UInt64(0))

    # Paint uses the same immutable publication: render, publish semantics,
    # then present. Consumers can independently choose software/native pixels.
    packet.invalidation.invalidate(INVALIDATE_CONTENT,Rect(10,20,200,36))
    assert_true(packet.needs_paint())
    submit_frame(host,renderer,packet)
    _assert_calls(trace,[1,2,3])
    assert_equal(trace[].rendered_generation,UInt64(37))
    assert_equal(trace[].rendered_resource,13)

    trace[].fail_render = True
    var rejected = False
    try:
        submit_frame(host,renderer,packet)
    except:
        rejected = True
    assert_true(rejected)
    _assert_calls(trace,[1])
    trace[].fail_render = False
    trace[].fail_publish = True
    rejected = False
    try:
        submit_frame(host,renderer,packet)
    except:
        rejected = True
    assert_true(rejected)
    _assert_calls(trace,[1,2])
    trace[].fail_publish = False
    packet.invalidation.clear()
    submit_frame(host,renderer,packet)
    _assert_calls(trace,List[Int]())
    print("Moxi portable frame publication passed")
