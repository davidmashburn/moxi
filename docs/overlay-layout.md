# Overlay candidate placement

`moxi.overlay_layout.place_overlay` takes an anchor and viewport in the same
published presentation coordinates. It tries ordered below/above/right/left
candidates, chooses the first complete fit or greatest visible area, then shifts
into the viewport. Oversized content receives a smaller allocation and
`needs_scroll`; remeasure at that width and supply scrolling rather than drawing
outside the allocated rectangle. A removed anchor returns `present=False`.

`Transform.composed`, `inverse` and `Rect.transformed` handle nested scroll/zoom
coordinate conversion. Apply each viewport offset once before candidate placement.
Singular/nonfinite inverses are errors. Rotated rectangle bounds are axis aligned.

Attach popup content to a presentation-root-owned region to escape the anchor's
local clip without adding a second geometry owner. Existing `PopupLayerState`
retains modal focus scope, escape dismissal and focus restoration; placement does
not replace that interaction state. Its anchors and bounds must refresh from the
same successful publication used for paint and input.

Portable tests cover candidate flipping, oversize allocation, missing anchors,
nested transform conversion and inverse rejection. Native modal accessibility and
composition checks remain integration gates.
