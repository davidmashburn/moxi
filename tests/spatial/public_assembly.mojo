from moxi_spatial import (SpatialViewport, SpatialNode, SpatialObject, SpatialPoint, SpatialMetric, SpatialTool, SpatialComponent, SpatialClip, SpatialEndpoint, SpatialCommand, SpatialProjection)
from std.collections import List

def main() raises:
    var a = SpatialViewport()
    var b = SpatialViewport(a)
    var nodes = List[SpatialNode]()
    nodes.append(SpatialNode(SpatialObject(8,SpatialPoint(0,0,0),0,1,SpatialPoint(1,0,0)),0))
    nodes.append(SpatialNode(SpatialObject(99,SpatialPoint(1,0,0),0,0.5,SpatialPoint(0,1,0)),8))
    if not a.replace_hierarchy(nodes):
        raise Error("Hierarchy rejected")
    if b.parent(99) != 8 or a.metric(SpatialMetric.DOCUMENT_ID) != b.metric(SpatialMetric.DOCUMENT_ID):
        raise Error("Document not shared")
    _ = b.select(8)
    _ = b.operation(SpatialTool.AXIS_X,0.5)
    if a.world_transform(99,SpatialComponent.X) != 1.5:
        raise Error("Hierarchy transform not shared")
    _ = a.set_probe(SpatialEndpoint.A,8,SpatialPoint(0,0,0))
    _ = b.set_probe(SpatialEndpoint.B,99,SpatialPoint(0,0,0))
    if a.measurement() != 1:
        raise Error("Probe not shared")
    _ = a.set_clip(SpatialClip(True,SpatialPoint(1,0,0),0))
    if not b.clip().enabled:
        raise Error("Clip not shared")
    _ = b.command(SpatialCommand.UNDO)
    if a.clip().enabled:
        raise Error("Clip history not shared")
    var camera = b.camera()
    camera.projection = SpatialProjection.ORTHOGRAPHIC
    _ = b.set_camera(camera)
    if a.camera().projection != SpatialProjection.PERSPECTIVE:
        raise Error("Camera unexpectedly shared")
    a.close()
    if b.metric(SpatialMetric.VIEWS) != 1 or b.world_transform(99,SpatialComponent.X) != 1.5:
        raise Error("Origin close destroyed linked document")
    b.close()
    print("PASS clean packaged assembly consumer: hierarchy, linked views, measurement, clip, history, origin close")
