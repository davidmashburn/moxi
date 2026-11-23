# D04 native gallery review — November 23, 2026

The four partial frames from the November 20 review and the subsequently observed
first-frame reflow overlap have been repaired and recaptured from clean source
`9d1f4e3a2bc32fd642cbb95fbc4e81230d8f695f`.
All 20 native frames were reviewed and pass their bounded scenarios.
The [validation record](validation.json) gives actions, expected and observed
results, per-frame outcomes, source/binary/PNG hashes, environment and limits.

These are AppKit content-view `cacheDisplay` **offscreen-render** captures of the
real native executable at 2360 × 1640 pixels (1180 × 820 points, scale 2). The
host was macOS 27.2.1 arm64, Mojo 1.1.0 (8189361e), Apple clang 21.0.0 and SDK 27.0.
Only F2 traverses AppKit NSEvent dispatch; remaining inputs use public Event or
command APIs. Physical input, IME and independent human acceptance remain open.

The repaired states are retained as native PNGs:

- [Mixed-script edit](02-mixed-edit.png): both editor rows are visible with room
  for native text insets, the footer and Share findings. The wider editor leaves
  part of child #5 outside the right viewport.
- [Keyboard destination preview](04-reparent-preview.png): the moving branch is
  revealed in the Research lane, clear of stationary siblings, before commit.
- [Pointer preview](08a-pointer-preview.png): the branch and proposed parent are
  separately legible with a connecting edge. The parent header truncates its
  trailing emoji; the body label remains legible.
- [Expanded 1,000-topic fixture](13-large-expanded.png): initial zoom 1 shows
  readable local topics and the root. Replay reports 37 ordinary commands after
  culling. Dense incident edges, truncated long headers and the minimap covering
  part of the bottom card remain visible limits.
- [Reflow start](06a-reflow-start.png) and [midpoint](06b-reflow-middle.png):
  the committed branch stays fixed, while Field notes starts farther along its
  existing upward path and its footer remains clear of the branch. Other
  neighbors with clear paths retain their original animation start.

The overlap regression was reproduced before repair by both a focused contract
and the real native replay. Their new assertions failed at the first reflow frame.
After repair, the native start/midpoint assertions and all six contracts pass.
Only the two reflow PNGs changed; the other 18 match the previous reviewed capture
byte for byte. Several camera states still crop Field notes at the left edge;
Fit brings the six-topic map inside the viewport. These deterministic snapshots
do not establish presentation-timed animation or native capacity acceptance.

The recipe records 184 authored input hashes, including native `.inc` files.
Git’s tracked/unignored inventory excludes generated Rust target JSONs and
retains unignored new authored inputs in scoped dirty evidence. The shared
[checker](../check_d04_d07.py) verifies all 184 inputs against their capture
commit and current checkout bytes, plus all 20 PNG hashes and dimensions. D07
retains its independent clean capture revision when its inputs remain identical.
The checker's previously exercised five isolated negative cases reject missing
frames, wrong PNG/source hashes, untracked authored capture inputs and abbreviated
capture revisions; those cases were reused because the checker is unchanged.

From the repository root:

```sh
pixi run d04-mindmap-contract
pixi run d04-mindmap-replay
python3 artifacts/demo-slideshows/check_d04_d07.py --revision HEAD
review_root=$(mktemp -d /tmp/moxi-gallery-check.XXXXXX)
ln -s "$PWD/artifacts/demo-slideshows/mindmap" "$review_root/mindmap"
ln -s "$PWD/artifacts/demo-slideshows/spatial-assembly" "$review_root/spatial-assembly"
python3 scripts/demo_slideshows.py "$review_root" --check
python3 scripts/demo_slideshows.py "$review_root"
```

The last command renders ignored HTML from the retained PNGs without rebuilding
the native executable. The recipe also renders its own `index.html`. Source or
capture changes require new provenance checks and visual review; these commands
do not certify that a changed implementation still looks correct.

The six-part contract suite and 70-command inventory passed after the final
reflow repair. They check unchanged-size input delivery without neighbor remounts,
temporary editor growth/cancel, valid preview destinations, move/undo, the large-map
initial camera, initial/later path collisions against two moved descendants,
ordinary-neighbor interpolation and exact settling. The final native build/replay,
two-gallery source/hash checker and focused three-gallery schema check exited 0.
Build warnings concern deprecated string conversion, the macOS
link/deployment target and an unused shared-canvas assignment. Saved and recovery
fixture bytes were checked separately: only the recovery envelope contains the
recovered-draft suffix.

All 20 native PNGs are deliverables beside this record, retained by a scoped
ignore exception. HTML and binaries remain generated. Full logs/contact sheets
are disposable local attachments in `/tmp/moxi-d04-reflow-9d1f4e3-evidence/`;
the reused checker negative cases remain in `/tmp/moxi-d04-d07-158c67a-evidence/`.
The [catalog audit](../CATALOG-AUDIT.md) distinguishes these retained images from
older galleries whose PNGs are only local or absent.

Browser slideshow navigation, physical pointer/keyboard/IME/capture-loss and
chooser flows, VoiceOver, independent human acceptance, other hosts/viewports,
packaged-consumer suites, broad repository tests, sanitizers and GitHub CI were
not run. The 1,024-command boundary, expanded 10,000-topic native capacity,
live-reference parity and performance gates remain unaccepted.
