# Choosing Moxi's ownership model

October 29, 2026. **Recommendation, not an adopted public API.** Follow-up to the
[three complete forms](form-ownership-comparison.md) and
[framework inventory](ui-pattern-inventory.md).

Later October 29 follow-up: the [matched shared-document comparison](shared-document-comparison.md)
now passes six real-App/ownership programs, including compiled extensions. It
supports keeping current-state ownership as the working default for this
single-owner workflow; handles save two adapters but leave the root route.
The subsequent [direct-method-binding experiment](direct-method-binding.md)
removes per-action adapters and is the leading authoring candidate, with runtime
costs and reader comfort still unverified. Shared ownership and observation
remain separate choices; the new handle experiment uses no observation engine.

October 30 follow-up: [state access and update work](state-access-comparison.md)
adds compiled field/keyed composition and actual Solid context/reactivity tests.
The original ownership recommendation remains provisional. Context lookup,
state lifetime and reactive scheduling can be chosen separately; the earlier
handle comparison was not evidence against Solid's observation model.

## Recommendation

Choose **A, current-state ownership and temporary projection, as the foundation**.
Use ordinary values plus change/action callbacks at reusable widget boundaries.
Do not make B's writable observed cells the default application-state model.

This revises the earlier provisional preference for B. Its small sharing edit
was real, but it answered a narrower question: how cheaply can two forms access
one field? The larger question is how developers understand edits, policy,
history, asynchronous results and component lifetime together.

C is useful within A: a text field receives a value and calls its owner's
method, while the runtime supplies that method with current state. These are
compatible contracts, already present in the handler experiment. This does not
require applications to choose three modes, introduce a message language, or
write an event reducer. B remains an option for shared document identity and
observation where demonstrated needs justify it; that is not a fourth default.

Confidence is **moderate** in this architectural recommendation, **high** in the
bounded compiler and contract results below, and **low** that the present source
surface meets the desired comfort level. The tests do not establish universal
ease, a performance winner, or a finished child-composition API.

## What was misleading about the comparison

The original three columns mixed three decisions:

1. **Ownership and authority:** where the truth lives and who may change it.
2. **Access and dispatch:** a temporary borrow, a shared handle, or a callback.
3. **Refresh:** which dependent views are reconsidered, and when.

A shared handle does not inherently supply observation. Projection does not
require repainting everything. A controlled callback does not inherently capture
stale state. Those properties come from the implementations surrounding them.

The earlier controlled example passed a rendered Name snapshot into Save. That
is appropriate for “save this displayed version,” but not necessarily for “save
the current document.” For the latter, Save should be an owner command that reads
the owner when executed. The new test does exactly that and passes for C as well
as A and B. All three can still show stale controls until their host refreshes.

Likewise, a mutable projection can bypass domain validation just as a writable
cell can. A is not intrinsically a policy-enforcement mechanism. In each design,
we must offer the appropriate authority at the boundary: a model method, a
restricted callback, or a narrower capability instead of unrestricted mutation.

## The experiment and its actual findings

New implementation-checkout files are under `experiments/ownership-decision/`.
Run `python3 experiments/ownership-decision/check.py`; `results.json` captures
commands, output, compiler, baseline and source hashes. They are local experiment
files, not yet published at the implementation Git revision cited below.

One domain engine implements a name and a valid interval, committed edits,
undo/redo, Save and request-completion policy. Three adapters exercise it through
a temporary document projection, two shared document handles, and queued
controlled intents. Sharing the engine makes the comparison fair, but also limits
its conclusion: these tests compare transport compatibility, not three complete
frameworks or independently designed policy implementations.

| Check | Result | What it establishes |
| --- | --- | --- |
| Normalized and rejected edits; unchanged edits | A, B, C pass | Each transport can use the same edit boundary without spurious history. |
| Move interval 10–20 to 30–40; undo in one step | A, B, C pass | A semantic edit can validate and commit both fields together. |
| Undo, redo, new edit discarding redo | A, B, C pass | Value history works with every transport. Each also passes 100 edit/undo/redo/save cycles. |
| Save current owner state; edit then Save before refresh | A, B, C pass | Commands need not capture old rendered values. Ordered settlement suffices for the tested C queue. |
| Copy a shared handle as an undo snapshot | Negative control exposes aliasing | Copying a handle preserves identity; copy the values or use another explicit history representation. |
| Mutate raw state without the owner method | Negative controls expose bypass in A and B | Neither unrestricted mutable access enforces policy. |
| Superseded/duplicate completion; edit then undo; replaced entity | Common policy tests pass | Request identity and a monotonic revision handle these cases. Returning to an old value does not make an old request current. |
| Mutation from `Screen.render(self, ui)` through an `ArcPointer` | Compiles and changes state | Read-only `self` alone does not make a shared-handle render pure. |
| `App(HandlerHost(TwoForms()), bounds)` | Compiles and runs | Both generic arguments can already be inferred; the repeated startup type is unnecessary. |

