# Native mind map (D04)

`examples/mindmap_native_app.mojo` is a native macOS application consuming the public `moxi_canvas` package. It has one application-owned ordered tree, semantic history and deterministic tree layout. Topic contents are ordinary `TextInputControl` and `Button` components hosted by `CanvasView`; the shared canvas owns transformed hit testing, focus, pointer capture, pan/zoom, clipping, connector geometry, semantics and ordered native presentation. There is no second renderer or canvas runtime.

The implementation supplies the core N0–N4 workflows, with the implementation and acceptance gaps listed below. **N0 and N4 acceptance are not complete.** In particular, live Freeplane behavior, physical IME, assistive technology, independent usability, the large native command capacity and the performance budgets remain open. A runnable replay is evidence of its recorded transitions, not release acceptance.

## Run and consume

All tasks have D04-specific names; existing tasks and galleries remain separate.

| Task | Purpose |
| --- | --- |
| `pixi run d04-mindmap-app` | Build and open the actual AppKit application |
| `pixi run d04-mindmap-probe` | Build the executable without opening a window |
| `pixi run d04-mindmap-contract` | Headless document/layout/history and public event contracts; shortcut inventory |
| `pixi run d04-mindmap-import-check` | Native storage and hostile import tests |
| `pixi run d04-mindmap-native-check` | Actual native replay and capture (alias of replay recipe) |
| `pixi run d04-mindmap-replay` | Build, replay, capture, hash and render this demo's slideshow |
| `pixi run d04-mindmap-consumer` | Compile three packages, then run a consumer outside the source checkout |
| `pixi run d04-mindmap-benchmark` | Headless layout and real application update/paint-list measurements |

Public headless modules are `moxi_mindmap.model`, `.codec`, `.history` and `.layout`. `MindMapApp` composes those with the public canvas. `storage` is optional macOS FFI, linked with `native/mindmap/storage.m` and Cocoa; it is not required by the clean headless consumer. See `packages/moxi_mindmap/README.md`. Package consumption is demonstrated with `.mojoc` files; registry distribution, installer signing and notarization are not supplied.

The app opens with an original synthetic useful map. Its production loop polls `MacOSWindowInstance` input and uses the same controller as replay. It retains explicit native instance ownership; the test capture helper selects only its exact window title. The capture helper is not an input/runtime implementation.

## Working with a map

The toolbar exposes Commands, Child, Edit, Move branch, Fold, Find, Outline, Undo, Save and Fit. Press **F6** to focus Commands, Enter to open it, or ordinary Tab/Shift+Tab to traverse toolbar controls. Commands also offers Leave map focus. The map's Tab binding intentionally creates a child while map-focused. A topic's lower control toggles its fold; its upper header starts a branch drag. The lower-right shared resize handle changes semantic spacing instead of setting arbitrary topic rectangles.

On macOS, Primary means Command. The binding policy supports Control on Windows/Linux, but this native app and its native evidence are macOS-only. Common bindings are:

| Action | Target chord or command |
| --- | --- |
| Child / sibling / previous sibling / insert parent | Tab / Enter / Shift+Enter / Shift+Tab |
| Edit / multiline edit | F2 / Alt+Enter |
| Commit / newline / cancel while editing | Enter / Shift+Enter / Escape |
| Navigate / extend selection | Arrows / Shift+Arrows; PageUp/Down and Shift variants |
| Begin edit at start/end | Home / End |
| Reorder / change level | Primary+Up/Down / Primary+Left/Right |
| Fold / show next child | Space / Shift+Space |
| Fold/unfold one level / all | Alt+PageUp/Down / Alt+Home/End |
| Find / next / filter / node list | Primary+G / Primary+Shift+G / Primary+F / Primary+Shift+F |
| Outline / connector / hyperlink | Primary+Shift+O / Primary+L / Primary+K |
| Notes / show notes | Primary+. / Primary+Shift+. |
| Undo / redo | Primary+Z / Primary+Shift+Z |
| New / open / save | Primary+N / Primary+O / Primary+S |
| Zoom | Alt+Up/Down; Fit in toolbar |
| Move destination, side, spacing, style, tags, icons, recover, import | F6, Enter → Commands palette |

