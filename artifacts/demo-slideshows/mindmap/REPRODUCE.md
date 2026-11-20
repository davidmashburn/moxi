# Mind-map native replay

Run `pixi run d04-mindmap-replay` on macOS with an available AppKit session. The task compiles the real native app, runs its deterministic public-input replay, captures its actual content view with `cacheDisplayInRect`, records source/PNG SHA256 values, and uses `scripts/demo_slideshows.py` schema v1 to render only this demo's `index.html`. PNG and HTML outputs remain ignored.

The manifest identifies the build revision and any scoped dirty sources. The recipe snapshots revision and source hashes before compilation and refuses to write provenance if they change during build/replay. Rebuild and recapture after integration; a source hash mismatch invalidates prior capture provenance. Sources include Mojo imports, native `.m` and `.h` files, original fixtures, tasks, and capture scripts. The inventory conservatively includes the native directory; it does not imply all backends ran.

F2 crosses AppKit's `keyDown:` event queue. Other replay input is supplied as public `Event` values or the app's actual public command entrypoint. Pointer replay uses displayed header/destination geometry. The production loop polls real window input and uses the same controller and renderer. No frame is a mockup, diagram, HTML UI, or reference-app screenshot.

These are **offscreen-render** captures of actual AppKit content views, not `native-window` captures. They establish recorded transitions, not physical IME, VoiceOver, independent usability, latency, allocation, GPU/presentation, or expanded 10,000-topic native acceptance. VoiceOver remained paused.

Logs: `/tmp/moxi-d04-native-build.log`, `/tmp/moxi-d04-native-replay.log`, `/tmp/moxi-d04-manifest.log`. Disposable save/recovery fixture: `/tmp/moxi-d04-replay-<monotonic-time>.moxi` and its `.recovery`/`.lock` siblings. Each run uses a unique fixture path printed in the replay log.

The replay includes commit-start, 90 ms midpoint, 180 ms completion and reduced-motion frames. These use deterministic public frame ticks; the interactive host uses its monotonic clock and the macOS Reduce Motion preference. Animation is derived presentation and adds no semantic undo steps.

## Reviewed-source capture — November 20, 2026

Regenerated from clean implementation `d7fa3ed563948860f4baf18bcc9f3eb279197135`:
**20/20 frames resolved, hash-checked and visually inspected**, at 2360 × 1640
pixels (1180 × 820 points, scale 2). The local host was macOS 27.2 arm64,
Mojo 1.1.0 (8189361e), Apple clang 21.0.0 and SDK 27.0. Build and native replay
exited 0; compilation emitted deprecation, unused-assignment and deployment-target
warnings. This is a bounded capture/provenance review with partial visual outcomes,
not full UI acceptance.

The original checkout's candidate was inspected read-only and remains unchanged.
Its manifest actually contained **17** frames, despite the planning document's
20-frame description, referenced revision `5db9a010053fd05412ee02d11eed05cce82b2a3c`,
had 29 source-hash mismatches against reviewed main, and lacked all 17 PNGs.
It could not establish current-source evidence. This checkout's current recipe
generated the full 20-frame sequence, including reflow and reduced-motion states.

[validation.json](validation.json) records every frame's action, expected result,
observed result, outcome and limits, plus original-candidate hashes, executable
hash, environment, capture times and local log/contact-sheet paths. The capture
manifest covers 179 source files. The shared
[checker](../check_d04_d07.py) additionally verifies the three native `.inc` files
omitted by this recipe's suffix filter: **182 source files match reviewed Git
blobs**. These includes were snapshotted before capture and unchanged afterward.
The supplemental hashes live in the validation record; the capture recipe itself
was not changed.

Reproduce both candidates and their joint checks from the repository root:

```sh
pixi run d04-mindmap-replay
python3 examples/spatial-assembly/gallery.py
python3 artifacts/demo-slideshows/check_d04_d07.py --revision d7fa3ed
review_root=$(mktemp -d /tmp/moxi-gallery-check.XXXXXX)
ln -s "$PWD/artifacts/demo-slideshows/mindmap" "$review_root/mindmap"
ln -s "$PWD/artifacts/demo-slideshows/spatial-assembly" "$review_root/spatial-assembly"
python3 scripts/demo_slideshows.py "$review_root" --check
```

Each recipe also validates and renders its own ignored `index.html`. The scoped
gallery check validates exactly these two demos, without requiring other missing
gallery outputs or changing the master gallery. The extra checker validates
source inventories, revision, supplemental includes, every PNG's SHA-256, schema,
dimensions and distinct frame references. Temporary negative cases confirmed
rejection of missing frames, wrong PNG hashes and wrong source hashes. It checks
the regenerated capture files; it does not perform or certify visual review.

The November 20 review has four partial visual outcomes:

- `02-mixed-edit.png`: the first wrapped editor row is clipped at the top. Later
  committed frames display the inserted mixed-script label; editor legibility
  and physical IME acceptance remain open.
- `04-reparent-preview.png`: the new edge reaches Research, but the moving topic
  remains on its old Draft side. This does not show its eventual left-side bounds.
- `08a-pointer-preview.png`: the dragged card overlaps Share findings and its
  title is partly occluded.
- `13-large-expanded.png`: the expanded fixture forms a dense, unreadable
  vertical strip. The replay reports 1,000 logical visible topics and 213 ordinary
  commands after viewport culling; it does not establish expanded native capacity
  or the large-graph performance budget.

Several intermediate frames also crop Field notes at the left viewport edge;
Fit in `08-side-spacing.png` brings the six-topic map inside the viewport. The
save/recovery frame was checked against the separate saved and recovery fixture
bytes, not merely its status message. The original saved fixture lacks the
recovered-draft suffix, while the recovery envelope contains it.

All frames were inspected directly as PNGs, using labeled contact sheets and
selected original-resolution frames. Browser slideshow navigation, physical
input/chooser/capture-loss paths, VoiceOver, independent human acceptance,
presentation timing, other viewport sizes/hosts, full test suites, packaged
consumer checks and CI were not run. The 1,024-slot boundary, 10,000-topic native
acceptance and performance gates remain open. Replaying or changing sources
requires a fresh visual review and validation record; do not reuse this dated
review for new captures.

PNG/HTML and builds remain ignored. Verbose logs, contact sheets and audit/check
outputs are retained locally at `/tmp/moxi-d04-d07-d7fa3ed-evidence/`; these are
disposable attachments, not tracked deliverables. No commits, pushes or external
writes were performed.
