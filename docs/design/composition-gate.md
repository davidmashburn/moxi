# Current-state composition gate

Later follow-up: [direct method bindings](direct-method-binding.md) remove the
per-action adapters and pass the matched behavior/extension checks. That is the
current authoring candidate; its runtime allocation and safety costs remain
explicit adoption gates.

October 29, 2026. Follow-up to the [ownership recommendation](ownership-decision.md).
Implementation experiment: `experiments/composition-gate/` in the Moxi development
checkout. **Behavior passes; the comfort/adoption gate remains open.**

Later October 29 follow-up: the [matched shared-document comparison](shared-document-comparison.md)
is now implemented and checked, including compiled field/validation extensions.
It keeps current-state ownership as the working default while leaving the
callback-authoring gate open. The original run and reasoning below are retained.

## What ran

Two reusable editors each own a draft, a base revision, a private note and an
error. Both display and edit one committed document. Apply asks the current
document to accept the draft; Reload discards the draft and reads the document.
The document owns normalization, validation, history and undo. A revision mismatch
rejects Apply instead of silently overwriting another editor's changes. Undo
advances the revision, so returning to an old value does not revive an old draft.
These are explicit product choices for the experiment, not mandatory Moxi rules.

This runs through the existing `App`, `HandlerHost`, event dispatch, layout,
retained text-input state and paint commands. There is no new UI runtime, shared
cell, observation graph, parser or application-written settlement loop.

Run `python3 experiments/composition-gate/check.py`. All four groups pass:

- **Drafts and history:** independent drafts/notes, whitespace normalization,
  both current-document labels refreshed, one accepted Apply producing one commit
  and one host render, unchanged Apply producing no history, render/resize/paint
  not replaying the commit, conflict preservation, Reload, and successive undo.
- **Owner policy:** incomplete drafts remain editable; blank and overlength
  commits are rejected; a changed length limit affects both editor instances;
  read-only mode rejects Apply and undo; rejected edits leave history unchanged.
- **Identity and reuse:** a third instance uses the same component and owner
  route; reordered editors retain identity, focus and cursor; subsequent typing
  reaches the correct editor; removal/remount assigns fresh control IDs and rejects
  old text/button targets. The same component works under a second root type and
  an additional named UI scope.
- **Value isolation:** copying the nested application preserves an independent
  document/history and independent editor state when the original changes.

Normal editing and actions use App events. Explicitly stale targeted events are
injected at the HandlerHost component boundary, as in the existing handler tests.
The nested UI scope is an identity namespace within a flat column. This does not
test nested layout, arbitrary component trees, independently mounted child hosts,
or two windows editing a long-lived document.

## What the source actually costs

The Editor's meaningful methods are ordinary Mojo:

```mojo
def set_draft(mut self, text: String):
    self.draft = text
    self.error = ""

def apply(mut self, mut document: Document):
    self.error = document.rename(self.draft, self.base_revision)
    if self.error == "":
        self.reload(document)
```

But dispatch to those methods is not free. The reusable component contains this
pair for Apply, and equivalent pairs for draft editing, note editing and Reload:

```mojo
def apply_draft(mut editor: Editor, mut document: Document, text: String):
    editor.apply(document)

def apply_clicked[R: EditorRoute](mut root: R, key: Int):
    root.route_editor(key, apply_draft, "")
```

The root supplies one current pair by key:

```mojo
def route_editor(mut self, key: Int, action: EditorAction, text: String):
    for index in range(len(self.shell.workspace.editors)):
        if self.shell.workspace.editors[index].key == key and self.shell.workspace.editors[index].mounted:
            action(self.shell.workspace.editors[index], self.shell.workspace.document, text)
            return
```

The compiler accepts the temporary disjoint borrows. No borrowed state is stored
in a handler. Shell and Workspace have no action-forwarding methods. A third
editor needs only data construction; adding the note field needs no owner-route
change. Validation and undo remain in Document.

The price is **eight component-specific adapter functions for four actions**, a
route trait, a callback type and one lookup route per root. Adding another action
adds another pair of adapters in this implementation. Some bridges ignore their
document or text arguments. This is precisely the sort of ceremony the earlier
adoption gate warned against; moving it into the reusable component does not
erase it. The root also knows where that component's state lives. Moving the
state requires updating that route, even though intermediate containers stay
uninvolved. A second root's route is written explicitly in the test.