The complete machine-readable inventory is `tests/mindmap/freeplane-reference.json`. Primary+D remains reserved for Freeplane clone semantics, which are excluded; Duplicate is explicitly named in the palette. Primary+Space is not captured on macOS because of Spotlight; Fold children has a palette entry. Summary nodes and their reserved chord are excluded. Native editor text selection and clipboard are kept separate from the application-local structured branch clipboard. Active marked composition owns Enter/Escape. Deterministic composition events are tested; physical input-method behavior is not accepted.

Move branch opens the searchable outline destination list. Up/Down chooses, Enter previews, Left/Right adjusts insertion slot and Enter commits; Escape cancels. Pointer header dragging uses the center of a target as its parent destination, and the top/bottom quarter as before/after sibling destinations. Dragging onto the root chooses its left/right side by pointer position. The committed layout provides stable hit regions while proposed geometry is shown. A folded destination reveals after a 0.6-second dwell; shared canvas frame ticks provide autopan. Each successful move is one semantic history step, invalid root/cycle moves are rejected, identical moves add no history, and cancellation restores temporary reveal. Keyboard side/spacing commands offer equivalents. While dragging, the moved branch follows shared canvas pointer geometry immediately and neighbors keep stable positions. After commit, affected visible neighbors interpolate from their current displayed bounds to the final layout over 180 ms; the moved branch reaches its final destination immediately. Frame ticks only change derived shared-canvas geometry, never semantic content or undo history. New commands settle pending motion; Undo discards it. The macOS host follows the system Reduce Motion preference, including changes while running; `MotionPolicy.REDUCED` supplies the same immediate final layout to other consumers. Replay explicitly exercises both policies. Hidden/newly revealed topics appear directly. All drawing, mounted controls, hit regions and semantics consume the same canvas geometry; destination hit regions during drag remain stable.

Search, filter and outline use the same ordered tree and include breadcrumbs/IDs to distinguish duplicate names. Temporary reveal does not overwrite fold preferences. Shift+Space reveals successive children without moving focus. Folding holds the selected topic's screen anchor. View changes are outside content undo; undo preserves current fold preferences for surviving IDs. Crosslinks are distinct from ancestry; connector commands support label editing/removal. Notes, inert hyperlink text, tags, icon names and four basic styles are stored as metadata. There is no HTML renderer, URL launcher, scripting, add-on system or cloud service.

## Model and persistence contract

A document has one stable root, unique positive topic IDs, exactly one parent per non-root topic, explicit ordered child lists and no cycles/disconnected records. Named domain types describe side, arrangement, style, commands, editor fields and application sessions. Root-side and per-topic spacing drive deterministic measured layout; two-sided and right-only arrangements are available. Text measurements are cached estimates from the ordinary component measurement API, not native glyph-run measurements. Camera motion does not remeasure topic text. Full layout traversal and application publication still touch the document; this is not a completed incremental-layout performance solution.

Semantic operations work on candidates and `MapHistory.commit` validates before publication. The history retains at most 33 snapshots and monotonic ID high-water marks. Stale generations cannot commit a move or restore an old editor snapshot. Undo/redo, delete/restore incident links and structured copy/paste retain/remap IDs appropriately. Structured copies preserve internal links and deliberately omit links outside the copied forest. Direct low-level model mutation requires validation; it is not a substitute for the application's transaction boundary.

The native format is UTF-8, line-oriented and human readable. Version 1 begins with `MOXI-MINDMAP`, version, root ID, next ID and arrangement separated by tabs. A `T` row contains ID, parent (`-1` for root), side, spacing, style, folded flag, text, note, hyperlink, tags and icon names. Preorder row order preserves sibling order. `L` rows contain crosslink ID, source, target and label. Backslash, tab, newline and carriage return use reversible escapes; malformed escapes and unknown versions/rows are rejected, without execution or permissive fallback.

Bounds: 10,000 topics, depth 256, 20,000 crosslinks, 64 KiB per text field, 8 MiB file/aggregate text, spacing −400…400, IDs below 900,000. Bounds are validation limits, not native rendering capacity promises. Escaping and row overhead can make a valid in-memory document exceed the on-disk byte limit; save then fails visibly.

Save checks the last-read SHA256, takes a nonblocking cooperating file lock, writes a mode-0600 temporary sibling, fsyncs, atomically renames and attempts directory fsync. Directory durability failures are reported. A changed external file is not silently overwritten. The stable `.lock` inode remains. Paths must resolve to bounded regular files; final-component symlinks are rejected. This is local application persistence, not a sandbox against a malicious user concurrently replacing parent directories; noncooperating writers can race the digest check. Disk/power-loss guarantees have not been fault-injected.

