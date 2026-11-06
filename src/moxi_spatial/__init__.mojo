"""Experimental bounded spatial interactions and AppKit+Metal composition.

Public consumers own the Moxi window and scheduling. Link the spatial objects
built by examples/spatial-explorer/build.sh. No app loop, backend object, private
image registry, or camera/picking/gesture implementation belongs in consumers.
World: right-handed +Y up; camera looks -Z; angles radians; window points +Y down;
Metal clip depth [0,1]; opaque premultiplied sRGB, explicit backing scale.
"""
from .spatial import (SpatialViewport, SpatialNode, SpatialClip, SpatialEndpoint, SpatialObject, SpatialCamera, SpatialPoint,
    SpatialTool, SpatialState, SpatialCommand, SpatialProjection, SpatialMetric,
    SpatialTiming, SpatialComponent, SpatialAnchor, SpatialAnchorPolicy,
    SpatialAnchorState, SpatialRoute, SpatialLine)
from .composition import CompositionSurface
