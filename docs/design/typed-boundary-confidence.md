# Typed boundaries: what the larger experiment decides

Keep ordinary fields, methods and read-only render functions as the authoring
foundation. **High confidence for the tested synchronous, owned-value model:**
selective declaration rebuilding does not require signals, field wrappers or a
new authoring language. The heterogeneous application and its generated
extension preserve correctness without per-field dependency lists.

Do not adopt the current experimental host as a public API. **High confidence:**
its repeated composition/routing declarations and positional identity rule are
real unresolved authoring costs. Passing the tests supports the mechanism; it
does not establish that people will find this API easy.

**High confidence:** whole-context structural equality should not be an
unconditional default optimization. The workbench timing below is a concrete
counterexample. **Moderate confidence:** conservative typed component inputs
remain a useful correctness baseline for cache boundaries. They delimit what a component can
read and prevent an undeclared input from silently entering that cache. They
still compare and copy more state than a component may display. Coarse input
boundaries are not automatic read tracking, and their cost must remain visible.

## Executed evidence

The October 30 follow-up uses implementation `feat/data-workbench` at `e66cdd9`
plus new uncommitted research under `experiments/typed-boundaries`. It imports the
prior domain and editor unchanged. `results.json` records exact source hashes,
commands, generated source and output; no implementation tree is copied here.
Reproduce with `python3 experiments/typed-boundaries/check.py`.

The workbench has eight heterogeneous regions: header, two editors, settings,
activity/history, scratchpad, read-only preview, and conditional inspector.
A generic `Boundary[Root, Child, Context]` compares the whole owned child and
its whole typed context. The application supplies explicit current-root routes.
A second host forces every mounted boundary to rerender, using otherwise
identical composition and dispatch.

Eight programs pass under Mojo 1.1.0 (`8189361e`):

- The base and generated-extension apps each execute 500 deterministic mixed
  transactions, with complete root, `ViewNode`, and `PaintCommand` equality
  after every paired operation. This covers IDs, geometry, semantics, selection,
  composition and changed flags as well as text and enabled state. Root layout
  metadata, paint changed/removed counts, dirty bounds and removed regions match.
- Separate expected-state assertions cover private drafts/notes, commit,
  conflict, reload, undo, validation/Unicode, permissions, read-only preview,
  external mutation with explicit refresh, copied-root routing, and retained
  callbacks/events from a removed inspector.
- Focus/caret editing, IME composition through a sibling update, and resizing
  retain parity. A local note edit rebuilds one region; a document commit
  rebuilds its five readers, leaving header/settings/scratchpad cached.
- Adding an editor reviewer field, setter/input and a new shared limit label
  changes no cache, host or workbench wiring. The new local input remains local;
  all three new editor labels follow a limit change.
- Reading `settings` from an inspector given only `Document` fails compilation.
  Supplying the cache a context type different from its pane's declared context
  also fails compilation.
- A conditional notice inserted before a positional input fails at runtime
  with a control-kind change. The existing named-scope repair preserves the
  input ID and active composition. Both outcomes are tested.
- Same-key remount fails explicitly. A separate hidden-setting fixture confirms
  conservative over-invalidation: five boundaries rebuild for an undisplayed
  setting; header, scratchpad and document-only inspector stay cached.

A focused independent static review exposed confounded permission evidence,
caller-only remount enforcement and incomplete paint metadata comparison. The
revised checks use a valid short draft and asserted permission toggles, invoke
the read-only preview command directly, reject same-key remount, and compare
dirty/removed paint metadata. Copied-root dispatch now starts with an old cached
context. All eight programs pass after these revisions. A compiler crash from
adding another count assertion to the large program was worked around by moving
that check to a small passing fixture; the compiler defect remains unresolved.

The differential reference shares routing/composition with the cached version.
It forces declarations while retaining controls, rather than building a fresh
retained runtime. It catches cache divergence, not every common runtime defect. The
independent state assertions and identity negative control provide additional,
bounded evidence; this is not a proof of arbitrary application correctness.

## What an author actually pays

The leaf editor remains ordinary Mojo:

```mojo
def set_note(mut self, text: String):
    self.note = text

def render(self, mut ui: UI[Self, Services], services: Services):
    ui.text_input("Private note", self.note, Self.set_note)
    ui.button("Apply", Self.apply, enabled=services.settings.writable)
```

The unchanged editor also owns draft/error/revision state and applies domain
validation through current services. Those details are application behavior.
There is no second list of fields that must change when a render reads another
member of the supplied context.

Composition still requires each cache's type, construction, input selection,
route, refresh, compose and dispatch calls. The experiment has eight explicit
routes and an application-owned inspector mount epoch. A read-only preview
copies `Services`, overrides permission, and discards context writes. That is
clear, but expensive when the context contains a large history. The explicit
third generic context type works around constraints encountered in the installed
compiler; a compile-time equality assertion guards its internal `rebind`.
No claim is made that this is the best possible Mojo formulation.

Changing structure also needs identity discipline:

```mojo
if self.notice:
    ui.begin_scope("notice")
    ui.label("Unsaved changes")
    ui.end_scope()
ui.text_input("Note", self.note, Self.set_note)
```

This reproduces the earlier identity rule in a focused failure/repair test.
Same-kind reorder, arbitrary dynamic collections and delayed work remain
outside this test. A mounted inspector's epoch fixes that inspector's stale
callbacks; it does not fix every collection or control lifetime in Moxi.

## Whole-frame cost changes the recommendation

