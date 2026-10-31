# Lifetime integration and author trial

This experiment asks whether the explicit assignment/reset contract survives real
App scheduler and native-input boundaries without putting lifetime bookkeeping in
application models. It extends `../lifetime-contract`; the API remains experimental.
The baseline is `becd2ba` on `feat/data-workbench`. Run:

```sh
python3 experiments/lifetime-integration/run.py
python3 experiments/lifetime-contract/run.py
```

`results.json` records exact source hashes, commands, outputs, compiler and platform.
The native probe requires macOS; the runner explicitly records its omission elsewhere.

## Contract supported by the probes

| Operation | Meaning | Ownership/state behavior |
| --- | --- | --- |
| Ordinary field assignment | Change the current document's values | Existing callbacks reach current values; unchanged text retains editor state |
| `update_model(app, command)` | Publish an external model command synchronously | Reconcile before further delivery; use this for collection reset outside UI handlers |
| `Keyed.reset()` inside a published command | Replace the collection's logical children | Fresh keys/controls; retire their requests and addressed packets |
| Root reset through the host adapter | Start a different document/session | Cancel root-owned requests, invalidate old native ingress, clear editor/scroll/gesture state, retain normal initial focus |
| Move an App | Transfer the same owner | Pending actions and requests remain valid |
| Copy a host into a new App | Create another owner with copied values | Independent delivery scope; source envelopes cannot mutate the copy |

Stable keys/scopes remain necessary for dynamic siblings. Raw model mutation followed
by a delayed refresh is not a publication boundary. Generic raw actions/events cannot
prove provenance. These are preconditions, not cases fixed by root-reset syntax.

## Real request scheduler

`request_bridge.mojo` uses **App's existing RequestScheduler**, including its
supersession and `should_deliver` checks. It owns scopes it creates, binds completion
actions to host/control identity, and cancels those scopes when controls retire.
It does not cancel unrelated App-owned work. `requests.mojo` checks assignment,
already-ready supersession, pending/ready child reset, root reset, foreign hosts with
equal numeric handles, ready-queue overflow, and repeated reset with bounded records.

This uncovered a production retention defect: 100 root resets left 103 scope records.
`becd2ba` reclaims cancelled scopes and their mounted bindings; monotonically allocated
IDs preserve stale-handle rejection. `tests/request_scope_retention.mojo` exercises
1,000 mount/unmount cycles and another 1,000 direct-cancel/remount cycles, with a live
survivor and stale ready results. Existing request suites also pass.

The bridge is adapter scaffolding, not a new application effects abstraction. It
supports only successful parameterless button completions, uses an explicit capacity
precondition, and must be the sole consumer of the request-ready queue. It forwards
unrelated results to App dispatch. Combining it with `App.advance_tasks()` would race
two queue consumers and is unsupported. Payloads, failures, timer integration, and
threaded workers are not a proposed final API here. Request keys identify stable
operation slots: the scheduler retains generation state for each distinct key until
its scope closes. The bounded-reset result does not claim bounded storage for an
ever-growing key vocabulary inside one live scope.

## Real native queue, generated lifetime prototype

`native_probe.m` includes a generated copy of `native/macos_window.m`. The runner adds
a queue-entry lifetime and current backend lifetime, stamping both real enqueue
paths. It compiles with warnings as errors, then `native_queue.mojo` uses the real
Mojo `MacOSWindow.poll_event` adapter. No production native source is modified and no
window is displayed.

The negative control demonstrates that queued, unaddressed keyboard text edits a
replacement root after model-only reset. The candidate host transaction invalidates
native ingress, clears native marked text/pointer gesture state, cancels owned
requests, and performs the model/retained/App reset before delivery resumes. Old
text, targeted text, IME, key, pointer-down/up and semantic-action packets are
rejected; an old resize packet is still processed. Fresh native input and request
completions work. Addressed packets also reject retired monotonically allocated IDs.
An already-dispatched button press is retired by reset, so a fresh release cannot
activate the replacement button. Retained native accessibility objects invoke real
press/text callbacks after reset while the native snapshot still holds their old
IDs. These packets have a current queue lifetime but cannot mutate the new root: the
retired target check is independently necessary.

