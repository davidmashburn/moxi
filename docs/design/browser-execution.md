# Browser execution for Moxi and Jupyter

Status: narrow feasibility demonstrated; full web target remains proposed.
Observed October 27, 2026. Implementation baseline: main `875f714`.

## Decision and evidence

Pursue a complete browser execution/rendering target alongside an independent
[server-backed views track](server-backed-views.md). These address orthogonal
questions: where interaction code executes, and where data/computation live.
The aim here is to reuse Mojo application and interaction code locally in the
browser. A complete web target must also accept reduced views from a backend;
it does not require every dataset or expensive computation to move into the browser.

Browser-local execution remains the preferred direction for immediate feedback.
Do not make feasibility of this compiler route a prerequisite for investigating
data reduction, or make a server transport a prerequisite for the web target.
Neither track requires a Jupyter adapter to establish its first result.

An uncommitted implementation experiment under `experiments/browser-execution/`
imports the existing FDG layout module unchanged. Its README and build script
contain reproduction instructions; build outputs are ignored. No product code
or project dependencies were changed. These are fresh checks, not inherited
standalone-viewer measurements:

- Mojo 1.1.0 (`8189361e`) lists ARM, RISC-V, and x86 targets. A direct wasm32
  build fails with no matching target. Official [compilation documentation](https://mojolang.static.modular.com/1.1.0/docs/tools/compilation/)
  provides LLVM IR/object emission and explains external cross-linking, but
  that does not itself establish a working Wasm target.
- A small exported arithmetic function runs in Chromium as wasm64 with no
  imports after host LLVM IR is retargeted through Apple Clang 21 and LLD 24.
- The existing 36-node/71-link FDG sample runs in Chromium 154. Weighted position
  checksums after 0, 1, and 100 steps agree with native to absolute tolerance
  `1e-8`; largest observed Chromium difference: approximately `6.82e-13`.
- Twenty additional 100-step runs finish with no tracked live allocations at
  call boundaries. Total: 506 allocations. Final artifact: 31,306 Wasm bytes.
  This tests reconstruction/disposal per call, not persistent graph state.
- Node also passes. The generated HTML page is self-contained: the solver runs
  in the browser and makes no backend calls. It prints probe results; it is not
  a rendered or interactive Moxi graph.

## What the route requires

The compiler emits Apple-host LLVM IR. A narrow conversion removes target
metadata/features, translates LLVM 24 floating-literal spelling for Clang 21,
and removes unsupported optimization/lifetime hints. Clang emits wasm64 and
LLD retains only the exported probe and its reachable code, avoiding native
async-runtime startup. This is an unsupported experiment, not a general compiler.

A JavaScript bridge provides aligned allocation/free and local math. Seven
error/diagnostic imports deliberately throw if called; they are not implemented.
Successful input never reaches them. The allocator checks frees and imposes a
64 MiB probe bound, but has no compaction/coalescing or concurrency support.

Memory64 preserves the probe's pointer/Int widths. It does not undo host-dependent
layout, ABI, SIMD, or compile-time choices already made by Mojo. A matched LLVM
toolchain and audited runtime boundary are required before relying on this path.
Checksum agreement is weaker than checking every node; no interaction or
end-to-end latency claim follows from it.

The community [Mojo2Wasm project](https://github.com/ravioli67/mojo2wasm) describes
an experimental independent frontend with type checking/lowering in progress.
It is not evidence that existing Moxi code can compile unchanged. A separate
[LLVM-to-wasm64 experiment](https://tangled.org/overby.me/overby.me/tree/main/dev/mojo/wasm)
was discoverable, but its page returned HTTP 403 during inspection; its runtime
and implementation claims were not verified or used as dependencies.

## Bokeh reference and data placement

Bokeh explicitly describes [server-side downsampling](https://docs.bokeh.org/en/latest/docs/user_guide/interaction/tools.html#controlling-level-of-detail)
for very large datasets, alongside client level-of-detail behavior during
interaction. It also supports both [browser JavaScript and server Python callbacks](https://docs.bokeh.org/en/latest/docs/user_guide/server/app.html).
The relevant lesson is deliberate placement of data, computation, and immediate
feedback. This does not mean Bokeh retains all plotted data on the server.

For Moxi, actively investigate a split architecture when reduced views are much
smaller than source data. The companion plan defines local viewport/gesture
behavior, server-owned queries/computation, bounded updates, cancellation/
coalescing, and rejection of stale results. A browser-native Moxi application
can consume those updates while continuing to handle immediate input locally.
Compare latency distributions, bytes moved, and browser memory for local and
remote kernels. No Bokeh or Moxi transport benchmark was
run here; round-trip cost alone cannot choose the architecture.

## Next acceptance gate

1. Use persistent graph handles with explicit create/destroy and bounded
   browser-local step/pin/release operations. Compare every node against native
   fixtures, including repeated interactions, invalid inputs, and disposal.
2. Replace the probe-only allocator/error imports with an explicit tested
   runtime subset; pin compatible compiler tools and audit host-dependent IR.
   Feature-detect memory64 and state the actual supported browser matrix.
3. Compile a minimal existing Moxi event-to-scene path and connect it to
   `native/hosts/moxi_web_host.mjs`. Exercise dragging, pan/zoom, selection,
   resize, text, and teardown without backend participation in immediate input.
4. Measure layout, scene, transfer across the Wasm/JS boundary, paint, input
   latency, memory, startup, and artifact size separately. Use those results to integrate
   the notebook lifecycle/transport from the [Jupyter plan](jupyter-integration.md).

Confidence: high that a real bounded Mojo solver can execute in the tested
browser; moderate that this route can host FDG interaction without a rewrite;
unproven for full Moxi. Persistent-state and event-to-scene tests could expose
runtime/ABI costs that change the recommendation. No Safari/Firefox, wasm32,
full UI, Jupyter, general error-path, capacity, or long-session tests were run.