Recovery is a separate `.recovery` envelope containing its expected base digest and a complete document. Recover loads in memory without overwriting the saved file and rejects malformed, interrupted or stale-base envelopes. Committed edits to a never-saved map use a unique recovery path under `~/Library/Application Support/MoxiMindmap/Recovery`; Recover opens that directory. Recovery snapshots persist for deliberate recovery/inspection and are not automatically deleted. Existing maps use adjacent recovery files. Active uncommitted text/composition and fold-only view changes are not autosaved; explicit Save includes fold preferences. Open/New/Import/Recover refuse to replace unsaved semantic work; save first. Normal close does not prompt for uncommitted editor text.

## Bounded `.mm` import and provenance

The importer accepts an ordered plain-text structural subset: `map`, `node` (`ID`, `TEXT`, `POSITION`, `FOLDED`, safe inert `LINK`), icon names, and `arrowlink` destination/middle label. IDs are independently remapped. Missing/dangling/self connectors are reported and omitted; duplicate source IDs are rejected. Unknown nodes/subtrees, rich notes, HTML, formatting, attributes, hooks, scripts and unsupported connector attributes are reported rather than executed or silently promoted into topics. Unsafe/local/executable links are omitted; retained links are never opened. Unknown map versions produce a subset warning. Reports are visible in a paged, keyboard-scrollable overlay and retained as text in the controller.

`NSXMLParser` runs without external entity resolution. DTD/entity declarations are rejected, along with malformed UTF-8/XML, multiple roots, excessive bytes/depth/counts, long attributes and excessive loss categories. Unknown subtrees remain skipped even when they contain nested `node` elements. Input files remain byte-for-byte unchanged. The importer is intentionally not full Freeplane parity.

