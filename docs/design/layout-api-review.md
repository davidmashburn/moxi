# Layout API decisions and contract probes

Status: design review backed by isolated executable models. A provisional
[Mojo/native paragraph slice](../native-paragraph-layout.md) now compiles and runs;
the complete API described here remains proposed.
The [layout system](layout-system.md) contains the integrated design. The
[probe README](../../experiments/layout-contracts/README.md) describes reproducible
checks and their limits.

## Decisions

The original recommendations were too abstract to justify confidence in their API.
The revised design makes the difficult ownership decisions explicit:

| Surface | Chosen contract | Alternative rejected and reason |
| --- | --- | --- |
| Custom box layout | Pure `measure` and `arrange`; immutable placement plan committed by the runtime | A placement callback that secretly measures or mutates children makes dependency tracking and atomic publication unreliable |
| Child measurement | Multiple distinct proposals permitted; identical valid requests memoized; final allocation uses a valid final result | One universal measurement per child cannot handle intrinsic queries followed by width-dependent wrapping |
| Adaptive composition | Change policy over children declared once in stable slots | Duplicating the children in conditional Row/Split branches introduces reconciliation and native-editor moves that the common case does not need |
| Split | Stateful controller plus pure allocation policy; divider chrome has focus/capture/semantics | Calling Split merely a layout algorithm hides interaction lifetime and keyboard accessibility |
| Mixed scrolling | One viewport composes BoxSection, ListSection and specialized section providers | A list-item source alone cannot express a header, lazy results and footer as one scrolling surface |
| Two-axis tables | Row/column ranges and one shared track snapshot | Flattening cells into a list loses independent horizontal visibility and frozen-track geometry |
| Identity and invalidation | Public logical keys and opaque capabilities; runtime owns generations and dependency stamps | Asking application authors to maintain version vectors turns internal bookkeeping into user-facing complexity |
| Cycles and constraints | Reject custom measurement cycles; named built-ins use specified algorithms; required solver conflicts fail atomically | An arbitrary iteration count is not a convergence algorithm; Kiwi does not establish portable uniqueness for underconstrained geometry |

The public names are provisional. These ownership and lifecycle rules are the
important decisions, and they should survive a naming or Mojo representation change.

## Concrete authoring exercises

### Baseline-aligned fields with wrapped text

A custom policy needs child measurement, baselines and local placement. It does
not need a solver handle, a global node ID, or access to the child's implementation:

```text
arrange(context, final_size, children):
  label = context.measure(children["label"], Exactly(label_width))
  field = context.measure(children["field"], Exactly(final_size.inline - label_width - gap))
  baseline = max(label.first_baseline, field.first_baseline)
  return placements(
    children["label"] at (0, baseline - label.first_baseline) using label,
    children["field"] at (label_width + gap, baseline - field.first_baseline) using field)
```

This is abbreviated pseudocode, not compilable Mojo. The parent's measurement hook
uses the same pure calculation when answering a proposed width. Final placement
must still satisfy the final offered box and its declared overflow policy.

The model exposes two concrete errors an apparently reasonable implementation makes:

- At a parent width of 54, the field has width 40 and one line. At 53, it has width
  39 and two lines. Reusing a natural-width result or rounding the cache key would
  produce the wrong height. The unchanged label measurement remains reusable.
- Two children with heights 10 and 9 need a combined height of 11 when their
  baselines differ. Taking only the maximum child height clips the aligned union.

Content validity also differs from geometry equality. Replacing eight characters
with eight different characters can leave the allocated size unchanged while making
an old content result invalid. The model checks the stamp; it does not draw text.
The production runtime must publish the new drawing/hit/caret payload even if it
reuses parent geometry.

### A workbench that collapses while editing

```text
Split(key="body", initial_fraction=0.32,
      collapse_below=760, compact=ColumnLayout(gap=12)):
  SettingsForm(key="settings")
  ResultsTable(key="results")
```

The same children remain mounted when the policy changes. The Split controller
retains pane allocation preferences. Compact mode retires the divider's hit target,
cancels its capture, and transfers divider focus to a surviving associated pane.
A pane editor keeps its identity. Returning to wide mode creates current divider
chrome and restores allocation preferences; it must not revive an old drag event.

A matching key is insufficient across a different owner or incompatible component
type. Those are remounts. Review specifically challenged owner replacement and
leave/return sequences because resetting a local generation counter can accidentally
make stale handles valid again.

