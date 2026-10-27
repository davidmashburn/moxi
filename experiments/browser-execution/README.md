# Mojo browser execution feasibility probe

Observed October 27, 2026 against Moxi `875f714`. This is an experiment, not a
supported web target or a complete FDG viewer. It imports the existing
`examples/fdg/src/layout.mojo` unchanged.

## Reproduce

From the repository root, with its Pixi environment installed, Apple Clang,
Python 3, and Node available:

```sh
bash experiments/browser-execution/build.sh
```

Open the generated `experiments/browser-execution/dist/probe.html` or
`dist/persistent-probe.html` in a browser
with WebAssembly memory64 support. It is self-contained and makes no server or
kernel calls. The page prints results; it does not draw an interactive graph.
Build outputs are ignored. `dist/native.txt` and `dist/node-result.json` retain
fresh native and Wasm results. The browser exposes `window.probeResult` for checks.

## What ran

- Mojo 1.1.0 (`8189361e`), Apple Clang 21.0.0, bundled LLD 24.0.0.
- Direct `mojo build arithmetic.mojo --target-triple wasm32-unknown-unknown
  --target-cpu generic --emit object` fails: no available target matches.
  `mojo build --print-supported-targets` lists ARM, RISC-V, and x86 families.
- Mojo emits host LLVM IR; `retarget.py` removes host target settings and adapts
  limited LLVM 24 syntax/lifetime hints for the installed Clang 21.
- Clang generates wasm64 objects; bundled LLD links only the exported probe and
  reachable code. Native `main` and its async runtime startup are discarded.
- The unchanged solver creates its 36-node, 71-link sample, then runs 0, 1, and
  100 steps. A weighted position checksum is compared with native execution
  using an absolute tolerance of `1e-8`. This is not per-coordinate equivalence.
- Node and Chromium 154 passed. Chromium checksums were
  `-490.73085389089306`, `-579.0101732943633`, and `-25242.94863141275`;
  the largest difference from the native reference was approximately `6.82e-13`.
- Twenty additional 100-step runs plus the three comparison runs made 506
  allocator calls, with zero tracked live allocations at each call boundary.
  Final Wasm size: 31,306 bytes; heap high-water address: 80,112 bytes. These
  are diagnostic observations, not throughput or latency benchmarks.

## Persistent-state gate

`persistent.mojo` adds probe-only C exports for create/destroy, step, pin/release,
and coordinate reads. The unchanged solver stays alive across calls. Its native
`main` independently invokes `Layout` directly and emits fixtures for all 36
nodes: position, velocity, and pin state at initialization, after 10 steps,
after pinning node 3 and taking 5 steps, and after releasing it and taking 20
steps. `persistent-check.mjs` uses these fresh fixtures in Node and embeds them
in the self-contained browser test page.

Node and Chromium 154 passed 18,900 scalar comparisons across 102 graph instances,
including two simultaneously live independent graphs and 100 create/interact/
destroy cycles. Maximum absolute difference from native: `3.98e-13` in Node,
`5.41e-13` in Chromium (acceptance tolerance `1e-8`). There were 2,346 allocations,
zero tracked live allocations after disposal, and a 90,000-byte heap high-water
address. The persistent module is 33,958 bytes. Results live in
`dist/persistent-{node,browser}-result.json`; rerunning `build.sh` updates Node
results and native fixtures, while browser results require running the page.

Rejected operations cover negative/oversized/fractional step counts, out-of-range
nodes, nonfinite/extreme pin coordinates, calls after disposal, and double
teardown. Rejection leaves graph state unchanged. A disposed JS owner stays
invalid when another graph reuses its address. Pinning persists across steps;
releasing resumes movement and matches native.

The private raw C ABI assumes valid owned addresses. `persistent-runtime.js`
keeps addresses inside checked owner closures; this is not an opaque-handle
registry or a public safe FFI. Calling raw exports with arbitrary addresses can
trap or corrupt the Wasm instance. Integer/coordinate validation covers the tested
operations, not general Mojo runtime failures. Allocation lifetime uses the
[Mojo 1.1 pointer API](https://mojolang.org/1.1.0/docs/std/memory/pointer/Pointer/):
explicit initialization, pointee destruction, and deallocation.

## Bridge and limitations

The browser artifact is a Wasm compute module plus handwritten JavaScript glue
and a self-contained HTML test runner. The solver is Mojo, not translated
JavaScript. Persistent graph objects remain in Wasm memory; the exported C ABI
passes numeric arguments and results. Memory64 addresses cross as JS `BigInt`;
step counts and floating-point coordinates use JS numbers. A step call can run
multiple solver iterations without serializing the graph.

The verification readback is deliberately scalar: 36 nodes times five fields
means 180 JS-to-Wasm calls per snapshot, followed by JS array construction.
Allocation and imported math functions also cross into JS. Interop time has
not been measured, and this is not the intended rendering API.

The next rendering experiment should keep browser events, animation scheduling,
DOM/IME/accessibility, and browser graphics API calls in the JS host. Mojo should
own application state and produce a documented flat numeric output buffer,
consumed through typed-array views, with bounded work per frame. This avoids
per-coordinate calls and exposing compiler-private String/List layouts. Text
needs explicit UTF-8 conversion and caching; buffer ownership, reuse, and view
refresh after memory growth must be explicit. Reading a typed view can avoid a
CPU copy, but does not eliminate scene encoding, browser rendering, or GPU
uploads. None of this bulk-output path is implemented yet. The existing
`native/hosts/moxi_web_host.mjs` provides host callbacks and SVG presentation,
but is not connected to this probe; its SVG path assigns markup to `innerHTML`
and is not evidence of an efficient graphics-buffer path.

`runtime.js` supplies checked allocation/free with simple free-block reuse and
browser-local math functions. It imposes a 64 MiB probe heap bound. It is not a
production allocator: it does not compact/coalesce memory or cover concurrency.
Seven diagnostic/I/O imports throw if reached; successful runs do not exercise
error handling. No runtime failure is silently replaced with a success value.

This is unsupported IR retargeting. A 64-bit memory model preserves the probe's
pointer and integer widths, but cannot reverse target-dependent decisions Mojo
already made for the Apple host. Broader ABI, layout, SIMD, exception, runtime,
and optimization assumptions need auditing. Use compatible LLVM versions in a
real toolchain rather than relying on this narrow syntax conversion.

Not verified: arbitrary graph input, capacity limits, Moxi scene/widget code,
rendering, interaction latency, Jupyter, Safari/Firefox, wasm32, general error
paths, long-session memory behavior, or release packaging. Native Moxi tests
were not rerun because product code is unchanged.

Next gate: compile the smallest Moxi event-to-scene path and connect it to the
existing browser host shim; audit runtime/error imports and toolchain assumptions
before treating this as a supported target. The server-backed reduced-view
experiment advances independently and can later supply data to this web target.
