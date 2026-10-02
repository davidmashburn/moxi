# Content layout

The proposed [unified layout system](design/layout-system.md) consolidates this
work into a target architecture and staged delivery plan. The first
[native paragraph protocol slice](native-paragraph-layout.md) is implemented
separately; the complete architecture is still proposed.

The new layout path is opt-in and provisional. It supports linear rows and
columns with independent content, weighted fill, and fixed sizing on each axis.
It is the first implementation slice from [the research](layout-research.md),
not a complete CSS Flexbox/Grid implementation.

```mojo
from moxi import AxisSize, ColumnView, Rect

var view = ColumnView(Rect(0, 0, 640, 480), 16, 8)
view.add_label(1, "Summary", 0)
view.set_sizing(1, AxisSize.fill(), AxisSize.content())
view.add_canvas(2, "Chart", 0)
view.set_sizing(2, AxisSize.fill(), AxisSize.fill())
view.set_min_height(2, 160)
view.layout()
```

`set_sizing` enables the new path. Existing min/max setters constrain the result.
For the low-level `LayoutStyle`, a negative maximum means unbounded, and a
conflicting maximum wins over a minimum. `ColumnView` retains its legacy zero
maximum convention (unbounded). Positive legacy preferred dimensions remain fixed unless explicitly overridden;
otherwise widths fill and heights measure content. `enable_content_layout()`
opts in without adding a sizing override. Existing declarations that never opt
in retain the legacy algorithm.

Call `layout()` after changing declarations and before reading `bounds_for()`.
It publishes the same bounds used by paint, hit testing, and accessibility.
`content_layout_active` confirms that the new path was used. Nonlinear container
modes or unsupported alignment retain the legacy path for the entire view;
check this flag when migrating a screen. `layout_diagnostic(id)` reports the last
finalized policy, limits, content extent, allocation, overflow, and pass counters. This avoids silently interpreting grid,
split, stack, or portal declarations as linear containers.

Fixed sizes and minima can exceed the viewport. The layout keeps readable
minimum sizes; enable clipping and use the existing root/container scrolling
contract to reach overflowing content. Scroll translation does not change the
retained measurement inputs. A clean repeated layout and a pure scroll should
perform no leaf measurements, though declaration synchronization and publishing
bounds still require work.

Text measurement uses Moxi's deterministic codepoint estimator, including font
size and width-dependent wrapping. This is not glyph-accurate CoreText paragraph
layout. The Metal renderer's text font is now independent of the allocated box;
that fix alone does not establish text measurement/rendering parity. Native
paragraph shaping, baseline alignment, RTL placement, adaptive wrapping rows,
content/fractional grids, and cross-component retained caches remain later work.

The CSV consumer in the sibling `moxi-csv-compare` repository is the authoring
acceptance case. Its chart uses remaining height with a 160-point minimum. Adding
or removing summary content changes that allocation without a chart-height edit.

## Reproducing the checks

```sh
pixi run content-layout-test
cargo build --release --locked --manifest-path experiments/layout-taffy/Cargo.toml
pixi run layout-reference-check
pixi run layout-baseline
pixi run content-layout-benchmark
```

The reference check compares all nine rectangles in three shared fixtures with
Taffy 0.14.0: weighted fill with a maximum, a padded column, and wrapped text at
its allocated width. Both fixtures use the same deterministic text estimator.
This is evidence for those cases, not CSS conformance or native text parity.
Rust is required only for the isolated reference experiment.

The baseline and content benchmarks time declaration synchronization, layout,
and bounds publication on identical flat, fixed-height trees. Construction and
compilation are excluded; each unchanged sample is the mean of 20 layouts.
These workloads differ from the Taffy arena benchmark, so their timings must not
be used to rank the two engines.

For now, Moxi's production path remains Mojo and opt-in. Taffy is a credible
candidate for richer flex/grid semantics, but its production text callback,
portable packaging, and Moxi integration have not been built. The current Mojo
adapter still copies/synchronizes declarations on every pass and conservatively
invalidates container measurements after input changes. Cached text measurement
alone does not make this path faster than the legacy fixed-height algorithm.


## Results from 2026-09-24

On Apple M4 / macOS 26.6.2, Mojo 1.1.0.dev2026082605, seven runs of the
flat fixed-height fixture produced the following median times in milliseconds.
Each unchanged observation averages 20 layouts. Compilation and construction
are excluded, and these final runs had no concurrent builds from this task.
[Raw samples](content-layout-timings.json) include every observation.

| Nodes | Legacy cold | Content cold | Legacy unchanged | Content unchanged |
| ---: | ---: | ---: | ---: | ---: |
| 100 | 0.003 | 0.115 | 0.00210 | 0.02310 |
| 1,000 | 0.022 | 0.605 | 0.02110 | 0.21020 |
| 10,000 | 0.309 | 6.039 | 0.21010 | 2.24420 |

The unchanged content path measured zero leaves in every sample, but took about
10–11 times as long as the simple legacy path. At 10,000 nodes its worst observed
unchanged sample was 2.613 ms, versus 0.217 ms for legacy. Seven samples do not
establish a reliable tail-latency distribution. No speedup is claimed. This
fixture quantifies adapter overhead; it does not value the new content semantics
or compare Moxi and Taffy on equivalent end-to-end integration work.

Validation completed:

- The full Moxi suite passed (74 files). After the final nested-scroll and empty
  input fixes, both targeted content-layout suites passed again.
- All nine shared reference rectangles matched Taffy within 0.01 points.
- Native text and scene parity checks passed, including stable CoreText ink size
  for the same font in differently sized boxes. Scene tests, Rust tests/clippy,
  the C bridge smoke test, API status, and whitespace checks passed.
- The external CSV consumer was rebuilt from local packages, passed its headless
  suite and package/host provenance checks, and produced an ad-hoc signed app.
- Live inspection confirmed usable empty path fields, A count 2 / mean 5 and
  B count 4 / mean 4.5, a shared histogram, and chart growth after window zoom.
  Exact viewport growth and inserted-summary allocation are headless assertions;
  native window dimensions were not independently measured.

Known live issues: the B summary is visible but absent from the automation AX
snapshot, and the empty chart's canvas label overlaps its empty-state message.
Neither is an accessibility or visual acceptance pass for the whole app.
VoiceOver remains paused. Japanese composition was not repeated for this change.
CI, non-macOS native builds, notarization, deep Mojo tree stress tests, and native
paragraph measurement/rendering parity were not verified. No commit or push was
made by this implementation pass.

Confidence is high for the tested linear content/fill cases, and moderate for
keeping this Mojo engine as the long-term choice. Matched end-to-end Taffy
integration measurements, broader text/layout conformance, or evidence of
unacceptable adapter overhead in real screens would change that choice. The next
steps are native text measurement parity and reducing declaration synchronization
and publication costs before considering a default switch.


The subsequent [Cassowary, Kiwi/Enaml, and xyflow evaluation](layout-constraints-and-graphs.md)
adds a scoped-constraint comparison before expanding the custom engine. This
updates the research direction without changing the opt-in runtime contract.
