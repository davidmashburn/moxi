# Separate historical gallery finding

Read-only inventory at `85b915424e7a7de85b18c0ccea46195d3617948c`,
`2026-11-26T03:21:24Z`, after the D08 recapture. **The required master gallery is
missing in this checkout; the generated master in the existing implementation
checkout is incomplete (26 of 72 standard galleries).** It omits D08, D04 mindmap,
D07 assembly, all 14 E02 and 12 E03 families, E04, and other published demos.
The planning requirement explicitly includes a master index, original PNGs,
self-contained navigation and per-demo/per-family sequences:
`origin/project-planning` at `87d1ad9460c12e8113afa13f22f97da725661daf`,
`DEFERRED-IMPLEMENTATION-MASTER.md`, lines 106–134. No shared index was changed.

The existing [catalog audit](../catalog-audit.json), recorded November 23, covers
59 manifests/481 frames. This checkout contains 72 standard manifests/580 frames,
plus a separate oscillator manifest. That retained report is an older inventory,
not certification of the present catalog. The standard catalog audit found:

| Finding | Observed scope |
| --- | --- |
| Explicit source hashes differ | 50 galleries: all 35 E01/E02/E03 families; canvas-graph, canvas-rich-node, E04, fdg-clean-consumer, fdg-export, fdg-inline-notebook, fdg-linux, linked-notebook, mindmap, both plot follow-ups, spatial-assembly, spatial-explorer, spatial-probe and sws-native |
| No per-file source inventory found | 21 galleries; current-source equivalence is unknown from these manifests/provenance, rather than proven stale |
| Recorded files match | Fresh D08 only; this checks the explicit inventory, not every possible dependency |
| Images present | 200 of 580 referenced frames: 112 recorded hashes match; 88 have no recorded PNG hash; no observed mismatches |
| Images absent locally | 380 referenced PNGs, all uncommitted paths; 20 standard manifests pass schema plus current local image checks |

The 21 without per-file inventories are allocation, browser-fdg, cairo-scene,
d01-math-backends, d02-native-math-editor, fdg-notebook,
i18-coordinated-representations, i19-inspectable-interactions, lived-spaces,
motion-envelope, native-lifecycle, not-implemented, p11-wayland,
server-backed-views, text-laboratory, v03, v04, v05, v11, v15 and visible-proposals.
An old revision alone is not proof of staleness; the 50 stale findings come from
actual recorded file hashes differing from this integration's bytes. They do not
show that the pictured historical behavior was false or that the demo is broken.

Generated HTML and large PNG/export files are deliberately ignored by repository
policy. The planning contract permits local large captures with committed compact
manifests and recipes. Their absence from Git is therefore expected; the 380
unavailable PNGs are a blocker to verifying/rendering those galleries **here**,
not evidence of 380 missing published deliverables. Regenerate actual captures
or obtain and checksum their original local bundle before certifying them.

There is also a concrete tooling blocker: oscillator uses a custom, unversioned
manifest with list-form slides. The shared slideshow loader rejects it with
`manifest version must be 1`; the unfiltered audit then crashes at
`scripts/audit_demo_manifests.py:71` with
`AttributeError: 'list' object has no attribute 'get'`. The counts above use the
existing audit function with that explicitly excluded nonstandard path; no shared
tool was repaired. This also prevents claiming that a normal all-catalog build or
audit currently passes.

Detailed local rows are retained in
[/tmp/moxi-d08-historical-audit.json](/tmp/moxi-d08-historical-audit.json)
(SHA-256 `4220dfc054297f77d1cddb2967d0788ddda99ae3714f7b1536de4a6d01e66522`). The unfiltered failure log is
`/tmp/moxi-d08-historical-full-audit.log`. This was a metadata, source-hash and
available-image audit; other demos were not rebuilt, visually reviewed or tested
for physical input, platform availability, external dependencies or acceptance.
Confidence is **high for the observed inventory/master omissions**. A complete
regenerated master with actual checked image bundles and refreshed source
inventories would change the current-evidence finding. No public main, ledger,
other gallery or remote destination was written.
