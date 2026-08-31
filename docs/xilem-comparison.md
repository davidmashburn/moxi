# Moxi and Xilem

Status: comparison and implementation plan for Moxi 0.5 plus experimental
post-0.5 slices, checked against
Xilem's upstream documentation and repository links on 2026-08-31.

## Executive summary

Moxi is a compact, Mojo-native UI core inspired by Xilem. It is useful for
learning, embedding, and agent-facing applications, but it is not a peer
replacement for Xilem as a general-purpose UI framework.

The closest architectural mapping is:

| Moxi | Xilem | Relationship |
| --- | --- | --- |
| `Component`, `ColumnView` | Xilem Core and typed views | State produces a lightweight description of the UI. |
| `ColumnRuntime`, controls | Masonry widget tree | A retained tree receives updates, layout, paint, input, and semantics. |
| `Renderer`, `WindowBackend` | Imaging, Winit, and platform adapters | The platform owns handles; the core crosses a narrow backend boundary. |
| `Scene`, `SceneRenderer` | Imaging/Vello scene path | Both have a backend-neutral drawing seam; Moxi's shipped software path is deliberately small. |
| `CapabilityBus` | No direct Xilem equivalent | Moxi adds agent authorization and side-effect policy. |

Xilem deliberately separates these layers. Its repository contains Xilem
Core, the Xilem/Masonry adapter, the native Xilem package, and an experimental
web backend. The native stack is built around Winit, Imaging, Vello/wgpu in the
Linebender stack, Parley, and AccessKit.

