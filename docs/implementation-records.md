# Moxi implementation records

Proposals and execution priorities live on the orphan `project-planning`
branch. Start with its [execution plan](https://github.com/davidmashburn/moxi/blob/project-planning/PROJECT-PLANNING.md).
The [historical post-0.5 design](https://github.com/davidmashburn/moxi/blob/project-planning/docs/post-0.5-roadmap.md)
and [Not implemented pattern](https://github.com/davidmashburn/moxi/blob/project-planning/docs/not-implemented-pattern.md)
have moved there; the execution plan reconciles the historical topics with its
existing gates. Keep future scope on that branch and implemented contracts,
usage documentation, and validation evidence beside product code.

This file retains implementation and policy records from the earlier planning
document. They are historical evidence, not a fresh verification of this
checkout. For current supported behavior, use [the feature inventory](features.md),
[the API guide](API.md), [plotting](plotting.md), [the support matrix](support-matrix.md),
and [the architecture guide](../ARCHITECTURE.md). These records were retained
when `docs/project-planning.md` was removed from `main`; they do not incorporate
the later desktop work on `feat/data-workbench`.

## Request and effect contracts

The Xilem critique is useful as a design warning rather than a mandate to copy
Xilem's full abstraction stack. The current keyed request slice addresses the
most concrete gap—replacement, cancellation, adapter completion, and stale
result identity—while keeping the deterministic core free of threads and I/O.
The recorded contract boundaries are:

| Contract or limitation | Boundary | Recorded evidence |
| --- | --- | --- |
| Lifecycle-owned request integration (opt-in keyed bridge shipped). | Tie scoped request keys to keyed subtree mount/removal while retaining bounded records and detached-result rejection; keep full automatic view diffing out of the component trait. | `RequestScheduler.mount_scope()` / `unmount_scope()` and `KeyedSubtreeExecutor.insert_scoped()` / `remove_scoped()` are traced in `tests/execution.mojo`; callers pair the explicit keyed boundary without callback-heavy trait machinery. |
| Define the real async adapter contract (deterministic adapter seam shipped). | Keep transport, executors, cancellation, and deadlines in host adapters; keep `RequestScheduler` deterministic and injectable. | `tests/request_adapter.mojo` acknowledges success, failure, timeout, and cancellation through `App`, rejects a late replacement callback, and uses no hidden threads; real transport ownership remains an adapter responsibility. |
| Keep view construction pure and effects explicit (policy shipped). | `build()`/`localized_view()` must not perform I/O or mutate external state; use a narrow request command rather than a broad `CompCtx` or HOC layer. | `docs/API.md` documents the policy and `SearchEffect` in `tests/request_adapter.mojo` submits work outside view construction before results return as events. |
| Measure Mojo API ergonomics before growing abstractions (baseline shipped). | Track compile time, diagnostic size, and public generic surface for `Component`, `ComponentSlot`, and request examples; prefer explicit actions/lenses over implicit two-way bindings. | `pixi run api-ergonomics-quick` / `-full` record compile fixtures, a consumer diagnostic, and the public surface before new generic or binding machinery is added. |
| Browser package limitation. | Treat the current host demo/ARIA bridge as an adapter, not proof of a Mojo Web runtime; keep WASM packaging and browser lifecycle tests as a separate gate. | `pixi run web-package-check` verifies the host lifecycle and records the compiler capability; `web-package-required` stays a release blocker until a Mojo WASM target and package ABI exist. |

Preserve the bounded request contract. Do not introduce a generic HOC system,
implicit two-way binding, or hidden executor in the core solely to match
another framework's vocabulary.

Performance is a release requirement, not a later optimization pass. Mojo is
being used for predictable, low-overhead UI work, so every renderer/runtime
slice must have a repeatable benchmark, a stated workload, and a recorded
reason for any tradeoff.

## Earlier macOS implementation slice

The current macOS pass closes two previously visible quality gaps. Metal keeps
the allocation-free ASCII geometry path for short labels, uses CoreText-backed
Unicode textures with a bounded persistent text cache for fallback glyphs,
flattens quadratic/cubic/arc paths, ear-clips concave simple polygons, and
scanline-tessellates bounded compound/self-intersecting paths with even-odd
fill semantics. Its benchmark reports synchronized CPU and optional GPU
timings.
Accessibility now transports
explicit toggle/disclosure state and numeric ranges through reconciliation,
paint, the native registry, and AppKit; the native presenter uses those same
states for list/table/tree/menu/dialog/tab/canvas affordances. The offscreen
Metal benchmark records Unicode texture draws, cache hits, and rasterizations
separately from geometry and continues to report vertices, submissions, paths,
fallbacks, and checksums.

The dense-plot rendering slice now follows the same contract: supported line,
step, scatter, bar, box, rule, interval, tick, heatmap, and rectangle marks can
compile into an ordered `PlotRenderPacket` of flat screen-space records. The
software renderer consumes that packet for parity, while Metal uploads each
contiguous batch once and expands lines and quads on the GPU. Packet reduction
is viewport-aware, source rows and stable keys remain intact, and unsupported
area/band/text/tooltip/lasso cases explicitly request the Scene fallback.

Remaining renderer limits are portable shaping/font fallback and
platform-specific GPU text/image/path tessellation. Dense visible canvas
frames now use asynchronous Metal pacing with a bounded three-slot ring;
offscreen benchmarks intentionally synchronize for complete checksums.
Remaining native limits are editable collection cells, system menu/dialog
tracking, live Mojo-runtime publication on iOS/Android/Web, and device-level
screen-reader automation.

The first product built on these contracts is a first-class plotting library:
a supported interactive 2D visualization system with portable data, declarative
scene generation, GPU/native presentation, and a path to advanced domains.

## Core contract decisions

1. `View` remains declarative and platform-independent. It owns no native
   handles and is safe to rebuild.
2. Retained runtime state, component state, capability calls, and platform
   handles have explicit ownership boundaries. A callback or native handle
   does not cross a serialization or capability boundary implicitly.
3. A backend advertises what it actually supports. iOS, Android, and Web are
   named targets in the capability matrix even when the Mojo runtime is not
   linked; host artifacts must report their real status rather than masquerade
   as macOS or headless.
4. Scene commands are the portable rendering contract. Software rendering is
   the deterministic oracle; GPU renderers consume the same scene/resources
   where practical and may expose a documented capability-specific extension.
5. Text shaping is an adapter boundary. The fallback estimator remains useful
   for headless tests, but user-visible text must identify whether shaping,
   bidi, font fallback, and glyph rasterization are real on that backend.
6. Examples, tests, and benchmarks consume shared scenarios and data fixtures.
   A demo is a contract test, not a hand-built mirror of the API.

## Performance policy

Every renderer/runtime change must update the benchmark story:

- Measure repeated runs, not a single timing; report workload size, pass count,
  checksum/validation signal, compiler/runtime version, and hardware notes.
- Keep quick benchmarks suitable for `pixi run check` and a fuller benchmark
  suitable for release/pre-submit runs.
- Cover at least reconcile, layout, paint/scene generation, software rendering,
  virtualized scrolling, GPU command encoding, buffer growth, submission, and
  synchronized completion. Record native GPU timestamps where the driver
  exposes them and keep CPU encode/wait/frame timings alongside them.
- Compare 100-, 1,000-, and 10,000-node workloads where the stage supports it;
  track allocations or command counts when wall-clock allocation data is not
  portable.
- Treat a 60 Hz frame as a 16.67 ms budget and a 120 Hz frame as an 8.33 ms
  budget. State whether a result is CPU-only, GPU-inclusive, or a cold start.
- Optimize only after a baseline exists. Prefer stable identity, bounded work,
  batching, dirty-region/dirty-component scopes, resource reuse, and fewer
  allocations over speculative micro-optimizations.
- Plot benchmarks must cover 10,000-point lines, 100,000-point scatter,
  million-point scatter with level-of-detail, faceted views, linked views,
  dense heatmaps, streaming updates, and repeated pan/zoom/selection.

The benchmark command and methodology belong in the repository, and release
notes should include the result artifact or a concise comparison table. A
regression should block a release when it breaks a stated budget or materially
increases work for a shared scenario.

## Earlier 2D plotting implementation slice

This records the implemented subset described by the earlier design. Current
API names, export lanes, and limitations are documented in [plotting](plotting.md),
[Python](python.md), and [the support matrix](support-matrix.md). The older
proposal and its superseded backlog statements are preserved on the planning
branch, rather than used as current support claims here.

The executable foundation now covers typed nullable columnar data, stable row
keys, snapshots and zero-copy views, field-aware encodings, second positional
channels, categorical labels/colors, core Cartesian marks, statistical
histogram/density/ECDF/box/heatmap/hexbin/regression recipes, facets with
independent scale resolution, layer/horizontal/vertical composition,
deterministic filter/sort/sample/bin/rolling/impute/stack/group/aggregate
transforms, forward/inverse scale mapping, annotations, JSON inspection/
round-tripping, PlotView/PlotControl, pointer/touch navigation, interval brush
and lasso selection, explicit linked selections, keyboard focus,
accessibility state, CSV fallback, SVG path/opacity output, and bounded
line/scatter geometry. The software renderer, SVG serializer, Metal geometry,
text, and path support, target fallback bridges, host status contract, and browser host
module are contract-tested.

## Browser/integration harness

The Web slice has a known-good server path (`python3 -m http.server 8765`), a
stable route (`native/web/host_demo.html`), explicit `MoxiWebHost.stop()`
teardown, Node contract tests, and a real browser smoke path. The browser demo
exercises pointer/focus/resize/frame callbacks and exposes a labeled Canvas;
the host bridge also exposes DOM accessibility mapping. The
`web_package_check.sh` probe records whether the pinned Mojo compiler exposes a
WASM target and fails closed for a required package build. Until that target
and package ABI exist, do not claim the Mojo Web package from the host demo.

## Documentation and release gates

Keep `README.md`, `SPEC.md`, `ARCHITECTURE.md`, API docs, changelog, showcase
instructions, capability reports, and benchmark methodology synchronized.
Each milestone needs:

- a status table distinguishing shipped, experimental, and planned behavior;
- a runnable example consuming the public API;
- unit/property tests for pure contracts and integration tests for visible
  behavior;
- benchmark output with the workload and environment recorded; and
- explicit non-goals and fallback behavior for unsupported targets.