The new domain test is **headless**. The two consumers in B are real aliased
handles, but there is no observed-cell implementation or subscription graph.
The shared engine's committed edits are not keystrokes: an actual field needs to
permit incomplete drafts, including temporarily empty or invalid input. A small
draft-copy check proves value isolation, not a complete editing workflow.

Four existing checks were also rerun successfully: handler contracts including
expected compiler failures, controlled child settlement, production reactivity/
task tests, and the request adapter. These cover one-action/one-refresh behavior,
conditional and keyed identity, synthetic composition and clipboard behavior,
cursor preservation in settled shared editors, and request cancellation/remount
generations. They do **not** integrate the new history engine with all those UI
features. No new native-window or real-network test was run.

The new history-bearing `Document` is movable. It does not implement the existing
`Component`/`Screen` implicit-copy requirement. The production workbench handles
similar storage with an explicit copy initializer. That is a real integration
cost for value owners, not a problem the headless experiment has solved.

## Why A wins as the default

**It gives us the smallest starting explanation consistent with today's Moxi:**
state is ordinary data; rendering reads it; event methods change it; the runtime
refreshes afterward. Current-state handlers and retained view identity have
already been exercised together. The stronger shared-owner version of B can use
the same methods, but adds reference semantics and an observation/lifetime
contract before we have established that most components need them.

This is a choice about the default burden, not a claim that reactive systems
cannot scale. B can be excellent when many independently mounted consumers
observe a long-lived model. It can restrict writes to owner methods and expose
read-only handles. But that stronger B is a shared model with a policy API, not
simply a universally writable field. Its access advantage survives; the claim
that sharing alone removes the need to design ownership does not.

**A keeps two mistakes more distinct.** A handler bug changes data incorrectly;
a refresh bug fails to display the new data. Observation can automate refresh,
but introduces dependency tracking, batched notification and disposal behavior
that developers may need to understand when updates are missing or unexpected.
That machinery can be valuable, but it should buy something measured. It should
not be adopted just to shorten the first two-form example.

**A preserves useful value reasoning.** A copied value can be a snapshot; a
temporary borrow makes its mutation window visible. This is not automatic deep
immutability: nested handles still alias, and copying large values may be costly.
Explicit snapshots, revisions and deltas remain available without making every
field reactive. Shared storage can be introduced at the document boundary if
copy or ownership constraints actually require it.

**We can improve invalidation separately.** The previous scoped-dependency
experiment already evaluates explicit and tracked dependencies over ordinary
source values. It also records remaining whole-parent composition/reconciliation
work. Adopting cells would not, by itself, eliminate that work. We should use
versioning, memoization or tracked reads where the measured cost lies, without
coupling that optimization to who has permission to edit the data.

## The strongest objection to this recommendation

A's sharing ergonomics remain worse in the original source example. B changes
construction; A changes the model decomposition and handler inputs. Passing an
unused shared argument to every local handler is a poor public interface. This
experiment does not make that objection disappear.

Grouping a genuinely shared document gives A a natural owner. Grouping unrelated
state solely to satisfy a lens would be a design failure. For independent form
drafts editing one document, the document and each draft should keep their own
lifetime and semantics. The host must route a command to the correct current
owner; a reusable form should not learn the shape of the entire application.

That route is the remaining API problem. We have concrete mutable projections
and existing root-method dispatch, but have **not** proved a generic stored
paired projection with a comfortable call site. Do not publish `project_pair`
on the strength of the current tests. Nor should application authors be asked to
write forwarding methods at every ancestor, a manual settlement pass, or a new
message enum for each reusable component.

If ordinary component extraction forces those costs to grow through unrelated
ancestors, I would prefer a narrowly scoped shared document handle over defending
A at any cost. Architectural continuity with Xilem is supporting evidence, not
a reason to preserve an uncomfortable API indefinitely.