- [Xilem README](https://github.com/linebender/xilem/blob/main/xilem/README.md)
- [Xilem architecture](https://github.com/linebender/xilem/blob/main/ARCHITECTURE.md)
- [Masonry `Widget` API](https://docs.rs/masonry/latest/masonry/core/trait.Widget.html)
- [Masonry virtual scrolling](https://docs.rs/masonry/latest/masonry/widgets/struct.VirtualScroll.html)
- [Parley](https://github.com/linebender/parley)
- [Vello](https://github.com/linebender/vello)

## Detailed comparison

| Area | Moxi 0.5 | Xilem |
| --- | --- | --- |
| Language | Mojo | Rust |
| Reactive model | A value component implements `build(bounds)` and `update(Event)`. Explicit `ActionQueue`, `StateScope`, lenses, memos, frame ticks, and deterministic tasks are available. | Typed view functions rerun after state changes and diff into retained widgets. |
| View representation | A flat, parent-aware `ViewNode` list with stable integer ids and typed component slots. | A typed lightweight view tree whose elements are Masonry widgets on native. |
| Reconciliation | `ColumnRuntime` matches `(id, kind)`, preserves retained storage, reports created/reused/updated/moved/removed counts, and emits changed/removed paint metadata. | Xilem compares new view values and performs minimal updates to the retained Masonry tree. |
| Layout | Linear columns/rows, padding, spacing, alignment, flexible slots, min/max constraints, intrinsic estimates, wrapping, stack, grid, split, and clipped portal containers. | Flex, grid, sized boxes, split panes, portals, z-stacks, and custom constraint-driven widgets. |
| Scrolling | Bounded portal scrolling, persistent offsets, clipping-aware hit testing, fixed/variable-extent range math, and a stable-key `VirtualRecycler`/`VirtualizedList` with measured heights, prefix offsets, overscan, anchor correction, and ensure-visible behavior. Scrollbars are not yet implemented. | Mature virtual scrolling widgets and viewport integration. |
| Rendering | Backend-neutral paint commands plus a scene IR. AppKit paints the native demo; `SoftwareSceneRenderer` is the deterministic oracle; `MacOSMetalRenderer` batches supported geometry, keeps an ASCII glyph fast path, rasterizes Unicode text through CoreText textures, uploads registered images, flattens quadratic/cubic/arc paths, and handles concave plus bounded even-odd compound/self-intersecting fills with blending, dynamic per-frame buffers, clips, transforms, synchronized CPU/GPU timing, and `CAMetalLayer` presentation. The interactive fractal path additionally uploads endpoints once and expands line quads in an instanced vertex shader; visible canvas frames use a three-slot async ring, while offscreen checksums synchronize. `SvgSceneRenderer` provides Web-compatible export. | Imaging abstraction with a high-performance 2D scene/rendering stack; Vello/wgpu is the current Linebender path. |
| Windowing | AppKit window/event bridge on macOS Apple Silicon, configurable size limits/resizability/fullscreen, portable lifecycle/scale contracts, native iOS/Android host shims, a framework-free browser host module, and host-side accessibility bridges. Mojo mobile/browser package targets and multi-window ownership are not shipped. | Winit-based native support plus an experimental DOM/web backend. |
| Text | Deterministic approximate portable shaping with script/direction/fallback runs and stable clusters; CoreText supplies native glyph ids, shaping, bidi, and fallback on macOS; Metal uses printable-ASCII geometry or a CoreText Unicode texture fallback. | Parley supplies rich layout, font fallback, shaping, bidi, segmentation, and editing infrastructure. |
| Accessibility | Backend-neutral roles, labels, values, hints, checked/expanded state, scalar ranges, bounds, parent links, and semantic actions; native macOS AX hierarchy exposes those attributes, state/value notifications, nested hit testing, and action bridge; Web maps snapshots to ARIA and iOS/Android expose virtual native nodes. | AccessKit-based accessibility integrated into the widget contract, with broader platform coverage. |
| Widgets | Label, button, text inputs, checkbox, progress, slider, switch, radio, image, multiline, combo, list, table, tree, menu, dialog, tabs, canvas, separator, containers, typed slots, and small state models. macOS collection presenters draw selection, headers/grids, disclosure, menu, dialog, tab, and canvas affordances from shared semantics; focused single-line text inputs use an AppKit field editor, while editable collection ownership remains open. | Broader and deeper widget layer, including platform-integrated controls and view composition. |
| Async | Deterministic frame-stepped scheduler with completion/cancel/fail results, bounded queues, and explicit task lifetime. External I/O/thread execution belongs to an adapter. | `task` views and reactive integration support asynchronous work in the broader framework. |
| Agent integration | In-process capability descriptors, schema checks, approvals, leases, typed handlers, replay, bounded queues, and conversation state. | No equivalent authorization/LLM capability bus; that is outside Xilem's stated UI scope. |
| Testing | Headless behavior tests, semantic snapshots, software-scene pixel/checksum checks, native compile checks, package-consumer checks, property-style edge cases, benchmark harness, and source-controlled visual references. | Masonry widget harness, interaction tests, render snapshots, and widget-tree snapshots. |
| Plotting | First-class typed stable-key table, executable versioned spec, field encodings, core/statistical recipes, categorical/temporal scales, independent facets, deterministic transforms, pan/zoom/brush/lasso/select/keyboard runtime, linked selection, line/scatter LOD, ordered `PlotRenderPacket` dense-mark path, PlotView, software/Metal/SVG scene output. | No direct plotting-library equivalent in the core comparison. |
| Maturity | Focused 0.5 package with hardened post-0.5 Metal/resource, shaping, variable-recycling, host-shim, and plotting slices; packaged non-macOS hosts remain unavailable. | Broader published project, but still explicitly alpha and subject to breaking changes. |

## Where Moxi is better

- Smaller conceptual surface and fewer dependencies.
- Mojo-native API and package workflow.
- Explicit ids, state transitions, bounds, dirty regions, queue limits, and diagnostics.
- Deterministic headless behavior and a deterministic software scene renderer.
- Direct AppKit integration, native IME/text behavior, and a compact native seam.
- A capability bus that makes agent-triggered side effects explicit and reviewable.
- A wxPython-style teaching showcase that exercises the real component contracts.

These are advantages for learning, embedding, and agent-facing applications;
they are not evidence that Moxi renders faster. The local benchmark is a
repeatability harness, not a comparative Xilem/Masonry performance result.

## Where Moxi is worse

- Metal now covers supported geometry, printable ASCII glyphs, CoreText Unicode
  texture text, registered image uploads, quadratic/cubic/arc paths, and
  concave plus bounded compound/self-intersecting fills. The dense fractal
  canvas has asynchronous pacing and GPU line expansion; generic GPU
  tessellation and portable typography remain open work.
- iOS, Android, and Web have native host shims, deterministic fallbacks, and
  host-side accessibility bridges, but no linked Mojo package targets or
  device CI is shipped; SVG remains an export fallback until the browser
  runtime is linked.
- Portable text remains approximate; there is no Parley-equivalent shaping or
  font-fallback engine outside the CoreText adapter.
- Virtualization now has measured variable-height builder/recycling and anchor
  correction, but it still lacks scrollbar widgets and richer viewport policy.
- Catalog controls have a deeper semantic/native macOS presentation now, and
  single-line text inputs use a real AppKit field editor; editable collection
  cells, menu tracking, full native control ownership, and device-level
  accessibility automation remain open.
- Plotting is now a useful typed 2D foundation, but it is not yet a Xilem/Vello-class
  rendering stack: violin/contour/candlestick families, true hexbin geometry,
  native text/path GPU work, and non-macOS hosts remain open.
- Native AppKit state is singleton-oriented; the portable multi-window model is not a native multi-window manager.
- The native queue/draw arrays retain fixed implementation ceilings, even though core queues are configurable and overflow is observable.
- Localized execution now has scope/dependency invalidation accounting, but no
  typed subtree builder or view-sequence diff comparable to Xilem's broader
  model.
- Narrower ecosystem, fewer backend implementations, and less external validation.

Xilem is not production-stable either: its own documentation calls the current
project alpha. The meaningful distinction is breadth and infrastructure, not
that one project is finished and the other is not.

## Remaining gaps, prioritized

These are residual gaps relative to a general UI framework, not failures
against the deliberately focused 0.5 release boundary.

### P0: foundations

1. Extend the Metal scene backend beyond the current asynchronous dense-line
   path with broader GPU text/image/path tessellation; Unicode textures,
   curve/elliptical-arc flattening, concave polygons, bounded even-odd
   compound fills, GPU timing, and bounded text-resource caching are now
   present.
2. Add a production portable shaping/font-fallback adapter; keep CoreText as
   the native reference path and retain the explicit approximate fallback.
3. Add scrollbar widgets and richer keyboard/touch reveal policy around the
   measured variable-height recycler.
4. Add automated native accessibility assertions and an AccessKit-equivalent
   cross-platform adapter contract; macOS, Web, iOS, and Android now have
   source-level semantic bridges, but device/screen-reader automation remains.

### P1: framework breadth

1. Add baseline/flex-style measurement and richer constraint negotiation while preserving deterministic existing layouts.
2. Deepen list/table/tree/menu/dialog/tabs/canvas rendering and editing instead of using label/panel fallbacks.
3. Replace root-only localized accounting with typed subtree execution and a stronger view-sequence abstraction.
4. Add native multi-window ownership, touch/gesture translation, and platform drag/drop adapters for macOS, iOS, Android, and Web.
5. Add external async transport/executor adapters with cancellation and deadlines while keeping the core scheduler deterministic.
6. Build the browser runtime and native mobile hosts behind the existing target contracts.

### P2: production hardening

1. Replace or make the native 128-slot-per-kind draw ceiling configurable; keep overflow observable until then.
2. Add iOS/Android/Web plus Windows/Linux CI and backend smoke tests as implementations land; current CI is macOS Apple Silicon only.
3. Run a like-for-like Moxi/Xilem/Masonry benchmark with published hardware, versions, workloads, and results.
4. Add fuzzing once the Mojo test/tooling path supports it; property-style deterministic checks now cover the critical edge contracts.
5. Capture native screenshots on macOS and add them to the visual QA record; source-controlled SVG references are present now.

### Agent-specific follow-up

The capability bus remains optional to the UI core. It still needs transport
adapters, an executor boundary, cancellation/deadlines, persistent audit
policy, and richer schema validation before it becomes a complete agent
runtime. The current in-process bus is a policy contract, not an LLM client.

## Implementation status

The backlog that motivated this comparison has been executed through the 0.5
boundary as follows:

| Slice | Status | Evidence |
| --- | --- | --- |
| Core/platform/render seams | Complete, with hardened Metal/SVG slices | `Component`, `WindowBackend`, `Renderer`, `SceneRenderer`, `MacOSMetalWindow`, `SvgSceneRenderer` |
| Layout and scrolling | Complete for the 0.5 contract; variable-height recycler slice added | stack/grid/split/portal, clipping, persistent scroll, `VirtualRecycler`, measured extents, anchor correction, tests |
| Rendering and resources | Deterministic/native contract complete; Metal geometry/resource/text slice hardened | resource handles, scene IR, software rasterizer, AppKit paths, Metal offscreen/visible demos, GPU ASCII fast path, CoreText Unicode textures, image cache, curve/arc flattening, concave/compound tessellation, GPU-instanced fractal lines, async three-slot canvas ring, CPU/GPU timing counters |
| Text and editing | Split contract complete; production portable shaping remains approximate | grapheme helpers, IME/selection/clipboard, CoreText glyph runs, script/fallback runs, bidi metadata |
| Components and reactivity | Complete for the focused catalog | descriptors, state models, action queues, memos/lenses/scopes, tasks |
| Accessibility and native actions | Deeper macOS slice plus host bridges; live package/device work remains | explicit semantic state/ranges, AppKit AX hierarchy/notifications/hit testing, AppKit text-field editor, Web ARIA mapper/overlay, iOS virtual elements, Android virtual node provider/action bridge |
| Hardening | Complete for 0.5 plus repeatable post-0.5 benchmarks | configurable core queues, property checks, analytics/plot/Metal benchmarks, package/release checks; native/cross-platform ceilings remain |
| Documentation and visual QA | Complete for source-controlled artifacts | comparison/API/architecture/performance/visual docs, plot/SVG references; native screenshot still requires a local macOS capture |
| Plotting foundation | Implemented as an experimental first library | `PlotDataTable`, statistical recipes, zero-copy views, `PlotSpec`, `PlotRuntime`, lasso/linking, facet resolution, LOD, accessibility, software/Metal/SVG output |

## Executed plan

1. **Boundary and baseline — complete.** Preserve the stable component/view API, keep platform handles out of core values, and exercise the shared wx scenario from tests and demos.
2. **Layout and scrolling — complete for 0.5.** Add stack/grid/split/portal, clipping-aware routing, persistent offsets, and virtual-range contracts; validate with deterministic geometry and interaction tests.
3. **Rendering and resources — complete for 0.5.** Add scene/resource seams, a deterministic software path, native image registration, and pixel/checksum tests.
4. **Text and editing — complete as a split contract.** Preserve native AppKit shaping/IME while making portable estimates and fallback behavior explicit.
5. **Components and reactivity — complete for 0.5.** Add the catalog, styles, state machines, semantic actions, task scheduler, queue bounds, and native presentation.
6. **Accessibility and platform coverage — macOS slice complete.** Add catalog roles/actions, native AX action dispatch, WindowConfig plumbing, and honest unavailable backend descriptors.
7. **Hardening and release — complete for 0.5.** Keep capacities observable, run property-style checks, refresh benchmarks, package-consumer checks, generated API docs, and visual references; the release gate now runs all of them.
8. **Post-0.5 slices — in progress.** Hardened Metal resources, CoreText/portable shaped runs, Unicode text textures, curve/concave/arc/compound path tessellation, synchronized CPU/GPU timing, GPU-instanced dense fractal lines, asynchronous visible canvas pacing, richer semantic AX state, deeper macOS collection presenters, AppKit single-line field ownership, variable-height recycling, localized accounting, Web/iOS/Android accessibility host shims, and the plotting foundation are now in tree; production portable shaping, generic GPU text/image/path tessellation, editable collection ownership, live mobile/browser package targets, and native screenshot automation remain.

The current validation entry point is:

```sh
pixi run release-check
```

The detailed source map is in [docs/API.md](API.md), the architecture
contract is in [ARCHITECTURE.md](../ARCHITECTURE.md), and visual acceptance
guidance is in [docs/visual.md](visual.md).

## Recommended positioning

Describe Moxi as “a Mojo-native, inspectable UI core with agent
capabilities and a plotting foundation,” not “Xilem for Mojo.” The highest-
value next architectural steps are production portable shaping, generic GPU
text/image/path tessellation, scrollbars/viewport policy, editable native
collection ownership, live mobile/browser package targets, and device-level
accessibility automation.
The capability bus should remain an optional first-class integration
rather than becoming entangled with rendering.
