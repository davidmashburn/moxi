# Complete master gallery

Open [the master](index.html) directly, or follow its link from [index.md](index.md).
It lists each gallery directory once, including the example decks already linked
by the historical table. E06's overview is represented by its three family decks.
The E02/E03 review is an evidence bundle, not a second set of family decks.

From the repository root, using Python 3.10 or newer and no extra dependencies:

```sh
python3 scripts/audit_demo_manifests.py --output /tmp/moxi-gallery-audit.json
python3 scripts/demo_slideshows.py --index-only
python3 -m unittest discover -s tests -p demo_slideshows_test.py -v
```

`--index-only` is the mode used for the committed master: it links only delivered,
validated decks and never writes individual decks. The normal slideshow command
also renders absent version-1 decks from validated originals, leaving existing
decks intact. Both modes keep unavailable galleries discoverable through their
original manifest, capture commands and available reproduction documentation.
Missing PNGs are never replaced with synthetic evidence. `--check` remains strict:
it exits unsuccessfully if any catalog entry has invalid or unavailable evidence.
The audit instead completes its inventory and reports each entry's failures.

The adapters recognize version-1 manifests, oscillator's list-form manifest,
E06 geometry capture records, the SWS4D native replay, two image comparisons and
the funnel comparison, the matrix instrument and the equation-linkage scenarios. Unknown or malformed manifests remain visible failures.
Custom formats retain their own semantics; they are not promoted to the standard
four-phase contract. Outside-root version-1 decks are discovered from local HTML
links in `index.md`. New custom producers require an explicit catalog adapter.

Deck links require valid original PNGs, any recorded dimensions and SHA-256,
valid local HTML resources, and association with those PNG bytes. PNG checks
include chunk CRCs and the compressed payload. Existing delivered HTML is never
rewritten. New version-1 decks embed images by default. The 56 decks delivered with
relative image links use the adjacent original PNGs and support the same
contact-sheet, button and keyboard navigation. Custom decks retain their original resource
layout; for example oscillator needs its adjacent PNGs, and funnel uses SVGs
from elsewhere in the repository. Copy the repository or the documented bundle
when moving such decks.

Source status is independent of capture availability. Only explicit per-file
inventories are compared. An old revision can still match; an absent inventory
means unknown. Oscillator's producer-relative filenames are mapped to
`examples/oscillator`. SWS4D's separate application inventory is reported as
external, not compared to unrelated Moxi paths. A matching partial inventory
does not certify dependency completeness or current behavior.

The [historical finding](spatial-world-panel/HISTORICAL-GALLERY-AUDIT.md) and
[November 23 audit](CATALOG-AUDIT.md) retain their original observations. Re-run
the normal audit for the present inventory; these tools do not recapture demos,
change their acceptance status, or update the ledger or planning branch.

## Current gallery inventory

The clean inventory at `8218159` contains 99 entries, 97 playable decks and 818 verified frame references. Two entries present comparison or review evidence directly. The repository-wide strict check passes. Offline Chrome decoded all 1,584 slide and thumbnail images at each of two sizes, 1280 × 800 and 390 × 844. Previous, next and thumbnail navigation worked in all 57 relative-image decks.

The [tricontour deck](e03-tricontour/index.html) pairs five historical frames with a new upstream-status capture. Its [provenance record](e03-tricontour/README.md) identifies the source of each frame and retains the checksum of the withheld original.

## Inventory after capture recovery

A clean checkout of `a4ce338` contains 96 playable decks across 99 catalog
entries. Of 818 recorded frame references, 817 resolve. The category-label
comparison and the Wave B/C review link directly to evidence. The tricontour
gallery links to its manifest and reproduction instructions. One original
reference image was withheld during publication review.

Offline Chrome opened all 96 delivered decks at 1280 × 800 and 390 × 844.
At each size it decoded 1,572 slide and thumbnail images. Next, arrow-key
and thumbnail navigation passed in each of the 56 new decks.

The recovery added 379 unchanged original PNGs. Of these, 320 match historical
checksums and 59 match the bytes in retained decks. These files document the
original runs. [Capture provenance](../../docs/demo-gallery-originals.md)