## Complexity as applications grow

Count **boundaries crossed by a change**, not just lines or number of widgets.
The relevant workloads differ:

| Change or workload | A: current-state projection | B: shared observed owner | C: controlled boundary |
| --- | --- | --- | --- |
| Add independent instances | Good with whole-submodel projection; naive forwarding grows with instances. | Fresh owner per instance; accidental reuse aliases state. | Same reusable child contract; parent supplies each value/callback pair. |
| Share one field across unrelated components | Weakest source transition in our original comparison; owner/routing must change. | Strongest: reuse a handle. Initialization and retention rules matter. | Hoist ownership and connect consumers; forwarding through unrelated ancestors is the cost to avoid. |
| Add validation or authorization | Owner method plus limited access where required. Raw mutable borrows can bypass it. | Owner method or mediated setter; unrestricted cells can bypass it. | Change callback naturally gives the owner a decision point. |
| Multi-field edit and undo | One owner method and explicit history. | Same; notification batching alone does not define validation, rollback or undo grouping. | One semantic request to the owner. Independent per-field callbacks need a grouping rule. |
| Many views of one long-lived document | Current owner routing is clear, but cross-tree access can become awkward. | Strong case for handles and scoped observation; the document outlives views. | Good leaf API; prop/callback plumbing may dominate if the host cannot route directly. |
| Expensive derived views | Needs measured invalidation/memoization boundaries. | Tracking can automate dependency discovery; graph maintenance and broad reads still cost work. | Depends on the owner and rendering engine, not on callbacks alone. |
| Remove a view while work is pending | Resolve current identity; reject stale targets and cancel view-owned work. | Also release subscriptions; surviving document handles do not imply a surviving view. | Reject obsolete callbacks/queued intents and settle before refreshing current children. |

All three need entity identity, domain policy and an event/refresh ordering rule.
B additionally needs a reliable observation contract if advertised as observed.
A additionally needs a convincing routing/composition surface. C additionally
needs a boundary that does not spread forwarding and settlement into callers.
There is no honest numerical winner from this small experiment.

For the existing data workbench, table, plots and controls already share an owner
with explicit domain operations. That makes it a plausible A workload. Its cached
arrays, component copy initializer and broad rebuild path are also evidence
against assuming value ownership is automatically cheap. A second, independently
mounted window editing the same document would be a much stronger B workload.
Neither workload was benchmarked in this investigation.

## What Marko and Xilem actually suggest

