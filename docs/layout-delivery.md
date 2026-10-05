# Layout delivery evidence

The optional candidate implements Mojo-owned retained flow/grid, shared native paragraph
measurement and painting, transactional Kiwi regions, variable extent collections,
fitted overlays and a composed native workbench. Implementation and local checks
are complete for the documented candidate profile. Public promotion remains
pending the verification listed below; the retained layout modules remain outside
the root exports. Portable frame contracts are exported independently of that
candidate promotion.

## Local evidence

Recorded on 2026-10-02 on Apple M4, macOS 26.6.2, Mojo
1.1.0.dev2026082605 (`dd957314`). Flow/grid execution is Mojo-owned; the
constraint solver remains Kiwi commit `5e76d91fd77dc443cb0db36e7398fc13844a0524`.

| Gate | Result and scope |
| --- | --- |
| Full repository regression | `pixi run check` passed, including portable tests, native scene/text/paragraph checks, screenshots, Python consumer, workbench release gate, packaging, browser and live-reload contracts |
| Candidate integration | `pixi run layout-candidate-check` passed: portable Mojo engine contracts, CoreText integration, differential fixtures at 116 parent sizes, 1,000 staged constraint builds, 250 composed churn/fault iterations, collection/overlay policies and native presentation |
| Atomic failure | Oversized native IDs and presentation capacity fail before geometry publication; the composed capacity case also preserves recycler lifecycle and recovers the previous editor mount |
| Native identity | Native probe passed ordered paint/custom canvas layering, clipped hit testing, stable accessibility objects and actual AppKit field-editor marked-range retention through offscreen clipping |
| Independent authoring | `pixi run layout-consumer-check` passed an independently authored screen against precompiled `moxi.mojoc`, from a temporary directory without repository source includes; native sidecars are explicitly linked |
| Existing installed package | `pixi run package-consumer` passed with moxi/moxi_plot 0.6.0 installed from a temporary local channel; this checks the existing package, not distribution of candidate native sidecars |
| Installed native services | `pixi run layout-package-consumer` passed: a fresh environment installed Moxi and the optional `moxi_layout_native` archive from a temporary local channel, then compiled and ran the independent layout consumer with only installed Mojo modules and the installed native archive |
| Hosted Mojo migration | [All five CI jobs](https://github.com/davidmashburn/moxi/actions/runs/37064134839) passed for `670175e`, completing at 2026-10-02 21:15:10 UTC; this includes Linux Mojo contracts and macOS candidate/precompiled-consumer checks |
| Hosted installed-package gate | [All five CI jobs](https://github.com/davidmashburn/moxi/actions/runs/37080596570) passed for `950205d`, completing at 2026-10-03 00:21:05 UTC; the package-consumer log confirms both the existing Mojo consumer and the installed native layout consumer passed |
| Reference-host performance | All four workloads with the predeclared 16.67 ms warm-frame p95 budget passed; raw samples and growth/churn observations are recorded below |

The rebuilt Mojo demo passed wide/narrow resizing, toolbar wrapping, RTL and
summary insertion. The earlier live demo also exercised divider dragging,
vertical scrolling, modal keyboard traversal
and dismissal, and a row editor scrolled offscreen and back with its text intact.
Japanese text was pasted; this does not establish input-method composition.

On 2026-10-03, `pixi run composed-layout-check` passed after assigning explicit
editor names. The rebuilt app's native accessibility tree exposed the dataset
field as “Dataset” and an activated cell editor as “Value, region 2, column 2”,
with their editable text still published as values. Regression checks preserve
these semantics through resizing, composition state and offscreen retention.
This verifies naming through AppKit, not VoiceOver speech or navigation.

Later on 2026-10-03, candidate checks and the full repository suite passed after
normalizing accessibility root parents, limiting modal accessibility to the
dialog subtree, announcing newly mounted focused controls and routing addressed
editor input by semantic key. The final recovery adjustment was rechecked with
`pixi run layout-candidate-check`, including rejected dialog opening/dismissal,
published focus retention and source-removal fallback; that rerun passed.
The full repository suite was not repeated after that recovery-only adjustment.

The rebuilt app's native accessibility tree exposed only the dialog and its
controls while modal. Tab changed the focused dialog control; Escape restored
the background tree and keyboard input to the prior cell editor. An AX value
write addressed to Dataset changed Dataset while subsequent keyboard input still
edited the cell. In the final build, opening a dialog during the deliberate
constraint conflict preserved the painted background and its accessibility tree;
clearing the conflict then allowed normal dialog publication and dismissal.
These observations do not certify VoiceOver or Japanese IME behavior. No system
settings changed during this pass, and the recorded timing run was not repeated.

## Frame cost

[Recorded timings](layout-workbench-timings.json) preserve all 840 measured frames,
phase costs, measurement/solver/engine-edit counters and bounded realization.
Each of seven workloads has 10 complete warmup frames followed by 120 samples.
The table reports milliseconds; the results describe this host and workload only.
The October 5 artifact records the Mojo/native backend, host identity, explicit
full profile and SHA-256 hashes of the measured frame/resource/host sources. The
four reference workloads pass the declared 16.67 ms p95 budget on the native
Apple M4; larger/churn workloads remain descriptive.
The measured production source is commit `16ea17c`; the run finished at
2026-10-05 06:24:42 UTC using stable Mojo 1.1.0 (`8189361e`).
The [previous Taffy run](https://github.com/davidmashburn/moxi/blob/db605f6/docs/layout-workbench-timings.json)
remains in Git history. These separate runs do not establish a causal speedup.

| Workload | Median | p95 | Maximum | Maximum realized cells |
| --- | ---: | ---: | ---: | ---: |
| Unchanged | 2.909 | 4.503 | 5.282 | 68 |
| Vertical scroll | 4.231 | 5.350 | 5.917 | 76 |
| Resize | 2.302 | 3.438 | 4.258 | 68 |
| Summary insertion/removal | 3.969 | 5.487 | 6.628 | 68 |
| 1500 × 1000 viewport | 4.877 | 10.542 | 21.991 | 92 |
| 2000 × 1400 viewport | 3.637 | 6.305 | 9.436 | 140 |
| Mixed resize/scroll/RTL/summary churn | 8.858 | 13.970 | 15.447 | 88 |

The budget applies to the first four workloads. The last three provide additional
observations, without a separately predeclared gate. All use a 100,000-row,
four-column source with variable row heights. Unchanged frames perform zero
measurements, engine edits, solver builds or new mounts. Larger viewports realize
more cells while retaining the same dataset; bounded realization does not imply
constant total source or track-metadata memory.

Timing includes declaration synchronization, provider measurement, strategy
staging/solve, validation, publication, paint commands, accessibility submission,
portable packet construction, measured paragraph resource binding, shared chart
commands and AppKit/CoreText bitmap painting at scale 1. Provider callback
time is a subset of allocation/arrangement, not an additional phase to sum.
Compilation, source initialization, the event loop, compositor, scanout, NSWindow
coordinate conversion, active native IME and VoiceOver are excluded. This is not
a display latency measurement. An earlier pre-optimization run exceeded the
budget during native submission; retained accessibility identity addressed that
bottleneck before the Mojo migration.

Reproduce with `pixi run layout-workbench-benchmark` after the candidate checks.
The task writes fresh samples to `dist/layout-workbench-timings.json`; the linked
document is the recorded run, not an automatically updated claim.

## Linux exploratory timings

[Linux VM timings](layout-workbench-linux-timings.json) record 56 complete frames:
eight samples and two warmups for each of the seven workloads. The measured
source is preserved in commit `504faef`; the artifact records hashes and the
actual QEMU TCG/Haswell-v4 configuration on the physical ARM64 Apple M4. The
shorter smoke profile is descriptive and does not enforce the native Mac budget.
The full Linux profile was skipped to bound emulation cost.

This pipeline includes portable semantics, paragraph bindings and the production
Cairo/Pango bitmap painter. With no opened GTK surface, native semantic submission
is a no-op: live accessibility proxy construction and AT-SPI updates are excluded.
The external service check covers those behaviors separately. These timings do
not establish native Linux 60 Hz performance or display latency.

Reproduce inside the guest with:

```sh
MOXI_LAYOUT_BENCHMARK_PROFILE=smoke \
MOXI_LAYOUT_BENCHMARK_ENVIRONMENT=lima-qemu-tcg-haswell-v4 \
pixi run --locked layout-workbench-benchmark
```

## Remaining verification

- Android/iOS host checks were skipped because the required SDK/NDK and simulator
  SDK were unavailable. No mobile layout release is certified by these checks.
- Live VoiceOver remains inconclusive. On retry, its switch enabled and the
  screen-reader process started after the tutorial was dismissed, but navigation
  produced no observable cursor or caption feedback through these tools.
  The switch was restored to off. Automated AX checks do not certify
  VoiceOver traversal, announcements or modal navigation.
- Live Japanese IME remains unverified. On retry, filtering the chooser allowed
  temporary addition of Japanese–Kana, but input-source switching shortcuts
  continued to enter Latin text without observed composition. The source was
  removed, U.S. restored as the sole source, the input menu turned off, and the
  automatically added Japanese dictation language removed. The native marked-text
  probe does not replace composition with the real Japanese input method.
  A later attempt to use the source menu was blocked by native UI-tool timeouts
  for the input-menu agent and menu-bar controller; no settings changed on that
  attempt.
- Horizontal scrolling through the live UI tools produced no observable movement
  in either direction. Portable two-axis collection offsets are covered by tests;
  native horizontal wheel delivery/direction still needs a direct manual check.
- The [optional native archive recipe](../packages/moxi_layout_native/README.md)
  is verified locally on macOS arm64 with a macOS 14 archive deployment target.
  The pinned stable Mojo 1.1.0 consumer requires macOS 15+ and Xcode or Command
  Line Tools 16+ under the [compiler requirements](https://mojolang.org/docs/requirements/).
  The recipe uses the host Apple compiler/SDK, is not a hermetic build, and has
  not been uploaded to a public channel. No Intel or non-macOS native-services
  package is certified.

The Linux GTK4/Cairo/Pango retained presenter has also passed native contracts and
synthetic X11 interaction checks in a real Ubuntu x86-64 VM. External AT-SPI
hierarchy/text/focus/actions and cross-process Unicode clipboard checks also pass.
Linux remains source-only and provisional without legacy widget parity. These
observations do not establish spoken screen-reader, physical input or Wayland
acceptance. Real IBus/Mozc composition, conversion, commit and cancellation pass
in a separate X11 service probe; physical keyboard use and exact caret x-coordinate
placement remain unverified. Source/toolchain provenance and current
stable-toolchain verification are recorded in [VM validation](vm-validation.md).
The [direct manual steps](layout-workbench.md#manual-release-checks) identify the
remaining macOS interaction checks.

Confidence is high in the observed local candidate contracts, installed package
consumer, hosted CI and reference-host timings. Passing the live
accessibility/input checks would change
the promotion assessment. Until then, this remains an optional candidate rather
than a certified replacement for the legacy layout path. The
[design acceptance requirements](design/layout-system.md#delivery-and-acceptance)
remain the target contract; unsupported profile features are documented in the
[retained layout profile](retained-layout.md).
