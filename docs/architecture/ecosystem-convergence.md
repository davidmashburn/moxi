# Ecosystem convergence boundary

Status: provisional architecture record, audited September 7, 2026.

This document is the implementation-side companion to the
[ecosystem convergence plan](../../../moxi-project-planning/ECOSYSTEM-CONVERGENCE-PLAN.md).
It records what Moxi owns, what remains an adapter, and which upstream
compatibility facts have been measured rather than assumed.

## Ownership

| Layer | Moxi owns | Deliberately does not own |
| --- | --- | --- |
| Product model | `PlotDataTable`, `PlotSpec`, `PlotRuntime`, stable row keys, selections, semantics, accessibility, and LOD policy | a foreign fluent plot object model |
| Scene | ordered `Scene`/`SceneCommand` values and `SceneRenderer` lifecycle | canvas-specific structs or native handles |
| Correctness renderer | deterministic software scene output and exact visual goldens | platform font pixels |
| Export/backends | SVG, AppKit, Metal, and future canvas adapters | one backend as the scene contract |
| Python | serialized specs and typed value/buffer inputs | borrowed Mojo object layout, windows, callbacks, or event-loop ownership |
| Upstream dataviz | reference output, algorithm provenance, and capability inventory | wholesale source or fluent API compatibility |

The software renderer remains the portable oracle until another backend has
semantic, structural, and output evidence for each command it claims.

## Python boundary

The first supported binding shape is intentionally narrow:

```text
render(spec_json, named_columns, width, height, format) -> bytes or RGBA
```

`spec_json` is the versioned `PlotSpec` representation. `named_columns` is a
value boundary: contiguous numeric buffers first, followed by explicit
validity, categorical, string, and timestamp encodings. A call owns all
temporary Mojo state in the initial proof; no Mojo object or renderer lifetime
escapes into Python.

The first Python product is headless export (`PNG`, `SVG`, later `PDF` and
`RGBA`). Native windows, callbacks, interactive event loops, and notebook
widgets are separate work. Until a clean wheel installs without a matching
Mojo compiler or manual import-path setup, the package remains experimental.

## Canvas boundary

`canvas_mojo` is a candidate implementation of `SceneRenderer`, not a
replacement for `Scene`. The initial adapter slice is limited to rectangles,
rounded rectangles, lines, linear gradients, transforms, rectangular clips,
opacity, and raw/PNG export. Text, typed paths, images, and offscreen layers
need explicit follow-on contracts.

The exact compatibility experiment used upstream `canvas_mojo` revision
`27401fe83c76488fe3b3ab2dcd12ad09333bba51` (`v0.21.0`, MIT). Its own Pixi
environment runs the smoke example with Mojo `1.0.0`. Moxi's locked
`1.1.0.dev2026082605` environment could not compile that source: the source
package failed on `std.runtime.asyncrt`, `InlineArray`, and compile-time
decorator syntax.

That blocker is now carried by the short-lived compatibility fork
[`davidmashburn/canvas_mojo@moxi/mojo-nightly`](https://github.com/davidmashburn/canvas_mojo/tree/moxi/mojo-nightly)
at immutable revision
`323154f9399f4ecfa6d5d2fb0fc7d87883fe3c1e`. The patch is limited to the
nightly API seam: it maps `parallelism_level` to public `std.runtime` and
`TaskGroup` to private `std.runtime._asyncrt`, replaces removed
`InlineArray` uses with `std.collections.Array`, changes `@parameter if` to
`comptime if`, and pins the package's precompile compiler exactly to
`1.1.0.dev2026082605` so its `.mojoc` is consumable by Moxi. Core buffer,
JPEG, blur, golden, and package-export tests pass under Moxi's runtime, and
the package precompiles and imports through Moxi's installed environment.

Moxi now pins that exact fork revision in `pixi.toml`. This makes `canvas` a
reproducible nightly dependency, but does not yet make it a `SceneRenderer`:
the adapter and rendering-path integration remain separate work. The fork is
nightly-only and relies on a private runtime module, so the follow-up is an
upstream PR or a public async-runtime replacement, after which the pin should
move back to an upstream revision. A floating checkout remains disallowed.

## Dataviz convergence

The selected reference is `dataviz_mojo` revision
`daed1bf9f0b367778109b724c4cd1e035114b476` (`0.8.0`, MIT). It currently
depends on `canvas_mojo` tag `v0.20.1` and exposes a fluent `Plot` plus more
than forty convenience marks. Moxi's inventory is in
[`dataviz-capabilities.tsv`](../dataviz-capabilities.tsv).

Each capability must acquire, in order:

1. a Moxi schema/validation row;
2. scene output and software/SVG parity;
3. interaction, accessibility, and tabular fallback behavior;
4. Python exposure through the same `PlotSpec`; and
5. a reference scenario and benchmark.

Static upstream output without those contracts is reference evidence, not an
absorbed Moxi feature.

## Current evidence

- `pixi run check` passes on the current Moxi `main` worktree, including the
  exact pinned canvas package installation.
- `pixi run benchmark-compare` passes all ten full-profile cases against the
  reviewed macOS arm64 baseline.
- `pixi run native-screenshot-check` remains the offscreen Metal tolerance
  gate; the visible AppKit lane has a fresh human-reviewed capture through
  `MOXI_RECORD_SECONDS=1 pixi run demo-record`.
- linked Mojo runtimes for Linux, iOS, Android, and Web remain unverified;
  their current artifacts are host shells or deterministic fallback paths.
