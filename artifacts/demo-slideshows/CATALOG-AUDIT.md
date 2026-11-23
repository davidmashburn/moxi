# Demo catalog audit — November 23, 2026

All **58 catalog manifests / 476 frame references** were audited against checkout
`158c67a36c376bbc0f88eaf363669a0485473343` at 07:26 UTC. The full
[catalog-audit.json](catalog-audit.json) records each manifest’s SHA-256, source
inventory checks, PNG checks and local-versus-committed image availability.
This audit does not recapture or visually review the older galleries.

| Check | Result |
| --- | --- |
| Schema, image presence and dimensions | 57 pass; `sws-native` fails for 13 locally absent PNGs |
| Recorded PNG SHA-256 | 395 match, 0 mismatch, 68 existing images lack a recorded hash, 13 images absent |
| Explicit recorded source inventory | 3 match current bytes, 47 differ, 8 have no per-file hashes |
| Referenced PNGs committed at the audit revision | 12 / 476 |
| Referenced PNGs present only in the working tree | 451 / 476, including the 34 refreshed D04/D07 frames before their artifact commit |
| Referenced PNGs absent and uncommitted | 13 / 476 |

**Local presence is not clean-clone availability.** The 13 absent SWS images are
the count missing from this working tree, not the number missing on a clean
clone. At the audit revision, 464 referenced PNGs are uncommitted. This change
retains all 34 refreshed D04/D07 native PNGs through per-directory ignore
exceptions; those frames become available with the evidence commit. The other
417 locally present frames are not added by this change. HTML and native
binaries remain generated. Counts in the JSON deliberately describe the named
Git revision, rather than assuming a later artifact commit.

The three matching explicit inventories are `mindmap` (184 source files),
`spatial-assembly` (156) and `plot-contour-followup`. The first two also have
current native replay, committed-source/PNG checks and per-frame visual records:
[D04](mindmap/REPRODUCE.md), [D07](spatial-assembly/README.md).
`plot-contour-followup` has its own [evidence record](plot-contour-followup/README.md);
this audit checks its recorded inventory and image bytes without adopting its
visual or performance claims.

The eight galleries without per-file source hashes are `browser-fdg`,
`d01-math-backends`, `d02-native-math-editor`, `fdg-notebook`, `native-lifecycle`,
`not-implemented`, `server-backed-views` and `text-laboratory`. The JSON identifies
all 47 differing inventories and their changed or missing source paths. The SWS
application namespace belongs to a separate repository; its 26 application files
were not compared with Moxi paths.

A matching explicit inventory certifies only the files actually recorded.
Dependency completeness, capture origin, native binary identity, visual quality,
physical-input/accessibility/human acceptance and performance were not audited
for the remaining catalog. No old gallery is promoted to integrated-source
acceptance on revision labels or image presence alone. Uncommitted status is
reported only for the union of recorded source inputs; unrelated worktree edits
are excluded.

Re-run the read-only audit from the repository root:

```sh
python3 scripts/audit_demo_manifests.py --output artifacts/demo-slideshows/catalog-audit.json
```

Refreshing it after an artifact commit updates the committed-image counts. A
future source/capture change also requires a new dated interpretation before
these records can support current implementation claims.
