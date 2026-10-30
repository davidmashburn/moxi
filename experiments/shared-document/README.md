# Shared-document comparison

Intent: decide whether storing a shared document handle in each reusable editor
makes the current-state composition example substantially easier to author.

Source of truth: `../composition-gate/check.mojo` and its Document policy. Keep
independent drafts, current committed labels, validation, undo, conflict handling,
identity, focus, removal and refresh behavior identical. The handler runtime and
public Moxi source remain unchanged. No observation system or language is added.

Ownership: each Editor owns its draft and a reference-counted DocumentHandle.
The workspace also holds that handle. Owner operations mediate writes by API
convention; the underscored storage is not a proven language-enforced capability.
Copying a handle shares its document; snapshot() explicitly copies the value.
Root-key routing still selects the current editor for local draft mutations.

Verification: run both real-App implementations against matched synthetic-event
scenarios. Compile and exercise adding a local field, adding a third editor and
changing owner validation. Check retained handles, value snapshots, document
replacement and external-mutation refresh explicitly. Count all facade and
routing code. No native, performance, multi-window, async or usability claims.

Implementation baseline: feat/data-workbench at f458f1f. Run from the repository
root:

```sh
python3 experiments/shared-document/check.py
```

All six programs pass on Mojo 1.1.0 (8189361e): current/shared behavior,
current/shared extension trials, and current/shared ownership semantics.
`results.json` records commands, outputs, source hashes, materialized-input hashes,
source counts and the exact extension diffs. The runner retains the generated
programs and full logs in a reported temporary directory. Its common shared
scenario bodies come from the original composition gate, with only document
access and routing syntax adapted. Copy semantics are deliberately tested
separately instead of weakening the original value-isolation assertion.

## What changes in the source

The current-state Editor accepts the current Document in `apply(document)` and
`reload(document)`. This Editor retains a DocumentHandle and calls `apply()` and
`reload()`. The root route still looks up the current Editor by key. No callback
captures an editor pointer or document handle; controls still store thin functions
and keys. The UI runtime, refresh timing and identity rules are identical.

Local setters can bind directly as `Editor.set_draft` and `Editor.set_note` inside
the root bridges. This saves two adapters: six remain, compared with eight in the
original. There is still a route trait, callback type and one route per root.
The handle facade adds 37 physical lines / 24 nonblank, noncomment lines. It
forwards to the original Document policy so both versions use the same rules.
This forwarding is a cost of this implementation, not a lower bound for all
shared-document designs. A merged shared owner could avoid some forwarding;
a raw ArcPointer could avoid the facade while exposing all mutable storage.

Application/domain source totals are 153 versus 175 nonblank, noncomment lines
(current versus shared). Both additionally reuse the same 261-line handler
runtime by that measure, plus the unchanged public Moxi implementation. The
alternate root is counted separately in results; test helpers are excluded from
authoring counts. Shared ownership uses standard-library ArcPointer; there is no
handwritten retain/release, subscription teardown, registry or new refresh code.
These are source counts, not complexity scores or runtime-cost measurements.

The compiled extension adds a local Reviewer text field. It adds nine source
lines and two adapters to current-state, seven lines and one adapter to shared;
neither changes the root. Adding a third editor is the existing data-construction
path in both, exercised through App. An ASCII-digit validation rule adds the same
three lines to Document in both; rejected edits leave commits unchanged and valid
edits still undo. This tests a local field, not a second persisted document field
or schema migration. Exact changes are retained in results.json.

## Semantics that matter

- Both pass independent drafts, normalized commit, shared label refresh, policy,
  no-op, conflict/undo, third instance, second root, reorder/focus/cursor,
  removal/remount and stale-target rejection checks.
- Copying the current-state root isolates the document and local state. Copying
  the shared root isolates local state but aliases the committed document.
  `snapshot()` explicitly copies document value/history.
- A retained Editor keeps its document usable after its Workspace goes away.
  Removing an Editor does not revoke a separately retained Editor/handle.
  Normal control removal rejects old events in both. No deallocation/leak test
  or thread-safety claim is made.
- External writes require explicit host refresh in **both** versions; resize
  only rebuilds the cached view. Shared handles add access paths, not automatic
  notification. Shared data alone does not update a second host/window.
- Replacing the workspace document has different hazards. Current routing
  follows the replacement, and an old draft with a coincident revision can apply
  to it. Shared editors keep the old handle and can edit the old document while
  the workspace points at the replacement. These negative controls demonstrate
  missing replacement policies, not successful product behavior. Neither is
  suitable for document switching without explicit identity/draft handling.
- The owner-method facade does not prevent mutation from `render(self)`: a
  negative control successfully calls Undo on successive renders. It is a
  conventional API boundary, not compiler-enforced purity or capability safety.

## Decision and limits

Keep current-state ownership as the working default for this single-owner UI.
The shared variant offers a small local-method benefit, not a substantial whole
application simplification. Use a shared domain handle when a domain lifetime or
sharing requirement calls for it; do not change ownership merely to address thin
callback boilerplate. Neither callback surface is adopted as a public Moxi API.

Confidence is moderate for that default and high for the checked behaviors.
A complete shared design that substantially reduces component/root wiring under
the same checks, a real independent-host requirement, or measured value-copy
costs could change the decision. No superiority at scale or universal comfort is
established. The next authoring problem is method binding, not another ownership
inventory. No binding redesign is implemented by this comparison.

Skipped: full repository suite, native interaction, accessibility, allocation or
performance profiling, async/reentrancy/concurrency, independent windows/hosts,
observation, nested layout and testing with unfamiliar developers. The earlier
compiler-crash diagnostic is preserved but not rerun. Durable analysis is in
`docs/design/shared-document-comparison.md` on the project-planning branch.