### A report with a header, lazy results and footer

```text
Scroll(key="report"):
  BoxSection(key="summary"): Summary()
  ListSection(key="results", source=rows, estimate=RowEstimate(28))
  BoxSection(key="footer"): LoadMoreStatus()
```

Each section returns content-coordinate geometry. The viewport owns section origins,
scroll offset, clipping and anchor compensation. A stable address combines section
and item keys, so identical item keys in different sections are unambiguous.
Measured height corrections preserve that address and within-item offset whenever
scroll clamping permits it. A removed anchor selects a surviving neighbour in the
previous committed order.

Review found and corrected two concrete errors in the initial reference model:
restoring an anchor subtracted its within-item offset even though capture added
that offset to the item start; and commit checked only the source revision, allowing
an old plan to overwrite newer scrolling on unchanged data. The revised contract
defines the anchor equation and requires a base viewport transaction check too.

This protocol deliberately does not claim that a 2D table is solved. A table adapter
must coordinate column tracks, horizontal visibility, frozen regions, and row-height
dependencies. That is a separate production gate, not something a successful 1D
reference model proves.

## Why these choices are better supported

[SwiftUI Layout](https://developer.apple.com/documentation/swiftui/layout) provides
proposal-based custom measurement and placement, while
[AnyLayout](https://developer.apple.com/documentation/swiftui/anylayout) demonstrates
changing layout algorithms while preserving child state. These support Moxi's
separation, not a claim that its eventual runtime will inherit SwiftUI's behavior.

[Flutter RenderBox](https://api.flutter.dev/flutter/rendering/RenderBox-class.html)
tracks whether a parent uses child size. Its
[MultiChildLayoutDelegate](https://api.flutter.dev/flutter/rendering/MultiChildLayoutDelegate-class.html)
has a different limitation: parent size cannot depend on children through that
particular delegate. Moxi needs a child-dependent measurement hook for forms.
[Compose custom layout](https://developer.android.com/develop/ui/compose/layouts/custom)
restricts repeated child measurement in a pass. Moxi instead permits explicit,
memoized intrinsic/final queries; this is a conscious tradeoff with a cache and
observability obligation, not a universal framework rule.

[Flutter's sliver protocol](https://api.flutter.dev/flutter/rendering/RenderSliver-class.html)
provides the relevant precedent for mixed viewport sections. The useful abstraction
is viewport-aware partial content, rather than making every collection pretend to
be an ordinary fully realized box.

[Kiwi's documented internals](https://kiwisolver.readthedocs.io/en/latest/basis/solver_internals.html)
describe numeric strengths and stay emulation. They do not supply a general proof
of unique geometry. The design therefore promises explicit requirements, sizing
summaries and tested helper policies, and avoids an unsupported portable ambiguity
check.

## Confidence and promotion gate

The combined reference suite passes **35 tests**. In temporary copies, deliberately
reintroducing four faults caused the corresponding regression checks to fail:
clipped baseline union, reversed anchor correction, stale scroll-plan publication,
and state retention across a changed owner. Those checks establish that the tests
distinguish these known failures from the chosen behavior; they do not establish
native runtime correctness.

**High confidence in the contract boundaries:** stable children under policy changes;
controller-owned interactive chrome; distinct intrinsic/final measurement and commit;
viewport-owned offsets with section composition; runtime-owned stale-work protection.
The evidence is concrete authoring examples, primary-source protocols, independent
adversarial review, and the executable reference checks linked above.

**Production readiness is unverified.** These models do not establish Mojo ergonomics,
native text correctness, accessibility/IME behavior, bounded production caches,
2D virtualization or frame time. Backend selection also remains provisional.
The viewport probe covers one row section between fixed header/footer boxes;
arbitrary section providers, section reordering and cross-section anchor fallback
remain design contracts to validate in the next implementation slice.

The next implementation slice should compile the small custom-layout interface in
Mojo and exercise one real paragraph in a resizable two-pane screen with a mixed
viewport. Promotion requires measure/draw payload sharing, no stale input or
accessibility geometry, zero unchanged leaf measurements, safe collapse during
composition, and bounded realization. An awkward external authoring exercise,
provider-specific measurement dependency, or a two-axis ownership counterexample
would change the API; native cost measurements could change its implementation.

No production source files were changed for these probes. The full repository suite,
native UI checks, benchmarks and CI were not run for this design-only iteration.
