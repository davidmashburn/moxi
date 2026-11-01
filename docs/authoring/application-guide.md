# Building an application

This guide applies the [authoring strategy](README.md) to a document editor,
dashboard, or multi-pane tool. The runnable examples use the experimental runtime;
the lifecycle requirements below also define what production integration must
preserve.

## Choose the owner before the control

Start with the data, independently of UI declarations. A document owns saved
content. A pane owns its draft, validation message, and selection of a document.
An application or session owns the open documents and shared services. Retained
controls own interaction state such as caret position and active composition.

Put shared application state in the nearest owner that must coordinate its users.
Two drafts editing one document need one document owner, as in
[shared.mojo](../../experiments/authoring-guide/shared.mojo). Keeping a second
independent document copy in each pane would require a synchronization policy.
Copying a value for display is different from creating another authoritative owner.

Do not start with a universal store. Lift shared state when a second consumer
appears; keep independent drafts local. A larger application may benefit from a
store for undo, persistence, transaction rules, or cross-screen commands. That
store is an ordinary domain object. Neither this authoring API nor Xilem-style
reconciliation eliminates the need to decide where shared state belongs.

## Make changes through methods

Give commands domain names: `rename`, `apply`, `delete_document`, `reload`.
`render` reads values and declares controls. Keep validation and business rules in
methods that can be exercised without a renderer.

For a small program, a method can directly update its owner's fields. For a larger
one, use a domain method that checks permissions, document identity, and revision
before accepting an edit. The shared example deliberately uses last-write-wins;
it does not implement conflict detection. Two long-lived drafts usually need a
base revision and an explicit policy for stale Apply operations.

State outside normal control dispatch must enter through a publishing boundary.
The prototype's `update_model(app, command)` runs a synchronous command, refreshes
declarations, and rebuilds the view. This ensures removed controls are retired
before queued work can be delivered. Directly mutating `app.component.root` and
later delivering queued work skips that guarantee.

## Compose with the smallest useful context

A pane declares the type of shared data it needs. A parent routes its actions into
the current child and shared owner. Use `field` for a direct child field with the
same context; use an explicit route when selecting a different owned object or
enforcing a mutation rule. These routes are ordinary functions, so their authority
and cost are visible.

Prefer a document or focused service context to the entire application. This
reduces coupling and makes permission boundaries easier to review. Context in this
prototype is a value passed during declarations and a current mutable owner
supplied during action dispatch; it is not dependency injection with automatic
ancestor lookup, nor a fine-grained subscription.

Passing context through many intermediate panes can still be repetitive. First
check whether those panes need to own state or merely factor a declaration
function. Introduce a shared access mechanism only after a real application exposes
the repetition. A global object with every service makes short examples easier but
does not establish scalable ownership.

## Give dynamic children durable identity

Use `Keyed` when children are inserted, removed, or reordered. Keep its entries
intact when moving them. Use `remove(key)` to close a child, `append(value)` to open
a new one, and `reset()` to discard all children while preserving the allocator.
Publish those changes before delivering pending work.

A stable key says “this is still the same child,” not “these values are equal.”
Changing an existing draft's text is a value update. Closing a document and opening
a different one in the same visible row is usually a new child lifetime. Remove
and append in that case, rather than replacing the value under the old key.

For hand-written dynamic declarations, use the runtime's structural scopes and
distinct stable keys. Do not derive identity from current sort order. Ordinary
fixed sibling positions are appropriate only while their logical structure is
fixed. A conditional same-kind control can otherwise inherit the previous
control's interaction state and pending action identity.

## Requests and native input

Keep side effects out of `render`. A handler can record a request intent; the host
starts work once and delivers a result through the owning scope. Work aimed at a
particular control must capture that target's identity when scheduled. Stamping
an old result with the current lifetime on arrival defeats stale-work protection.

There are two different decisions: whether a result still belongs to a live owner,
and whether it is still the latest result for that owner. Lifetime checks solve
the first. Search-as-you-type, for example, also needs request ordering or
cancellation so an older query cannot overwrite a newer result while the pane is
still open. Cancellation alone is not proof that a completion cannot arrive.

A full root reset must be one host transaction:

1. Invalidate old native ingress, including queued input and marked-text state.
2. Cancel and retire request scopes belonging to the old session.
3. Replace the root lifetime and clear its retained interaction/scroll state.
4. Publish the new layout, text-input state, and accessibility snapshot before
   accepting new work.

The current integration experiment implements and tests these pieces through
adapters. The short `reset(app, root)` in the headless example implements only the
App/model portion. Do not wire that function alone to a native “New session” menu
and assume requests and OS input are covered. Production promotion must provide
one supported integrated entry point and one request-queue consumer.

Within a session, native keyboard and pointer input follows sequential dispatch:
click or Tab first, then typing uses the resulting focus. Explicitly targeted
delayed work must additionally reject retired targets. A late accessibility
callback from an old retained object can arrive in a new native queue, so clearing
the queue alone is insufficient.

The prototype's request bridge delivers a bounded kind of action completion; it
is not a general payload, error, progress, or network store API. Those adapters
need the same lifetime rules. Real OS IME behavior and cross-platform input must
be tested separately from injected queue tests.

## Preserve the distinction between data and a running host

Copy application data when a domain operation needs a copy. Do not use host copying
as the ordinary way to update a screen. A host copy is an independent delivery
owner, even if its model values and control IDs initially match. A move preserves
the existing owner. `App` itself is not implicitly copyable.

Persist domain values, not runtime control IDs, delivery scopes, or caret internals.
Loading a different document/session usually creates a new lifetime; refreshing
values for the same document may preserve it. Make that choice explicit at the
application boundary.

## Check behavior, then measure work

Test commands without UI where possible. Add UI tests for the ownership boundaries
that matter: editing one draft leaves another alone; reordering preserves the
intended editor; closing a child rejects its pending work; root reset rejects old
work and accepts new work; a shared save obeys the domain's conflict policy.

The guide's [behavior checks](../../experiments/authoring-guide/check.mojo) exercise
real captured actions and targeted text delivery. Their control lookup by kind and
ordinal is test scaffolding, not application authoring code.

Measure model work, declaration work, layout, paint generation, and native drawing
separately before optimizing. A small state change can still trigger broad work;
ordinary fields do not automatically create a dependency graph. Cache or narrow
expensive boundaries only with a clear invalidation rule. The runtime must handle
selection, focus, and composition changes even when domain values look unchanged.

Confidence is high in the bounded lifetime cases exercised by the experiments,
and moderate in the authoring strategy's comfort at application scale. Human
authors repeatedly needing manual generations, confusing assignment with reset,
or passing large contexts through every pane would be evidence to revise the API.
