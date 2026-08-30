# Moxi and Xilem

Status: comparison and implementation plan for Moxi 0.5, checked against
Xilem's upstream documentation and repository links on 2026-08-30.

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
| Scrolling | Bounded portal scrolling, persistent offsets, clipping-aware hit testing, and fixed-extent virtual-range math. | Mature virtual scrolling widgets and viewport integration. |
| Rendering | Backend-neutral paint commands plus a scene IR. AppKit paints the native demo; `SoftwareSceneRenderer` deterministically rasterizes basic shapes, gradients, lines, and declared path bounds. | Imaging abstraction with a high-performance 2D scene/rendering stack; Vello/wgpu is the current Linebender path. |
| Windowing | AppKit window/event bridge on macOS Apple Silicon, configurable size limits/resizability/fullscreen, and a portable `WindowManager` model. Native multi-window ownership is not shipped. | Winit-based native support plus an experimental DOM/web backend. |
| Text | Deterministic codepoint estimates and grapheme-aware boundary helpers in portable code; AppKit supplies native shaping/bidi/IME. | Parley supplies rich layout, font fallback, shaping, bidi, segmentation, and editing infrastructure. |
| Accessibility | Backend-neutral roles, labels, values, state, bounds, parent links, and semantic actions for the catalog; native macOS AX hierarchy and action bridge. | AccessKit-based accessibility integrated into the widget contract, with broader platform coverage. |
| Widgets | Label, button, text inputs, checkbox, progress, slider, switch, radio, image, multiline, combo, list, table, tree, menu, dialog, tabs, canvas, separator, containers, typed slots, and small state models. Catalog controls are intentionally shallow and some native paths use label/panel fallbacks. | Broader and deeper widget layer, including platform-integrated controls and view composition. |
| Async | Deterministic frame-stepped scheduler with completion/cancel/fail results, bounded queues, and explicit task lifetime. External I/O/thread execution belongs to an adapter. | `task` views and reactive integration support asynchronous work in the broader framework. |
| Agent integration | In-process capability descriptors, schema checks, approvals, leases, typed handlers, replay, bounded queues, and conversation state. | No equivalent authorization/LLM capability bus; that is outside Xilem's stated UI scope. |
| Testing | Headless behavior tests, semantic snapshots, software-scene pixel/checksum checks, native compile checks, package-consumer checks, property-style edge cases, benchmark harness, and source-controlled visual references. | Masonry widget harness, interaction tests, render snapshots, and widget-tree snapshots. |
| Maturity | Focused experimental 0.5 package with an honest macOS boundary. | Broader published project, but still explicitly alpha and subject to breaking changes. |

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

- No shipped Metal/Vello/wgpu GPU renderer and no retained GPU surface path.
- No implemented Windows, Linux, web, or cross-platform accessibility backend.
- Portable text remains an estimate/fallback contract; there is no Parley-equivalent shaping or font fallback engine.
- Virtualization currently provides range math rather than a complete virtualized view builder with scrollbars and item recycling.
- Catalog controls have semantic/state coverage, but many native macOS render through intentionally shallow label/panel fallbacks.
- Native AppKit state is singleton-oriented; the portable multi-window model is not a native multi-window manager.
- The native queue/draw arrays retain fixed implementation ceilings, even though core queues are configurable and overflow is observable.
- No localized component execution, automatic dependency graph, or typed view-sequence diff comparable to Xilem's broader model.
- Narrower ecosystem, fewer backend implementations, and less external validation.

Xilem is not production-stable either: its own documentation calls the current
project alpha. The meaningful distinction is breadth and infrastructure, not
that one project is finished and the other is not.

## Remaining gaps, prioritized

These are residual gaps relative to a general UI framework, not failures
against the deliberately focused 0.5 release boundary.

### P0: foundations

