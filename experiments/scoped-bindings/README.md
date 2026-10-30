# Scoped binding experiment

This experiment asks whether coupling a committed text edit to a declared state
scope makes a Moxi caller simpler, and whether it changes work compared with
explicit invalidation. Everything lives here; it adds no public Moxi API or
dependency.

The follow-up [dependency experiment](DEPENDENCIES.md) tests the more important
question: can dependencies come from reads rather than separate wiring, and what
does that cost when branches and consumer lifetimes change?

Run from the repository root with the pinned Mojo environment:

```sh
pixi run --locked mojo run -I src experiments/scoped-bindings/probe.mojo
```

## Workload and controls

The same editor feeds a greeting and a character-count label. An independent
sibling builds 1, 100, or 1,000 labels. Each run makes 100 committed Unicode text
replacements. Initial mount is excluded. All variants use real `TextInputState`
editing, `LocalizedExecution`, `ColumnView.layout()`, `ColumnRuntime.reconcile()`,
and `ColumnRuntime.paint()`.

- `root`: editing invalidates the common ancestor and rebuilds both children.
- `explicit`: editing invalidates only the form's declared scope.
- `binding`: a small `TextBinding.replace()` helper performs the edit and
  invalidates the same form scope.

All variants recompose, lay out, reconcile, and produce the complete parent paint
stream after each flush. This intentionally retains the full-parent work that can
remain after localizing child builders. It would be misleading to omit that work
and present a child-build reduction as an equivalent whole-frame reduction.

The explicit caller is:

```mojo
if not replace_committed(self.input, event):
    return False
return self.execution.invalidate_scope(FORM)
```

The binding caller is:

```mojo
return self.binding.replace(self.input, event, self.execution)
```

The binding owns a scope id, while the caller owns and passes the editor. It keeps
no borrowed pointer, second state copy, derived cache, or callback registry.
Scope registration and dependency declaration remain explicit in both variants.
This tests a small part of Marko's authoring model; it does not implement Marko,
compile-time dependency inference, a general typed lens, or automatic scheduling.

## Verification and counters

Every edit checks parity of command counts, changes/removals, ids/kinds, text,
geometry, cursor/selection, marked text, and semantic labels/values across all
three variants. Expected derived strings are checked independently, and editor
and sibling retained slots must survive every update. Additional cases exercise
identical replacements, two writes before one flush, selection/composition
cleanup with unchanged committed text, a missing scope, Unicode deletion and
cursor-based insertion, and rejection of an unrelated action event. Transaction
cases run against all three modes.

Source state changes immediately. Derived values are computed during the next
form build, so previously built render output stays stale until `flush()`. A
missing scope rejects the binding edit before source mutation. An unchanged
editor does not invalidate; selection or composition changes still do.

The CSV reports actual builder calls, nodes supplied to explicit `layout()`
calls, nodes supplied to parent reconciliation, and emitted/changed paint
commands. `layout_input_nodes` counts inputs, not internal node visits, text
measurement calls, cache misses, or time. Emitted commands are generated commands,
not commands submitted to a native renderer. The probe manually drives the
existing execution graph; it does not exercise the `App` event pump.

## Observed result

The run on October 26, 2026 with Mojo 1.1.0 (`8189361e`) passed all checks.
The captured work counts are in [results.csv](results.csv).

For 100 edits with 1,000 independent rows, both scoped variants eliminated all
100 sibling rebuilds after mount. Nodes supplied to layout calls fell from
200,800 to 100,800. Each variant still supplied 100,500 nodes to parent
reconciliation and generated 100,700 paint commands, of which 202 changed.
The explicit and binding variants matched every reported work count at every
sibling count. This is no evidence of an elapsed-time improvement from bindings.

The authoring change replaces a three-line edit/invalidate sequence with a
single helper call. It adds a descriptor and scope-validity contract, and callers
still declare the same dependencies. In this workload,
that is a modest coordination convenience with no additional rendering benefit.
The result supports keeping it experimental; it does not justify introducing a
general reactive API or template language.

## Decision boundaries

Equal work between `explicit` and `binding` would establish that this helper
preserves the scoped workload, not that bindings optimize rendering. Any work
saved against `root` comes from scope selection, which already exists in Moxi.
The helper moves edit/invalidation coordination into one place but introduces a
scope-bearing descriptor and its validity contract.

It also cannot statically prevent pairing the descriptor with the wrong editor
or choosing an insufficient dependency scope. Derived dependencies and scope
lifetime remain the caller's responsibility. The boolean return combines an
unchanged editor and a rejected missing scope. Those limits matter before any
attempt to promote this into a public binding API.

This experiment does not measure elapsed performance, allocations, native text
shaping, content-sized/wrapped layout, actual rendering, keyboard/focus routing,
the complete IME lifecycle, accessibility publication, asynchronous tasks, keyed
reorder/removal, or compiler inference. Fixed-height labels keep child geometry
stable; cross-sibling layout propagation needs a separate experiment.
