# Moxi execution plan

## Remaining work after the gallery review

### November 25 implementation

| Track | Verified on the implementation branch | Open acceptance |
| --- | --- | --- |
| D04 · Dense mind maps | At 1× and 0.5×, pressing either side's distinct branch terminal selected the intended branch. Culling reduced 4,851 edge commands to 17 in a 1,000-topic fixture. The same pinned benchmark driver built against both revisions. [24 native frames and replay instructions](https://github.com/davidmashburn/moxi/tree/7e8eb35/artifacts/demo-slideshows/mindmap) | Independent runs measured 6.22 and 9.07 ms p95 text-input CPU. Repeatable 8 ms performance, 1,000 simultaneously visible topics and physical input remain open. |
| D08 · World-panel text | Insertion and substring rectangles projected to the destination within 0.01 point. A partly clipped two-character range now falls back to the supported screen editor. [Native replay](https://github.com/davidmashburn/moxi/tree/73806fd/examples/spatial-world-panel) · [Six-frame gallery and checks](https://github.com/davidmashburn/moxi/tree/033596d/artifacts/demo-slideshows/spatial-world-panel) | Physical IME placement, inverse character picking and world semantic hit testing remain open. |
| P05 · Linked notebook plot | A freshly built renderer emits unique SVG clip IDs. Removing the focused record reveals the replacement row without moving the notebook. Separate outputs retained focus, and retry and kernel restart recovered the plot. [Reproduction and evidence](https://github.com/davidmashburn/moxi/tree/a4f7e00/examples/linked_notebook) | Shared adapter extraction, real remote-host operation and assistive technology remain open. |
| P06 · FDG native export | GTK exported SVG, PNG and PDF. Cancel preserved the destination and the next Save reproduced its SVG. An exploratory AppKit Save produced an SVG that independently reopened pixel-for-pixel. AppKit Cancel passed separately. [Dialog evidence](https://github.com/davidmashburn/moxi/tree/aedd058/examples/fdg/tests/dialog) | The successful macOS Save lacks a launch-time binary hash. Recovery Save, Escape cancellation, Mac PNG/PDF, physical input and distribution acceptance remain open. |
| D06/D07 · Spatial renderer | Native sanitizer runs exercised six application replays, 20 single-view cycles and 20 linked-view cycles. The assembly test rejected failure and missing submissions on its right view. [Native evidence](https://github.com/davidmashburn/moxi/tree/0c8c8a5/docs/evidence/spatial-native-2026-11-25) | Leak detection, GPU instrumentation and sustained presentation performance remain open. |
| E01 · Category labels | All nine Wave A families identify categories. Grouped and stacked bars identify all three series, and the population pyramid labels both sides. [Nine-family comparison](https://github.com/davidmashburn/moxi/blob/e533797/artifacts/demo-slideshows/e01-category-labels/comparison.png) | The pyramid title and numeric ticks crowd at 180 × 150. Broader glyph coverage and physical interaction remain open. |
| E02 · Contour connectivity | The native contours matched 42 pinned saddle segments. All 50,601 sampled positions in the filled saddles agreed with the reference. [Comparison and replay](https://github.com/davidmashburn/moxi/tree/e533797/artifacts/plot-contour-connectivity) | Constant cells at the threshold follow Moxi’s upper-band rule. Radial labels, scientific review and performance remain open. |
| E03 · Chord, calendar and flow | All nine chord shapes exceeded 0.995 sampled overlap. The 19 calendar labels and four Sankey labels were within 0.48 px of their reference anchors. [Comparison and replay](https://github.com/davidmashburn/moxi/tree/e533797/artifacts/demo-slideshows/e03-flow-calendar-followup) | Raster and PDF annotations, mixed-layer framing and native-window interaction remain open. |
| E05 · Cairo export | All five PNG and PDF feature checks passed. The PDF contains a vector triangle, and a rasterized replacement failed the path test. [Comparison and replay](https://github.com/davidmashburn/moxi/tree/aa4db48/experiments/cairo-scene) | Evaluation complete. Keep Cairo experimental pending a consumer, broader Scene coverage, Linux packaging and throughput evidence. |
| E06 · Specialized catalog layouts | Funnel stages retain exact Int64 order. Parallel coordinates, bump rankings and weighted arcs matched their pinned fixtures. Eleven native clicks and seven browser selections returned their source rows. Collapsing and enlarging the viewport retained arc selection and restored finite geometry. [Catalog galleries](https://github.com/davidmashburn/moxi/tree/cca2268/artifacts/demo-slideshows/e06) · [Funnel comparison](https://github.com/davidmashburn/moxi/tree/367a7b3/examples/funnel) | Funnel palette and margins, raster/PDF labels, live native input, performance and independent visual acceptance remain open. |
| I02 · Matrix instrument | Numeric and keyboard basis edits share selection and undo. The independent check covered 88 matrices, singular and zero cases, and 320/390-pixel layouts. [Matrix walkthrough](https://github.com/davidmashburn/moxi/tree/0586432/artifacts/demo-slideshows/matrix-instrument) | Tested in Chrome with the Moxi Python renderer. Other engines and physical input remain open. |
| I10 · Investigation tools | A native workbench collected a named cohort, fit three models, compared residuals and reopened the saved panel in another process. The replay rejected 31 malformed configurations. [Native walkthrough](https://github.com/davidmashburn/moxi/tree/1644692/artifacts/demo-slideshows/investigation-tools) | Long coefficients and panel metadata can clip at minimum width. Integration with the existing workbench and independent panel reuse remain open. |
| I11 · Visible proposals | The native line-fit demo previews both edits, rejects stale proposals after an intervening user edit, and applies a fresh pair in one revision. The six-step AppKit replay passed. [Example and instructions](https://github.com/davidmashburn/moxi/tree/07272f4/examples/visible-proposals) · [Offline gallery](https://github.com/davidmashburn/moxi/tree/07272f4/artifacts/demo-slideshows/visible-proposals) | The bounded experiment is complete. Physical input and independent comprehension of the conflict message remain unassessed. |
| I13 · Visual execution debugger | Two rebuild policies produced identical SVGs for all thirteen actions. The debugger reported twelve evicted source readings separately from eight dropped action records. [Run and replay](https://github.com/davidmashburn/moxi/tree/8caa40f/examples/execution-debugger) | The bounded experiment passed. Native file chooser, other hosts and timing remain unverified. |
| I15 · Flight recorder | A browser download reopened after reload with the same 12 readings and peak of 84. A second file reported eviction, a missing tick and a missing async result separately. [Replay](https://github.com/davidmashburn/moxi/tree/bb25e02/examples/flight-recorder) | Bounded synthetic experiment complete. Physical sensor and worker timing fidelity are outside the recorded data. |
| I18 · Coordinated representations | A table row, scatter mark and spatial card identify the same sources in two domains. The 15-step browser replay covered filtering, grouped selection, deletion and reload. Malformed URLs now receive HTTP 400. [Example and replay](https://github.com/davidmashburn/moxi/tree/b95bfba/examples/coordinated-representations) | Bounded experiment complete. Coincident marks and independent user assessment remain open. |
| I19 · Inspectable interactions | Drag and numeric entry previewed the same sample. Escape restored the cursor. After two edits and reload, a saved command replayed once on the narrower trace, rejected a stale repeat and preserved both undo steps. [Example and replay](https://github.com/davidmashburn/moxi/tree/7695110/experiments/inspectable-interactions) | Bounded experiment complete. Native canvas and independent usability remain open. |
| I20 · Application operations | Button, replacement button, F2 and script selected the same two cohort members. The read-only route preserved membership and the write count. [Native replay](https://github.com/davidmashburn/moxi/tree/a727c2b/examples/application-operations) | Bounded experiment complete. Independent usability and physical input remain unassessed. |
| I21 · Equation linkage | Exact equation text survived layout switching, geometric edits, cancellation and shared undo. Nine model tests and 15 offline Chrome scenarios passed. [Equation walkthrough](https://github.com/davidmashburn/moxi/tree/0586432/artifacts/demo-slideshows/i21-equation-linkage) | Covers the documented grammar and session history. Independent authoring remains open. |
| P08 · 4D slice editor | The editor reopened edits across three planes. All 24 seeded legacy-mask and 12 unmasked volumes matched the pinned reference. All 24 hard-exclusion outputs matched the previous editor. One synthetic case labeled 231 voxels in legacy mode and 45 with hard exclusion. [Native frame and verification](https://github.com/davidmashburn/moxi/tree/dd80023/artifacts/demo-slideshows/sws4d-native) | Partial. Original sparse document import, real stacks, representative performance and independent scientific acceptance remain open. The application has no configured remote. |
| P09 · Linux renderer | GSK NGL on llvmpipe matched at least 99.52% of Cairo window pixels within eight RGB levels across five interaction states. With ordered X11 input, both renderer paths passed 17 input checks and 20 rapid click/type trials each. [Parity and input replays](https://github.com/davidmashburn/moxi/tree/8cf8877/experiments/linux-gsk) | Physical GPU presentation and latency, mid-frame device loss, physical input and external input methods remain open. |
| P10 · Mobile hosts | A C caller exercised the existing Mojo counter on macOS. A fresh rebuild verified the ARM64 target and export for iOS device, iOS Simulator and Android. Swapped Apple targets and a missing export failed the new checks. [Reproduce the compiler probes](https://github.com/davidmashburn/moxi/tree/22bc679/experiments/mobile-runtime) | Partial. Neither mobile shell has executed the transition. Simulator tooling requires the Xcode license agreement. Android needs a configured SDK platform and NDK. |
| P11 · Wayland and Windows | The GTK workbench ran twice under headless Sway with Xwayland disabled. Seven frames covered focus, dismissal and resize. Cross-linking produced x64 and ARM64 Windows DLLs. [Run instructions and evidence](https://github.com/davidmashburn/moxi/tree/05ba794/experiments/wayland-host) | Partial. Loading and calling the DLL on Windows, Wayland desktop integration and physical input remain open. |
| V01 · Motion from a sketch | The native editor compared two executable arm motions with an editable target. Pointer input on either pinned endpoint preserved a keyboard draft at an interior knot through apply, cancel and undo. The repaired replay reproduced all 17 original window captures. [Native walkthrough](https://github.com/davidmashburn/moxi/tree/2f7f646/artifacts/demo-slideshows/motion-model) | Participant comprehension, physical input and desktop-compositor capture remain open. |
| V02 · Compose Worlds | All 11 rule settings replayed across 13 seasons at desktop and narrow widths. Three named branches support promotion, local overrides and undo. Returning from the formula restored the draft, caret and selection direction. [Replay and captures](https://github.com/davidmashburn/moxi/tree/53a3a62/examples/compose-worlds) | Whether authors can predict delayed effects and intentionally produce a pattern requires a participant trial. |
| V03 · Invent notation | A score revision kept slot identities and focus. Fourteen tests and browser checks covered incompatible schemas, unreadable-score recovery downloads, failed writes and same-origin restart. [Evidence](https://github.com/davidmashburn/moxi/tree/bbf8b25/examples/invent-notation) | Partial. Second-author completion and discoverability remain open. |
| V04 · Spring linkage | Across 42 candidates the solver found an exact force-curve match and an alternative within 0.034 N RMS. The 546-sample derivative comparison and narrow-screen undo passed. [Run instructions and evidence](https://github.com/davidmashburn/moxi/tree/05ba794/examples/spring-linkage) | Partial. A measured linkage and independent branch-selection trial remain open. Collaborative preview loaded the app but timed out again during capture. Six offline Chrome frames are available. |
| V05 · Executable argument | The static comparison retained its cost reversal at 30 riders and reopened at phone width. The model passed all 183 input pairs. [Run instructions and evidence](https://github.com/davidmashburn/moxi/tree/05ba794/examples/executable-argument) | Partial. Reader comprehension and empirical transport costs require independent evidence. |
| V06 · Motion and sound | A two-second recorded gesture drove the flight path and sound gain. Editing a point while stopped changed both. Repeated offline PCM matched at 44.1 and 48 kHz. Cancelling a replacement preserved the prior take, and restoring the checkpoint recovered its curve and inspection time. [Recorded-gesture slideshow](https://github.com/davidmashburn/moxi/tree/3fcc04c/artifacts/v06-recorded-gesture) | Physical audiovisual timing and an artist comparison with manual synchronization remain open. |
| V07 · Oscillator lesson | Fourteen checks exercised a five-step lesson with interruption at step three. Restoration recovered text, selection direction and answer disclosure. The offline report distinguishes the control, checkpoint and explored trial. [Evidence](https://github.com/davidmashburn/moxi/tree/bbf8b25/examples/oscillator) | Partial. Whether learners predict and explain an unfamiliar result requires participants. |
| V08 · Probability instrument | Across 4,356 edits the distribution preserved normalization and enforced the pinned mean. One editable measurement transfers between the plot and triangle. Fractional previews and committed values fit at 390 px. Escape cancels a held drag in both views. [Seven source-matched captures](https://github.com/davidmashburn/moxi/tree/6a77d3e/examples/probability-instrument/evidence/attachments/v08-current-2026-11-26) | Participant prediction and explanation, physical touch and assistive technology remain open. |
| V09 · Lived spaces | Two native routes linked partition and lighting changes to sightlines. A recorded five-action sequence resumed after step three with its ordered undo intact. An independent sixteen-action recording matched every replay prefix. [Evidence](https://github.com/davidmashburn/moxi/tree/bbf8b25/artifacts/lived-spaces/i07) | Partial. A visitor-eye view, designer assessment, physical lighting and timing remain open. |
| V10 · Fictional allocations | A promoted allocation retained its reason and dissent after a branch edit. Undo cleared the decision and preserved the edit. All 18 outcomes matched the static table. [Run instructions and evidence](https://github.com/davidmashburn/moxi/tree/05ba794/examples/allocation) | Partial. A participant trial is needed to assess negotiation with the table and interactive tool. |
| V11 · Foldable motif | The linked pattern and six folded faces preserved selection. Measuring a crease retained numeric and slider drafts, and selecting a narrow neighboring face worked at 75°. [Run instructions and evidence](https://github.com/davidmashburn/moxi/tree/05ba794/examples/foldable-motif) | Partial. Physical folds, maker comprehension and document round trips remain open. |
| V12 · Personal instrument | Users authored transitions between Accent and Length and performed the same phrase by pointer and keyboard. After a startup build failure the saved graph survived copying, editing, saving and reloading. Ten Chrome scenarios and the original replay passed. [Eleven source-matched captures](https://github.com/davidmashburn/moxi/tree/6a77d3e/examples/personal-instrument/evidence/mode-graph/v12-current-2026-11-26) | Independent authorship, repeat use, motor comfort and audible playback assessment remain open. |
| V13 · Signal workbench | A keyboard-built filter and RMS patch produced 32 recorded blocks. Chrome verified invalid wiring, cancellation, failed processing, undo and reload. An idle-connection regression also passed. [Example and replay](https://github.com/davidmashburn/moxi/tree/647b31d/examples/visual-instrument) | Independent construction and diagnosis, physical acquisition and real-time measurements remain open. |
| V14 · Temperature forecast | Moxi rendered 84 frames. An artificial CO₂ covariate helped in two held-out sessions. In the reversed session it nearly doubled the error and its band covered four of 21 outcomes. [Offline exhibit and reproduction](https://github.com/davidmashburn/moxi/tree/6611891/examples/temperature-replay) | Calibration, field measurements, device integration and human evaluation remain open. |
| V15 · Pose stroke | Direct and interpolated brushes held their widths through synthetic confidence loss and reacquisition. A native Moxi renderer and five browser scenarios exercised calibration, saving, reopening and render-error recovery. [Eleven captures and replay](https://github.com/davidmashburn/moxi/tree/b03503f/artifacts/demo-slideshows/v15-pose-stroke) | Live tracking, latency, accidental activation and user comfort require a device and participants. |

### November 23 implementation

| Track | Delivered and verified | Remaining decision or evidence |
| --- | --- | --- |
| Mindmap and assembly | Replayed 20 mindmap and 14 assembly frames. Four reported mindmap defects, three assembly captions and a newly observed reflow overlap were repaired. Both galleries passed offline Chrome navigation. [Mindmap replay](https://github.com/davidmashburn/moxi/commit/7962853) · [Assembly review](https://github.com/davidmashburn/moxi/commit/eed5663) | Dense large-map edges, map capacity and physical interaction remain open. |
| Plots | Compared all 26 families against reference implementations. The three contour families now have genuine references and scalar encodings. Ten radial layouts omit Cartesian axes. Ridgeline preserves the full sampled peak on both exports. [Current comparisons](https://github.com/davidmashburn/moxi/commit/52c6a5e) · [26 historical family frames](https://github.com/davidmashburn/moxi/commit/6004afb) | The upstream ridgeline clips its peak. Its historical raster threshold fails, while the complete path geometry passes. Category labels, legends, chord aspect and seams, contour connectivity, calendar and flow annotations, and independent scientific acceptance remain open. |
| Native Python | A fresh CPython 3.11 arm64 build passed 48 native and 372 facade tests. Both wheels carry the verified notices. [Installed consumer and hashes](https://github.com/davidmashburn/moxi/tree/3e71975/experiments/python-native). Installed wheels render text and searchable vector PDF. Both local interpreters and both [fresh macOS 15 arm64 jobs](https://github.com/davidmashburn/moxi/actions/runs/45131806275) passed 48 native and 364 facade tests per interpreter. The [portable review](https://github.com/davidmashburn/moxi/blob/f9f1305/artifacts/demo-slideshows/e04-python-native/REVIEW.md) works in a clean checkout. | Keep the wheel experimental pending redistribution rights, sanitizer coverage and other host targets. |
| SeedWater | Rebuilt the external consumer against packaged Moxi. All 33 application contracts, 18 pinned scientific fixtures, 168 sampled pixels and the 13-frame replay passed. Stable cell IDs and segmentation partitions matched. Eight forced process exits at file publication boundaries preserved every published document. The native recovery flow retained the three source files. [Interrupted save evidence](https://github.com/davidmashburn/moxi/blob/e2f75cf/artifacts/demo-slideshows/sws-native/README.md). [Replay, images and source inventories](https://github.com/davidmashburn/moxi/blob/e9fd68f/artifacts/demo-slideshows/sws-native/README.md) | Real external stacks, power-loss recovery and independent scientific acceptance remain open. |
| Workbench | Import, filter, selection, CSV/SVG export, reopening, failed imports and ordinary quit passed in the signed app. A native content-view replay verifies the corrected axis ticks and legend. [Acceptance record and screenshot](https://github.com/davidmashburn/moxi/blob/fcc05cc/docs/workbench-native-acceptance.md) | The revised bundle's interactive relaunch was blocked by the window automation bridge. Physical IME, sustained presentation timing and independent human authoring remain open. VoiceOver stays paused. |
| World panels | The source-free packaged replay measured the owner-local caret at (26, 58) against the required projection at (388.62, 259.67). The screen editor passed its containment check. [Replay and decision](https://github.com/davidmashburn/moxi/blob/fcc05cc/examples/spatial-world-panel/README.md) | Keep the screen editor available. Promotion requires transformed caret and accessibility geometry plus physical acceptance. |

The browser host passed centering, keyboard input and wheel checks at 390, 900 and 1180 CSS pixels in real Chrome and Playwright WebKit. Firefox exited before page load after failing to open its test profile. The pinned compiler still lacks the Mojo/WASM target used by the separate runtime experiment.

The [catalog audit](https://github.com/davidmashburn/moxi/blob/839d0ff/artifacts/demo-slideshows/CATALOG-AUDIT.md) validated 59 manifests and 481 local frame references. A second audit in a clean checkout loaded all six refreshed galleries, verified their source inventories and counted 95 committed frames. The other 386 frames require local generation. Of all 59 historical and current inventories, six match, 45 differ and eight lack per-file hashes. The full local `pixi run check` passed at `f9f1305`. The signed workbench and packaged layout consumer have separate acceptance records. All six [hosted CI jobs](https://github.com/davidmashburn/moxi/actions/runs/45134903015) passed on published main commit `839d0ff`, including macOS validation and the installed package consumer.

### Reopened proposals

All 28 previously deferred proposals are open for implementation alongside the four gallery-review priorities. The [master inventory](DEFERRED-IMPLEMENTATION-MASTER.md#original-scope-and-execution-design--november-6-2026) supplies the scope, dependencies, storyboards and acceptance criteria for each ID.

| Group | Reopened IDs | First executable work |
| --- | --- | --- |
| Applications and hosts | P08, P09, P10, P11 | Establish the SWS4D volume fixture. Run the Linux GPU, mobile runtime and Wayland/Windows feasibility probes on their target hosts. |
| Plotting | E05, E06 | Evaluate Cairo against the scene corpus. Begin E06 against the five catalog families already present in the capability inventory. |
| Product experiments | V01–V15 | Start each proposal with its bounded experiment and use its evidence to decide on expansion. |
| Independent ideas | I10, I11, I13, I15, I18, I19, I20 | Use the seven independent entries in the master coverage map. The other idea IDs already map to existing workstreams. |

E06 is partial. The [five-family audit](https://github.com/davidmashburn/moxi/blob/53fab67/docs/dataviz-migration.md#e06-catalog-reconciliation) includes five runnable upstream references and checks 40 Moxi source rows. [Effect scatter](https://github.com/davidmashburn/moxi/commit/53fab67) now paints the halo for ordinary x/y input. Funnel, parallel coordinates, bump and arc diagrams have specialized layouts with checked source-row selection. Cross-host native interaction and independent visual acceptance remain open. Of the 28 reopened proposals, 7 have completed their bounded experiments, 21 have partial results. All 28 now have a published result. The existing pause on VoiceOver sessions still applies.

### November 20 baseline

November 20, 2026. The package and checkpoint tasks from November 9 are complete.
The repaired implementation passed all six [hosted checks](https://github.com/davidmashburn/moxi/actions/runs/44825872712).
The first editable scene supports edit, asynchronous Run, compiler diagnostics,
last-good rendering and Revert in the native Demo Browser.

All 30 galleries named for fresh review have records in the
[implementation handoff](https://github.com/davidmashburn/moxi/blob/5d85208e820446d0ebd4072987fce1f39fa1e8ed/docs/deferred-pause-handoff.md).
The capture baseline is `d7fa3ed`. The following work is still open.

1. Triage the four partial mindmap frames and stale clipping text in three
   assembly frames. Refresh the affected captures after fixes. Audit the
   remaining catalog manifests before citing them as integrated-source evidence.
2. Address plot parity by family. The 26 families passed bounded semantic
   checks. Across 156 scenarios, 36 were partial and six reference/comparison
   scenarios were blocked by absent contour, contourf and tricontour APIs.
   [Family results](https://github.com/davidmashburn/moxi/blob/5d85208e820446d0ebd4072987fce1f39fa1e8ed/artifacts/demo-slideshows/plot-wave-b-c-review/RESULTS.md)
3. Keep the native Python extension experimental pending raster text, vector
   PDF, fresh-host/ABI and redistribution evidence. Keep world-panel promotion
   rejected pending transformed IME and semantic geometry plus physical input
   and assistive-technology acceptance.
4. Resume the existing packaged workbench, physical-input and independent
   authoring acceptance tasks. The synthetic captures do not measure human
   usability or sustained presentation performance.

## Remaining work — November 9, 2026

This was the follow-through list for `main` at `b2361c2`.
[Current state](CURRENT-STATE.md#current-audit--november-9-2026) records the
implementation and CI evidence. The old proposal sequence below is historical;
landed work must not be restarted from those instructions. This reconciliation
adds no implementation or publication authorization and does not schedule the
untouched proposals.

### 1. Repair package CI and reconcile the published checkpoint

- **Owner:** native layout package inputs, starting at
  `packages/moxi_layout_native/recipe.yaml` in the implementation repository.
  Include `macos_window_state.h` and audit all transitive native include inputs.
  The current `package-consumer` CI fails before it can validate the consumer.
- **Acceptance:** a clean package build and installed consumer pass, followed by
  a green `package-consumer` job on the resulting commit. Report the other main
  jobs independently; do not substitute the earlier local checkout checks.
- **Documentation:** update `docs/deferred-pause-handoff.md` to distinguish its
  original local checkpoint from the November 6 publication and failed CI.
  Contextualize per-track “full suite/CI not run” entries in the delivery ledger
  against the subsequent aggregate checks without inventing per-track coverage.
  Correct any remaining local-only authoring status in shipped docs. Preserve
  dated evidence and distinguish separate `moxi-sws` app work from Moxi commits.

### 2. Certify the reviewed integration's demo evidence

- **Owner:** demo replay/capture scripts and `artifacts/demo-slideshows` manifests.
  Regenerate or verify provenance against the exact reviewed source, visually
  inspect the outcomes, and record reproduction commands and limits.
- **First outstanding artifacts:** D04 mindmap's 20-frame and D07 assembly's
  14-frame candidate manifests are untracked and uncertified. E02/E03/E04 and
  D08 still need fresh integrated-source gallery review. Audit the other
  manifests before treating worker captures as evidence for fixed main.
- **Acceptance:** source fingerprints match, gallery tooling passes, scenario
  outcomes and images are reviewed, and offscreen/synthetic captures remain
  labeled. Do not turn candidate files into accepted evidence merely by tracking
  them. The implementation checkout's untracked artifacts are left untouched.

### 3. Close the started tracks' explicit acceptance gaps

| Owning plans | Remaining bounded work and acceptance signal |
| --- | --- |
| [Workbench](WORKBENCH-HARDENING-PLAN.md), [application validation](APPLICATION-VALIDATION-PLAN.md), [authoring migration](docs/design/example-authoring-migration.md) | Complete existing H2/H6/native workflow and independent authoring gates; exercise launcher, packaged workflow, chooser and physical input. Historical timings and agent exercises do not establish current human acceptance. |
| F01/F02 and [host architecture](CROSS-PLATFORM-HOST-ARCHITECTURE-PLAN.md) | Verify the promised text/lifecycle paths on applicable hosts; physical IME, native menu/sheet presentation and sustained resource behavior remain open. Keep the eight-session AppKit profile distinct from retained-layout and Metal support. |
| [Browser](docs/design/browser-execution.md) and [server views](docs/design/server-backed-views.md) | Test other browsers and supported toolchains, actual remote/authenticated transport, revision restart through the browser, disconnect/load/long-session behavior and human interaction before broader support claims. The reduction transfers fewer bytes but is slower in the Python sweep; no overall performance or memory win is established. |
| [Jupyter](docs/design/jupyter-integration.md), P03–P05 | JupyterLab and its kernel ran in separate network namespaces on one host. Retry recovered after a network interruption, and keyboard scrolling at 480 px kept focus in the widget. [11 network scenarios and 16 ordinary notebook checks](https://github.com/davidmashburn/moxi/blob/abe04fd/examples/fdg/notebook/network/RESULTS.md). Test physical remote hosts, repeated restart after a partition, other frontends and native-viewer restart ownership. Dense labels and zoom overflow remain open. Extract a shared notebook adapter only after the two consumers demonstrate a common contract and the P04 remote gate passes. |
| [FDG](docs/design/fdg-port.md), P06 | Exercise actual Save-dialog save/cancel and a fresh distribution build/install. Existing Ubuntu GTK/Xvfb evidence is emulated; wheel is not manylinux and does not bundle system GTK or optional rsvg-convert. Verify claimed target hosts and distribution/license scope. |
| [Watershed](docs/design/sws-port.md), P07 | In the separate app repo, rerun native smoke/replay after recovery fixes, test real external image stacks and power-loss recovery, and obtain human scientific acceptance. Retain pinned-reference equivalence evidence; do not infer app delivery from Moxi sampling hooks alone. |
| [Math backend](docs/design/math-backend-experiment.md) / [editor](docs/design/math-editing.md), D01/D02 | Physical US/non-US keyboard/IME, typography, simultaneous font/view sessions, lifecycle/leak checks and fresh-host packaging/signing/runtime redistribution. D02 now exists; D01's old “editor integration must follow” is not unstarted work. |
| [Canvas](docs/design/canvas-interaction.md) / [mindmap](docs/design/mind-mapping.md), D03/D04 | Resolve or explicitly narrow the 8 ms large-graph budget and 1,024-slot native capacity boundary; validate native capture-loss/editing/chooser interactions and independent usability. Measure allocation/GPU/input-to-presentation costs before promoting performance claims. |
| [Spatial](docs/design/3d-interaction.md), D05–D08 | Keep S0's negative renderer decision. Production selection requires a public per-window compositable GPU interface, a maintained candidate and sustained presentation-inclusive measurements. D06/D07 consumers exist; D08 promotion stays rejected until transformed IME and semantic geometry agree. Retain screen-space controls as the supported alternative within the experiment. |
| [Ecosystem](ECOSYSTEM-CONVERGENCE-PLAN.md), E01–E04 | Resolve labels/legends/theme and reference parity gaps. Contour/tricontour reference APIs are absent at pinned upstream; document a defensible reference strategy before parity claims. E04 remains experimental pending ABI/host/sanitizer/runtime redistribution evidence; native raster text/vector PDF are unsupported. |
| [NotImplemented](docs/not-implemented-pattern.md), N01 | Native/manual acceptance and explicit character-wrapping limits; no new component implementation is needed. |

VoiceOver remains **paused**. Record that gate as open; do not schedule or run a
VoiceOver session without the user's decision to resume it. Accessibility models
and automated semantics do not replace that human acceptance.

### 4. Keep untouched proposals visible and deferred

P08 SWS4D, P09 Linux GPU/H4, P10 additional mobile adapters, P11 additional host
follow-through, E05 Cairo evaluation, E06 catalog reconciliation, V01–V15 and
I10/I11/I13/I15/I18/I19/I20 remain pending. The
[master list](DEFERRED-IMPLEMENTATION-MASTER.md#current-delivery-status) retains
scope, dependencies and storyboards for all 50 IDs. Starting them needs a new
implementation decision; this planning update does not reprioritize them.

## Historical execution plan

The material below preserves earlier design reasoning, milestone contracts and
proposal sequences. “Next”, “proposed” and non-goals in those dated sections
belong to their original baselines. Use the current list above for remaining
work, and the master status table for delivery. Existing acceptance criteria
remain valid unless an explicit later decision supersedes them.

This plan converts the implementation audited in [CURRENT-STATE.md](CURRENT-STATE.md)
into a supportable product boundary. It deliberately prioritizes contracts and
evidence over more feature breadth.

## Native math editing proposal

The [native math editing plan](docs/design/math-editing.md) scopes a reusable
WYSIWYG editor and typesetting library as a demanding interaction use case for
moxi. Every 2D document state has a lossless, human-readable/editable text
counterpart whose structure directly mirrors the visual slots; WYSIWYG remains
the primary editing target. The [backend experiment](docs/design/math-backend-experiment.md)
compares SymEngine and SymPy before choosing an initial adapter. These proposed
workstreams do not supersede the execution priorities below.

## Mind mapping and canvas interaction proposals

The [mind-map application plan](docs/design/mind-mapping.md) specifies rapid
topic editing, folding, branch restructuring, crosslinks, persistence, and
bounded import. The [canvas framework plan](docs/design/canvas-interaction.md)
develops the reusable native interaction layer alongside it, with a freeform
graph editor as a second consumer. The app owns hierarchy and tree layout;
the framework owns viewport, selection, gestures, and graph interaction.
The [reference assessment](docs/design/canvas-interaction.md#reference-assessment-and-native-design-decisions)
captures which xyflow behaviors transfer and why browser-specific mechanisms do
not. The first gate proves ordinary native controls under canvas transforms,
including layout-driven port anchors, editing/focus preservation, and localized
execution, before expanding graph features.
Freeplane-compatible keyboard commands are the app default, and the framework
supports application shortcut profiles. Both require responsive feedback,
coherent undo, native input/accessibility
evidence, and a small public application API. These proposals do not supersede
the existing workbench hardening priority or require the math editor to ship.

## 3D interfaces and spatial interaction proposal

The [3D interface scope](docs/design/3d-interaction.md) explores embedded
viewports, spatial workspaces, scientific probes, linked views, projected UI,
world-space components, and future immersive input. The initial proposed path
proves native viewport hosting, reactive inspection, and precise manipulation
with two consumers. World-space text/UI and XR have separate evidence gates.
Renderer selection remains open; current GPU support does not establish a 3D
scene contract. This proposal preserves existing execution priorities and does
not promote deferred 3D plotting features into the current plotting scope.

## Combined ideas and comparative rankings

The [idea reference](ideas/README.md) explores 15 broad product visions using
plotting, structured math, graphs, native controls, and spatial interaction as
creative ingredients. It retains the earlier 21 briefs while separating
[framework questions](ideas/FRAMEWORK.md) from product opportunities. The
[comparative rankings](ideas/RANKINGS.md) assess agency, expressive ambition,
and transfer across domains independently from first-experiment cost. Current
demonstration applications do not define the horizon of those visions.
Existing implementation evidence remains distinct from proposed integrations.
The collection does not change execution gates or schedule the broader visions
as release requirements; the speculative ranking is not determined by proximity
to the workbench.

## Product decision

Position Moxi as a **Mojo-native, inspectable UI and visualization core with
optional agent-safe capabilities**. Do not position it as feature parity with
Xilem, a native-widget wrapper, or a complete cross-platform application
framework.

The differentiator is the combination of:

- value-owned Mojo components and explicit mutation;
- a backend-neutral, inspectable rendering seam;
- deterministic headless behavior and performance accounting;
- native macOS presentation plus honest platform capability reporting;
- typed plotting built on the same scene/runtime contracts; and
- an optional authorization boundary for UI and agent actions.

## September 18 application validation priority

The next execution milestone is specified in
[APPLICATION-VALIDATION-PLAN.md](APPLICATION-VALIDATION-PLAN.md): a bounded
macOS data workbench that proves linked plots, ordinary controls, text input,
virtualized rows, accessibility, and state preservation in one useful workflow.
This sharpens the existing product decision around interactive visualization
close to Mojo computation. It is a hypothesis to validate, not a new support
claim or a mandate to expand all adjacent surfaces.

Start with A1's fixture-driven workflow and A2's native interaction evidence.
Use that evidence for targeted API improvements and bounded local data import,
then make a measured support decision. S3 is part of this milestone; S2 is
informed by demonstrated ownership or authoring problems. Required Gate 2 and
Gate 4 slices can precede Gate 3. The numbered gates below remain capability
boundaries, not a requirement to implement another platform before validating
the existing application stack. Historical completion records are preserved.

## Relocated implementation-branch proposals

The proposal sections formerly kept in `docs/project-planning.md` on
`feat/data-workbench` now live on this planning branch. Their source is
implementation commit `c8c7cbb7741519c9796a02ffa25c02e701b2f58a`; the new
`NotImplemented` scope was an uncommitted addition to that document.
This is a documentation reconciliation, not a new implementation audit or a
change to execution priority. The existing
[workbench hardening plan](WORKBENCH-HARDENING-PLAN.md) continues to own the
application follow-through. Historical validation claims elsewhere in this
branch retain their original evidence dates.

- [Not implemented pattern](docs/not-implemented-pattern.md) scopes a reusable
  informational component for intentionally unfinished application features.
  It is a candidate follow-up, not an implemented widget or an automatic
  exception to the next gate's restriction on new public widget types.
- [Historical post-0.5 roadmap and plotting design](docs/post-0.5-roadmap.md)
  preserves the former version milestones, platform sequence, plot grammar,
  interaction model, validation ideas, and non-goals. Its illustrative APIs
  and old completion/deferment language are historical. The owning gates below
  control future decisions; do not execute the archived checklist as a second
  roadmap.

| Relocated topic | Owning plan or gate | Reconciliation and remaining decision |
| --- | --- | --- |
| Portable font fallback, paragraph policy, native editing, menus/dialogs and drag/drop | Gate 2 below; workbench hardening for application acceptance | Retain the existing incremental ownership and native-evidence gates. Use the implementation support matrix and host ADR for current platform boundaries before selecting another slice. |
| Localized execution and scrollbar/viewport interaction | Gate 1 localized-execution record and application validation | These are not wholly unimplemented. The current feature inventory documents localized execution and pointer-driven scrollbar input. Protect that behavior; scope only a demonstrated adoption, preservation, or viewport defect. |
| Scoped request lifetime, async adapters, build purity and ergonomics | Contract decisions below; application validation for a concrete adapter consumer | The implementation document records shipped scoped-request and deterministic adapter seams. Transport, real executor ownership and deadline policy remain adapter responsibilities. Preserve those seams rather than reopening the component trait or adding a generic effect framework. |
| Platform order and 0.9 host milestones | Gate 3 below | The older macOS/iOS/Android/Web sequence is historical. The implementation support matrix now records a linked provisional Linux retained host. Future target selection starts from that evidence; browser host artifacts still do not establish a Mojo WASM package. No new platform or production support claim is made by this move. |
| Canonical fixtures, reference parity and performance gates | Gate 1 scenario/benchmark records; application validation | Reuse the existing registry and evidence policy. The archived proposal to create a registry is superseded; fixture metadata ownership and additional reviewed baselines remain decisions under the existing gates. |
| Supported 2D plotting, streaming, interaction, export quality and release boundaries | Gate 4 below; ecosystem convergence E3–E8 where applicable | Harden the documented package and backend subset. Versioned spec serialization and Python PNG/SVG/PDF exports already have implementation documentation; their mention as future work in the archive is not evidence that they are absent. Do not equate Python export coverage with native/GPU parity. |
| Extended encodings/transforms/scales/marks, polar/geographic/3D, function sampling and editing tools | Explicit non-goals below; ecosystem convergence capability waves for already-scoped overlap | Preserve the design vocabulary in the archive without scheduling its entire catalog. Any promotion needs a concrete consumer, a verified gap in the relevant package, and its own acceptance and performance evidence. |
| Capability-bus platform executors, transport, persistence, deadlines and cancellation | Contract decisions and capability-runtime non-goals below | Keep the in-process authorization boundary distinct from host request scheduling. Existing request machinery is not evidence that every external capability executor or transport has been implemented. |
| Earlier 0.6–1.0 release numbering | Existing gate exit criteria and support decisions | Preserve the original milestones as history; they no longer establish release dates, priority, or completion for every backend. |

Evidence consulted for this reconciliation is the implementation checkout's
`docs/features.md`, `docs/plotting.md`, `docs/python.md`,
`docs/support-matrix.md`, `docs/architecture/adr-005-host-frame-contract.md`,
the request-lifetime assertions in `tests/execution.mojo`, and this branch's
existing gate/current-state records. No builds, runtime tests, benchmarks, or
native acceptance checks were rerun. Code and current implementation docs
remain the source of truth; select and verify an individual follow-up before
changing its completion status or priority here.

## Contract decisions to hold

1. **State source of truth:** application/component values own durable UI
   state. Retained widgets own only interaction/render state needed between
   builds. Native handles, renderer caches, and task executors stay outside
   declarative values.
2. **Mutation path:** typed actions and normalized events are the only
   first-class mutations. Callbacks and live objects do not cross component,
   capability, serialization, or host ABI boundaries implicitly.
3. **Identity:** stable typed keys identify components, views, data rows, and
   resources. Integer offsets may remain an internal compatibility mechanism,
   but must not be the long-term composition API.
4. **Rendering oracle:** `Scene` plus declared resources is the portable
   correctness contract. Software rendering supplies deterministic evidence;
   native/GPU paths declare coverage and fallback explicitly.
5. **Serialization:** only versioned value specifications are serializable.
   `PlotSpec` is the model to follow. Components, platform handles, closures,
   caches, and leases are runtime-only.
6. **Support lanes:** every public feature is labeled `stable`, `provisional`,
   `experimental`, or `host-artifact`. Platform support separately records a
   portable contract, a buildable host, and a linked runtime.
7. **Examples are tests:** a capability is not demonstrated by a hand-built
   mirror. One scenario definition feeds its demo, contract test, visual
   reference, and benchmark where applicable.

## Reference and parity strategy

- Use `SoftwareSceneRenderer` as the deterministic renderer oracle and replay
  the same scene/resource corpus through SVG and supported native/GPU paths.
- Use real platform behavior for platform claims: CoreText/AppKit for macOS
  text and accessibility, browser Canvas/ARIA in a browser, and the actual
  UIKit/Android accessibility APIs when those targets advance. Static SVGs or
  hand-drawn widget imitations are documentation, not behavioral references.
- Compare structure, bounds, semantics, command order, and stable checksums
  exactly where possible. Use documented tolerances only for raster output
  that legitimately differs by platform, font, color space, or GPU.
- Record unsupported commands and fallback use as parity results. A visually
  plausible fallback must not silently count as native coverage.

## Gate 1: contract hardening

This was the next milestone. All six workstreams have now been exercised in
the ordered pass; new widget or plot-family work remains out of scope until
the follow-on boundaries below are deliberately accepted.

### Gate 1 progress at local `main` `9fcd3b5` (September 7, 2026; implementation follow-on `2987c39`)

The ordered implementation pass has delivered the Gate 1 slices. The status
below records what is proven in source and validation and leaves the remaining
support boundaries visible for the next pass.

| Ordered slice | Status | Evidence | Still open |
| --- | --- | --- | --- |
| 1. Public API audit | Inventory, focused import lanes, and compatibility/deprecation enforcement complete | `e418b29`, `7295e2e`, `721e50a`, generated `docs/api-status.md`, 887 export classifications, `docs/api-lanes.tsv`, `docs/api-compatibility.tsv`, `api-status-check`, `tests/api_lanes.mojo` | review each future move against the manifest and decide which provisional lanes become package promises |
| 2. Canonical scenario registry | Registry, consumer inventory, and descriptor-driven fixture records complete across all seven families; feature interaction state remains module-local | `0991f29`, `90f2aef`, `4ef1171`, `5f9c44b`, `332eb07`, and `a50900b`, seven descriptors, demo mapping, scenario checker, registry test, golden/benchmark metadata, and theme/capability/fractal records | make expected semantic/counter/checksum metadata descriptor-owned and enforce every behavior fixture through the catalog check |
| 3. Software goldens and browser lifecycle | Software/host gates complete; native text/scene replay, an offscreen screenshot tolerance lane, and a manually reviewed visible AppKit capture are exercised | `62a9caa`, `9c25379`, `b74d4eb`, and `707ff64`, seven exact PPM goldens, shared text corpus, CoreText replay, Metal scene replay, browser lifecycle evidence, native PPM capture, checked-in tolerance/mask report, and `/tmp/moxi-visible-appkit-current.mov` | retain visible-state review artifacts; real device/browser automation and a linked Mojo Web runtime remain open |
| 4. Typed localized execution | Keyed parent/child scheduling is integrated into the opted-in `App` path; deterministic indexes cover scope, dirty-component, keyed topology, and dependency-edge fanout; an out-of-order registration contract covers middle insertion/removal; a two-child preservation harness covers IME/focus, root scroll, sibling popup, accessibility identity, pointer capture, and deeper nested state; non-opted-in components retain an explicit root fallback | `676cbd4`, `b813e53`, `83030c3`, `06231a5`, `9606b24`, `15648d9`, `7b9d8bd`, and `2987c39`, `DependencyFanoutIndex`, `IntIndex`, `KeyedSubtreeDescriptor`, `KeyedSubtreeSchedule`, `KeyedSubtreeExecutor`, retained parent composition, keyed insertion/removal/reorder counters, `App.execution_work_counters()`, and execution/composed integration tests | reduce counted root-wide fallback as more components opt into localized hooks |
| 5. Structured benchmark profiles | Protocol, localized matrix, reviewed macOS baseline, same-environment comparison, dispersion policy, CI evidence, and a portable deterministic contract are complete | `4df99c8`, `850f610`, `75fea05`, `5a0e2ec`, `2a1a112`, `26aa56`, `64f27a2`, `363cae2`, `7137c48`, and `43e7cb0`; schema v2, `benchmark-quick`/`benchmark-full`, 1/10/100-child counters, policy-checked 30-run baseline, median/p95/MAD comparator, and cross-host quick contract | compatible reviewed full-profile baselines beyond macOS arm64 |
| 6. Documentation reconciliation | Main docs and planning ledger are current through the ordered implementation and release pass | `87e79bf`, `d6c008c`, `e428303`, `8100623`, `332eb07`, `b74d4eb`, `7295e2e`, `64f27a2`, `363cae2`, `721e50a`, `06231a5`, `707ff64`, `7137c48`, `43e7cb0`, `7e12d3c`, `9606b24`, `15648d9`, `7b9d8bd`, and this update; README/API/text/performance/benchmark/demo/comparison docs plus generated API status and status ledger | keep both branches synchronized as follow-on slices land |

The current-head repository gate passed at `2eeb802`: 70 Mojo tests,
API/demo/scenario/visual checks, native text and scene replay, native
screenshot tolerance evidence, host checks, package-consumer checks, and build
validation; the canvas vertical slice also passes its focused pixel/parity
tests, shared primitive/theme/plot fixtures, stable input-error checks,
canonical export, checksum manifest, benchmark task, and indexed-channel
package consumer. The release/package gate remains evidenced at
`7137c48`; the follow-on changes dependency fanout lookup and adds
interaction/state preservation assertions without changing the public API or
intended scheduling semantics. The clean full profile produced 30 samples
across 10 cases; the reviewed macOS baseline was refreshed after the native
geometry fix, and the comparator reports dispersion while enforcing the
registered host matrix. The portable quick contract also passes on the
candidate report. A visible AppKit
capture was manually reviewed, but this remains evidence for a host review
lane, not a claim that linked non-macOS runtimes or additional full-profile host
baselines are complete.

### 1. Classify and narrow the public API

The first pass landed the inventory, lane file, focused imports, and API check
at `7295e2e`; `721e50a` now makes compatibility/deprecation decisions
mechanical for future releases. The generated status, support-lane allowlist,
focused import paths, and compatibility manifest are all checked by the
release gate. Future API work must retain the one-minor-release shim policy
for documented moves and record deprecations in `CHANGELOG.md`.

Acceptance:

- every exported name has an owner module and support lane;
- package-consumer tests cover the stable lane plus explicit focused provisional
  opt-ins;
- adding an unclassified export fails validation; and
- README/API docs no longer call an experimental backend part of the 0.5
  compatibility promise.

### 2. Make scenarios first-class infrastructure

`src/moxi/scenarios.mojo` is now the registry rather than another showcase
module. It registers, without duplicating feature state:

| Scenario | Required consumers | Contract it proves |
| --- | --- | --- |
| form + component slot | demo, behavior test, golden | focus, editing, IME, clipboard, child identity |
| theme control states | demo, behavior test, golden | tokens, recipes, hover/pressed/focused/disabled/error states |
| 10k collection | demo, interaction test, benchmark | stable keys, reorder, popup, scrolling, bounded recycling |
| mixed text | headless/native test, golden | wrapping, grapheme edits, bidi/fallback reporting, accessibility |
| plot gallery | demo, spec round-trip test, golden, benchmark | typed data, transforms, interactions, software/SVG/Metal parity |
| capability walkthrough | demo, replay test | manifest, policy, approval, handler execution, audit sequence |
| fractal canvas | demo, renderer test, benchmark | Mojo compute feeding portable and Metal rendering paths |

Implementation targets are `src/moxi/scenarios.mojo`, the existing feature
modules, `tests/`, `examples/`, and `benchmarks/`. The registry should expose
stable ids, default bounds, deterministic seed/data, expected semantic nodes,
and expected counter/checksum metadata. It must not own windows or renderers.

Acceptance: changing a canonical fixture in one place updates every consumer;
the demo catalog check also verifies that registered scenarios have tests and
documented commands. The current implementation makes collection/plot
defaults, text probes, theme mode records, capability walkthrough steps, and
the fractal preset/depth records flow through registry-owned fixture tables.
Expected semantic, counter, and checksum metadata remains a follow-on
refinement.

### 3. Deliver one true localized-execution vertical slice

Extend the current accounting types into a typed subtree contract. Start with
the composed counter/form scenario rather than redesigning the entire view
model.

The keyed scheduler and counter contract landed at `83030c3`, and `06231a5`
integrates the typed keyed child path into `App` for components that opt in.
The normal `build()`/`update()` path intentionally remains an observable root
fallback for components that cannot yet provide localized hooks.

The stable keyed descriptor, typed child builder, parent composition, explicit
root fallback, and deterministic work counters are landed in the composed
`App` slice. `9606b24` adds a two-child preservation contract covering
marked-text/focus, root scroll offset, and a sibling modal popup across local
recomposition. `15648d9` adds a deterministic sorted integer index for scope,
dirty-component, descriptor, order, dirty-child, and child lookup while
retaining dense lists as the source of truth; `7b9d8bd` adds the out-of-order
registration/removal contract. `2987c39` adds a derived dependency-edge
fanout index, and the composed tests now cover accessibility identity, popup
pointer capture, and deeper nested local state. The remaining execution
boundary is adoption: non-opted-in components still use the counted root-wide
fallback.

Acceptance checks:

- updating one child runs one child builder and does not run an unrelated
  sibling builder (landed in `tests/execution.mojo`);
- focus, IME composition, root scroll offsets, sibling popup state,
  accessibility identity, popup pointer capture, and deeper nested state
  survive the composed local update (landed in `tests/composed.mojo`, with the
  fanout implementation in `2987c39`);
- stable topology identities use deterministic indexed lookup for the localized
  scope/dirty, keyed child, and dependency-edge fanout paths (landed in
  `src/moxi/execution.mojo` at `15648d9`, `7b9d8bd`, and `2987c39`); dense
  dependency storage remains the source of truth and root-wide fallback remains
  counted;
- insertion/removal/reorder has an explicit tested localized path, while
  root-wide fallback is counted (landed in `tests/execution.mojo`);
- a 1/10/100-child benchmark demonstrates bounded work using counters, with
  no wall-clock claim required; and
- all existing 68 test programs continue to pass.

### 4. Add deterministic visual regression

Use the software renderer first. Native screenshots remain a separate parity
lane; `707ff64` now captures the offscreen Metal scene and applies an explicit
threshold/mask policy without claiming pixel-identical native output.

The software corpus and browser lifecycle landed at `62a9caa`/`9c25379`; the
shared text corpus plus CoreText/Metal structural replay landed at `b74d4eb`;
and the software manifest/export/checker plus offscreen native screenshot
capture, comparison, and CI artifact upload landed at `707ff64`. The remaining
targets are:

- extend the native capture corpus beyond the compact scene to representative
  visible AppKit states and document the font/scale-specific masks;
- keep exact output for the software oracle and use the checked-in thresholded
  and masked policy only for explicitly native reference captures;
- add real device/browser automation and a linked Mojo Web runtime before
  calling those targets supported; and
- retain actual/expected/diff images and native reports as reviewable CI
  artifacts whenever a visual contract changes.

Acceptance: a one-pixel intentional software change produces a locally
inspectable diff; native captures report masked pixels and channel budgets;
baseline updates require an explicit command and change review; no demo-only
render path exists for a golden; and the browser host check has deterministic
readiness and teardown rather than depending on a developer-owned session.

### 5. Make performance results comparable

Preserve the current workloads and counters, then keep the result protocol
reviewable. The schema, quick/full commands, reviewed macOS baseline,
same-host comparator, dispersion policy, and portable quick contract are
landed. The remaining target is a clean full-profile baseline for each
additional host/compiler combination before enabling its wall-clock lane.

Acceptance: CI detects checksum/work inflation separately from noisy time,
validates the portable quick contract on any host, and uploads repeated
quick-profile evidence; release notes can link to a machine-readable baseline;
and the documentation does not promote a single workstation timing to a
universal claim. Additional full-profile hosts remain planned until their
compiler/runtime baselines are collected and reviewed.

### 6. Establish one documentation vocabulary

The vocabulary pass updated `README.md`, `ARCHITECTURE.md`, `docs/API.md`,
`docs/performance.md`, `docs/accessibility.md`, `docs/demo-browser.md`, and
`docs/xilem-comparison.md` on `main` from the generated support matrix and
scenario manifest. Future edits must preserve the same generated-status
workflow.

Required conventions:

- “implemented” means source plus a passing contract check;
- “supported” additionally requires a documented public lane and release gate;
- “host artifact” never implies a linked Mojo target;
- “deterministic reference” never implies native visual parity; and
- status snapshots identify the commit/release they describe.

Archive superseded long-form specifications instead of maintaining several
competing current roadmaps. The root README should explain how to evaluate the
project; architecture docs should explain ownership and boundaries; API docs
should list support status; the changelog should describe shipped deltas.

## Gate 1 follow-on: structural boundary

The package split (#2) and module split (#3) established a three-package
shape and removed the largest file-level review barriers; the packaging and
contract follow-on (#4) closed two of the resulting gaps. All three merged to
`main` at `a34963f`. S3 remains open; S1, S2, S4, and S5 are
settled and kept below as the record of what closed them. None was a
prerequisite for another.

### S1. Sibling-package distribution boundary — settled

`moxi_plot` is an installable package built from a local source path
(`packages/moxi_plot/pixi.toml`), published after `moxi` so its runtime
dependency resolves from the same local channel. `tests/package_consumer.mojo`
asserts installed `PlotDataTable`/`PlotSpec`, and the release preflight
dry-runs both packages per target. The open question about
`pixi-build-mojo` and local-monorepo sources is answered: `source = { path }`
works.

Evidence: CI `package-consumer`, green on `main`. Remaining boundary:
`moxi_demo` is still source-only, which is the intended outcome for a demo
lane but is not yet stated in the support matrix.

- Non-goals held: publishing to a public channel; a Python extension wheel.

### S2. Oversized-struct boundary — settled

Retain `ColumnView`, `ColumnRuntime`, `Plot`, `PlotSpec` and
`DemoBrowserState` as their current owners.
`docs/architecture/adr-006-large-struct-ownership.md` records the decision,
per-struct coupling, extraction alternatives, remaining review costs and
focused review paths against implementation baseline `fa42b6f`.

The inspected boundaries keep declaration geometry together, preserve retained
identity and paint history under one owner, keep both plot projections tied to
the same data/coordinate policy, keep spec serialization with its grammar, and
keep browser selection/routing/reset lifetime coherent. Existing delegated
components remain the appropriate seams. Moving whole methods to functions
that accept the same struct would not reduce the hardest review units.

The earlier size figures were file lengths, not isolated struct sizes;
`PlotSpec` already has a top-level parser and compiler, and its serializer is
180 lines at the review baseline. Size remains a cost, especially the plot
projection and browser composition methods. This is an explicit no-extraction
decision, not a claim that file splitting removed that cost.

- Acceptance met: recorded retain decisions for all five structs; no public
  names, state ownership or observable behavior changed.
- Validation: source/caller/failure-path review, the repository prose-artifact
  check and whitespace check. Compiler and behavior suites were not rerun for
  this documentation-only decision; no extraction occurred. Native GUI and
  reviewer-productivity claims were not evaluated by S2.
- Reopen for demonstrated projection divergence, duplicated ownership logic
  in another consumer, or review defects attributable to coupled
  responsibilities. A future extraction must identify the smaller state
  contract and reasoning removed, preserve public behavior, and run
  `pixi run test` plus affected targeted tests after each extraction.
- Non-goals held: redesigning the view model, unsupported partial-impl
  patterns and line-count-only refactoring.

### S3. Validate the interactive macOS claims against a real desktop

IME composition, the native accessibility tree, selection/clipboard, and
scroll/virtualization need recorded desktop scenarios in addition to headless
contracts. Partial native sessions have occurred; S3 is not wholly unstarted.

The workbench's September 18 replay covered native AX actions and path-field
focus/caret retention across zoom/restore. On September 23, user-driven
Japanese composition and commit and spoken VoiceOver controls were observed.
See the implementation worktree's `docs/workbench-native-acceptance.md` and
`docs/data-workbench-hardening.md` for exact builds and limits. Full IME editing
and VoiceOver traversal remain open; further VoiceOver testing was paused at
the user's request. These Workbench results do not establish equivalent
Playground coverage or current-build acceptance.

The latest Playground attempt was blocked by `cgWindowNotFound`. That is an
incomplete automation observation, not a native acceptance pass or a proven
application defect. Headless AX focus/queue regressions cannot replace the
missing desktop scenario verdicts. S3 remains open.

- Owner boundary: host review lane, not a CI gate. This produces findings, not
  a pass/fail signal.
- Files: the demo lane under `src/moxi_demo/`, `native/macos_*.m`,
  `src/moxi/macos.mojo`, `scripts/launch_demo_app.sh`; harness kept outside the
  repository.
- Preconditions: a usable macOS automation session with the required
  Accessibility and Screen Recording access, plus an active CJK input source
  and user participation for genuine IME scenarios. The latest Playground
  automation blocker is `cgWindowNotFound`; the earlier Workbench session
  demonstrates that native testing previously ran. Resume paused VoiceOver
  work only when the user requests it.
- Validation command: the scenario scripts in the external harness, starting
  with `pixi run demo-walkthrough` as the project's own definition of working.
- Acceptance: each scenario has a recorded verdict with screenshot or AX-dump
  evidence; every divergence from a documented claim becomes an issue or a
  documentation correction. A scenario that cannot be driven is itself a
  finding.
- Non-goals: turning this into a CI gate; device farms; automating VoiceOver.

### S4. Keep the api-status machinery honest across three packages — enforced

`scripts/api_status_check.sh` loops over per-package lane, surface, and status
files, and public trait method sets are inventoried in
`docs/trait-surface.tsv`. The trait lane exists because `Component` gained
`update_retained` without the export-name surface being able to see it: a
trait method is a promise to every implementer, and a default body makes the
addition source-compatible but not contract-neutral.

The remaining hole is the same shape. Export-name counting still cannot see a
struct's method set, a changed function signature, or a field added to a public
value type. Decide whether those warrant the same treatment or whether the
trait lane plus review is where this stops; more generated inventories are not
automatically better.

- Owner boundary: release support.
- Files: `scripts/api_status_check.sh`, `docs/*-api-lanes.tsv`,
  `docs/*-api-surface.tsv`, `docs/trait-surface.tsv`,
  `docs/api-compatibility.tsv`, `tests/api_lanes.mojo`.
- Validation command: `pixi run api-status-check`.
- Acceptance: a name moved between packages fails validation until it has a
  compatibility row; adding an unclassified export in any package fails; adding
  or removing a public trait method fails until the inventory is regenerated
  and reviewed.
- Non-goals: per-package version numbers; independent release cadences;
  inventorying every struct method.

### S5. Keep profiled benchmarks separable from diagnostics — settled

A retained-dispatch comparison was added to `benchmarks/plotting_interaction.mojo`,
which is a policy-checked full-profile case. New deterministic metric lines
change that case's exact signature and added iterations blow its wall-clock
budget, so the reviewed baseline would have failed the next full run. CI did
not catch it because the case is full-profile-only while CI runs the quick
profile. The comparison now lives in a standalone `plot_reactive` program
outside both profiles.

- Owner boundary: benchmark protocol.
- Files: `scripts/benchmark.sh`, `benchmarks/`, `docs/benchmarking.md`,
  `benchmarks/results/`.
- Acceptance: changing a profiled program's output is a deliberate act that
  ships with a regenerated, re-reviewed baseline; a comparison between two code
  paths in one process stays a standalone diagnostic.
- Open: CI runs only the quick profile, so full-profile drift is found late.
  Decide whether a periodic full run is worth its cost or whether the
  regenerate-on-change discipline is sufficient.
- Non-goals: promoting ratios or wall-clock values to product claims.

## Gate 1 exit criteria

- The stable/provisional public surfaces are mechanically classified.
- Six or more canonical scenarios are registered, with real demo and contract
  consumers; every fixture must still be made the single source for its golden
  and benchmark where relevant.
- At least one typed component subtree updates without a root rebuild, with a
  safe and observable root fallback.
- Deterministic software goldens run in CI and produce reviewable diffs.
- Benchmarks emit structured records, at least one environment-stamped reviewed
  baseline, a same-environment regression comparison with dispersion reporting,
  and repeated CI evidence; compatible baselines beyond macOS arm64 remain
  follow-on work.
- `pixi run release-check` passes and the support vocabulary is consistent
  across current docs.

## Follow-on gates

### Gate 2: text and native-macOS quality

- Extend the shared text corpus with richer fallback/font collections and
  paragraph cases.
- Define host-selected font collections and fallback policy around the
  HarfBuzz adapter; the current CoreText comparison is structural rather than
  glyph-id/pixel exact.
- Move AppKit queues/draw/accessibility storage from process-global fixed arrays
  toward instance-owned storage, or document and test a hard bounded profile.
- Prove native multi-window ownership, deep collection editing, menu/dialog
  lifecycle, drag/drop, and automated AX assertions incrementally.

Exit: the supported text subset and native ownership limits are testable rather
than prose, and two native windows cannot corrupt shared state.

### Gate 3: one real non-macOS runtime at a time

Select the first target using runtime/toolchain feasibility, not novelty. Run
the same compact form + plot scenario end to end through a linked Mojo runtime,
with readiness, input replay, accessibility publication, screenshot/checksum,
teardown, and a baseline. Only then repeat for another target.

The current UIKit, Android, and browser shells remain valuable host artifacts.
They are not three simultaneous implementation commitments.

Exit per target: a clean machine can build and run the scenario; CI or a
documented device harness proves startup, interaction, accessibility, and
teardown; capability reporting matches observed behavior.

### Gate 4: supported 2D plotting package

- Stabilize the implemented `PlotDataTable`/`PlotSpec`/`PlotRuntime` subset and
  document version migration.
- Add streaming invalidation, export quality, text/legend layout, interaction
  replay, and accessible data-table navigation using canonical fixtures.
- Require parity evidence across software, SVG, and each supported native/GPU
  backend.
- Evaluate Cairo for vector/PDF export and wgpu for a portable GPU backend only
  with a prototype against the scene corpus; integration is contingent on
  reduced maintenance or new target coverage.

Exit: the declared 2D subset is inspectable without a renderer, deterministic
under update/replay, accessible, exportable, and performance-baselined.

## Research reconciliation

The Modular ecosystem research changes emphasis but does not justify a broad
rewrite:

| Research signal | Decision |
| --- | --- |
| Human-owned architecture with agent-generated repetitive coverage | Keep API/ownership decisions explicit; use agents for test matrices, fixtures, adapters, and doc synchronization. |
| `mozz` mutation/property testing | Expand deterministic properties now; pilot fuzzing only when failures can be replayed and shrunk into checked-in cases. |
| Terminal and HTML UI projects favor small, teachable layers | Keep progressive, copyable demos; do not hide behavior behind showcase-only helpers. |
| Toolkit bindings expose linker/platform-path cost | Preserve scalar host ABIs and honest capability gates rather than moving core state into an external toolkit. |
| Cairo and wgpu offer adjacent rendering paths | Evaluate them as scene adapters after the corpus exists; do not adopt both speculatively. |
| Mojo’s GPU direction is differentiating | Keep fractal and dense-plot scenarios as first-class compute-to-visualization proofs. |
| Mojo 1.x raises stability expectations | Classify the public surface and add compatibility policy before the next breadth wave. |

## Explicit non-goals for the next gate

- new public widget types or plot mark families;
- polar, geographic, 3D, contour, or candlestick plotting;
- production iOS, Android, Web, Windows, or Linux claims;
- a second GPU backend;
- arbitrary runtime reflection or a browser IDE;
- a network transport, persistence layer, or bundled LLM client for the
  capability bus;
- performance marketing based on the current local benchmark numbers; and
- further structural refactoring beyond the boundaries named in the Gate 1
  follow-on, including nested subpackages, which the tree has no precedent for
  and which no current problem requires.

## Recommended implementation sequence

1. Public export inventory, focused lanes, compatibility enforcement, and
   documentation vocabulary (landed).
2. Scenario registry and descriptor-owned fixtures (landed; expected metadata
   ownership remains a follow-on refinement).
3. Software golden export/checker plus native screenshot evidence (landed).
4. Localized composed-child execution with work counters and an opt-in `App`
   parent/child path (landed; IME/focus, root scroll, sibling popup,
   accessibility identity, pointer capture, and deeper nested state are covered
   by the composed harness; deterministic topology indexes are covered at
   `15648d9`, `7b9d8bd`, and `2987c39`; non-opted-in components retain the
   counted root-wide fallback).
5. Structured quick/full benchmark output, reviewed macOS baseline, and the
   portable deterministic contract (landed; other full hosts remain planned).
6. Final Gate 1 documentation reconciliation and release decision (landed in
   the current handoff); ecosystem convergence E0 is documented on local
   `main` at `9fcd3b5`, with the exact canvas compatibility result and dataviz
   inventory recorded; E2's local nightly/package gate is complete at
   `2eeb802` from the resolved toolchain pair, while E1/E4 remain gated on
   portable packaging and Python ABI decisions. Uploading the two package
   artifacts to a chosen public channel remains an external release action.
7. Structural boundary follow-on: the package split, module split, and
   packaging/trait-contract follow-on landed on `main` at `a34963f` (S1, S4,
   and S5 settled). S2 is settled by the November 6 retain decision in ADR-006.
   S3 remains partially verified; complete native scenarios require a usable
   desktop session and appropriate human participation.

8. Application validation: reconcile the implemented A1–A5 slices and remaining
   acceptance gates in
   [APPLICATION-VALIDATION-PLAN.md](APPLICATION-VALIDATION-PLAN.md), bringing S3
   into the remaining native acceptance work and using demonstrated defects
   to select any text/native or plotting follow-up. Defer new feature/platform
   breadth until this bounded workflow has a recorded support decision.

The landed sequence remains historical context. The application milestone is
the next proposed execution priority and consumes the infrastructure already
reviewed above.
