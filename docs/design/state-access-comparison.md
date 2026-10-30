# State access, ownership and update work

October 30, 2026. Experimental results; no adopted public API.

Follow-up: [actual Marko 6 Tags API browser experiment](marko-tags-reactivity.md)
adds three compiler-backed variants and a matched work comparison. The original
Mojo/Solid results below retain their original scope.

**Keep current-state ownership as the working baseline, but do not treat the
earlier shared-pointer experiment as evidence against Solid's approach.** That
experiment tested storage and callback transport. This follow-up tests two
missing ideas: reaching shared dependencies through nested components, and
updating only computations that read changed data.

The result is not a choice between clear but clunky and sleek but wasteful.
Ordinary methods, reusable state projections, scoped dependency access and
selective updates are separate design choices. The difficult part is making
their lifetime and invalidation rules fit Mojo without pushing those rules onto
every application author.

## What ran

Implementation: `experiments/state-access/` in the `feat/data-workbench`
checkout, based on `0764b1b5e8017526a8e94b2b367480a9d7f7590f`.
Planning baseline: `9969376de584045905d43151b08353fc33b02539`. Experiment sources
and captured results are preserved in [implementation commit `e66cdd9`](https://github.com/davidmashburn/moxi/commit/e66cdd95dcffce3519fb6970087a15fe1821a4db); this follow-up is versioned
on `project-planning`. Result manifests retain the execution baseline and exact
source hashes; a branch name alone does not identify the tested sources.

The nested example is Shell → Workspace → Group → Editor. Two editors have
private draft, note, error, document identity and base revision. They share a
document and settings. Committing checks identity, revision, write permission
and normalized name length. Shared labels update, while a sibling's draft stays
private until Reload. Undo restores the previous committed name and advances
revision. Removing, remounting and replacing state exercise identity/lifetime
boundaries.

| Question | Mojo implementation | Solid implementation |
|---|---|---|
| Runtime fidelity | Real Moxi `App` with synthetic input; existing method-binding runtime | Actual pinned Solid 1.9.17 client runtime in Node, with providers, signals, stores and effects |
| Local state | Ordinary value fields | Private signals |
| Shared access | Explicit typed `Services` bundle passed through component signatures | Separate Document/Settings providers, found by descendants |
| Child composition | Compile-checked field adapter and reusable keyed collection | One-time component setup under an owner; collection explicitly mounts/disposes editor roots |
| Commands | Ordinary methods; framework routes to current root/child | Closures call domain operations through a stable document slot |
| Selective work | Separate full/memo projection harness; cache not integrated into App | Actual tracked sink computations |
| Scope override | Explicit alternate service bundle | Nested provider shadowing |
| What it is not | An execution or benchmark of Xilem | A DOM/native UI benchmark or a Mojo reactive runtime |

The test suites share behavioral requirements, not a byte-identical replay of
all input events. Domain storage and error wording differ. The measured scale
cases use the same five output dependencies and mutation sequence; no input,
layout, widget reconciliation or callback construction work is included there.

## What the Mojo author writes

The editor remains ordinary fields and methods:

```mojo
def render(self, mut ui: UI[Self, Services], services: Services):
    ui.label("Current: " + services.document.name)
    ui.text_input("Name draft", self.draft, Self.set_draft)
    ui.text_input("Private note", self.note, Self.set_note)
    ui.button("Apply", Self.apply, enabled=services.settings.writable)
    ui.button("Reload", Self.reload)
    ui.label(self.error)
```

An intermediate component no longer writes a forwarding action method:

```mojo
def render(self, mut ui: UI[Self, Services], services: Services):
    field["workspace"](ui, self, services, key=1)
```

The adapter projects the same field during rendering and event dispatch. The
field name is compile checked. A reusable `Keyed[Editor]` owns entries and looks
up current membership on dispatch. Adding a Reviewer field changes only Editor;
the application and adapters remain byte-identical in the extension test.

One explicit application boundary still joins separately owned state and
services:

```mojo
def route_shell(mut self, key: Int, action: Action[Shell, Services]):
    action(self.shell, self.services)
```

This removes repetitive routing source. It does not remove the `Services`
parameter from intermediate signatures, implement ambient context, or establish
that `field["workspace"]` is the right public spelling. Its field strings select
compile-time members; they are not unchecked runtime paths.

Solid's corresponding editor calls `useDocument()` and `useSettings()` at setup,
creates its local signals, and installs computations that read the properties
they display. Shell and Workspace do not forward those dependencies. Providers
select which document/settings an editor sees; reactive reads determine which
computations subscribe. Neither mechanism by itself grants or revokes command
authority.

## Measured output work

Nine Mojo checks pass, including expected compiler rejections, the local field
extension and descriptor lifetimes. The integrated Solid suite passes 125
assertions. A separate comparison verifies both source manifests and equal
changed-write counts across 15 cases (2, 100 and 1,000 editors). All results are
reproducible from the experiment README. Review corrected initial differences
in Apply enablement, no-op rename and Undo before taking these final counts.

At 1,000 editors, each with five output sinks:

| Mutation | Full projection evaluations | Per-editor memo evaluations | Solid evaluations | Changed writes, all three |
|---|---:|---:|---:|---:|
| First editor draft | 5,000 | 5 | 1 | 1 |
| First editor private note | 5,000 | 5 | 1 | 1 |
| Shared name | 5,000 | 5,000 | 1,000 | 1,000 |
| Write permission | 5,000 | 5,000 | 1,000 | 1,000 |
| Unread settings property | 5,000 | 0 | 0 | 0 |

**Every memo pass additionally checks 1,000 dependency records**, including the
unread-property case. Each record contains five values. Both Mojo strategies
visit all editors; the memo strategy avoids some output computation but is not
constant work for a local edit. Solid's figures count actual effect callbacks;
subscription setup, graph maintenance and scheduling overhead are uncounted.

The [interactive comparison](state-access-comparison.html) shows all three
sizes. Its values come from `experiments/state-access/comparison.json`, which
hashes the two source-verified result manifests. Matching changed-write counts
are a useful guard, not proof of complete framework or behavioral equivalence.

These are operation counts, not elapsed time or total CPU work. The actual
Mojo App still rebuilds through its existing runtime. The five-output memo
cache is a separate prototype and cannot be presented as an optimized App.

## Limits exposed by the experiment

**Nesting still has a runtime cost.** One render of two Mojo editors across four
boundaries creates 40 erased callback descriptors and destroys all 40. There
are two allocation sites per descriptor in the inherited implementation. This
is instrumentation plus source inspection, not allocation profiling. The
adapter avoids retained application-state pointers but inherits unsafe erased
callback storage. A shorter application does not imply a cheaper runtime.

**Fresh keys are only safe within the tested collection lifetime.** Removing
and appending a Mojo editor assigns a fresh key; a retained old action becomes
inert. Replacing the entire collection resets its key allocator. A retained
action can then reach a new child with the same key. The executable negative
control demonstrates that failure. Generation identity or an equivalent
lifetime contract is required before adoption. The 100-cycle test bounds
collection entries, not the inherited retained UI's retired identity records.

**Solid disposal detaches observations, not arbitrary retained commands.** A
disposed editor stops evaluating its UI sinks. A retained callback can still
commit after its local revision/draft are refreshed through retained methods;
it does not resurrect those sinks. Normal removed UI cannot invoke that
callback, but external references or future async work need an explicit command
lifetime policy. This is different from claiming that every removed component
must revoke all of its domain operations.

**Document identity is separate from revision and subscriptions.** Both variants
reject a draft belonging to a different document even if its revision matches.
Solid's stable slot changes the document observed by existing readers; drafts
remain private until Reload. The Mojo application supplies distinct document
identities. Reactivity does not establish that identity policy for either one.

**Mojo origin constraints remain relevant.** A simple generic lens trait failed
because the whole-parent return origin did not match the projected field's
origin. Compile-time reflection and type-equality `rebind` checks work for the
tested field adapter. This is evidence about those two implementations, not a
proof that general lenses are impossible. The original deeply nested integration
source also crashed Mojo 1.1.0; ordinary model methods avoided the crash. The
unminimized source is preserved under `diagnostics/` outside the passing suite.

## Recommendation and decision gates

**Moderate confidence:** retain ordinary model fields, methods and current-state
dispatch as the authoring baseline. Keep reusable field/keyed composition as an
experiment. Correct the callback allocation and identity contracts before
adopting its runtime.

**High confidence in the mechanism distinction:** context lookup and dependency
tracking solve problems the earlier shared-handle test never exercised. Solid
is a useful reference for both. A scoped dependency facility could coexist
with value-owned application state; using context does not require Redux,
globally writable state or a different template language.

**Low confidence in universal comfort or comparative native performance.** The
Solid counts justify testing selective updates; they do not justify replacing
Moxi's ownership model or promising a native speedup. The Mojo memo strategy
scans every editor. Xilem's explicit memo data can be placed at different
subtree boundaries; this scan is not a lower bound on Xilem or Moxi work.

The next useful decision gate is one small Mojo implementation of targeted
invalidation behind the same editor methods, compared with a coarse subtree
memo boundary. Require the same visible behavior, identity/replacement tests,
bounded subscriptions/retired state, and a complete source example. Count setup,
dispatch, allocations and teardown as well as update work. If that requires
application-managed subscriptions or a second state language, it fails the
comfort goal even if the update count improves.

Separately, have an unfamiliar reader add a field, another shared dependency
and a nested editor without reading runtime internals. More passing assertions
cannot substitute for that evidence. A smaller complete authoring contract,
correct lifetime behavior and measured native cost would change the working
recommendation; user approval or isolated short snippets would not.

## Sources and verification boundaries

Raph explicitly discusses React and Redux in his
[reactive UI account](https://raphlinus.github.io/ui/druid/2019/11/22/reactive-ui.html).
His later [Xilem architecture discussion](https://raphlinus.github.io/rust/gui/2022/05/07/ui-architecture.html)
motivates current-state event routing and composition. The implemented adapter
borrows that idea, not an assertion that Xilem settled every application's shared
state problem. Current APIs include
[lens](https://docs.rs/xilem_core/0.4.0/xilem_core/fn.lens.html) and
[memoize](https://docs.rs/xilem_core/0.4.0/xilem_core/fn.memoize.html).

Solid documents [scoped context](https://docs.solidjs.com/concepts/context),
[reactive stores](https://docs.solidjs.com/reference/store-utilities/create-store)
and [fine-grained tracking](https://docs.solidjs.com/advanced-concepts/fine-grained-reactivity).
The experiment runs its actual client runtime with `node --conditions=browser`;
default Node server resolution would not test that behavior.

Skipped: full repository suite, actual Rust/Xilem execution, browser/native
rendering, accessibility, latency, allocator profiling, sanitizers,
async/concurrency/reentrancy, multi-window integration and human usability.
Neither production Moxi nor its dependency lockfiles changed. The Solid package
and lockfile are confined to the experiment. Unrelated local edits were kept.
