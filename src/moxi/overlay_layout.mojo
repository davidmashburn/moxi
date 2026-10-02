"""Portable ordered overlay candidates in published presentation coordinates."""
from std.collections import List
from std.math import isfinite
from .geometry import Rect, Size
from .popup import POPUP_PLACE_BELOW, POPUP_PLACE_ABOVE, POPUP_PLACE_RIGHT, POPUP_PLACE_LEFT


struct OverlayPlacement(ImplicitlyCopyable):
    var bounds: Rect
    var placement: Int
    var present: Bool
    var needs_scroll: Bool
    def __init__(out self, bounds: Rect, placement: Int, present: Bool, needs_scroll: Bool):
        self.bounds = bounds
        self.placement = placement
        self.present = present
        self.needs_scroll = needs_scroll


def place_overlay(anchor: Rect, size: Size, viewport: Rect,
                  candidates: List[Int] = [POPUP_PLACE_BELOW, POPUP_PLACE_ABOVE, POPUP_PLACE_RIGHT, POPUP_PLACE_LEFT],
                  anchor_present: Bool = True) raises -> OverlayPlacement:
    """First full fit, otherwise greatest visible area followed by viewport shift.

    Oversized content receives a smaller exact allocation and must be remeasured
    and made scrollable. Removed anchors close the overlay. No scroll offset is
    added here: anchor and viewport already use presentation coordinates.
    """
    for value in [anchor.x,anchor.y,anchor.width,anchor.height,size.width,size.height,viewport.x,viewport.y,viewport.width,viewport.height]:
        if not isfinite(value):
            raise Error("Overlay geometry must be finite")
    if anchor.width < 0 or anchor.height < 0 or size.width < 0 or size.height < 0 or viewport.width < 0 or viewport.height < 0 or len(candidates)==0:
        raise Error("Invalid overlay extents or candidate list")
    for placement in candidates:
        if placement < 0 or placement > 3:
            raise Error("Unknown overlay candidate")
    if not anchor_present or viewport.width == 0 or viewport.height == 0:
        return OverlayPlacement(Rect(viewport.x,viewport.y,0,0),candidates[0],False,False)
    var chosen = candidates[0]
    var best: Float64 = -1
    var result = Rect(anchor.x,anchor.y+anchor.height,size.width,size.height)
    for placement in candidates:
        var rect = Rect(anchor.x,anchor.y+anchor.height,size.width,size.height)
        if placement == POPUP_PLACE_ABOVE:
            rect.y = anchor.y-size.height
        elif placement == POPUP_PLACE_RIGHT:
            rect.x = anchor.x+anchor.width
            rect.y = anchor.y
        elif placement == POPUP_PLACE_LEFT:
            rect.x = anchor.x-size.width
            rect.y = anchor.y
        var visible = rect.intersection(viewport)
        var area = Float64(visible.width)*Float64(visible.height)
        if area > best:
            best = area
            result = rect
            chosen = placement
        if visible.width == size.width and visible.height == size.height:
            break
    var scroll = size.width > viewport.width or size.height > viewport.height
    result.width = min(size.width,viewport.width)
    result.height = min(size.height,viewport.height)
    result.x = max(viewport.x,min(result.x,viewport.x+viewport.width-result.width))
    result.y = max(viewport.y,min(result.y,viewport.y+viewport.height-result.height))
    return OverlayPlacement(result,chosen,True,scroll)
