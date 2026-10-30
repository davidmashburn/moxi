# Selective updates beneath ordinary methods

This experiment keeps `state-access/{domain,editor,application,adapters}.mojo`
unchanged and replaces the host for its fixed shared-document editor tree.
Typing rebuilds one editor's declarations and retained controls. Shared-state
comparison decides whether the other editors must rebuild. This is an
application-specific prototype, not a generalized or adopted Moxi API.

Run from the repository root:

```sh
python3 experiments/selective-updates/check.py
```

`results.json` records the compiler, source hashes, generated extension source,
full program output, and 36 work measurements. The runner validates expected
counts and compares every retained editor node with an independent full render.
The oracle compares node kind/text/enabled/checked, not IDs, parentage, layout,
accessibility metadata or action identity. Its work is outside the update
counters. Temporary detailed logs are reported by the runner.

## Contract and outcomes

- Preserve ordinary fields, methods, current-state command routing, private
  drafts/notes, value-owned services, and retained text editing state.
- Infer the affected editor from its routed control. A child action may change
  that editor and its shared services; the adapter has no root-wide action or
  arbitrary pointer-mutation tracking.
- Compare shared inputs once per action, not once per editor. `AllInputs`
  snapshots and recursively compares the whole value context; `DisplayInputs`
  explicitly lists `document.name` and `settings.writable`.
- An external service-only transaction calls `services_changed()` on the host.
  When owned by an App, it then calls `app.rebuild()` to update the composed view.
  The event path already rebuilds App after a handled update. Arbitrary
  direct local/root writes, membership changes, and reorder call `refresh()`;
  that full fallback reconciles all editors. Writes are not automatically
  observable outside these transaction boundaries.

At 1,000 editors (same behavior at 2 and 100):

| Mutation | AllInputs editor renders | DisplayInputs editor renders |
| --- | ---: | ---: |
| Draft in last editor | 1 | 1 |
| Private note in last editor | 1 | 1 |
| Shared name | 1,000 | 1,000 |
| Writable setting | 1,000 | 1,000 |
| Unrelated setting | 1,000 | 0 |
| Command-only length limit | 1,000 | 0 |

Each editor render emits nine declarations: eight visible nodes and a scope
container. It re-evaluates the original five dynamic outputs; it is not Marko
or Solid style leaf-level reactivity. Each measured mutation performs one
shared comparison and zero full fallbacks. That one comparison is **not
constant-time**: AllInputs can inspect all document history and copies it into
an owned snapshot when shared state changes. A 10,000-entry history check
verifies correctness and snapshot independence, not timing or memory use.

Three programs pass:

1. Real `App` tests for both policies: draft isolation, commit/conflict/reload,
   undo, validation/Unicode, current settings, permissions, copied hosts,
   retained callback rejection after remove/append, 100 remounts, reorder,
   direct-write fallback, caret and clipboard. Scale uses the same host and
   actual retained input/action dispatch but does not run full App frame work.
2. Generated editor extension: ordinary reviewer field/setter/control and a
   new shared limit label. The unchanged conservative host stays correct.
   An actual App-view check proves the external transaction needs App rebuilding
   after the cache update.
   DisplayInputs predictably leaves the new label stale until its projection
   includes the limit; the full-render oracle detects it. The oracle is a test
   tool, not an always-on production safeguard.
3. Unchanged state-access behavior suite, including its existing whole-keyed-
   collection replacement identity-reuse negative control.

## What this does and does not establish

Local render avoidance works without field wrappers, signals, dependency
annotations, or per-handler dirty calls. The adapter still knows the concrete
`Application -> Shell -> Workspace -> Keyed[Editor]` layout and routes through
existing `Keyed.route`; its integration code is not free or general-purpose.
It renders the editors directly because the three intermediate panes only
forward children. Parent chrome, heterogeneous readers, provider overrides,
conditional mounted subtrees and arbitrary trees are not covered.

Cache selection uses a binary-search index, but existing action routing scans
`Keyed.entries` (the scale test intentionally edits the last child).
Composition still visits/copies all child views, and normal App layout,
reconciliation and painting remain broad. **No O(1) event or frame-time claim
follows from one editor render.** ID namespaces are bounded at 1,024 and fail
closed on exhaustion; this is experimental routing machinery. Whole collection
replacement can reuse keys, as in the baseline; this host does not solve it.

Reflective equality is appropriate only for this owned value graph and its
standard value equality. Pointer identity, external mutation, custom equality
that omits render-relevant state, and opaque/foreign resources require a
separate contract. Snapshot/equality cost and rebuilding all readers on shared
writes make AllInputs a correctness baseline, not a settled scheduler.

Recommendation: keep ordinary authoring and conservative component-level
selectivity as the working direction. Do not require hand-maintained shared
render dependency lists by default. Confidence is moderate: a heterogeneous
workbench plus full-frame and snapshot-cost measurements could overturn this.
Skipped: full Moxi suite, native/manual interaction, timing/allocation profiling,
async races, accessibility audit, general runtime integration and usability
studies. No production code changed. Sources and captured results are versioned
together in this directory; source hashes identify the tested working-tree state.
