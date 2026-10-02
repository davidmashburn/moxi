# Layout delivery evidence

The optional candidate implements Mojo-owned retained flow/grid, shared CoreText
measurement and painting, transactional Kiwi regions, variable extent collections,
fitted overlays and a composed native workbench. Implementation and local checks
are complete for the documented candidate profile. Public promotion remains
pending the verification listed below; the root public exports remain unchanged.

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
| Reference-host performance | All four workloads with the predeclared 16.67 ms warm-frame p95 budget passed; raw samples and growth/churn observations are recorded below |

The rebuilt Mojo demo passed wide/narrow resizing, toolbar wrapping, RTL and
summary insertion. The earlier live demo also exercised divider dragging,
vertical scrolling, modal keyboard traversal
and dismissal, and a row editor scrolled offscreen and back with its text intact.
Japanese text was pasted; this does not establish input-method composition.

## Frame cost

[Recorded timings](layout-workbench-timings.json) preserve all 840 measured frames,
phase costs, measurement/solver/engine-edit counters and bounded realization.
Each of seven workloads has 10 complete warmup frames followed by 120 samples.
The table reports milliseconds; the results describe this host and workload only.
The artifact records the Mojo backend and a SHA-256 of the measured engine source.
The [previous Taffy run](https://github.com/davidmashburn/moxi/blob/db605f6/docs/layout-workbench-timings.json)
remains in Git history. These separate runs do not establish a causal speedup.

| Workload | Median | p95 | Maximum | Maximum realized cells |
| --- | ---: | ---: | ---: | ---: |
| Unchanged | 1.364 | 1.846 | 2.371 | 68 |
| Vertical scroll | 2.717 | 3.385 | 3.870 | 76 |
| Resize | 1.705 | 2.652 | 3.179 | 72 |
| Summary insertion/removal | 2.632 | 4.876 | 8.438 | 72 |
| 1500 × 1000 viewport | 2.532 | 5.199 | 8.358 | 96 |
| 2000 × 1400 viewport | 3.110 | 4.357 | 5.416 | 140 |
| Mixed resize/scroll/RTL/summary churn | 6.312 | 9.792 | 10.806 | 88 |

The budget applies to the first four workloads. The last three provide additional
observations, without a separately predeclared gate. All use a 100,000-row,
four-column source with variable row heights. Unchanged frames perform zero
measurements, engine edits, solver builds or new mounts. Larger viewports realize
more cells while retaining the same dataset; bounded realization does not imply
constant total source or track-metadata memory.

Timing includes declaration synchronization, provider measurement, strategy
staging/solve, validation, publication, paint commands, accessibility submission,
chart commands and AppKit/CoreText bitmap painting at scale 1. Provider callback
time is a subset of allocation/arrangement, not an additional phase to sum.
Compilation, source initialization, the event loop, compositor, scanout, NSWindow
coordinate conversion, active native IME and VoiceOver are excluded. This is not
a display latency measurement. An earlier pre-optimization run exceeded the
budget during native submission; retained accessibility identity addressed that
bottleneck before the Mojo migration.

Reproduce with `pixi run layout-workbench-benchmark` after the candidate checks.
The task writes fresh samples to `dist/layout-workbench-timings.json`; the linked
document is the recorded run, not an automatically updated claim.

## Remaining verification

- Hosted macOS/Linux CI is configured for the Mojo engine but has not run for
  these commits. Linux execution was not verified locally. The
  [previous Taffy baseline CI](https://github.com/davidmashburn/moxi/actions/runs/37050637932)
  passed all five jobs; that run does not validate the Mojo replacement.
- Android/iOS host checks were skipped because the required SDK/NDK and simulator
  SDK were unavailable. No mobile layout release is certified by these checks.
- Live VoiceOver remains inconclusive. Its switch enabled, but no responsive
  VoiceOver process, cursor or caption feedback could be observed through this
  session. The switch was restored to off. Automated AX checks do not certify
  VoiceOver traversal, announcements or modal navigation.
- Live Japanese IME remains unverified. The input-source sheet did not respond
  reliably to selection/keyboard actions, so addition was canceled. U.S. remains
  the sole source and the input-menu setting remains off. The native marked-text
  probe does not replace composition with the real Japanese input method.
- Horizontal scrolling through the live UI tools produced no observable movement
  in either direction. Portable two-axis collection offsets are covered by tests;
  native horizontal wheel delivery/direction still needs a direct manual check.
- The precompiled consumer demonstrates explicit native linkage. A standalone
  conda package containing the candidate Kiwi/macOS sidecars is not supplied
  or certified by the existing package-consumer pass.

Confidence is high in the observed local candidate contracts and reference-host
timings. Passing hosted CI and the live accessibility/input checks would change
the promotion assessment. Until then, this remains an optional candidate rather
than a certified replacement for the legacy layout path. The
[design acceptance requirements](design/layout-system.md#delivery-and-acceptance)
remain the target contract; unsupported profile features are documented in the
[retained layout profile](retained-layout.md).