Stable editor keys, list copy initializers and HandlerHost are also visible.
The route requires keys to be unique within its workspace; this experiment does
not provide generic composition of independently keyed child-owner domains.
The callback has unrestricted mutable access to Document, so owner-policy
discipline is a convention here, not a capability or compiler-enforced boundary.

## Assessment and decision

**High confidence:** the tested editing/lifetime behaviors work with current
state and ordinary methods. The earlier fear of handlers multiplying across
every ancestor is avoidable for this bounded shape. More instances do not add
handlers; owner policy does not spread into children.

**Moderate confidence:** current-state ownership remains a workable internal
foundation. It does not need a reactive graph to support this workflow. This is
not evidence that its copying, lookup or full-root refresh costs are acceptable
at scale; none were measured.

**Low confidence:** the current source meets the desired comfort level. I would
not adopt this adapter surface as Moxi's public component API. The behavior test
passes, but the complete acceptance gate does not. In particular, the test has
not earned a claim that A is simpler than restricted shared-document handles.

Keep the ownership recommendation provisional and retain this executable case
as a regression target. Do not grow a framework around EditorRoute on the strength
of a passing test. If pursuing A, the next implementation must remove these
component-specific bridges in ordinary Mojo while keeping the same assertions;
renaming or moving them is insufficient. If that needs comparable machinery to
a shared-document capability, compare those concrete surfaces before selecting
the public API. A shared handle still needs mediated writes, lifetime rules and a
refresh contract; this test neither implements nor disproves that alternative.

Evidence that would change this assessment: a compiled method-binding/projection
surface that removes the eight bridges without exposing new routing rules to
component authors; or a restricted shared-document implementation that passes
this same editing/lifetime contract with substantially less author code. Comfort
also needs a reader unfamiliar with the implementation to successfully change
the component. User approval alone is not evidence of that.

The recommended next comparison is one implementation of this same editor with
local drafts and a shared document handle exposing owner operations, using the
existing refresh mechanism and the same assertions. Count all wiring and lifetime
code. Compare the complete source needed to add a field, share a document, change
validation and remove an editor. If handles substantially simplify that source
without moving the cost into cleanup or hidden mutation, prefer them at the
application boundary; otherwise retain A and address its binding machinery.
That comparison was proposed at the time of this record. It has since
[run without an observation engine](shared-document-comparison.md); both pass,
but handles do not substantially simplify the complete authoring surface.

## Compiler finding and provenance

Publication follow-up: the experiment and dependencies are preserved in
[`f458f1f`](https://github.com/davidmashburn/moxi/commit/f458f1fc4085b533883434e447fbcb5fbfbc9cb6).
All 139 sources in the passing composition manifest match the published tree.
The composition gate was not rerun for publication because its tested sources
were unchanged. The separate ownership runner was rerun after excluding ignored
scratch probes from its manifest; all six groups passed. Statements below about
uncommitted work and checks not rerun describe the initial composition run.

The first full compile crashed in Mojo 1.1.0 (8189361e), before any assertions ran.
Isolation narrowed the trigger to direct assignment of the deeply nested
`app.component.root.shell.workspace.document.max_length` field after the preceding
UI operations. An isolated assignment immediately after App construction compiles,
so this is not evidence that nested assignment is generally unsupported. The
reduced failing source is retained in the experiment at
`diagnostics/policy_assignment.mojo`, outside the passing gate command. Changing the
test to call Document's `set_max_length` and `set_writable` methods allows the
combined suite to compile and all four groups to pass. These two extra owner
methods are included in the source cost, not omitted as test infrastructure.
This is a workaround, not a diagnosed or fixed compiler defect.

Implementation baseline: `feat/data-workbench` at
`c8c7cbb7741519c9796a02ffa25c02e701b2f58a`; planning baseline:
`project-planning` at `1a1d180fa07b841aadbdf3aff197168e53224ef4`.
Both checkouts already contain uncommitted work. This task adds the composition
experiment and planning follow-up only; it does not commit, push, or change the
public runtime. `results.json` captures the final command, compiler, output and
SHA-256 source manifest, including the existing runtime dependency and lockfile.

Not run: the full repository suite, native-window interaction, performance or
allocation measurements, asynchronous completion/cancellation, independent-window
sharing, observation, or a usability study. Prior handler/ownership test results
remain earlier evidence and were not rerun here. This is not a three-way UI
implementation comparison or a proof of universal ease.
