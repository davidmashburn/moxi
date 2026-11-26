# Capture and viewer review

The final capture set in [manifest.json](manifest.json) comes from source commit
`f0682a1828d85d1bd2a301bc11be331447216795`, with no source changes at capture.
All 12 recorded source hashes, the executable hash, all 17 PNG hashes and their
dimensions were independently checked after capture. Both the offline slideshow
and inline viewer contain the same 17 original PNGs.

All 17 final frames were inspected as a contact sheet. The minimum-size
[alternatives view](04-alternatives.png) and [saved panel](11-narrow-panel.png)
were also inspected at full resolution. The plotted marks, residuals, controls,
status text and alternatives are visible at 980 by 800 native points. Coefficient
inputs retain full precision; their trailing digits can clip at this size. The
separate equation readout remains visible. Horizontal text-field navigation was
not tested.

The slideshow was exercised in the T3 browser preview at 728 pixels in dark mode
and 390 pixels in light mode. A DOM interaction probe passed Next, the left arrow
key, contact-sheet jump, previous-slide wrap and visible-slide state across all
17 captures. The final inline viewer preview had no console messages. This
browser check verifies the slideshow, not the native consumer; the native
interaction and persistence evidence is in [REVIEW.md](REVIEW.md).

The inline adapter changes only viewer styling and initially collapses the
contact sheet. It uses the original embedded screenshots. The standalone
[index.html](index.html) is reproduced by the documented check command and needs
no server or network. Generated PNGs and HTML remain local under the repository's
artifact convention; compact evidence and reproduction sources are committed.
