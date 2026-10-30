# Actual Marko 6 Tags API experiment

Compiles Marko 6.4.7 with compiler 5.42.13, then executes its production client
runtime in a browser. This is separate from the older Marko-AST-to-Mojo generator.
No production Moxi runtime or dependencies change.

The contract matches the state-access experiment: nested Shell → Workspace →
Group → Editor, private drafts/notes, shared document/settings, normalization,
Unicode length, permission/identity/revision guards, explicit reload, no-op
commits, undo, replacement, keyed reorder/remount, and retained callbacks.
The 2/100/1,000-editor scale sequence uses the same five sink values and updates.

Three source variants are built, with the same behavior harness:

- **baseline:** callbacks read `input.rename`; whole document/settings props.
- **narrow:** adds `<const/rename=input.rename>` and calls that alias. This lets
  the compiler split the callback dependency from the whole input object.
- **projected:** also passes `writable=settings.writable` through the intermediate
  tags instead of the settings object. The root command still checks all current
  settings. These edits are explicit in `build.mjs`; generated sources are in
  `dist/<variant>/src/`.

The ordinary authored editor uses `<let/draft=input.document.name>`,
`<input value:=draft>` and event handlers containing assignments. No observation
helper or dependency array is required in application code. The five counters
are inserted **after** official compilation, into existing DOM leaf arguments.
This preserves compiler dependency analysis. Replacement patterns must match
exactly once or the build fails. Raw and instrumented compiler output are saved
side by side. Test-only action registration supports the escaped-callback test;
its work is not among the five measured sinks.

## Reproduce

```sh
cd experiments/state-access/marko
npm ci
npm run build
npm run serve
```

Open `http://127.0.0.1:4179/?variant=baseline`, then `narrow`, then `projected`.
On each page, click **Run checks and download results**. Save the three
`browser-<variant>.json` downloads into this directory. For browser automation,
`await window.runExperiment()` runs the same suite and returns the result.
Then, in another terminal in this directory:

```sh
node finalize.mjs
```

The finalizer rejects mismatched source/build hashes, checks output-value parity
against the prior Mojo/Solid comparison in all 45 cases, and writes
`results.json` and `comparison.json`. Runtime checks wait two animation frames
between steps to accommodate Marko's microtask/frame scheduling. This is not a
throughput benchmark. The server binds only to loopback and serves fixed paths.

## Measurement boundaries

- Leaf evaluations count entry into five existing compiled DOM operations.
  They exclude upstream projection, propagation, equality checks, event wiring,
  test registration, allocation, layout and paint. Zero leaves is not zero work.
- Changed DOM values are before/after snapshots, **not setter calls or mutation
  records**. For typing, the browser input already holds the new value before
  the reactive handler runs. The comparison means equal visible results.
- Mojo's full/memo figures are from its separate headless projection harness;
  Solid's are actual reactive effects without DOM. This is a dependency/work
  comparison, not an apples-to-apples renderer speed ranking.
- Registration cleanup checks bounded live registrations, not heap reclamation.
  Intentionally escaped callbacks may still invoke root commands after removal.
- Shared access here uses explicit props. It does not test a scoped ambient
  context API, SSR, hydration/resumption, streaming, async commands, concurrent
  mutation, accessibility, native widgets, or user-rated comfort.

Primary sources: [reactivity](https://markojs.com/docs/reference/reactivity),
[core tags](https://markojs.com/docs/reference/core-tag),
[template mount API](https://markojs.com/docs/reference/template),
[immutable state](https://markojs.com/docs/explanation/immutable-state).
