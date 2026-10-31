# Explicit lifetime contract experiment

Intent: distinguish ordinary value replacement from starting a new UI lifetime,
without changing ordinary model fields or introducing a model wrapper. Baseline:
`3d26104` on `feat/data-workbench`. Experimental runtime only; no production edits.

Proposed contract:

- Assignment preserves logical identity. Old actions target current values, and
  unchanged text keeps selection/IME. Changing text follows existing editor rules.
- `Keyed.reset()` clears entries while preserving its key allocator. Appended
  children therefore receive new identities. Assigning a fresh Keyed value is a
  same-owner update, not a supported new-lifetime reset.
- `host.reset(root)` creates a fresh delivery scope, clears retained controls,
  preserves the control-ID allocator, and renders the replacement root. The outer
  App must rebuild afterward so focus tracks the new view. `reset(app, root)`
  performs both steps, clears App scroll records/scrollbar capture, and retains
  Moxi's normal first-focusable-control policy.
- External model commands use `update_model(app, Root.reset_editors)` to mutate,
  render, and reconcile synchronously before queued delivery resumes. Ordinary UI
  handlers already have this lifecycle. Raw field mutation plus later refresh is
  not an atomic reset and must not interleave with delivery.
- Dynamic siblings need stable explicit scopes/keys. Positional declarations are
  safe only while their logical structure remains stable; envelopes cannot infer
  that a same-kind control at the same position now means something else.
- Captured actions and queued events carry an opaque scope owned outside the
  model. Delivery checks that scope before mutation or App focus/event processing.
  A captured action also requires its original control ID to remain live.
- Constructing or copying a host creates a distinct delivery scope. Its model and
  retained UI values copy normally, but queued work must be captured on the intended
  host. Independent copies can allocate equal keys and IDs without cross-delivery.
  Resetting one host leaves the other host's deliveries valid.

Boundary: compose the prior typed-key and retention candidates, add a reset method
and delivery envelopes. Raw Action/Int-target Event remain low-level internals;
these envelopes must be used at asynchronous capture/enqueue time, not stamped on
arrival. Queued delivery currently accepts only explicitly targeted action, text,
and composition events. Keyboard/pointer and untargeted inputs are rejected; App
otherwise resolves their targets at dispatch time. Native adapter integration must
settle their routing semantics before expanding this boundary. This prototype does not wire a native event queue or make raw direct
Action invocation safe across arbitrary owners.

Verification: assignment controls; collection/root reset; stale deliveries before
and after refresh; same numeric ID in two simultaneously live hosts; host copies;
focus, selection, active IME; fresh deliveries; repeated reset with bounded records.
Preserve the six historical replacement observations as explicit raw-path limits.
Record source hashes and commands. No performance, human usability, full production
suite, merge, or CI claim belongs to this slice.

## Author-facing shape

Ordinary model methods and declarations stay as they were. A collection reset is
an owner method, with no generation arithmetic:

```mojo
def reset_editors(mut self):
    self.editors.reset()
    _ = self.editors.append(Editor())
```

At the application boundary, `reset(app, Root())` starts a new root lifetime.
`app.component.root = Root()` instead replaces values within the current lifetime.
That distinction is intentional and must be taught; concise spelling alone does
not establish comfort. Existing manually routed non-collection children still
need their typed mount keys and reset policy.

Async adapters capture and deliver work using ordinary Mojo functions:

```mojo
var pending = app.component.queue(targeted_event)
# Later, possibly after reset or replacement:
_ = deliver(app, pending)
```

A captured parameterless button action uses `app.component.capture(control_id)` with the same
`deliver` entry point. Synchronous input continues through the existing App route.
Envelope plumbing belongs in the runtime/adapter; application authors should not
stamp scopes or manage session counters. The prototype leaves its fields public
and keeps the old raw APIs, so this is a correctness convention, not a security
or enforced API boundary.

## Findings and limits

The first shared-scope copy design passed ordinary copy/reset tests but failed
`copy_divergence.mojo`: two copies independently reset their collections, allocated
equal keys/control IDs, and cross-delivered a fresh captured action. The candidate
now gives each host copy a distinct scope. Envelope copies preserve their original
scope, and the reference-counted marker stays alive while pending work refers to
it, preventing marker-address reuse during that lifetime. No model pointer is
retained. This is process-local identity, not a serialized/network token.

Reset uses normal view reconciliation: removed editing state is discarded and the
first new focusable control receives focus. A test that expected focus=-1 was
incorrect for a nonempty replacement view; no production focus behavior changed.
An initial record-count assertion also omitted two retained scope declarations;
the complete fixture has five retained records, including its scopes.

Run `python3 experiments/lifetime-contract/run.py`. Evidence is in `results.json`:
commands, output, source/generated hashes, compiler, platform and baseline. The
ten-program suite passes and covers value/whole-root assignment, preserved selection/IME, collection and
root resets, stale text/IME/actions, 100 root resets, distinct hosts with equal
numeric IDs, independently allocating host copies, destroyed source hosts with copied pending
envelopes across 100 new hosts, unsupported queue inputs,
prior workbench/nested/churn/retention checks, and exact historical replacement
observations. The raw-path counterexamples remain deliberately visible.

The independent smaller-model review found two additional contract holes. A bare
collection reset leaves old retained IDs valid until refresh; the original test
ignored the return value and therefore did not prove pre-refresh rejection. The
supported external path now uses `update_model`, and the fixture requires False
for all old deliveries after it returns. `unpublished_reset.mojo` preserves the
unsafe bypass as a negative control: delivery returns True even though the keyed
route suppresses the model write. A handled Bool is not proof a callback ran.

`structure.mojo` also reproduces same-kind positional aliasing: removing Alpha
lets Beta inherit its ID; an old captured action increments Alpha while an old
queued event increments Beta. Explicit stable scopes prevent both deliveries.
This was inherited behavior, not fixed by a host envelope. Stable structure/keys
are now a hard precondition. The reviewer inspected source and parent results;
the parent added and ran the counterexample/regression probes. That slice included no second model
review round or fresh-author usability trial; see the integration follow-up below.

High confidence in the targeted-delivery checks under these preconditions. Moderate
confidence in explicit reset as the right public contract; a fresh author trial
and native queue integration could change that judgment. No new performance
claim: scope allocation/refcount and envelope overhead were not measured. This reset helper
still does not cancel App tasks/requests or establish behavior
for native accessibility/keyboard/pointer queues. The integration follow-up added
scroll reset here and tests the other boundaries in adapter scaffolding. Those need integration with the
existing App/request lifetime machinery before production use. Control/key integer
exhaustion and concurrent delivery are outside the checks. Full production tests,
CI, native event/pixel validation, human usability and merge readiness were skipped.

## Integration follow-up

The [integration experiment](../lifetime-integration/README.md) exercises App request
scopes, the real native queue/poll adapter with a generated lifetime prototype,
scroll reset, App moves, and a fresh smaller-model author trial. It supersedes the
pending evaluation list above; native/request integration is still adapter scaffolding.

A host copy means copied values in a new owner, not an implicitly copied App:

```mojo
var duplicate = App(HandlerHost[Workspace](copy=source.component), Rect(0, 0, 640, 900))
```

`var moved = source^` transfers the same App owner and preserves pending deliveries.
The copy spelling is primarily a host/tooling concern. Ordinary application callbacks
continue to mutate model fields through methods.
