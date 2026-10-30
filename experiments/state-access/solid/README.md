# Solid state-access experiment

This is a bounded, headless experiment using real Solid.js client reactivity. It models:

- `Shell > Workspace > Group > Editor` composition with context lookup for a shared `Document` and `Settings`.
- Reusable editors with private draft, note, error, and base-revision state.
- Shared rename, stale-revision rejection, reload, undo, read-only and codepoint-length validation.
- Nested provider shadowing, editor disposal/remount, stable root document-slot replacement, and retained callbacks after disposal.
- Actual `createRenderEffect` evaluation counts and changed output-sink writes for `Current`, `draft`, `note`, `error`, and `Apply enabled` at 2, 100, and 1000 editors.

## Exact commands

From this directory:

```sh
npm ci
npm run check
```

`npm run check` executes `node --conditions=browser check.mjs`. The `browser` condition is required for Solid's client runtime; Node's default server resolution is not used for this experiment. The run writes machine-readable results to `results.json` and excludes that file from its own source-hash list.

The pinned package is `solid-js@1.9.17`, recorded exactly in `package.json` and `package-lock.json`. `node_modules/` is ignored locally.

## Scope and limitations

This is headless real Solid reactivity with no DOM. It does not render native or browser UI, implement the Mojo adapter, or make comparative latency/performance claims. Evaluation counts are runtime instrumentation inside the five sink computations; the dependency-graph expectations in `results.json` are labeled as inferred. `setupCount`, `liveCount`, `disposedCount`, and `peakLiveCount` are lifecycle counters. A disposed editor's retained command remains callable by design; that behavior is tested separately from the disposed UI sinks.

## Matched projection contract

The integration review aligns this variant with Mojo: Apply enabled depends only
on write permission, while the command reports empty/long names; no-op normalized
renames preserve revision/history; Undo respects permission, pops name history,
and does not increment the rename count. Editing a draft clears its error.
The five scale mutations and initial data match `../update_work.mojo` exactly.
History is represented differently (Solid retains an initial entry), and the
behavior suites are requirement checks, not identical input-event replays.
