# Child routing authoring experiment

Observed October 27, 2026, against implementation branch `feat/data-workbench`
at `c8c7cbb7741519c9796a02ffa25c02e701b2f58a`. The experiment is uncommitted in
`experiments/child-routing/`, depends on the uncommitted
`experiments/handler-api/runtime.mojo`, and changes no production source.
Source hashes and run output live in its `results.txt`. Prior source and
unrelated documentation edits were preserved.

This follows the [handler experiment](handler-api-experiment.md). The user
authorized testing existing `ComponentSlot` routing to remove root-state handler
forwarding: first two independent forms, then one intentionally shared value.
The question was whether comfort really requires repeated rendering or hidden
side-effect rules. No new language, parser, state-projection framework, or
production API was introduced.

## Acceptance and outcome

| Question | Observed result |
| --- | --- |
| Can a child own both state and handlers? | Yes. Two full greeting forms reuse one child type with zero per-field parent forwarding methods, versus ten in the prior root-host example. |
| Does independent input re-render both children? | No. Only the changed child runs its render; parent view composition/reconciliation still occurs. |
| Do same local keys collide across children? | Not in the tested fixed slot namespaces. Conditional nickname controls coexist. |
| Does reordering existing children preserve editing state? | Yes: native IDs, App focus and cursor remain attached to the persistent slot. |
| Can both children edit one parent-owned value? | Yes for the tested pair of name editors, through explicit change requests and input snapshots. Full forms sharing arbitrary fields were not tested. |
| Is eager child rendering safe for controlled inputs? | No. The first composition refreshes with an old input, clamps the cursor, and renders the origin twice. |
| Can settlement precede rendering? | Yes in the bounded corrected variant: one shared commit, one render per affected child, correct cursor and next keystroke. |
| Is the resulting author API comfortable? | Not established. Parent wiring and the shared settlement contract remain too visible. |

## What changed in the authoring model

The complete local form in `form.mojo` uses ordinary fields, methods, and a
read-only render. Its controls refer to local handlers such as `Self.set_name`
and `Self.save`. Adding a field inside the form no longer requires another
forwarding method at the parent. `IndependentForms` owns two existing
`ComponentSlot[HandlerHost[GreetingForm]]` values and routes targeted events.

This is a meaningful reduction in composition cost, but the actual parent still
declares slot IDs and numeric offsets, embeds views, handles dispatch, and
delegates copy/cut/paste. The deep `slot.component.root` access is also mechanical.
No extra helper was introduced to disguise that cost. Conditional scopes remain
explicit within a child. Fixed offsets are suitable only for this bounded test;
unbounded local ID allocation could eventually overlap another child's range.

## Shared state exposed an ordering defect

`NameEditor` receives a `value` input and emits `requested` plus `has_request`.
The parent owns `name` and consumes one child's request before updating both
input snapshots. The flag distinguishes no request from a request for empty text.
The contract assumes synchronous, sequential event delivery.

Using the previous host unchanged (`shared.mojo`) initially renders the child
before its parent consumes the request. Replacing `Ada` with `Grace` restores
`Ada` temporarily, clamping the editor cursor to 3. The subsequent parent-driven
refresh displays `Grace` but leaves the cursor at 3 instead of 5. The origin
renders twice and its sibling once. This failure is retained in the comparison
checks and explicitly labeled as a known failure, not a passing usability gate.

The correction (`settled.mojo`) uses a bounded host variant (`deferred.mojo`)
whose update dispatches without rendering. The parent consumes the change,
updates inputs, then refreshes each affected child once before returning to App.
The cursor remains at 5 and the next `!` produces `Grace!`. Cursor-only movement
refreshes only the active editor. Clipboard cut/paste must also pass through
settlement. Rebuild, resize and paint replay neither requests nor side effects.

The correction adds a real contract: a deferred child is stale until its parent
settles and refreshes it. Two host modes and handwritten settlement should not
become normal application-author responsibilities. The result justifies
investigating one framework-owned dispatch/settlement/render boundary; it does
not establish a general scheduler, arbitrary nesting, cycles, or async behavior.
The original eager host remains unchanged so the earlier experiment stays
reproducible. Neither variant retains a mutable borrow of application state.

## Verification performed

`bash experiments/child-routing/check.sh` exited 0. Its first program verifies
independent forms and records the eager shared-state failure; its second verifies
the corrected shared-state implementation. Checks use real App hit testing,
ComponentSlot event/view projection, keyboard routing, focus, editor state and
App clipboard commands. Coverage includes Unicode, synthetic composition,
independent cursors, empty values, child reorder, copied state isolation,
unknown/untargeted events, consumed requests, and render counts.

`bash experiments/child-routing/native.sh --build-only` exited 0, with existing
native-window deprecation warnings. The corrected shared demo was opened and
checked through native input: replace the first editor with `Grace`, then type
`!`; both fields and greetings show `Grace!`. Tab to the second editor, replace
with `Moxi`, then type `!`; both show `Moxi!`. A screenshot confirmed focus on
the second editor. The demo was left open. These are bounded native observations,
not a full native interaction or accessibility pass.

Early compilation crashed on a check containing a deeply nested editor cursor
read. Explicit generic arguments did not fix it. A small host-level cursor
helper avoided the crash and the complete checks then compiled and ran. The
compiler failure was not diagnosed upstream. The toolchain is the existing
locked Mojo 1.1.0 environment; no dependency changes were made.

Shell syntax, whitespace, source hashes and local planning links were checked.
No performance benchmark, full repository suite, non-macOS/browser checks,
VoiceOver, actual IME, OS clipboard, mouse caret/selection, dynamic child
insertion/removal/remount, async requests, general nested settlement, or
independent author-comprehension study was run. Cached render behavior across
bounds changes, linear lookups and retained identity history are inherited
limits. Application render counts do not measure total runtime work: the parent
still rebuilds, embeds copied nodes and reconciles, and slots project flat views.

## Decision supported

Keep the architectural separation: dispatch changes, settle ownership, then
render affected views. Let ordinary components own their local state and
handlers; involve parents when state is actually shared. This experiment shows
that root-level forwarding for every child field and an extra origin render are
not unavoidable in the tested cases. It does not justify adopting the current
experimental surface or claiming Marko-like comfort.

High confidence in the narrow behavior results; moderate confidence in the
composition direction; low confidence that this parent API meets the comfort
goal. The next design bar is concrete: adding a local field, reusing a child and
intentionally sharing a value should not require an application author to edit
routing code or learn refresh ordering. Successful independent edits at that bar
would strengthen the recommendation. A broader composition example requiring
repeated passes or losing editor state would weaken it. Broad framework research
is not needed to recognize the current boundary; any further experiment should
test that authoring bar rather than another spelling of individual controls.

The subsequent [composition authoring draft](composition-authoring-draft.md)
writes both complete forms before implementing another runtime. It assesses
the three source edits and makes the proposed mounted-state ownership change
explicit. Its examples are uncompiled; they do not extend these test results.
