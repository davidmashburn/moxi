# Authoring documentation and production extraction

Decision accepted November 1, 2026. The user selected the ordinary-fields,
methods, stable-child-identity and explicit-reset strategy, requested practical
documentation, then authorized production extraction as a separate change.
Approval selects the direction; it does not add correctness or usability evidence.

Implementation baseline: `feat/data-workbench` at
[`9d6da90`](https://github.com/davidmashburn/moxi/commit/9d6da90).
The [authoring guide](https://github.com/davidmashburn/moxi/blob/9d6da90/docs/authoring/README.md)
provides counter, keyed-editor and shared-document examples, a general application
guide, and primary-source framework comparisons. Three examples plus a behavioral
check compile and run against the prototype. These checks cover reorder, shared
versus local state, assignment, and root/collection reset. Full production tests,
native UI and CI were not rerun for that documentation-only slice.

## Extraction contract

Make the same model API available from the production package without experiment
include paths. Integrate it with existing `App` event and request delivery; preserve
the lower-level `Component` API. Promote the bounded control vocabulary already
exercised (labels, buttons, checkboxes, text inputs, scoped children), not a universal
widget toolkit or automatic field-dependency tracker.

Retain one request queue consumer in `App.advance_tasks`. Host-owned completions
must validate lifetime and live target; request scopes retire with their controls.
Root reset cancels only owned requests, clears App interaction/scroll capture,
invalidates native input, and publishes fresh output before delivery resumes.
Keep headless reset explicitly named so it cannot be mistaken for native reset.
No new general-purpose application wrapper is required if these guarantees fit
existing lifecycle hooks. If that approach fails integration tests, revisit the
boundary before adding an adapter that competes for queue ownership.

Acceptance scenarios: the guide examples use package imports; queued/captured
work rejects retired roots and controls; ordinary replacement/reorder preserves
owners; copied hosts reject foreign completions; superseded and bounded-queue
requests do not retain callbacks; native reset drops old input but preserves resize
and close policy; sequential focus/input and late addressed callbacks behave
correctly; existing Component, scheduler, input, paint and clipboard paths pass.
Native tests must use the real production backend without source patching.

Platform scope: implement and verify headless and macOS integration here. Do not
silently offer a no-op native reset on unsupported backends. Linux requires a
separate executed GTK/IME validation before claiming equivalent native support.
No dependency change, broad unrelated cleanup, main merge or PR is included.

Confidence before implementation: high in the bounded mechanics established by
the [lifetime integration](lifetime-integration-decision.md) experiments; moderate
in production integration and application-scale comfort. Real OS IME behavior,
human author feedback, and combined end-to-end timing remain distinct evidence.

## Production result

The extraction is implemented on `feat/data-workbench` in
[`6f17e65`](https://github.com/davidmashburn/moxi/commit/6f17e65). `moxi.authoring` now
exports the model, child-composition, action and lifetime API. The guide examples
live in `examples/authoring` and use normal package imports. A native counter
uses the same model through the existing `App.run` loop.

`Component.reconcile_requests` is a default no-op lifecycle hook; `HandlerHost`
uses it to retire owned requests without draining the scheduler. `App.advance_tasks`
remains the single ready-queue consumer. Assignment preserves the current owner;
explicit reset replaces it, cancels only its work, clears retained interaction,
invalidates native input and publishes before dispatch resumes. External updates
use `update_model` to publish synchronously. The bounded request adapter delivers
parameterless button success actions; it is not a general payload/error store.

macOS reset clears queued keyboard, pointer and composition input, native editing
state and gestures while preserving ordered resize and close state. The native
probe compiles the actual production backend without patching its source. A late
accessibility text callback exposed a crash in the superclass fallback for a
retired element; the backend now ignores that retired target. Unsupported native
backends reject reset before changing the model.

Executed validation:

- The 84-file regression suite passes, including the new authoring tests.
- Focused authoring checks pass after the final adapter changes: 1,000 reset
  cycles, bounded queue overflow, supersession, explicit scope cancellation and
  reopening, host copy isolation, current-owner routing, editing retention, and
  timer/input delivery through `App.run`.
- Native queue wraparound, reset, sequential focus/input, pointer capture,
  publication, and late accessibility delivery checks pass. The optional smoke
  also passes with a real AppKit window attached; its events remain synthetic.
- The existing native accessibility ABI test passes all 64 flag combinations.
- Three guide examples and their behavior check run; the native counter builds.
- Headless package precompilation, API inventory, documentation generation,
  prose checks, local document links and whitespace checks pass.

The full local `check` benchmark/release chain was not rerun. No physical keyboard
or OS IME session, Linux native reset, human usability study, or combined
end-to-end performance measurement was performed for this extraction. Those
limits remain distinct from the passing synthetic integration tests.

The first production CI run stopped before tests because jobs using floating
`pixi-version: latest` rejected the lockfile, as they had on the preceding docs
commit. The existing Linux native job pinned to 0.81.0 passed, and local
`pixi install --locked` passed with 0.81.0. Follow-up
[`f7b8769`](https://github.com/davidmashburn/moxi/commit/f7b8769) pins the other jobs
to that same validated version without changing dependencies or the lockfile.
The [follow-up CI run](https://github.com/davidmashburn/moxi/actions/runs/41286233459)
passes Linux headless authoring/package checks and retained-layout checks;
macOS core/native validation and the remaining jobs are still running.

Confidence is high in the exercised ownership and delivery mechanics and moderate
in application-scale comfort. Frequent manual generation management, confusing
assignment/reset semantics, or repeated broad context plumbing in real applications
would change the recommendation. This extraction makes no new performance claim.

At the extraction checkpoint, documentation and production code were pushed,
local validation was complete, and independent review and CI were pending.
The follow-ups below supersede that checkpoint; main remains unchanged.


## Marko translator follows the production API — November 1

Implemented and pushed in
[`b7cb576`](https://github.com/davidmashburn/moxi/commit/b7cb576). The existing
`experiments/tags-authoring` subset now emits ordinary `Screen` fields, handlers,
and `UI` declarations hosted by `HandlerHost`. Its private event/editor/clipboard
adapter is deleted. Syntax and source examples remain unchanged. Source sites
become stable declaration keys; host-assigned control IDs change on remount.

The compiler retains the language-specific binding and conditional model
initialization rules. It still flattens imported components into root fields;
this does not validate reusable `Pane` composition, context routing, or Marko's
fine-grained runtime. Derived expressions are expanded at their uses, and
successful events refresh the full declaration set.

Measured maintenance change: the two generated examples shrink from 176 to 113
lines, the private runtime from 43 to zero, and the compiler from 292 to 268.
Production text inputs and checkboxes gain `show_label=False` to keep accessible
names without duplicating separately declared labels. Defaults are unchanged;
both child-routing overloads have focused coverage.

The existing behavior suite, four source variations, a new static-model case,
eight official Marko syntax compilations, twelve unsupported-input cases,
production authoring tests/examples, API/prose checks, and native build pass.
New checks reject stale editor IDs and captured actions after remount and root
reset. No physical native interaction, real IME, browser behavior equivalence,
human authoring study, or performance measurement was performed for the migration.
The historical accessibility-focus observation remains unresolved.

Moderate confidence: maintain the translator as an executable compatibility probe
and teaching comparison. Eliminating duplicate runtime behavior is practical
value; it does not establish a reason to adopt another primary authoring language.
Repeated translator-specific runtime requirements or difficult generated-code
debugging in larger examples would weaken this recommendation. See the
[implementation explanation](https://github.com/davidmashburn/moxi/blob/b7cb576/experiments/tags-authoring/README.md).

The independent production review has completed and identified two follow-ups:
reset cancellation can consume shared queue capacity, and underlying request task
records outlive pruned request metadata. Both were independently reproduced:
one unrelated completion dropped under 32-slot pressure, and 1,000 task records
after 1,000 reset cycles. The resolution is recorded below. The reviewer's
earlier authoring-test parse errors were from concurrent edits; the final
committed test and subsequent label tests passed locally.


## Production review resolution — November 1

Fixed separately in
[`f8b0e17`](https://github.com/davidmashburn/moxi/commit/f8b0e17).
`RequestScheduler.discard_scope` closes a non-global owner and releases its pending
work and already-queued results without generating cancellation notifications.
The authoring host uses it for removed controls and root reset. It can also
reclaim results left by external scope cancellation. Unrelated results retain
their order, payload, status, and queue capacity. Ordinary `cancel_scope` still
produces its existing cancellation results; standalone task history still uses
explicit `forget_task`.

Request-owned task records are now released when results are consumed or their
metadata is pruned after queue overflow. The independent reproductions now show
zero dropped unrelated completions at 32-slot capacity, and zero task/request
records after 1,000 schedule/reset/advance cycles. Regression checks also cover
consumed queue prefixes, superseded requests, queued and pending owner work,
external cancellation, stale completion rejection, and a surviving sibling scope.

The complete 84-file suite passes. Final focused authoring and request-retention
checks, the production macOS synthetic native reset probe, API inventory, prose,
local links, and whitespace checks pass. Existing native deprecation warnings
remain. The full local benchmark/release chain, physical input, OS IME, VoiceOver,
and browser runtime equivalence were not rerun. The fixes were independently
reproduced and verified by the parent; a second delegated review was not run.

Status: documentation, production extraction, translator migration, and both
review fixes are committed and pushed. Full GitHub CI is still pending; local
validation is not a claim that CI passed. Main remains unchanged. Confidence is
high in the corrected bounded-lifetime behavior and moderate in application-scale
authoring comfort. No new performance or human-usability conclusion follows.
