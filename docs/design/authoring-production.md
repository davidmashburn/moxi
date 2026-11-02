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
has now passed all jobs, including macOS core/native validation and the package
consumer. Later translator and lifecycle-fix commits have separate CI runs.

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
review fixes are committed and pushed. The extraction baseline CI passed;
[CI for the final lifecycle fix](https://github.com/davidmashburn/moxi/actions/runs/41287313179)
passed all six jobs at `f8b0e17`, verified November 1, 2026.
Main remains unchanged. Confidence is
high in the corrected bounded-lifetime behavior and moderate in application-scale
authoring comfort. No new performance or human-usability conclusion follows.


## Next application-author check

Exercise the production API with a shared document, keyed groups, and keyed
local drafts inside each group. The small published examples separate shared
context from dynamic collections; this check combines them through several
ownership levels. Reuse the documented API without runtime changes, generated
application code, a global store, or a new composition helper.

Acceptance: edit locally and Apply explicitly; queued input and captured Apply
follow the original draft through both group and draft reorder; removing or
resetting a group/draft rejects its old work while a surviving sibling stays
usable; reopening allocates a fresh lifetime; root reset rejects old work.
Sibling groups intentionally reuse their local draft keys. Run the example and
checks, retain the actual source, and record authoring friction and code size.

A bounded `gpt-5.6-luna` author task starts from the production guide and examples.
This provides agent-author evidence, not human-usability evidence. It does not
establish large-tree performance, native input quality, or a general application
architecture. Existing data-workbench migration and extending the Marko language
subset are outside this check. Confidence in broader comfort remains moderate;
new runtime ceremony or substantial source-reading would lower that assessment.


## Nested workspace result

Implemented in `07d377a` on `feat/data-workbench`. The
[workspace](https://github.com/davidmashburn/moxi/blob/07d377a/examples/authoring/workspace.mojo)
uses one shared document, keyed groups, and keyed drafts. It reuses the existing
`Document` and `Draft` types. There is one handwritten root route; the collection
and `field` routes handle the remaining levels. No production runtime or public
API changes were needed.

The smaller-model author produced an 81-line model and 167-line check. It needed
to inspect the production composition/routing source and the reused draft's
control order. An omitted `Pane` import and initially incorrect test control
positions required corrections before its focused checks passed. This was an
agent author working from the published material, not an unassisted human trial.

Parent review found that Reverse swapped only the first two entries, which was
misleading after Add, and that whole-group removal was not covered. The final
88-line model reverses all entries and adds Close first group. The 206-line check
also verifies three-entry reorder, whole-group retirement and reopening with
reused child-local keys, previously captured surviving sibling actions, and an
old Apply reading current text after an edit. Counts include blank lines and
comments and exclude the reused `Document`/`Draft` definitions; they are not a
framework code-size comparison. Internal control-path selectors make up test
scaffolding, not application code.

Parent verification passed all four examples and both behavior checks with
`python3 examples/authoring/run.py`. The updated `pixi run --locked headless-check`
also passed, including production authoring tests and package precompilation.
Shell syntax, documentation links, prose-artifact, whitespace, and staged/outgoing
content checks passed. Existing native string-conversion deprecation warnings
remain. Both example checks now run in the standard suite and Linux headless CI
lane. [CI for `07d377a`](https://github.com/davidmashburn/moxi/actions/runs/41340698355)
was queued when checked on November 1, 2026; a passing run is not yet verified.

The complete local suite, native layout/input, physical IME, accessibility,
large-tree timing, and human usability were not rerun. The previous six-job CI
pass belongs to `f8b0e17`, not this change. No merge to main was performed.

Assessment: high confidence that the tested nested ownership and action routing
compose under the production contract; moderate confidence in authoring comfort.
The application needs little bespoke routing, but typed context propagation,
field projections, keys, and test selectors remain explicit. This does not
justify a new abstraction or a fine-grained performance claim. A human change
exercise on this runnable source would be stronger comfort evidence than another
agent-only ownership probe; a representative native screen and end-to-end timing
would be required before generalizing to application-scale performance. The next
product step should choose such a screen and its required controls, rather than
expand the Marko subset or redesign the state model speculatively.

## Native workspace smoke and scroll regression

Implemented in `9f97bcf` on `feat/data-workbench`. A 14-line
`examples/authoring/workspace_window.mojo` connects the unchanged workspace model
and production `HandlerHost` to `MacOSWindow`, `MacOSRenderer`, and `App.run`.
`pixi run --locked authoring-workspace-build` builds it; run
`./dist/moxi-authoring-workspace`. The normal macOS check lane now builds this
entry point. No production runtime or authoring API changes were required.

On November 1, 2026, a real AppKit window was exercised through UI automation.
Pointer focus, select-all, and typing updated Alpha's first local draft while
Saved stayed unchanged. Apply updated the shared title. Reversing drafts and
groups preserved that edited draft and its control identity. Scrolling reached
the moved draft; resetting its collection replaced the two drafts with a fresh
reset draft and kept the shared title. Screenshots showed the scrolled controls
and reduced content after reset. An ignored local app bundle wrapped the built
binary for automation; it is not a new packaging API or committed artifact.

The portable workspace check now also dispatches scroll and pointer events to
an initially offscreen Beta editor. Untargeted text input reaches that editor,
leaves the other group and shared document alone, and preserves scroll across
rebuild. A pointer click on Apply saves the edited value. Removing a group then
reduces and clamps the scroll offset. These are headless App routing assertions,
not substitutes for the native smoke observation.

Validation passed: native workspace build, focused workspace regression, complete
portable headless lane (including production authoring checks and package
precompilation), shell syntax, prose-artifact and whitespace checks. Staged files,
content, commit message, and outgoing implementation diff were reviewed for
secrets and unrelated private material. The two pre-existing unrelated document
edits were left untouched. Existing native string-conversion deprecation
warnings remain. The complete local suite, physical IME, window resizing,
end-to-end timing, and an unassisted human authoring trial were not run.

Two limits became concrete. The default vertical form works but repeats controls
and labels across a long scroll; it is not a finished workspace layout. An
accessibility-driven click on the text field did not focus it, while a coordinate
pointer click did; accessibility button activation worked. The cause of the text
focus difference has not been isolated, so this is neither a backend diagnosis
nor an accessibility conformance claim. The example instructions record both.

Confidence is high in the exercised pointer/scroll/ownership behavior and remains
moderate in general authoring comfort. The native wrapper adds no state/routing
ceremony, but it supplies no new performance evidence. A human change exercise
or a representative compact screen could change the comfort assessment. The next
bounded engineering investigation is to isolate accessibility text-field focus
against the native bridge and its existing tests before choosing a fix. A layout
composition change needs an explicit representative screen and acceptance
criteria; this smoke check alone does not justify another authoring abstraction.

At the last check, CI for `07d377a` had passed four jobs while `validate` was still
running. That is partial evidence, not a completed CI pass. [CI for `9f97bcf`](https://github.com/davidmashburn/moxi/actions/runs/41341882191)
was in progress after push. Its completed result remains unverified. No main
merge or pull request was performed.

## Try-science continuation — November 2, 2026

Contract: use at most three cycles to decide whether current friction requires a
backend correction, clearer examples, or an authoring API change. Implementation,
focused regression tests, documentation, commits and pushes remain authorized;
no main merge, new language, or broad layout redesign is implied. Baseline is
`9f97bcf`; its six CI jobs have now all passed (run `41341882191`). Existing
unrelated document edits remain outside scope. No prior worker is outstanding.

Cycle 1 question: is the text-field accessibility focus failure in the native
bridge, the automation action's semantics, or authoring dispatch? Compare direct
AX focus/set-value/press behavior with pointer focus, then trace queue ingress and
App routing. A direct native focus request failing independently of the authoring
host supports a backend fix; failure confined to an unsupported automation press
would instead narrow the smoke claim. Preserve retired-target rejection, disabled
control behavior, publication without queued feedback, and ordinary text editing.
Enough evidence for a fix requires a reproducer on the old path and passing
focused regressions after the smallest change. UI automation alone will not prove
accessibility conformance or human comfort. A bounded independent reader examines
the frozen baseline while the parent prepares the discriminating probe. Raw logs
stay in temporary files. Budget: cycle 1 active, two further cycles available;
choose later questions from its result rather than fill a fixed test quota.

Cycle 1 parent probe (`/tmp/moxi_ax_focus_diag.m`, log
`/tmp/moxi-ax-focus-diag.log`) found: AXPress returns false and queues nothing for
a text field; AXValue queues addressed text input; legacy focus-settable/query
and setter paths throw in unsupported superclass methods; modern focus setter
changes the Cocoa property while the published focus remains false and the queue
stays empty. This reproduces a bridge gap without HandlerHost. It does not prove
which AX operation the automation tool used. Apple documents AXPress for elements
that behave like buttons, and accessibilityFocused as keyboard focus:
https://developer.apple.com/documentation/appkit/nsaccessibilityprotocol/accessibilityperformpress()
https://developer.apple.com/documentation/appkit/nsaccessibilityprotocol/setaccessibilityfocused(_:)

Cycle 2 criteria (fixed before implementation): route explicit native text-field
focus requests through App without activating controls or changing text; focus
then typing in a single queued batch must reach the requested field. Reject
retired and disabled targets at ingress and again at dispatch; publishing focus
must not enqueue feedback. Check composition cleanup and blur target identity.
Retain AXPress semantics and existing authoring signatures. Independent baseline
review remains active; production source stays frozen until that reader finishes.

Cycle 3 is an independent authoring trial against the committed baseline in an
isolated worktree: add a dirty indicator derived from current shared title and
Revert to that current title. Applying a sibling changes comparison status without
replacing local text; reorder must retain the owner. Worker may read only public
authoring docs and examples, plus compiler diagnostics, and must log corrections
and help. No runtime or documentation edits, commits, or pushes are delegated.
Acceptance requires parent verification through real routed actions, not just
calling model methods. This supplies agent evidence only. This dispatch uses the
third and final cycle; no additional cycle is authorized by this budget.

### Three-cycle outcome

The independent baseline reader completed before production edits. Its source
review agreed with the direct probe: AXPress rejection on a field is expected;
missing focus input is a native bridge defect. The reader ran no native tests.
The parent independently reproduced the distinction and integrated the fix.
Both delegated tasks are terminal with no pending child runs or questions.

Cycle 2 adopted an addressed `FocusEvent` through the existing native queue and
App. Native text-field focus/blur uses current snapshot identity and enabled
state; App validates focusability again at delivery. Publication reads model
focus without calling the input setter. This avoids both feedback and conflating
focus with activation. A new regression initially failed because composition
cleanup rebuilt the view and restored first-control focus after explicit blur.
The retained runtime now remembers explicit blur across rebuilds until a later
focus operation; initial focus and removed-control fallback remain unchanged.
The updated regression passes. This is a bounded backend/runtime correction,
not an authoring API redesign.

Integration review also found that a new Event payload must survive normalized
recordings. The writer now emits replay version 2 with a focus flag; the reader
accepts version 1 with that flag false. Older readers cannot consume new version
2 recordings. Tests cover both focus values, all normalized fields, legacy input,
invalid flags, and unknown versions. This format change is called out in the
implementation commit's breaking-change footer and application guide.

Cycle 3 used an uncoached `gpt-5.6-luna` author at max effort in an isolated
checkout of `9f97bcf`. Its allowed reading was public authoring docs and examples;
no runtime, experiments, planning, web, or history. The author added an `is_dirty`
comparison, a `revert` method and control, and a status label: 11 net application
lines, no stored dirty flag, no additional route, and no runtime change. It
reported no compiler errors, corrections, or requests for help. Its executable
checks route captured actions through shared documents and nested reorder;
Revert reads the current saved title even when captured before a sibling Apply.
Existing introductory and workspace checks also passed in its checkout.

The parent inspected the actual implementation and test artifact, imported them,
and added assertions for rendered status after local editing, sibling Apply and
Revert. Those passed, addressing the author's explicit limit that it had checked
state predicates but not rendered text. The new check runs in both standard and
headless lanes and the example runner. Application examples and guide now explain
current-value comparison versus opening-revision conflict detection. Structural
path/ordinal selectors remain substantial test scaffolding (157 lines in the
integrated check), so the small application edit must not be described as equally
small testing effort. Public behavioral-test ergonomics remain unevaluated.

Implementation: [focus correction `2937717`](https://github.com/davidmashburn/moxi/commit/2937717)
and [example/guide `f98ae21`](https://github.com/davidmashburn/moxi/commit/f98ae21)
on `feat/data-workbench`. No merge to main or PR was performed.

Verified locally: native authoring regressions with a real AppKit window opened
and closed; form focus/composition; identity diff; accessibility contract;
interaction foundation; frame publication; event replay including the final
strict-flag checks; portable headless lane including rendered dirty/Revert
checks and package precompilation; native workspace build; API inventory (997
exports, 103 trait methods); whitespace checks. Existing deprecated native string
conversion warnings remain. The complete `scripts/check.sh` suite, physical IME,
screen-reader conformance, Linux native behavior, resized-window visual fit,
post-change manual workspace interaction, and performance timings were not run
locally. The native test injects actual Objective-C callbacks but does not prove
what CUA's original accessibility click invoked. Baseline CI passed all six
jobs; latest implementation CI must be assessed separately after push.

Assessment: **high confidence in the tested focus and ownership mechanics**;
**moderate confidence in keeping ordinary fields/methods as the authoring
surface**. A fresh constrained agent completed a useful extension without
coaching, but this is neither a human trial nor evidence of universal ease.
**Performance confidence is unchanged**: no new benchmark was run, and shared
commands still refresh declarations. Selective paint behavior must not be sold
as fine-grained application dependency tracking. Human confusion about context,
identity, or handlers; repeated routing ceremony in a larger real application;
or measured declaration-refresh costs could change the recommendation.

Budget disposition: three of three cycles used, none remaining; stop this round.
No worker remains active. The next discriminating comfort evaluation is an
unassisted human application task using the guide, with misunderstandings and
interventions recorded. A separate larger-application performance trial could
measure declaration refresh, but neither is silently appended as a fourth cycle.
Raw probe and worker notes are temporary local evidence; durable findings,
reproduction tests, limitations, and source links are captured here and beside
implementation. No token-savings or human-time claim is made.

Delivery: both implementation commits are pushed. Latest
[CI for `f98ae21`](https://github.com/davidmashburn/moxi/actions/runs/41409481088)
was in progress at the post-push check; a completed pass is not yet claimed.
Staged and outgoing content review covered all new implementation/example files,
commit messages and intermediate versions, plus this planning update. Unrelated
local documentation edits were preserved outside the commits.

### November 2: human group-action trial prepared

The user's subsequent "go" authorized preparing the recommended human trial.
This is one bounded preparation pass, not a fourth automated research cycle or a
claim that a human trial has happened. All six jobs in the previously pending
[CI run for `f98ae21`](https://github.com/davidmashburn/moxi/actions/runs/41409481088)
have now passed: validation, portable headless, native Linux layout, candidate
macOS layout, retained Linux layout, and package consumer.

Implementation-branch commit
[`4b1be26`](https://github.com/davidmashburn/moxi/commit/4b1be26) adds the
[participant brief](https://github.com/davidmashburn/moxi/blob/4b1be26/examples/authoring/human-trial.md)
beside the existing example. The task is to add Revert group: update every local
draft in one group from the current shared saved title, preserve identities and
order, and leave other groups and the saved document unchanged. No solution is
included. Public documentation and examples are allowed; runtime-source lookups,
help, errors, and misunderstandings should be recorded. Any implementation help
changes the remaining attempt from unassisted to assisted.

The brief contains a sequential manual acceptance checklist covering shared
values, nested reorder, sibling isolation, added drafts, and empty groups. After
the human attempt, the maintainer must independently check captured actions
against current values and identities, including rejection after group removal.
Those checks are specified, not executed against an implementation that does not
yet exist. Existing selector maintenance is recorded separately from application
authoring friction.

Preparation verification: the existing `workspace_check.mojo` and
`draft_revert_check.mojo` pass, and `authoring-workspace-build` succeeds on macOS.
The build still emits existing deprecated native string-conversion warnings.
The new visible checklist was reviewed against the starter's controls and state;
it has not been run on a completed group action. No new interactive native pass,
performance measurement, full local suite, or human attempt was performed.

Decision criteria: a successful feature plus an accurate explanation of current
owner/context dispatch supports this narrow pattern's learnability. Needing
runtime internals, repeated confusion about ownership or signatures, or unrelated
routing machinery would justify revising the public examples or API. Compile
success and line count alone do not raise comfort confidence. One familiar human
cannot establish universal ease or application-scale behavior. Confidence remains
high for the previously tested mechanics and moderate for the authoring strategy.
The next evidence is the participant's diff and observations, followed by targeted
independent regression checks; no further automated comfort trial is active.
