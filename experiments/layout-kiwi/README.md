# Kiwi constraint-layout experiment

This isolated experiment tests whether scoped Cassowary-family constraints improve
Moxi layout authoring. It does not change production layout or add a dependency to
Moxi's package. Kiwi 1.5.0 is pinned to upstream commit
`5e76d91fd77dc443cb0db36e7398fc13844a0524`; the upstream BSD license is preserved
alongside the pin. Enaml informed the preferred-size policies; Enaml and Qt are not
runtime dependencies. The [research and decision criteria](../../docs/layout-constraints-and-graphs.md)
explain why graph placement and xyflow remain a separate experiment.

## Result and decision

The native bridge works from the pinned Mojo toolchain. All 76 native fixture
assertions passed, the paired Mojo runs independently checked every published
rectangle, and nine rectangles matched the Moxi and Taffy reference executables.
C-language ABI smoke checks and AddressSanitizer/UndefinedBehaviorSanitizer
runs of the bridge tests and native fixtures also passed. Captured [fixture results](results/fixtures.json) and [raw timing samples with
summaries](results/comparison.json) are checked in with this experiment.

Median elapsed microseconds from seven paired samples on this machine:

| Operation | Moxi LayoutTree | Kiwi through C ABI |
| --- | ---: | ---: |
| Construction plus first layout/publication | 2.792 | 15.625 |
| Width and height resize | 1.583 | 0.667 |
| Summary insertion plus resize back | 3.417 | 12.209 |
| Minimum-size overflow | 1.542 | 1.375 |
| Unchanged layout/publication | 1.334 | 0.708 |

The fixture favors Kiwi on some retained edits and Moxi on construction and
structural insertion. These microsecond samples include substantial overhead and
first-run variation; they do not establish a workbench speedup. The JSON retains
phase breakdowns and p95 values so construction/optimization costs cannot disappear
into an inexpensive `updateVariables` measurement.

**Recommendation: prototype a scoped constraint-authoring layer next, while keeping
the existing tree layout.** Confidence is high that this C ABI is feasible on the
tested Mac, and moderate that scoped constraints will improve authoring. That
second judgment needs a real form/splitter authoring exercise, native text,
publication into Moxi, and region-size/churn measurements before adoption.

The prototype should provide aligned edges, gaps, equal dimensions, named
preferred-size policies, and constraint IDs tied to controls. Parent allocation
must remain required; overflow and text remeasurement need explicit policies.
Equal-strength preferences do not express which control should compress first.
The experiment only diagnoses a rejected constraint, not a minimal conflict set.

Three observed limits shape that API:

- 1,001 weak preferences defeated one medium preference. Kiwi's numeric strengths
  must not be exposed as a promise of strict Cassowary priority tiers.
- After adding/removing 64 distinct variables, solver variable entries grew from
  1 to 65; reset reduced them to 0. This supports bounded region lifetimes and a
  rebuild policy, but says nothing about exact heap bytes.
- Text stabilized after allocation and measurement for the tested fixed widths.
  Each font/width case creates a fresh solver; this does not verify retained font
  invalidation or convergence of arbitrary width/height dependency cycles.

Splitter stability here comes from explicit required positions for unrelated
controls, not automatic stays. Weighted-fill parity includes Moxi-side allocation
policy. Neither behavior comes for free from choosing a constraint solver.

## What this exercises

- A CSV column with measured header/summary heights, a chart minimum, summary
  insertion, resizing, and overflow below the chart minimum.
- Aligned labels and fields, preferred-size compression, equal buttons, and a
  rejected required minimum with author-facing identifiers.
- An edited splitter, hard movement limits, unrelated stable positions, constraint
  churn, and competing weak/medium preferences.
- Width-dependent text measurements, font changes, line-break thresholds, and a
  bounded solve/measure sequence. The deterministic ASCII estimator is deliberately
  the same kind of fixture metric used in the Moxi/Taffy comparison, not native
  paragraph shaping.
- An explicit weighted-fill allocation policy. A linear solver does not supply
  flexbox's clamp-and-redistribute algorithm automatically.

## Ownership and measurement

