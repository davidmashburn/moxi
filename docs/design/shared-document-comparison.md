# Shared-document comparison and working decision

Later follow-up: [direct method bindings](direct-method-binding.md) remove the
per-action adapters and pass the matched behavior/extension checks. That is the
current authoring candidate; its runtime allocation and safety costs remain
explicit adoption gates.

October 29, 2026. Follow-up to the [composition gate](composition-gate.md).
**Keep current-state ownership as the working default. Shared handles did not
produce a substantial authoring improvement in the matched implementation.**
This selects an ownership direction, not the current callback API for adoption.

## Contract and implementation

The goal was to replace the current document borrow with a retained shared
document handle while preserving independent drafts, owner validation, normalized
commit, undo, revision conflicts, identity, removal and refresh behavior. Keep
ordinary Mojo, the same real App/HandlerHost and the same Document policy. Count
all facade, routing and lifetime machinery. No public Moxi API, new language,
observation engine or generic component runtime was in scope.

Implementation: `experiments/shared-document/` on `feat/data-workbench`, based on
`f458f1fc4085b533883434e447fbcb5fbfbc9cb6`. The earlier current-state experiment
and its runtime are unchanged. The new Editor owns a DocumentHandle as well as
local drafts. Workspace holds another handle to the same reference-counted
Document. A small facade exposes owner methods, getters and an explicit value
snapshot. Underscored storage is a convention, not a proven access restriction.

The most visible difference is small:

```mojo
# Current state: the route supplies the current document for this action.
def apply(mut self, mut document: Document):
    self.error = document.rename(self.draft, self.base_revision)
    if self.error == "":
        self.reload(document)

# Shared handle: the editor retains its document identity.
def apply(mut self):
    self.error = self.document.rename(self.draft, self.base_revision)
    if self.error == "":
        self.reload()
```

Both still route callbacks by key to the current local Editor. The stored
callbacks are thin functions, not captures of mutable editor state. Sharing the
document does not solve the runtime's Root-typed callback binding problem.

## Matched behavior and actual changes

Run `python3 experiments/shared-document/check.py` from the development checkout.
All six programs pass on locked Mojo 1.1.0 (8189361e). The runner derives shared
common scenarios from the original test body, changing only document access and
route syntax. It runs each base variant and each extended variant through App
events, plus ownership-specific checks. Source hashes and exact extension diffs
are in `results.json`; generated source and full logs are retained in a reported
temporary directory. No manual edit to a generated test is required.

| Check or change | Current-state document | Shared document handle |
| --- | --- | --- |
| Independent drafts, notes and normalized Apply | Pass | Pass |
| Both current labels refreshed, once-only effects, no-op | Pass | Pass |
| Validation, read-only policy, stale draft, undo | Pass | Pass |
| Reorder, focus/cursor, removal/remount, stale events | Pass | Pass |
| Third editor and reuse under another root/scope | Pass | Pass |
| Four existing actions | Eight component adapters | Six component adapters |
| Add local Reviewer text field | Nine lines, two adapters, no root changes | Seven lines, one adapter, no root changes |
| Add another editor sharing the document | Existing Editor construction path; no new handlers | Same |
| Reject ASCII digits in names | Three lines in Document; no child/root changes | Identical shared policy source |
| Copy the application | Document/history and local state are independent | Local state independent; document still shared |
| Value snapshot | Ordinary Document copy | Explicit `snapshot()` |
| External write updates visible UI | Explicit host refresh | Explicit host refresh |

Line deltas exclude blanks/comments. The extension is compiled and exercised:
Reviewer stays independent across three editors; invalid names leave commits
unchanged; a valid name commits and undoes without losing local fields. The
field is local, not a new persisted field or schema migration. The third-editor
path already exists in both baseline applications; the experiment exercises it,
rather than counting it as a newly implemented framework feature.

The shared version saves two adapters because its callback type directly accepts
`Editor.set_draft` and `Editor.set_note`. Apply and Reload still need bridges, as
do the Root-to-Editor calls. Both retain a route trait, callback type, key lookup,
list copy initializer and one route per root. The second root is counted
separately in the machine-readable results; it is not hidden application code.

Complete application/domain source is **153 nonblank, noncomment lines for
current-state and 175 for shared**, before extension; afterward it is 165 and
185. Both additionally reuse the same 261-line handler runtime plus unchanged
public Moxi source. The facade accounts for 24 lines (37 physical lines), and
uses standard-library ArcPointer for retain/release. There is no application
subscription cleanup, lifetime registry or new invalidation code. This includes
all handwritten handle machinery, but not a count of standard-library internals.
Test infrastructure is excluded from authoring counts and retained in full.