Reference: official [Freeplane 1.13.3 release](https://github.com/freeplane/freeplane/releases/tag/release-1.13.3), commit `3a76de18523993a55bf885190438bffef38662a5`. The Apple DMG SHA256 is `f6c8639cbe91ca431c84b44eb64ab0b3f984454ec0203e1132e49586265a2347`; its Info.plist and gitinfo matched. The inventory links exact upstream menu, accelerator, platform override and listener/action sources. Source and target chords are recorded separately. Facts about bindings and behavior were independently interpreted; no GPL source or distributed map was copied, linked or translated into this implementation. Original XML fixtures are dedicated to CC0-1.0 in `tests/mindmap/fixtures/README.md`.

The official bundled reference application was launched with an isolated temporary profile and synthetic fixture; its log reached MindMap mode. Native inspection returned `cgWindowNotFound`, so no live reference shortcut/drag recordings or equivalence verdict exist. Source inspection does not satisfy that N0 gate. Inline Alt+Enter, application-local clipboard and optional root folding are explicit target differences. Live selection direction, held keys, drag hit regions, side-dependent level changes and exact undo/fold/editor parity still need equivalent-sequence comparison.

## Evidence and remaining gates

`tests/mindmap/` exercises ordered structure, mixed-script round trip, malformed records, cycle/root rejection, normalized branch moves, no-op history, incident links, fold-preserving undo, bounded deep trees, retained measurements, public projection, clean package use, actual ordinary-control events, composition arbitration, semantic pointer/keyboard preview and cancellation, spacing, stale queued work, atomic storage and hostile XML. Shared D03 contracts, native ordered layer tests and F02 lifecycle/ownership checks must continue to pass after integration.

The genuine slideshow is `artifacts/demo-slideshows/mindmap/index.html`, generated from schema-v1 `manifest.json` and its own capture recipe. It includes initial state, mixed-script edit, fold/search, keyboard preview/cancel/commit/undo, pointer preview/capture-cancel/drop/undo, side/spacing, crosslink/outline, save/recovery, visible import loss and folded/expanded 1,000-topic fixtures. Every PNG is an AppKit content-view `cacheDisplay` **offscreen-render**, not a native-window capture. F2 traverses `NSEvent` to the native queue; remaining replay steps use public `Event`/command calls on the real app. No mocked UI, diagram or reference screenshot substitutes for the running application. Manifest hashes include native `.m` and `.h` dependencies, base revision and scoped dirty sources. PNG/HTML stay ignored; recipe, manifest, sources and docs are reviewable. The local recipe regenerates these artifacts from the current implementation.

Measurements and exact remaining gates are recorded below. Full logs use `/tmp/moxi-d04-*.log`. These data do not claim independent users, assistive technology, physical input, allocator instrumentation or frame presentation acceptance.

Before parent integration and neighbor reflow, the worker’s dirty-source checks passed: D04 model/layout/application/failure contracts, 69-entry reference inventory, native storage/import checks, clean precompiled consumer, genuine native replay, shared canvas contracts, D03 native layer/isolation/capacity regression and F02 lifecycle integration. That worker capture contained 17 PNGs and 171 source hashes, independently rechecked against the worktree; all PNG/HTML artifacts remain ignored. Key mixed-edit, destination-preview, outline, import-report and large-fixture frames were visually inspected. Full final logs are `/tmp/moxi-d04-final-{capture,consumer,shared-contract,shared-layers,f02}.log`, with `/tmp/moxi-d04-contract-suite.log` and `/tmp/moxi-d04-storage-test.log`. Compiler warnings remain, including existing deprecated string interop and an unused shared-surface assignment; no warning cleanup is included.

Parent integration checkpoint: model/layout/failure and application checks, the 69-entry reference inventory, storage/import checks, clean precompiled consumer, shared canvas/native-layer contracts and F02 lifecycle checks passed. The added neighbor-reflow and exact-final-bound regression tests passed, and the updated native executable built successfully. The benchmark programs completed; their combined shell invocation then failed because the script was edited while running. The final script passes `bash -n`; the native build was run separately and passed. Full native replay and fresh 20-frame slideshow capture after these changes remain pending at the pause checkpoint. No physical IME, VoiceOver, live Freeplane equivalence, full repository suite or remote CI was run by the parent for this checkpoint.

## Shared-canvas adaptations and integration

Six existing source files have bounded adaptations for this consumer; `pixi.toml` only adds uniquely named tasks:

- `surface.mojo`: optional application toolbar/search labels and an opt-out of generic default commands prevent reference shortcuts being reinterpreted. Public toolbar focus helpers support escape from map focus. `propose_destination(..., semantic_graph=True)` permits stable-edge rerouting, normalized port-anchor changes and temporary visibility for tree reparent/side/reveal previews; stable counts/IDs/content/port ownership/types/directions and graph-policy validation remain mandatory. Its default retains the original geometry-only contract.
- `native.mojo`: search/report ordinary controls are ordered after graph interaction overlays, preventing topic panels from covering report text; existing custom slices remain intact.
- `runtime.mojo`: toolbar focus stays in ordinary control arbitration instead of being stolen by application map shortcuts.
- `commands.mojo`: a named Option-only modifier supports reference fold/zoom chords.
- `event.mojo` and `native/macos_window.m`: F2/F6/PageUp/PageDown keys and map-focused logical accelerators survive AppKit text interpretation. Active text editing retains its responder path; Option-letter dead keys remain with the input method. F02 callback ownership and D03 native ordered slices are unchanged.

Integration checks cover the D04 tasks above, `canvas-contract`, `canvas-native-layers`, and the existing native lifecycle contract. Rebuild/recapture after committing source changes so the gallery hashes identify the reviewed implementation.

## Measurement snapshot

Host: Apple M4, arm64, macOS 27.0.1 (26A434). The table below records the worker’s pre-reflow local samples, not a controlled performance lab. Parent integration measurements follow below. The layout loop takes 21 edits after cold construction; nearest-rank p95 is sample 20 and p99/max sample 21. The deep fixture uses bounded chains of up to 200 topics, distributed under the root. The rich fixture has 1,000 long mixed-script labels/notes and 998 crosslinks. All timing is CPU wall time; native submission is excluded from the benchmark.

| Layout fixture | Visible / total | Cold layout ms | Edit p95 ms | p99 / max ms |
| --- | ---: | ---: | ---: | ---: |
| Wide 100 | 100 / 100 | 0.216 | 0.076 | 0.089 |
| Folded 100 | 1 / 100 | 0.009 | 0.005 | 0.006 |
| Deep 100 | 100 / 100 | 0.196 | 0.092 | 0.097 |
| Wide 1,000 | 1,000 / 1,000 | 1.848 | 0.645 | 0.704 |
| Folded 1,000 | 1 / 1,000 | 0.025 | 0.018 | 0.019 |
| Deep 1,000 | 1,000 / 1,000 | 1.931 | 0.903 | 0.914 |
| Wide 10,000 | 10,000 / 10,000 | 18.949 | 14.820 | 17.550 |
| Folded 10,000 | 1 / 10,000 | 0.299 | 0.377 | 0.424 |
| Deep 10,000 | 10,000 / 10,000 | 22.001 | 9.981 | 11.504 |
| Rich 1,000 | 1,000 / 1,000 | 563.981 | 0.636 | 0.656 |

Last repeated edits remeasured one visible topic (zero when folded) and changed zero box positions once label dimensions stabilized. The rich fixture publishes 1,997 ancestry/crosslink edges. Projection and encode/decode timings are in `/tmp/moxi-d04-benchmark.log`; rich cold measurement cost is substantial. Cached local-label timings do not establish broad reflow or high-crosslink application latency.

Actual `MindMapApp` construction/publication/paint-list work is measured separately at a 1180×820 viewport:

| Topics | Folded | Construct ms | Semantic update ms | Paint-list ms | Ordinary commands |
| ---: | --- | ---: | ---: | ---: | ---: |
| 100 | No | 10.886 | 1.816 | 0.351 | 213 |
| 100 | Yes | 0.634 | 0.565 | 0.070 | 17 |
| 1,000 | No | 86.708 | 9.338 | 1.242 | 213 |
| 1,000 | Yes | 4.960 | 4.114 | 0.364 | 17 |
| 10,000 | No | 709.507 | 106.739 | 10.207 | 213 |
| 10,000 | Yes | 139.554 | 58.083 | 6.892 | 17 |

These matrix rows are single samples. A separate 21-sample 1,000-topic application test measures edit through paint-list at **10.759 ms p95 / 11.829 ms max**, and move preview+commit through paint-list at **33.908 ms p95 / 85.237 ms max**. The provisional 8 ms hot-interaction budget is **not met**. Constructing mounts and projecting hidden records also remain substantial work even when drawing is culled. Full-frame layout, search and report building are synchronous and bounded by document limits; they are not background-scheduled.

Parent integration measurements include neighbor reflow and were taken while other compilation work shared the host. Across 21 samples, 1,000-topic edit through paint-list measured **63.941 ms p95 / 64.285 ms max**; move preview and commit measured **198.045 ms p95 / 198.232 ms max**; one reflow frame through paint-list measured **3.190 ms p95 / 38.506 ms max**. These runs confirm the interaction budget remains unmet. They are not a controlled before/after comparison, and a low reflow p95 does not establish native frame latency. The 10,000-topic expanded application took 1,454.325 ms to construct, 349.229 ms for its single semantic update and 32.323 ms for paint-list generation. No allocator, GPU or display measurements were collected.

Viewport culling keeps these regular application samples at 213 ordinary commands. A deliberately huge logical viewport produces **4,013 ordinary commands for 1,000 topics** and is explicitly **not submitted** to the inherited 1,024-command native presenter. The real replay submits a viewport-culled expanded 1,000-topic map (213 commands) and a folded map (17). That is not fully visible 1,000-topic or 10,000-topic native acceptance. The presenter rejects over-capacity submission; this work does not lift D03's limit.

Remaining release gates, with no implied acceptance:

- Live pinned Freeplane equivalent keyboard/branch-move sequences, held keys, side-dependent levels, editor/fold/undo parity and host-layout conflicts.
- Physical non-US keyboard and marked-text IME behavior, selection/caret fidelity while transformed, and mixed RTL/combining text with native measurement. Synthetic events and one AppKit F2 key are insufficient.
- Actual screen-reader navigation/announcements and independent keyboard/pointer usability. VoiceOver was kept paused; shared AX publication and F02 automated checks are not a human assistive test.
- The 8 ms p95 interaction target, broad reflow/search latency, fully visible large-native capacity, next-60-Hz-frame end-to-display timing, allocation counts, retained memory and GPU/presentation work. No such measurements were fabricated.
- Fault-injected storage interruptions/fsync failures/power loss, full crash recovery of active uncommitted composition, distribution/notarization and cross-platform native hosts. The tested recovery envelope handles stale/malformed files, not every storage failure mode.
- Independent reduced-motion interaction review and physical system-preference changes. Deterministic tests cover neighbor interpolation, exact completion, one-step history, cancellation, mid-animation Undo and the reduced-motion policy; these do not establish human usability.

Confidence is high in the specifically passing automated contracts and recorded local transitions, moderate in unexercised native usability, and insufficient for release acceptance. Reproducible contradictory transitions or reference/physical testing would change that assessment. Shared native regression results must be reevaluated after any parent integration changes.