The C ABI owns one opaque solver; integer variable and constraint IDs belong to the
caller. C++ exceptions must not cross the ABI. Required conflicts are errors rather
than silently weakened constraints. Reset is the boundary for discarding retained
solver variables. This remains a single-threaded experimental interface; callers
must obey handle lifetime rules.

`mojo/comparison.mojo` runs the same CSV sequence using Moxi's `LayoutTree` and the
C ABI. Both paths publish to a Mojo `List[Rect]` and independently assert every
rectangle against expected geometry. It is a small solver-region comparison,
not a `ColumnView`, renderer, accessibility, or full application benchmark.

Creation includes building declarations/constraints. Mutation includes Kiwi's
incremental optimization during add/remove/suggest calls. The separately timed
Kiwi layout phase is `updateVariables`, which only publishes solved values inside
Kiwi; it must not be described as the complete solve cost. Publication includes
copying values across the C ABI into Mojo rectangles. End-to-end phase time also
includes timing/status-check overhead. No empty-call overhead is subtracted.

The seven paired samples alternate engine order. P95 is nearest-rank, so it is the
maximum of seven observations. These tiny fixtures can demonstrate feasibility and
catch large regressions, but cannot establish application-level speed or scaling.

## Reproduce

On the current macOS development machine, from the repository root:

```sh
bash experiments/layout-kiwi/scripts/run.sh
```

This fetches the pinned upstream source, builds an optimized C++ static/dynamic
library, runs native and C-language ABI checks, validates the native fixtures,
and builds/runs the Mojo comparison using the repository's pinned Pixi toolchain.
Generated artifacts are under `build/` and ignored. The runner uses Apple's C++
runtime (`-lc++`); other platform packaging has not been verified.

Captured environment: Apple Silicon arm64, macOS 26.6.2 (25G83), Apple clang 21.0.0
(clang-2100.0.123.102), Mojo 1.1.0.dev2026082605 (dd957314). C++ benchmark/library
code uses `-O3`; fixture checks remain enabled. The experiment-local clock uses
`mach_absolute_time` on macOS because the existing `CLOCK_MONOTONIC` benchmark
clock rounded these small phases to microseconds in this environment.

## Integration limits

The bridge validates non-finite inputs and caller IDs and reports a rejected
constraint's ID. It does not compute a minimal conflicting set or a complete
explanation of why all requirements cannot fit. The form fixture maintains its
own mapping from constraints to author-facing labels; Moxi would need that mapping
in its declaration layer. After an internal error or allocation failure, reset or
destroy the handle; exception containment is not a general transaction guarantee.

The CSV Mojo fixture holds the viewport width and height with strong edit suggestions and
the chart fill with a medium preference. It verifies the viewport remains exactly
as suggested for every tested state. This is a bounded fixture policy, not a
promise that arbitrarily many weaker preferences can never move the parent size.
Production region ownership should enforce parent allocation as required bounds
and apply an explicit overflow policy inside them.

No native window, paint/hit/accessibility publication, VoiceOver, IME, native text
shaping, cross-platform packaging, or CI run is covered here. The full Moxi suite
is not rerun for these isolated files. Exact allocator bytes, allocation-failure
injection, long-running application memory, and large solver-region scaling are
also outside this experiment's measurements.

The wrapper also retains consumed constraint IDs until reset, so repeated
add/remove with fresh IDs grows wrapper bookkeeping as well as any solver entries.
Reset clears logical entries but is not a promise to return allocator capacity to
the operating system; destruction/recreation is the stronger lifetime boundary.
A production adapter needs a measured rebuild policy and stable node-to-variable
mapping rather than an indefinitely growing stream of constraint IDs.

The optional three-engine geometry comparison uses the existing Moxi and Taffy
reference executables (Taffy is not needed for the Kiwi runtime bridge):

```sh
pixi run layout-reference-build
cargo build --release --locked --manifest-path experiments/layout-taffy/Cargo.toml
python3 experiments/layout-kiwi/scripts/parity_check.py \
  experiments/layout-kiwi/build/fixtures.json \
  dist/moxi-layout-reference \
  experiments/layout-taffy/target/release/layout-taffy
```

This compares computed relationships and measured heights for nine rectangles.
The weighted row deliberately computes clamp/redistribution outside Kiwi; parity
there confirms the adapter's allocation policy, not a built-in flex algorithm.