The facade deliberately reuses the same value-owned Document policy. Forwarding
could be reduced by implementing a shared owner directly, and a raw ArcPointer
could remove it while exposing mutable data. Therefore the 22-line difference
is not an inherent cost of reference ownership or sufficient reason to reject
it. The more meaningful result is that root routing remains, extension work is
almost identical, and additional sharing semantics do not buy much comfort here.

## Lifetime and refresh findings

**Copies differ intentionally.** Copying a shared root aliases its committed
document while preserving independent local drafts/notes. An explicit snapshot
isolates both document value and history. The original value-isolation test still
passes for current-state; it was not weakened to make handles look equivalent.

**Handles retain access.** An Editor returned from a destroyed Workspace remains
usable. A separately retained Editor can still commit after removal from the
application's list. Normal control removal rejects stale UI targets in both.
No callback in this experiment captures a handle, so the control table does not
extend document lifetime. We did not measure final deallocation or leaks, and
retaining access is not the same thing as revocation/cancellation.

**Both require explicit refresh for external mutations.** The checks change
the model outside a UI event, verify the old labels remain even after resize,
then explicitly refresh/rebuild and verify the new labels. A shared document is
not an observation system and does not notify another host. Ordinary UI actions
still refresh once after dispatch in both variants.

**Neither has a complete document-replacement policy.** Negative controls show
the current route can apply an old draft to a replacement document whose revision
happens to match. Shared editors continue editing the old document after only
the Workspace's handle is replaced. Replacing a document must be an explicit
operation with document identity and a draft disposition policy; matching revision
numbers alone is insufficient. These are exposed limitations, not desirable
behavior. Switching documents was not added as a product feature in this task.

**The facade does not enforce render purity.** A compiled negative control calls
its Undo method from `render(self)` and consumes history on successive renders.
Owner operations enforce their own validation, but the handle permits calling
them from rendering. Current-state callbacks also have unrestricted mutable
Document access during actions; neither implementation proves capability safety.

## Decision and what would change it

**Moderate confidence: keep value-owned current-state application state as the
default for this single-owner UI.** Do not change the ownership model merely to
save two adapters. Use explicit shared domain handles when the document genuinely
needs an independent lifetime or cross-owner access. That is a requirement-driven
option, not an observed performance win or a completed multi-window feature.

**High confidence: both implement the tested interaction contract. Low
confidence: either current callback surface meets the desired comfort level.**
Do not adopt EditorRoute as the public API just because the suite is green.

The next bounded implementation problem is binding ordinary methods to reusable
component state while preserving these regression scenarios. Ownership selection
is settled as a working direction; another framework inventory or another
cosmetic A/B example is unlikely to help. This comparison does not implement a
new binding API. It also does not show that custom per-action bridges are
intrinsic to current-state ownership. Any binding change must count its full
machinery and avoid merely hiding the same work in another author-maintained
layer.

Evidence that would change the default: a complete shared implementation that
substantially reduces root/component wiring under the same assertions; actual
independent-host document requirements; or measurements showing value copies
dominate the real workload. A reader unfamiliar with the implementation must
successfully modify the example before claiming authoring comfort. Approval,
shorter isolated snippets, or more passing behavioral assertions do not establish
that claim.

## Provenance and verification limits

Planning baseline: `project-planning` at
`f98395b3c525c0e3b093ac291867ea5dad43d22f`. The implementation experiment and
direct-method-binding follow-up are committed in [0764b1b](https://github.com/davidmashburn/moxi/commit/0764b1b5e8017526a8e94b2b367480a9d7f7590f)
on `feat/data-workbench`. Unrelated implementation documentation and experiments
were preserved. No public source, original handler runtime, dependencies or
lockfile changed. Source hashes were rechecked before publication; the passing
suites were not rerun for this documentation-only publication update.

The manifest covers 144 source files, including the runner, new Mojo files,
original composition sources, handler dependency, public Moxi sources and lock.
The old compiler-crash diagnostic is hashed but excluded from passing commands;
it was not rerun. Commands execute the real App with synthetic events and a flat
ColumnView; the nested scope tests identity placement, not nested layout.

Skipped: full repository suite, native interaction and accessibility, performance
and allocation profiling, asynchronous completion, concurrency/reentrancy,
independent windows/hosts, observation/subscription teardown, nested layout and
an unfamiliar-developer usability exercise. Earlier broad ownership results are
inherited evidence, not rerun by this task.
