# Explicit assignment and reset contract

Status: experimental candidate, not a stabilized API or production fix. Observed
2026-10-31. Baseline: implementation branch `feat/data-workbench` at `3d26104`.
Evidence lives in `experiments/lifetime-contract` at implementation commit `646041e`;
its runner records source hashes. This follows [scoped identity and retained
storage](scoped-identity-retention.md).

## Proposed decision

Keep ordinary fields and methods. Assignment changes values within an existing
logical owner. Explicit reset starts a new lifetime. Put the delivery identity
outside replaceable model values, in the host/runtime.

- `Keyed.reset()` clears children but preserves the allocator. New entries receive
  fresh keys without application generation arithmetic.
- `reset(app, Root())` creates a fresh root delivery scope, retires old controls,
  preserves the ID allocator, renders, and reconciles App focus. Reconciliation
  retains normal first-control autofocus; old selection/IME is discarded.
- Host construction and host copying each create an independent delivery scope.
  Model values still copy normally. Pending work belongs to the host on which it
  was captured; copying an envelope preserves that provenance.
- External model changes use `update_model(app, command)`, which runs the method,
  refreshes declarations, and reconciles the App before returning to event delivery.
  UI event handlers already publish through this lifecycle. Delivery between a raw
  model mutation and its later refresh remains unsupported.
- Dynamic siblings require stable scopes/keys. Same-kind positional controls can
  silently alias after insertion/removal; host identity cannot infer their meaning.
- Capture asynchronous button actions/targeted events before reset, then validate scope and live
  target before delivery. Raw descriptors and raw numeric-ID events cannot prove
  provenance and remain internal escape hatches in this experiment.

This is ordinary Mojo API design. The runtime owns an opaque reference-counted
marker; application models do not carry a wrapper or session counter. A pending
marker stays alive until its envelopes are released, preventing identity reuse
while stale work exists. It is not a serialized or cross-process ID.

## What changed the design

A deliberately adversarial copy probe disproved the first proposal that host
copies should share a delivery scope. Two copies can independently allocate the
same fresh keys and control IDs after a collection reset. An action from one then
mutated the other's new child. Independent host-copy scopes close that case; normal
model-copy behavior and routing tests remain separate from host identity.

App also re-resolves keyboard/pointer targets at dispatch time. Merely stamping a
host scope on an unaddressed event does not stop it from following new focus. This
candidate accepts only explicitly targeted action/text/composition queued events;
it rejects unsupported kinds and unresolved targets. Native adapter routing needs
a separate integration step, not a claim that the generic event queue is solved.

## Comfort assessment

Collection authors can write `self.editors.reset()` and append replacement values.
Root replacement becomes `reset(app, Root())`. Existing render methods are unchanged.
Envelope handling belongs in the adapter, not every application callback.

The remaining teaching cost is real: `root = Root()` preserves logical identity,
whereas explicit reset invalidates pending work and editor state. The API cannot
infer that distinction from ordinary value assignment. Typed mount keys/routes for
other manually composed children remain unchanged; this is not a reduction of all
composition ceremony. No fresh author or human trial has validated the spelling. External callers also
need `update_model(app, Root.reset_editors)` so mutation and view publication finish
before queued work runs. This is a real lifecycle requirement, not zero ceremony.

## Verification and next gate

All ten programs pass. The suite tests assignment with active selection/IME, atomic collection reset, a negative control for raw mutation before
refresh, stale text/IME/action delivery, root reset, 100 repeated resets,
foreign hosts with deliberately equal IDs, divergent copied allocators, destroyed
source hosts with copied envelopes across 100 replacement hosts, and fresh work. It also runs prior workbench, nested route, churn, retention-edge, and exact
six-case replacement characterization checks. The original raw-path counterexamples
are retained as limits, not relabeled as fixed.

High confidence in the bounded targeted-delivery mechanism; moderate confidence in
the public reset contract. Native adapter behavior or an unfamiliar author's misuse
could change the recommendation. No new timings establish the cost of markers or
capture envelopes. Full production tests, CI, native queues/pixels, and human
usability were not evaluated. No production files changed and no merge occurred.

Before adoption, connect scope invalidation to existing App/request lifetime
machinery. Task/request cancellation, scroll state, native keyboard/pointer and
accessibility routing, and the permitted host copy/move behavior need explicit
integration tests. Then give a fresh author a reset/replace task without key-space
coaching. These are narrower and more informative gates than another framework
inventory or another authoring abstraction.


Existing integration evidence: `src/moxi/tasks.mojo` at this baseline already has
`RequestScheduler.mount_scope`, `unmount_scope`, `cancel_scope`, and
`should_deliver` (closed-scope plus generation checks); `App.advance_tasks` calls
`should_deliver` before dispatching request completions. The experiment does not
connect `reset` to these paths. Reuse those mechanisms during integration instead
of exposing a second application-level request lifetime system.


## Independent review and response

The GPT-5.6-Luna max reviewer identified stale pre-refresh acceptance and same-kind
positional aliasing. Both were independently reproduced. The first is addressed
on the supported external path by atomic `update_model` publication; the unsafe
raw-mutation path is retained as an explicit negative control. The second requires
stable explicit scopes/keys and is tested with both the aliasing counterexample
and the scoped control. These constraints narrow the claim; they do not establish
universal comfort. The reviewer performed source inspection, not an independent
Mojo run. Parent verification is recorded in the runner output; no second review
round was run after these changes.
