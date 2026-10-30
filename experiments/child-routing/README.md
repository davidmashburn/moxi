# Child routing authoring experiment

Isolated ordinary-Mojo follow-up to `../handler-api`. No production Moxi code or
previous experiment source changed. Run from the repository root:

```sh
bash experiments/child-routing/check.sh
bash experiments/child-routing/native.sh
```

The native demo shows the corrected shared-name case. `--build-only` compiles
without opening it. The checks exercise actual `App`, `ComponentSlot`, hit
testing, focus, keyboard, and clipboard routing without a native window.

## What the author writes

`form.mojo` owns both its fields and handlers. For example, these are real lines
from the compiled child, with the other controls omitted:

```mojo
def set_name(mut self, text: String):
    self.name = text

def render(self, mut ui: UI[Self]):
    ui.text_input("Name", self.name, Self.set_name)
    var selected = self.selected()
    ui.button("Save", Self.save, enabled=selected != "")
```

`IndependentForms` owns two `ComponentSlot[HandlerHost[GreetingForm]]` fields.
It embeds their views and routes each event to the appropriate slot. There are
**zero per-field forwarding handlers**, versus ten in the earlier `TwoForms`.
Adding a field inside the form does not require another parent handler. The
complete parent remains mechanical: explicit slot IDs/offsets, embedding calls,
event dispatch, and three clipboard methods. The source deliberately leaves
that machinery visible rather than hiding it behind a new composition helper.

Independent state is accessed at `first.component.root.name` and
`second.component.root.name`. This nesting is also a cost of the current host
adapter, not a proposed ideal public API. Conditional scopes within a form still
require stable keys. Different children can reuse the same local key.

## One deliberately shared value

The shared case is narrower than two full forms: two reusable name editors edit
one parent-owned `name`. This isolates the ownership and scheduling question;
sharing arbitrary fields between complete forms has not been demonstrated.

`NameEditor` receives a `value` snapshot and records a change request. The parent
owns the authoritative string, consumes the request, and supplies the resulting
value to both children. It uses a separate `has_request` flag because an empty
string is a legitimate edit. The synchronous, one-event-at-a-time protocol is
explicit; there is no retained mutable borrow, closure capture, observer, parser,
or generated language.

Two implementations make the scheduling difference reviewable:

| Case | Dispatch and settlement | Renders for one value edit | Cursor after replacing Ada with Grace |
| --- | --- | --- | --- |
| `shared.mojo` | Existing eager `HandlerHost`, then parent settlement | Origin 2, sibling 1 | 3: incorrect |
| `settled.mojo` | Child dispatch, parent settlement, child refresh | Origin 1, sibling 1 | 5: correct |

The eager version temporarily re-renders the old input before the parent applies
the request. Synchronization restores `Ada`, clamping the editor cursor; later
restoring `Grace` does not restore its expected cursor. The checks intentionally
retain this **known failure** as a comparison, not as acceptable behavior.

`deferred.mojo` is a small fork of the existing host whose `update` dispatches
without refreshing. The parent must settle and refresh before returning control
to `App`. It also must do so for clipboard cut/paste. This is an additional
scheduling contract, and forgetting it leaves stale output. Two public host
types and handwritten settlement are **not** the recommended user API. The
fork only tests whether the extra pass is fundamental. It is not needed in
these cases when dispatch and settlement precede rendering.

The shared state still has explicit input/output plumbing: `requested`,
`has_request`, and parent `settle`. The source has no generic state projections,
but that does not make shared ownership free or universally easy. A production
design would need one framework-owned settlement boundary, including all event
and clipboard entry points, rather than asking every application to reproduce
this ordering. General scheduling is outside this experiment.

## Evidence and limits

`results.txt` records the run, source hashes, and validation scope. Checks cover:

- Independent editing and saves, one changed-child render, no sibling render,
  and no save replay during rebuild, resize, or paint.
- Duplicate local conditional keys across children, Unicode text, namespaced
  App clipboard, keyboard activation, and Tab focus.
- Reordered persistent slots preserving identity, focus and cursor; copied
  components isolating state; untargeted and unknown events rejected.
- Shared edits from either child, empty strings, independent cursors, the next
  keystroke after replacement, synthetic composition, consumed requests, and
  one refresh per affected child after settlement.

An early check caused Mojo 1.1.0 to crash while compiling a deeply nested editor
cursor read. Reading the cursor through a small host-level test helper compiled
and allowed all behavior checks to run. Explicit generic arguments alone did not
fix the crash. It was not diagnosed upstream; do not treat this as a general
language limitation or a fixed compiler bug.

Render counts measure application render invocations, not time, allocations, or
total framework work. `App` still rebuilds/reconciles the parent view, embedding
copies child nodes, and `ComponentSlot` searches/projects the flat tree. The
localized executor is not used. Fixed offsets 1000 and 2000 only suit this
bounded example: monotonically allocated local IDs could eventually collide
with another child's range. There is no automatic namespace allocation here.

Inherited limits include retained identity history, linear lookup, cached render
output across bounds changes, thin handlers, and explicit refresh after external
state mutation. Read-only `self` does not enforce absence of external I/O.
Shared inputs are display snapshots; independently mutating them bypasses the
parent's ownership rule. Requests support synchronous sequential events only.

Not established: performance, general nested settlement, async/request handling,
dynamic child insertion/removal/remount, arbitrary shared forms, responsive
rendering, cross-platform behavior, or independent author comprehension. The
full repository suite and broad native accessibility/IME checks were not run.

## Assessment

High confidence in the tested ownership and ordering behavior. Moderate
confidence that local handlers plus framework-managed settlement are a useful
direction. Low confidence that the current parent surface meets the comfort
goal. The improvement is real but specific: independent composition no longer
multiplies field handlers, and correct shared editing does not inherently need
an extra render of the origin. Comfortable composition syntax remains unresolved.

Evidence that would strengthen the recommendation: an application author can
add a local field, reuse a child, and intentionally share a value without editing
routing code or learning refresh ordering. A broader example that requires
repeated passes or loses editor state would weaken it. Passing these tests alone
does not establish either result.