Within one root, unaddressed input remains an ordered stream: Tab → activate → Tab →
type, and click → type, follow focus changes during dispatch even when all events
were queued before a render. Capturing every input's target from the last rendered
focus would break this behavior. Addressed asynchronous work has stricter owner
provenance; ordinary input follows the evolving focus within the current root.

This does not specify all child-removal/IME UX, guarantee OS cancellation of a
composition session, or implement multiwindow epochs. It tests actual enqueue/poll
code called by the fixture, not OS-generated Cocoa events or external accessibility
clients. The AX fixture constructs retained callback objects and publishes snapshot
entries; it does not test the native AX tree builder or OS object retention. The prototype's global backend lifetime follows the current single-backend
test shape and is not a production multiwindow design.

## Scroll and move/copy

`scroll_reset.mojo` first failed: replacing a root retained its root scroll offset and
active scrollbar drag. The experimental reset now clears App's scroll records and
scrollbar capture before rebuild. Ordinary updates preserve them. `move.mojo` checks
that moving the App preserves action/request provenance while copying its host
creates an independent owner.

## Author comfort

A GPT-5.6-Luna max worker wrote a two-editor app and its own behavioral checks from
the contract and selected examples. Its first draft is preserved in
`author-first-attempt.mojo.txt`; the corrected source is `author.mojo`. The parent
reviewed the changes and independently reran the final program. See
[the author report](author-report.md) for the exact first-pass failures and consulted
sources.

The model used ordinary fields/methods, keyed editors and published owner commands.
It needed three compile corrections: import `Pane`, use an explicit host copy inside
a new App, and put positional arguments before keyword arguments. No runtime change
was needed to make its behavioral assertions pass. The host-copy documentation now
shows the actual constructor. Control lookup by kind/ordinal is test/adapter
scaffolding; it is not extra code ordinary render methods need to write.

This is one assisted model-author trial. It does not prove universal ease. Its
replacement method updates individual fields rather than assigning a complete
Editor, and its selection check compares state without first creating a nonempty
selection. The preceding lifetime suite separately covers whole-value replacement
and active selection. Preserve that distinction when interpreting the trial.

## Decision and remaining limits

High confidence in the tested lifetime mechanics and scheduler regression. Moderate
confidence in the author-facing contract: ordinary values and methods, stable child
keys, explicit new-lifetime reset, and one publication boundary for external commands.
The added mechanics belong in the host/adapter, not every model. Human mistakes about
assignment versus reset, or real native IME behavior that violates these assumptions,
would change the recommendation.

This slice supports proceeding to a production extraction decision; it does not
establish merge readiness. The reset entry point in the earlier prototype remains
model/App-only; native/request integration here is an adapter candidate, not something
already connected to `App.run`. Adopting it means giving the production host one reset
transaction, with native invalidation and owned-request cancellation beneath it.

No new speed claim: envelope/refcount/epoch/bridge overhead was not benchmarked.
Full production-suite coverage, CI, rendered pixels, real user input, concurrency,
integer exhaustion and human usability were not checked. The selected production
regressions and preceding ten-program lifetime suite are recorded separately.

## Independent native review

A separate GPT-5.6-Luna max source review traced native enqueue/poll, App dispatch,
routing captures and accessibility against requested baseline `646041e`
(the checkout advanced to `becd2ba`; the inspected native/routing files were unchanged). It did not execute tests or review
the later complete adapter implementation. Its findings agree with the parent
negative control: rebuild is not an input-lifetime boundary, and monotonic IDs alone
do not protect unaddressed input. It specifically identified already-active pointer
capture and late retained AX callbacks; the parent added the executable cases above.

The review also identified Linux's separate deferred queue and targeted IME packets
(`native/linux_window.c`), plus the process-global one-window native contract
(`docs/architecture/adr-005-host-frame-contract.md`). Linux runtime behavior was not
tested here. A copied Mojo host does not clone a live native window; production
binding must preserve that distinction. Native callback provenance across rebinding
an existing window to a different host needs explicit treatment before adoption.