1. Add a real GPU scene backend, preferably Metal on the current target, behind `SceneRenderer` and the existing resource contract.
2. Add a portable shaping/font-fallback implementation or an explicit adapter to one; keep AppKit as the native reference path.
3. Turn `VirtualListState` into a view-builder/recycling API with visible-item semantics, scrollbars, and keyboard reveal/ensure-visible behavior.
4. Add automated native accessibility assertions and an AccessKit-equivalent cross-platform adapter contract.

### P1: framework breadth

1. Add baseline/flex-style measurement and richer constraint negotiation while preserving deterministic existing layouts.
2. Deepen list/table/tree/menu/dialog/tabs/canvas rendering and editing instead of using label/panel fallbacks.
3. Add localized component invalidation/dependency tracking and a stronger typed view-sequence abstraction.
4. Add native multi-window ownership, touch/gesture translation, and platform drag/drop adapters.
5. Add external async transport/executor adapters with cancellation and deadlines while keeping the core scheduler deterministic.

### P2: production hardening

1. Replace or make the native 128-slot-per-kind draw ceiling configurable; keep overflow observable until then.
2. Add Windows/Linux/web CI and backend smoke tests as implementations land; current CI is macOS Apple Silicon only.
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
| Core/platform/render seams | Complete | `Component`, `WindowBackend`, `Renderer`, `SceneRenderer`, headless adapters |
| Layout and scrolling | Complete for the 0.5 contract | stack/grid/split/portal, clipping, persistent scroll, virtual-range math, tests |
| Rendering and resources | Complete for the deterministic/native contract | resource handles, scene IR, software rasterizer, AppKit image/control paths |
| Text and editing | Complete as an explicit fallback boundary | grapheme helpers, IME/selection/clipboard, AppKit shaping/bidi, fallback flags |
| Components and reactivity | Complete for the focused catalog | descriptors, state models, action queues, memos/lenses/scopes, tasks |
| Accessibility and native actions | Complete for the macOS 0.5 surface | semantic roles/actions, AX hierarchy, AX action queue bridge |
| Hardening | Complete for 0.5 | configurable core queues, property checks, benchmark, package/release checks; native/cross-platform ceilings remain |
| Documentation and visual QA | Complete for source-controlled artifacts | comparison/API/architecture/visual docs and SVG references; native screenshot still requires a local macOS capture |

## Executed plan

1. **Boundary and baseline — complete.** Preserve the stable component/view API, keep platform handles out of core values, and exercise the shared wx scenario from tests and demos.
2. **Layout and scrolling — complete for 0.5.** Add stack/grid/split/portal, clipping-aware routing, persistent offsets, and virtual-range contracts; validate with deterministic geometry and interaction tests.
3. **Rendering and resources — complete for 0.5.** Add scene/resource seams, a deterministic software path, native image registration, and pixel/checksum tests.
4. **Text and editing — complete as a split contract.** Preserve native AppKit shaping/IME while making portable estimates and fallback behavior explicit.
5. **Components and reactivity — complete for 0.5.** Add the catalog, styles, state machines, semantic actions, task scheduler, queue bounds, and native presentation.
6. **Accessibility and platform coverage — macOS slice complete.** Add catalog roles/actions, native AX action dispatch, WindowConfig plumbing, and honest unavailable backend descriptors.
7. **Hardening and release — complete for 0.5.** Keep capacities observable, run property-style checks, refresh benchmarks, package-consumer checks, generated API docs, and visual references; the release gate now runs all of them.
8. **Post-0.5 follow-up.** Implement GPU, portable text, true virtualization, deeper native widgets, cross-platform backends, and native screenshot automation in that order.

The current validation entry point is:

```sh
pixi run release-check
```

The detailed source map is in [docs/API.md](API.md), the architecture
contract is in [ARCHITECTURE.md](../ARCHITECTURE.md), and visual acceptance
guidance is in [docs/visual.md](visual.md).

## Recommended positioning

Describe Moxi as “a Mojo-native, inspectable UI core with agent
capabilities,” not “Xilem for Mojo.” The highest-value next architectural
step is a real GPU/resource backend, followed by portable text and true
virtualization. The capability bus should remain an optional first-class
integration rather than becoming entangled with rendering.