## Inventory before capture recovery

The clean checkout at `aedd058` with the revised catalog contained 98 galleries. The master linked 39 delivered decks. All 39 opened at 1366 × 900 and 390 × 844. Across both layouts the browser decoded 1,192 images, and all 350 local references in the master and delivered decks resolved with exact filename case.

The manifests reference 777 frames. Git contains 397 of those references, including 185 with a verified recorded hash. The remaining 380 references occur across 52 galleries. Each gallery with missing frames links to its available capture evidence or reproduction instructions. Of the 98 recorded source inventories, three matched the checkout, 57 differed and 38 lacked comparable per-file hashes.

## Initial inventory at a947a65

The November 26, 2026 clean-checkout audit found 93 unique galleries: 84 version-1,
one oscillator, three E06 geometry, one SWS4D, three image comparisons and one
review bundle. This includes nine outside-root galleries already linked in the
markdown. There are 85 manifest files; the other eight entries use custom evidence.
These counts describe the requested `a947a65` candidate, not the older checkout
in the historical audit. No historical captures were added or changed.

| Measure | Observed |
| --- | ---: |
| Delivered, checked deck links | 34 |
| Deck links after normal build from existing original PNGs | 38 |
| Galleries with valid capture evidence / unavailable evidence | 41 / 52 |
| Frame references: present committed PNGs / absent PNGs | 344 / 380 (724 total) |
| Present frame hashes: verified / not recorded / mismatched | 139 / 205 / 0 |
| Gallery source status: differ / unknown / match | 55 / 38 / 0 |

Frame counts are references, not unique image counts; contact-sheet image
elements and SVG comparisons are not additional captured frames. Every unavailable
entry retains its original reproduction recipe or a linked reproduction document.
None of the actual inventories establishes current-source equivalence. Unit
fixtures separately test old revisions with matching hashes, changed or missing
sources, absent inventories, unknown formats, missing PNGs and corrupt captures.

## Initial verification record

Tested a clean local clone of `463e7654a151fda0dbefa1fe98eb61f9bef4b8cc`,
04:08–04:14 UTC on November 26, 2026. The browser exercised the committed master in a clean local clone. The observations below describe that inventory.

| Scenario and steps | Expected and observed result |
| --- | --- |
| Unfiltered audit; 12 regression tests | PASS: complete inventory without filtering; all tests pass; checkout stays clean. |
| Strict `demo_slideshows.py --check` | PASS: exits 1 for 52 unavailable galleries, with no fabricated output. |
| Committed master: search, no results, clear; follow all links | PASS: 93 unique entries, 202 HTTP-successful links, 34 deck links; clearing restores all entries. |
| Load all delivered decks in browser frames and decode images | PASS: all 34 decks, 501 image elements, zero decode failures (includes repeated images and SVGs). |
| Mindmap next/previous, arrow key, final contact thumbnail, reload | PASS: counters 2/24, 1/24, 2/24, 24/24; one visible frame; reload returns to 1/24. |
| Oscillator final anchor; E06 next; outside-root execution-debugger next/final; funnel resources | PASS: final oscillator frame visible, E06 caption changes, debugger reaches 2/9 and 9/9, all funnel PNG/SVG images decode. |
| Missing E02 pie: expand recipe and follow reproduction link | PASS: evidence and real instructions available, no deck link. Master wraps without horizontal overflow at 1280×900 and 390×844 CSS pixels. |
| Normal build, then master links and generated-deck navigation | PASS: four decks generated from validated originals, 206 working links, all four decks decode; contour next reaches 2/12. Existing HTML/PNG/manifest/provenance files are unchanged except the master. |

Browser: T3 preview, Chromium 152 / Electron 44 on macOS, served only from the
tested clone at `http://localhost:8799/artifacts/demo-slideshows/index.html`; no
authentication or live external systems. The committed master identifies its
snapshot as `a947a65` plus four audited source worktree changes; the clean-clone
audit confirms its counts against the committed tools. Tests establish catalog
availability and navigation, not fresh application behavior. Application
recapture, physical input, performance, complete dependency provenance and
VoiceOver were not tested. Missing historical hashes limit byte provenance for
205 present frame references.