Marko's native binding shorthand supplies a value and a change handler. Its
controllable components let the parent assume ownership and intercept proposed
changes. That explains part of the comfort: concise syntax packages an ownership
contract. We can adopt the contract in ordinary Mojo, although matching the
shorthand exactly would require language/compiler assistance or a library
representation of the binding. We should not claim the same syntax is free.
[Marko controllable components](https://markojs.com/docs/explanation/controllable-components).

Xilem 0.4.0 keeps application state as an arbitrary Rust type, gives callbacks
current mutable state, and reconciles lightweight views with retained widgets.
Its `lens` adapts a component to a field of the owner; `memoize` skips view
construction until its comparison data changes. A preserves that direction
without requiring that every event rebuild every expensive subtree. These Rust
APIs establish the architectural precedent, not Mojo feasibility for a generic
stored lens. [Xilem](https://docs.rs/xilem/0.4.0/xilem/),
[lens](https://docs.rs/xilem_core/0.4.0/xilem_core/fn.lens.html),
[memoize](https://docs.rs/xilem_core/0.4.0/xilem_core/fn.memoize.html).

Raph's earlier inventory emphasizes the friction around ownership, lenses,
incremental updates and asynchronous interaction. It is useful as design
reasoning, not a scorecard proving one modern framework is superior. The lesson
I take is to evaluate complete authoring paths and failure modes, not count which
frameworks use each pattern.
[Xilem's original architecture discussion](https://raphlinus.github.io/rust/gui/2022/05/07/ui-architecture.html).

Solid provides a useful counterexample to caricaturing reactive state: its store
API separates reads from a setter, and cleanup is tied to reactive scopes. Its
batch primitive groups downstream work; it is not a substitute for defining our
domain edit and undo semantics. These mechanisms show how B can be engineered
well, while also identifying contracts Moxi would need to supply.
[Stores](https://docs.solidjs.com/reference/store-utilities/create-store),
[cleanup](https://docs.solidjs.com/reference/lifecycle/on-cleanup),
[batching](https://docs.solidjs.com/reference/reactive-utilities/batch).

## What this means in practice

Use the existing handler experiment as the starting vocabulary:

```mojo
def set_name(mut self, text: String):
    self.name = text

def save(mut self):
    self.saved = self.selected()
    self.saves += 1
```

These methods are compiled today in `experiments/handler-api/examples.mojo`.
Its form builder supplies the current value and method to `ui.text_input`, and
supplies Save's method to `ui.button`. The runtime calls the method on current
state and then refreshes. A reusable input is controlled; the owning form remains
ordinary data. Validation/history belong in the appropriate owner method, with
separate draft state when a user must be allowed to type an incomplete value.

One event should have this order: resolve its current target, run its handler,
settle any owner requests after child borrows end, and refresh affected views.
Rendering should not replay the action. This ordering is an engine responsibility.
Application authors should not write the settlement loop.

The constructor spelling can already be reduced to:

```mojo
var app = App(HandlerHost(TwoForms()), Rect(0, 0, 520, 900))
```

Hiding `HandlerHost` entirely behind an entrypoint is a separate API decision.
Neither nesting nor type inference selects an ownership architecture.

## Decision now; one remaining adoption gate

**Composition follow-up, October 29:** the [executable gate](composition-gate.md)
passes its editing, policy, history and lifetime assertions. It avoids per-field
forwarding through ancestors, but still needs eight component-specific adapters
for four actions plus one route per root. Therefore the comfort/adoption gate
remains open; this recommendation is still provisional. Do not adopt that adapter
surface as the public API or treat behavioral success as an A-over-B usability win.

Stop adding framework inventory entries to resolve this question. Choose A's
owner/current-handler contract as the working direction, keep C at reusable
control boundaries, and defer a default observable-cell API.

The next gate is **composition quality**, not another counter or a full reactive
runtime. Extract two independently drafted editors of one document into a reusable
component; then add parent validation, undo and removal. Require that changing
the policy changes the owner, not every child, and adding another view does not
require per-field forwarding through unrelated ancestors. Keep the draft/commit
semantics explicit and preserve cursor, focus and event identity.

This is a bounded implementation target, not a recommendation to repeat the
three-way experiment indefinitely. If it cannot be expressed clearly in ordinary
Mojo, reopen B as a shared-document capability with mediated writes. Do not hide
the failure under a new DSL or a renamed wrapper. If it succeeds, optimize
invalidation using measured application workloads before adding observation as a
general programming model.

I would change the recommendation for evidence of dominant cross-tree shared
document workloads, a compiled B API that preserves render purity and teardown
without caller ceremony, or A composition that still leaks routing into ordinary
components. Conversely, a shorter counter or user approval alone would not
increase confidence. Authoring comfort still needs the user's assessment of a
complete source example and eventually evidence from unfamiliar developers.

## Provenance and verification limits

Publication follow-up: the executable ownership/composition experiments and their
handler/child-routing dependencies are preserved in implementation commit
[`f458f1f`](https://github.com/davidmashburn/moxi/commit/f458f1fc4085b533883434e447fbcb5fbfbc9cb6).
The ownership runner was rerun before publication: all six groups passed. Its
manifest now excludes ignored generated scratch probes; all 147 recorded sources
match the published tree. The baseline and initial uncommitted state below describe
the investigation, not the publication state.

Inspected implementation: `feat/data-workbench` at
`c8c7cbb7741519c9796a02ffa25c02e701b2f58a`; planning baseline:
`project-planning` at `1a1d180fa07b841aadbdf3aff197168e53224ef4`.
Compiler checked: Mojo 1.1.0 (8189361e), locked Pixi environment.

The implementation checkout already had uncommitted handler, child-routing,
render, scoped-binding and tags experiments, plus unrelated documentation edits.
This work adds only `experiments/ownership-decision/` there. The manifest hashes
the current Mojo sources, relevant experimental dependencies, runner and lockfile.
Earlier native results and scoped-dependency timing remain inherited evidence;
they were not rerun or upgraded into new performance claims. Existing Bygone
comparison files remain separate source specifications.

Skipped: full repository suite, native window interaction, accessibility testing,
performance/allocation profiling, real asynchronous I/O, thread/reentrancy safety,
observed subscription teardown, generic paired-lens integration and usability
testing. No production API or implementation branch history was changed.
