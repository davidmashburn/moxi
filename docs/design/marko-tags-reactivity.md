# Marko 6 Tags API: comfort and update work

October 30, 2026. Follow-up to [state access and update work](state-access-comparison.md).
Experimental evidence, not an adopted Moxi API.

**Marko strengthens the case for pursuing both comfortable authoring and selective
updates. It does not require us to choose a terse API with whole-tree rendering.**
In this example its local bindings are easier to read than the corresponding
explicit signal plumbing. That is an authoring assessment, not a usability-test
result. Confidence is moderate; a larger application and independent readers
could change it.

## What ran

Actual Marko **6.4.7**, official compiler **5.42.13**, optimized DOM output,
esbuild **0.25.12**, executed in the T3 Chromium browser. Five real Tags API
components form App → Shell → Workspace → Group → Editor. This is not the older
Marko-AST-to-Mojo generator. Implementation lives in
`experiments/state-access/marko/` on the implementation checkout based on
`0764b1b5e8017526a8e94b2b367480a9d7f7590f`; the planning worktree baseline is
`9969376de584045905d43151b08353fc33b02539`. Experiment sources and captured
results are preserved in [implementation commit `e66cdd9`](https://github.com/davidmashburn/moxi/commit/e66cdd95dcffce3519fb6970087a15fe1821a4db); this analysis is versioned on
`project-planning`. Execution-baseline metadata remains unchanged.
`results.json` records exact source/build hashes, package versions and browser
user agent. `comparison.json` links to the earlier verified Mojo/Solid results.

**375 assertions passed across three variants; all 45 scale cases matched the
earlier visible-output change counts.** Each variant exercises normalization,
Unicode code-point limits, empty/long names, private drafts/notes, stale edits,
same-revision document replacement, read-only commands and undo, normalized
no-op commits, keyed reorder, remove/remount, 25 lifecycle cycles and escaped
callbacks. Checks drive DOM inputs/buttons as well as explicit command hooks.

## The comfortable part is real

This is authored source from the reusable editor, without measurement wrappers:

```marko
<let/draft=input.document.name>
<let/note="">
<let/error="">

<label>Name draft
  <input value:=draft onInput() { error = ""; }>
</label>
<label>Private note <input value:=note></label>
<button disabled=!input.settings.writable onClick=apply>Apply</button>
<p>${error}</p>
```

There is still an `apply` function, identity/revision bookkeeping and a domain
command. Marko removes observation/binding ceremony; it does not remove the
application's consistency rules. `<let>` initialization does not continuously
resynchronize an edited draft; Reload is explicit and the test verifies this.

The compiler discovers reactive dependencies and emits update functions. That
explains why assignments can look ordinary while updating individual bindings.
Solid discovers its dependencies at runtime. These are different mechanisms
behind a similar author experience, not evidence that plain Mojo assignments
already carry the same information. See the [Marko reactivity reference](https://markojs.com/docs/reference/reactivity).

## Three source variants, not three invented runtimes

1. **Whole input:** the editor calls `input.rename(...)` in its handler and
   receives the document/settings objects through intermediate tags.
2. **Callback alias:** add `<const/rename=input.rename>` and call `rename(...)`.
   The compiler can now expose separate input-property update functions instead
   of coupling the callback to the whole input object.
3. **Narrow props:** keep that alias and pass `writable=settings.writable`
   through the intermediate tags. The editor consumes `input.writable`; the
   root command continues to check the full, current settings.

The build generates variants 2 and 3 with explicit source transformations;
otherwise their behavior and test harness are identical. Generated source and
unmodified/instrumented compiler outputs remain in ignored `dist/<variant>/`.
Inspection confirms grouped input dispatch in variant 1 and separate
`$input_document`, `$input_writable`, `$input_rename` paths in variant 3.

At **1,000 editors**, these are evaluations of five selected leaf expressions:

| Mutation | Whole input | Callback alias | Narrow props | Solid | Mojo full | Mojo memo |
|---|---:|---:|---:|---:|---:|---:|
| One draft | 1 | 1 | 1 | 1 | 5,000 | 5 |
| One private note | 1 | 1 | 1 | 1 | 5,000 | 5 |
| Shared name | 2,000 | 1,000 | 1,000 | 1,000 | 5,000 | 5,000 |
| Write permission | 1,000 | 1,000 | 1,000 | 1,000 | 5,000 | 5,000 |
| Unrelated setting | 1,000 | 1,000 | 0 | 0 | 5,000 | 0 |

All variants change the same visible values: 1, 1, 1,000, 1,000, 0. The same
relationships hold at 2 and 100 editors. The whole-input variant reevaluates
Apply's unchanged permission binding on document changes. Passing settings as
an object also reevaluates that binding when only an irrelevant setting changes.
An equality check at the projected writable value avoids that downstream work.

**These are not speed rankings.** Mojo memo additionally checks all 1,000
editors. Marko also performs upstream propagation, comparisons and command/event
work outside the five leaf counters. Its narrow-props zero means zero measured
leaves, not zero CPU work. Mojo projection is separate from real App; Solid uses
actual effects without DOM; Marko uses actual DOM. No timings were collected.

Counters are inserted into generated JavaScript *after* official dependency
analysis, wrapping the existing leaf arguments. Application templates contain
no counter calls, and a changed compiler shape causes the instrumentation to
fail rather than silently miscount. Visible changes are DOM snapshots, not DOM
setter counts; typing sets the input value before its event is handled.

## Limits and consequences for Moxi

- **Fine-grained does not mean every formulation has minimum work.** The
  boundary shapes above change compiler output substantially. This is observed
  with high confidence for these pinned versions. A compiler upgrade or
  differently factored component could change the figures.
- **Lifetime and command authority remain separate.** Registrations/DOM are
  cleaned up, keyed reorder preserves a draft, and remove/reinsert makes fresh
  state. A deliberately retained Apply callback still successfully committed
  after removal in all variants. This is the same category of limitation seen
  in Solid; it is not a Marko rendering leak or proof of heap reclamation.
- **Shared dependency access remains a separate question.** These Marko examples
  use explicit props, including intermediate forwarding. They do not establish
  scoped provider lookup or eliminate prop drilling. No context API was tested.
- **The syntax has defined semantics.** Derived values update on the scheduled
  flush, so they can be stale within the mutating handler; the test waits across
  frame boundaries. Plain object updates in this experiment replace values.
  Nested in-place mutation is not equivalent to assigning a reactive variable.
  These rules are documented in [reactivity](https://markojs.com/docs/reference/reactivity)
  and [immutable state](https://markojs.com/docs/explanation/immutable-state).

My recommendation remains **ordinary fields and methods as Moxi's working
surface, with selective invalidation tested beneath it**. Confidence: moderate.
Marko is a stronger comfort target than our explicit signal sketches, especially
for local fields and bindings. But copying its surface requires deciding where
its compiler-provided dependency knowledge comes from in Mojo. The experiment
does not establish a way to obtain that knowledge without compiler support,
tracked access, explicit projections, or comparisons.

The next useful Moxi gate is a small implementation under the existing method
API: preserve private drafts and current-state command routing, update one
editor for a local edit, and avoid scanning every editor for an unrelated
change. Record any new field wrappers, annotations or manual invalidation the
application author must write. That evidence would change the recommendation
if the machinery costs more comfort or runtime work than it saves. Keep this
separate from adopting an ambient context mechanism or a new authoring language.

Skipped: full Moxi tests (no production changes), rerunning unchanged Mojo/Solid
runtime suites (their source/result provenance was revalidated), timing,
allocator/heap profiling, native rendering, SSR/hydration/resumption, streaming,
async command races, accessibility checks and human usability testing. This
experiment also does not execute Xilem or prove a universal framework ranking.

## Reproduce and inspect

See `experiments/state-access/marko/README.md` for install/build/browser steps and
`finalize.mjs` for provenance and comparison checks. The interactive
[comparison](marko-tags-reactivity.html) switches scale, Marko variant and
comparison strategy. The earlier [Mojo/Solid comparison](state-access-comparison.md)
remains the record of its distinct runtime and ownership checks.

## Selective-update follow-up

The [Mojo implementation probe](selective-method-updates.md) now exercises
editor-level caching beneath the unchanged ordinary-method surface. Local input
rebuilds one editor at scales up to 1,000. Avoiding all work on unrelated shared
changes required an explicit projection, whose missing-dependency negative
control produced stale UI. The conservative version handled new reads without
bookkeeping; broad shared writes and full-frame costs remain open.