The separate `python3 experiments/typed-boundaries/cost.py` probe compiles once
with `-O3`, warms each case once and takes three samples. Timed work is actual
`App.update` plus backend-neutral `App.paint` for the same local draft edit;
setup, checks and destruction are outside the timer. `cost-results.json`
preserves raw samples, machine/compiler details, commands and source hashes.

| Shared history entries | Cached median (range), ms | Forced median (range), ms |
| --- | ---: | ---: |
| 0 | 0.126 (0.124–0.127) | 0.143 (0.142–0.144) |
| 10,000 | 0.320 (0.320–0.322) | 0.193 (0.192–0.194) |
| 100,000 | 2.503 (2.245–2.571) | 0.742 (0.701–0.830) |

The cached path renders one boundary; the forced path renders eight. Both use
the same generic cache/host machinery, including snapshots and the preview
scope copy. The forced path short-circuits comparisons, and wins when broad
input equality costs more than the declarations it avoids. This is evidence
against an unconditional whole-context comparison strategy, not evidence that
all incremental systems are slower or that these timings predict native latency.
Three samples establish a local counterexample, not a universal speed ratio.
The machine was not isolated from other work; this is diagnostic evidence, not
a controlled latency benchmark.

This revises the preceding recommendation to continue conservative selectivity
as the default direction: retain it as a correctness baseline or measured
optimization, and require full-frame benefit before making it the default.
The authoring recommendation survives the counterexample; the particular
change-detection mechanism does not earn default status from render counts.

## The earlier selective host also loses at full-frame work

A separate optimized benchmark under `experiments/selective-costs` compares the
previous `HandlerHost[Application]`, `SelectiveHost[AllInputs]` and
`SelectiveHost[DisplayInputs]`. Run `python3 experiments/selective-costs/run.py`.
The manifest records machine/compiler, exact hashes, raw samples and validated
protocol counts: 87 frame/stage rows and 27 model rows. Root review checked its
source, validation and manifest against the current files.

At 100 fully composed editors, actual `App.update` plus backend-neutral
`App.paint` has these medians and ranges in milliseconds (three samples after
two warmups; Apple M4, Mojo 1.1.0, `-O3`):

| Host | Local draft edit | Shared Apply command |
| --- | ---: | ---: |
| Original handler | 14.974 (14.968–15.102) | 14.972 (14.866–15.662) |
| Selective whole inputs | 33.997 (33.585–38.536) | 34.826 (34.630–34.917) |
| Selective narrow inputs | 33.773 (33.683–34.319) | 34.812 (34.725–39.628) |

The small two-editor cases are close; the 1,000-editor cases are multi-second
for every host. Those largest cases have only one warmup and one sample, an
explicit feasibility cap rather than a stable estimate. The test uses a tall
viewport to compose all editors; it does not test virtualized lists.

Separate stage timings put much of the observed cost in backend-neutral paint:
100-editor `paint_after_update` medians are about 13.6 ms for the handler and
32.1/33.2 ms for whole/narrow selective inputs. Build/layout and idle App rebuild
are measured separately; these stage samples are not additive parts of the
same measured frame. A profile is still needed to identify the implementation
hotspot; stage timings alone do not prove its cause.

Unlike the eight-region experiment, these modes have different retained
composition wrappers. Checksums compare visible leaf kind, text, enabled and
checked state, plus independent domain assertions; they do not prove full
structural, geometry or identity equality. Therefore this comparison assesses
the existing adapters as implemented, not an isolated cost of selectivity.
Narrowing shared inputs alone does not rescue this adapter's full-frame cost.

The separate snapshot/equality microbenchmarks are diagnostic, not allocation
profiles or promises of production cost. Snapshot loops include temporary
construction/destruction, and empty-history operations are normalized from
1,024 repetitions because individual calls are below useful timer resolution.
The eight-region whole-frame counterexample is the cleaner evidence against
unconditional broad equality.

## Decision and remaining evidence

Choose the authoring foundation now. Keep current-state commands and repeatable
rendering, and keep change detection beneath that surface. Treat full rebuilding
as a correctness reference. Further framework syntax comparisons would be less
useful than reducing the demonstrated composition and identity costs.

The current host is research machinery, not the next public API. Integrating a
boundary into Moxi's existing retained component execution should preserve the
ordinary editor source and centralize mechanical routing/lifetime work. A new
public cache type or extra per-field dependency checklist would spend the
comfort benefit these experiments are trying to retain.

The next useful implementation experiment should profile and reduce the actual
retained frame cost, using these same workloads and parity checks. Keep the
authoring source unchanged, isolate topology changes from change detection,
and measure full update/paint time. Only then integrate boundary routing and
lifetime work into normal composition; do not expose this prototype host as
the public API. A declaration-count win alone is no longer an acceptance gate.

The experiments do **not** yet establish fast automatic selectivity without
additional author ceremony. That combined claim remains unproven: broad equality
is correct under this contract but expensive, and narrow hand-written inputs
can miss new reads. A replacement must be measured without silently transferring
dependency maintenance to application authors.

The high-confidence authoring recommendation would change if a representative
application needed pervasive wrappers, dirty calls, hidden side effects or
per-field dependency maintenance for correctness. The composition assessment
would change with a compiled ordinary-Mojo example that removes the repeated
wiring and makes conditional identity predictable. Human comprehension remains
unmeasured; automated checks cannot raise that confidence.

No production source or public API was changed. Native renderer/GPU latency,
allocation/heap behavior, async races, arbitrary aliases/custom equality,
accessibility behavior on a live OS, full regression tests and human usability
were not verified. Whole-value equality assumes complete equality contracts
and owned values; external writes still require host refresh and App rebuild.

The [interactive counterexample](typed-boundary-confidence.html) compares the
eight-region timings as history grows.
